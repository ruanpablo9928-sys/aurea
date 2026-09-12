#pragma once

#include "OpticalFlowTypes.h"
#include "../scene3d/DeviceProfile.h"
#include <atomic>
#include <mutex>

namespace aurea {

class QualityController {
public:
    explicit QualityController(DeviceTier tier = DeviceTier::Medium);
    ~QualityController() = default;

    void setDeviceTier(DeviceTier tier) { tier_ = tier; }
    DeviceTier getDeviceTier() const { return tier_; }

    // Registra métrica de tempo de inferência do último quadro
    void recordInferenceTime(float timeMs);

    // Avalia o fator de escala ideal de resolução [0.5, 0.75, 1.0] para o contexto atual
    float getRecommendedScale(FlowQuality quality, bool isPreview, bool isScrubbing) const;

    // Número de quadros que podem ser antecipados (prefetch) sem sobrecarregar a memória
    int getMaxPrefetchFrames(bool isScrubbing) const;

    // Métricas
    float getAverageInferenceTimeMs() const { return avgInferenceTimeMs_.load(); }
    float getLastInferenceTimeMs() const { return lastInferenceTimeMs_.load(); }

private:
    DeviceTier tier_ = DeviceTier::Medium;
    std::atomic<float> lastInferenceTimeMs_{0.0f};
    std::atomic<float> avgInferenceTimeMs_{0.0f};
    int sampleCount_ = 0;
    mutable std::mutex mutex_;
};

} // namespace aurea
