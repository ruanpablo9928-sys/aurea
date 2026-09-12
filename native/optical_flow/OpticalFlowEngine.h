#pragma once

#include "OpticalFlowTypes.h"
#include "VulkanBackend.h"
#include "NCNNBackend.h"
#include "SceneCutDetector.h"
#include "FlowFrameCache.h"
#include "QualityController.h"
#include "InterpolationScheduler.h"
#include "GPUTextureBridge.h"
#include "RIFEModelManager.h"
#include "../video/ffmpeg/FFmpegTypes.h"
#include "../scene3d/DeviceProfile.h"
#include <memory>
#include <chrono>

namespace aurea {

class OpticalFlowEngine {
public:
    OpticalFlowEngine();
    ~OpticalFlowEngine();

    // Inicialização orientada às capacidades do dispositivo
    bool initialize(const DeviceCapabilities& capabilities);
    void shutdown();

    bool isAvailable() const;
    bool isModelLoaded() const;

    void setGPU(std::shared_ptr<GPUProcessor> gpu);

    // Carregamento de modelo com configuração explícita
    bool loadModel(const RIFEModelConfig& config);

    // Carregamento automático pelo nível de qualidade e contexto
    bool loadOptimalModel(FlowQuality quality, bool isPreview);

    // Interpolação síncrona determinística (para EXPORT e cálculo imediato)
    std::shared_ptr<InterpolatedFrame> interpolate(const DecodedVideoFrame& frameA,
                                                   const DecodedVideoFrame& frameB,
                                                   float t,
                                                   const FlowInterpolationRequest& request);

    // Obtenção direta de textura GPU para renderização de camada de vídeo no RenderCore
    uint32_t getInterpolatedTexture(const DecodedVideoFrame& frameA,
                                   const DecodedVideoFrame& frameB,
                                   float t,
                                   const FlowInterpolationRequest& request);

    // Interpolação assíncrona para prévia e playback (não bloqueia UI)
    void requestInterpolationAsync(const DecodedVideoFrame& frameA,
                                  const DecodedVideoFrame& frameB,
                                  float t,
                                  const FlowInterpolationRequest& request,
                                  InterpolationCompleteCallback callback);

    // Atualiza a geração ativa (descarta instantaneamente requisições obsoletas durante scrubbing)
    void setScrubbingGeneration(uint64_t generationId);

    // Configuração de qualidade e limiares
    void setQuality(FlowQuality quality) { quality_ = quality; }
    FlowQuality getQuality() const { return quality_; }

    void setSceneCutThreshold(float threshold);

    void clearCache();

    // Diagnósticos internos (para Debug HUD / telemetria)
    OpticalFlowDiagnostics getDiagnostics() const;

    std::shared_ptr<FlowFrameCache> getCache() const { return cache_; }
    std::shared_ptr<QualityController> getQualityController() const { return qualityController_; }

private:
    bool initialized_ = false;
    FlowQuality quality_ = FlowQuality::High;
    RIFEModelConfig currentConfig_;

    std::shared_ptr<VulkanBackend> vulkan_;
    std::shared_ptr<NCNNBackend> ncnn_;
    std::shared_ptr<SceneCutDetector> sceneCutDetector_;
    std::shared_ptr<FlowFrameCache> cache_;
    std::shared_ptr<QualityController> qualityController_;
    std::shared_ptr<InterpolationScheduler> scheduler_;
    std::shared_ptr<GPUTextureBridge> textureBridge_;

    mutable std::mutex mutex_;
    uint64_t nextRequestId_ = 1;
};

} // namespace aurea
