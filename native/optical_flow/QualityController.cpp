#include "QualityController.h"
#include <algorithm>

namespace aurea {

QualityController::QualityController(DeviceTier tier)
    : tier_(tier) {}

void QualityController::recordInferenceTime(float timeMs) {
    lastInferenceTimeMs_.store(timeMs);

    std::lock_guard<std::mutex> lock(mutex_);
    sampleCount_++;
    // Média móvel exponencial (EMA) com alpha = 0.2
    float currentAvg = avgInferenceTimeMs_.load();
    if (sampleCount_ <= 1) {
        currentAvg = timeMs;
    } else {
        currentAvg = 0.8f * currentAvg + 0.2f * timeMs;
    }
    avgInferenceTimeMs_.store(currentAvg);
}

float QualityController::getRecommendedScale(FlowQuality quality, bool isPreview, bool isScrubbing) const {
    if (!isPreview) {
        // Export sempre renderiza a 100% da resolução
        return 1.0f;
    }

    // Durante scrubbing rápido na timeline, prioriza responsividade máxima
    if (isScrubbing) {
        return (tier_ <= DeviceTier::Medium) ? 0.5f : 0.75f;
    }

    float avgMs = avgInferenceTimeMs_.load();

    switch (quality) {
        case FlowQuality::Low:
            return 0.5f;
        case FlowQuality::Medium:
            if (avgMs > 25.0f && tier_ <= DeviceTier::Medium) {
                return 0.5f; // Sobrecarga detectada: reduz escala para preservar FPS
            }
            return 0.75f;
        case FlowQuality::High:
            if (avgMs > 35.0f && tier_ <= DeviceTier::Medium) {
                return 0.75f;
            }
            return 1.0f;
        case FlowQuality::Ultra:
            return 1.0f;
    }

    return 1.0f;
}

int QualityController::getMaxPrefetchFrames(bool isScrubbing) const {
    if (isScrubbing) {
        return 0; // Scrubbing: zero prefetch para não entupir a fila
    }

    switch (tier_) {
        case DeviceTier::Low:
            return 1;
        case DeviceTier::Medium:
            return 2;
        case DeviceTier::High:
        case DeviceTier::Ultra:
            return 3;
    }

    return 1;
}

} // namespace aurea
