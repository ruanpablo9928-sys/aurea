#pragma once

#include "time_remap/TimeRemapProperty.h"
#include "ffmpeg/FFmpegVideoDecoder.h"
#include "cache/VideoFrameCache.h"
#include "cache/PrefetchManager.h"
#include "../renderer/GPUProcessor.h"
#include <string>
#include <memory>
#include <cstdint>
#include <unordered_map>
#include <mutex>

namespace aurea {

class VideoTrack {
public:
    VideoTrack(const std::string& filePath, std::shared_ptr<GPUProcessor> gpu);
    ~VideoTrack();

    bool open();
    void close();
    bool isOpen() const { return isOpen_; }

    int getWidth() const;
    int getHeight() const;
    int64_t getDurationUs() const;

    // Obtém textura GPU do quadro correspondente a compositionTimeUs avaliado via Time Remap
    uint32_t getFrameTextureAt(int64_t compositionTimeUs, const TimeRemapProperty& remap, uint64_t generationId = 0, bool exactSync = false);

    std::shared_ptr<FFmpegVideoDecoder> getDecoder() const { return decoder_; }
    std::shared_ptr<VideoFrameCache> getCache() const { return cache_; }

private:
    std::string filePath_;
    std::shared_ptr<GPUProcessor> gpu_;
    bool isOpen_ = false;

    std::shared_ptr<FFmpegVideoDecoder> decoder_;
    std::shared_ptr<VideoFrameCache> cache_;
    std::shared_ptr<PrefetchManager> prefetch_;

    std::shared_ptr<GPUTexture> currentGpuTexture_;
    int64_t lastPtsUs_ = -1;
    mutable std::mutex mutex_;
};

class VideoEngine {
public:
    VideoEngine();
    ~VideoEngine();

    void setGPU(std::shared_ptr<GPUProcessor> gpu) { gpu_ = gpu; }

    std::shared_ptr<VideoTrack> loadVideo(const std::string& filePath);
    void releaseVideo(const std::string& filePath);

    // Obtém textura para uma camada de vídeo no instante da composição
    uint32_t getFrameTexture(const std::string& filePath, int64_t compositionTimeUs, const TimeRemapProperty& remap, uint64_t generationId = 0, bool exactSync = false);

    void clearCache();

private:
    std::shared_ptr<GPUProcessor> gpu_;
    std::unordered_map<std::string, std::shared_ptr<VideoTrack>> tracks_;
    mutable std::mutex mutex_;
};

} // namespace aurea
