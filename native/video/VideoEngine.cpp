#include "VideoEngine.h"
#include <iostream>

namespace aurea {

VideoTrack::VideoTrack(const std::string& filePath, std::shared_ptr<GPUProcessor> gpu)
    : filePath_(filePath), gpu_(gpu) {
    decoder_ = std::make_shared<FFmpegVideoDecoder>();
    cache_ = std::make_shared<VideoFrameCache>(128 * 1024 * 1024); // 128 MB
    prefetch_ = std::make_shared<PrefetchManager>(decoder_, cache_);

    // Registra callback do decoder para alimentar o cache automaticamente
    auto weakCache = std::weak_ptr<VideoFrameCache>(cache_);
    decoder_->setFrameCallback([weakCache](std::shared_ptr<DecodedVideoFrame> frame) {
        if (auto c = weakCache.lock()) {
            c->put(frame);
        }
    });
}

VideoTrack::~VideoTrack() {
    close();
}

bool VideoTrack::open() {
    if (isOpen_) return true;
    if (!decoder_->open(filePath_)) {
        return false;
    }
    isOpen_ = true;
    return true;
}

void VideoTrack::close() {
    if (!isOpen_) return;
    decoder_->close();
    cache_->clear();
    currentGpuTexture_.reset();
    isOpen_ = false;
}

int VideoTrack::getWidth() const {
    return decoder_->getStreamInfo().width;
}

int VideoTrack::getHeight() const {
    return decoder_->getStreamInfo().height;
}

int64_t VideoTrack::getDurationUs() const {
    return decoder_->getStreamInfo().durationUs;
}

uint32_t VideoTrack::getFrameTextureAt(int64_t compositionTimeUs, const TimeRemapProperty& remap, uint64_t generationId, bool exactSync) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!isOpen_) {
        if (!open()) return 0;
    }

    // 1. Mapeamento temporal de Composição -> Tempo da Fonte (PTS)
    double compSec = static_cast<double>(compositionTimeUs) / 1000000.0;
    double sourceSec = remap.evaluate(compSec);
    int64_t sourcePtsUs = static_cast<int64_t>(sourceSec * 1000000.0);

    // 2. Dispara pré-busca adaptativa para playback em tempo real
    if (!exactSync && prefetch_) {
        prefetch_->onCompositionTick(compSec, remap, generationId);
    }

    // 3. Tenta obter do cache (L1/L2)
    auto frame = cache_->get(sourcePtsUs);
    if (!frame) {
        if (exactSync) {
            // Decodificação síncrona determinística frame a frame para exportação
            frame = decoder_->decodeExactSync(sourcePtsUs);
            if (frame) {
                cache_->put(frame);
            }
        } else {
            // Decodificação assíncrona orientada a pipeline para preview de baixa latência
            decoder_->requestFrame(sourcePtsUs, generationId);
            frame = decoder_->getLatestFrame();
        }
    }

    if (!frame || frame->rgbaData.empty()) {
        return currentGpuTexture_ ? currentGpuTexture_->id : 0;
    }

    // 4. Se o quadro for novo, aloca textura e envia os pixels para GPU
    if (gpu_ && frame->ptsUs != lastPtsUs_) {
        if (!currentGpuTexture_ ||
            currentGpuTexture_->width != frame->width ||
            currentGpuTexture_->height != frame->height) {
            currentGpuTexture_ = gpu_->acquireTexture(frame->width, frame->height);
        }

        if (currentGpuTexture_) {
            gpu_->uploadTextureRGBA(currentGpuTexture_->id, frame->width, frame->height, frame->rgbaData.data());
        }

        lastPtsUs_ = frame->ptsUs;
    }

    return currentGpuTexture_ ? currentGpuTexture_->id : 0;
}

VideoEngine::VideoEngine() = default;

VideoEngine::~VideoEngine() {
    clearCache();
}

std::shared_ptr<VideoTrack> VideoEngine::loadVideo(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = tracks_.find(filePath);
    if (it != tracks_.end()) {
        return it->second;
    }

    auto track = std::make_shared<VideoTrack>(filePath, gpu_);
    tracks_[filePath] = track;
    return track;
}

void VideoEngine::releaseVideo(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = tracks_.find(filePath);
    if (it != tracks_.end()) {
        it->second->close();
        tracks_.erase(it);
    }
}

uint32_t VideoEngine::getFrameTexture(const std::string& filePath, int64_t compositionTimeUs, const TimeRemapProperty& remap, uint64_t generationId, bool exactSync) {
    auto track = loadVideo(filePath);
    if (!track) return 0;
    return track->getFrameTextureAt(compositionTimeUs, remap, generationId, exactSync);
}

void VideoEngine::clearCache() {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& pair : tracks_) {
        pair.second->close();
    }
    tracks_.clear();
}

} // namespace aurea
