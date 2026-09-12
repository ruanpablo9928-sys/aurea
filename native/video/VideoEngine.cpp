#include "VideoEngine.h"
#include "../optical_flow/OpticalFlowEngine.h"
#include <iostream>
#include <cmath>

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
    double speed = remap.getSpeed(compSec);

    // Freeze Frame: se velocidade for 0 e já houver textura renderizada, reutiliza imediatamente (Zero GPU compute)
    if (std::abs(speed) < 1e-4 && currentGpuTexture_ && lastPtsUs_ >= 0 && !exactSync) {
        return currentGpuTexture_->id;
    }

    // 2. Dispara pré-busca adaptativa para playback em tempo real
    if (!exactSync && prefetch_) {
        prefetch_->onCompositionTick(compSec, remap, generationId);
    }

    // 3. Localiza os quadros delimitadores [Frame A, Frame B] e fator de interpolação t
    int64_t ptsA = 0, ptsB = 0;
    float t = 0.0f;
    decoder_->getTimeMapper().findBoundingFrames(sourcePtsUs, ptsA, ptsB, t);

    // Se t estiver nos extremos ou se optical flow não estiver ativo, busca quadro discreto
    if (!opticalFlow_ || ptsA == ptsB || t <= 0.01f || t >= 0.99f) {
        int64_t targetPts = (t >= 0.99f) ? ptsB : ptsA;
        auto frame = cache_->get(targetPts);
        if (!frame) {
            if (exactSync) {
                DecodedVideoFrame syncFrame;
                if (decoder_->decodeExactFrameSync(targetPts, syncFrame)) {
                    frame = std::make_shared<DecodedVideoFrame>(std::move(syncFrame));
                    cache_->put(frame);
                }
            } else {
                decoder_->requestFrame(targetPts, generationId);
                frame = decoder_->getLatestFrame();
            }
        }

        if (!frame || frame->rgbaData.empty()) {
            return currentGpuTexture_ ? currentGpuTexture_->id : 0;
        }

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

    // 4. Interpolação via Optical Flow / RIFE
    auto frameA = cache_->get(ptsA);
    auto frameB = cache_->get(ptsB);

    if (exactSync) {
        if (!frameA) {
            DecodedVideoFrame syncA;
            if (decoder_->decodeExactFrameSync(ptsA, syncA)) {
                frameA = std::make_shared<DecodedVideoFrame>(std::move(syncA));
                cache_->put(frameA);
            }
        }
        if (!frameB) {
            DecodedVideoFrame syncB;
            if (decoder_->decodeExactFrameSync(ptsB, syncB)) {
                frameB = std::make_shared<DecodedVideoFrame>(std::move(syncB));
                cache_->put(frameB);
            }
        }
    } else {
        if (!frameA) decoder_->requestFrame(ptsA, generationId);
        if (!frameB) decoder_->requestFrame(ptsB, generationId);
        if (!frameA) frameA = decoder_->getLatestFrame();
        if (!frameB) frameB = decoder_->getLatestFrame();
    }

    if (frameA && frameB && !frameA->rgbaData.empty() && !frameB->rgbaData.empty()) {
        FlowInterpolationRequest req;
        req.ptsAUs = ptsA;
        req.ptsBUs = ptsB;
        req.targetPtsUs = sourcePtsUs;
        req.t = t;
        req.generationId = generationId;
        req.exportMode = exactSync;
        req.preview = !exactSync;
        req.quality = exactSync ? FlowQuality::Ultra : opticalFlow_->getQuality();

        uint32_t flowTex = opticalFlow_->getInterpolatedTexture(*frameA, *frameB, t, req);
        if (flowTex != 0) {
            lastPtsUs_ = sourcePtsUs;
            return flowTex;
        }
    }

    // Fallback: se os quadros interpolados ainda não estiverem prontos no preview, exibe o mais recente
    auto fallbackFrame = frameA ? frameA : decoder_->getLatestFrame();
    if (fallbackFrame && !fallbackFrame->rgbaData.empty() && gpu_) {
        if (!currentGpuTexture_ ||
            currentGpuTexture_->width != fallbackFrame->width ||
            currentGpuTexture_->height != fallbackFrame->height) {
            currentGpuTexture_ = gpu_->acquireTexture(fallbackFrame->width, fallbackFrame->height);
        }
        if (currentGpuTexture_) {
            gpu_->uploadTextureRGBA(currentGpuTexture_->id, fallbackFrame->width, fallbackFrame->height, fallbackFrame->rgbaData.data());
        }
        lastPtsUs_ = fallbackFrame->ptsUs;
    }

    return currentGpuTexture_ ? currentGpuTexture_->id : 0;
}

VideoEngine::VideoEngine() = default;

VideoEngine::~VideoEngine() {
    clearCache();
}

void VideoEngine::setGPU(std::shared_ptr<GPUProcessor> gpu) {
    std::lock_guard<std::mutex> lock(mutex_);
    gpu_ = gpu;
    if (opticalFlow_) {
        opticalFlow_->setGPU(gpu_);
    }
}

void VideoEngine::setOpticalFlowEngine(std::shared_ptr<OpticalFlowEngine> flowEngine) {
    std::lock_guard<std::mutex> lock(mutex_);
    opticalFlow_ = flowEngine;
    if (opticalFlow_ && gpu_) {
        opticalFlow_->setGPU(gpu_);
    }
    for (auto& pair : tracks_) {
        pair.second->setOpticalFlowEngine(opticalFlow_);
    }
}

std::shared_ptr<VideoTrack> VideoEngine::loadVideo(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = tracks_.find(filePath);
    if (it != tracks_.end()) {
        return it->second;
    }

    auto track = std::make_shared<VideoTrack>(filePath, gpu_);
    if (opticalFlow_) {
        track->setOpticalFlowEngine(opticalFlow_);
    }
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
