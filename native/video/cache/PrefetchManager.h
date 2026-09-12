#pragma once

#include "../time_remap/TimeRemapProperty.h"
#include "../ffmpeg/FFmpegVideoDecoder.h"
#include "VideoFrameCache.h"
#include <memory>
#include <atomic>

namespace aurea {

enum class PlaybackDirection {
    Forward,
    Reverse,
    Freeze
};

class PrefetchManager {
public:
    PrefetchManager(std::shared_ptr<FFmpegVideoDecoder> decoder,
                    std::shared_ptr<VideoFrameCache> cache);
    ~PrefetchManager() = default;

    // Notifica avanço do playhead da composição para engatilhar prefetch inteligente
    void onCompositionTick(double currentCompTime,
                           const TimeRemapProperty& remapProperty,
                           uint64_t generationId,
                           int prefetchCount = 4);

    PlaybackDirection getCurrentDirection() const { return currentDirection_; }
    double getCurrentSpeed() const { return currentSpeed_; }

private:
    std::shared_ptr<FFmpegVideoDecoder> decoder_;
    std::shared_ptr<VideoFrameCache> cache_;

    std::atomic<PlaybackDirection> currentDirection_{PlaybackDirection::Forward};
    std::atomic<double> currentSpeed_{1.0};
};

} // namespace aurea
