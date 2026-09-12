#include "PrefetchManager.h"
#include <cmath>

namespace aurea {

PrefetchManager::PrefetchManager(std::shared_ptr<FFmpegVideoDecoder> decoder,
                                 std::shared_ptr<VideoFrameCache> cache)
    : decoder_(decoder), cache_(cache) {
}

void PrefetchManager::onCompositionTick(double currentCompTime,
                                       const TimeRemapProperty& remapProperty,
                                       uint64_t generationId,
                                       int prefetchCount) {
    if (!decoder_ || !decoder_->isOpen() || !cache_) return;

    double speed = remapProperty.getSpeed(currentCompTime);
    currentSpeed_ = speed;

    if (std::abs(speed) < 0.05) {
        // Freeze frame: não despacha decodificação desnecessária
        currentDirection_ = PlaybackDirection::Freeze;
        return;
    }

    if (speed < 0.0) {
        currentDirection_ = PlaybackDirection::Reverse;
    } else {
        currentDirection_ = PlaybackDirection::Forward;
    }

    // Intervalo de tempo do prefetch (ex: próximo quadro da timeline a cada 1/30s)
    double dtStep = 1.0 / std::max(24.0, decoder_->getStreamInfo().fps);
    if (speed < 0.0) {
        dtStep = -dtStep;
    }

    for (int i = 1; i <= prefetchCount; ++i) {
        double futureCompTime = currentCompTime + (dtStep * i);
        if (futureCompTime < 0.0) break;

        double targetSourceTime = remapProperty.evaluate(futureCompTime);
        int64_t targetPtsUs = static_cast<int64_t>(targetSourceTime * 1000000.0);

        // Se já estiver em cache, pula
        if (cache_->get(targetPtsUs) != nullptr) {
            continue;
        }

        // Solicita ao decoder assíncrono em background
        decoder_->requestFrame(targetPtsUs, generationId, SeekAccuracy::ExactFrame);
    }
}

} // namespace aurea
