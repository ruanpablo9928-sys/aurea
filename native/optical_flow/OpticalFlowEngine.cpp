#include "OpticalFlowEngine.h"
#include <cstring>
#include <chrono>

namespace aurea {

OpticalFlowEngine::OpticalFlowEngine() {
    vulkan_ = std::make_shared<VulkanBackend>();
    ncnn_ = std::make_shared<NCNNBackend>();
    sceneCutDetector_ = std::make_shared<SceneCutDetector>();
    cache_ = std::make_shared<FlowFrameCache>();
    qualityController_ = std::make_shared<QualityController>();
    scheduler_ = std::make_shared<InterpolationScheduler>(2);
    textureBridge_ = std::make_shared<GPUTextureBridge>(nullptr);
}

OpticalFlowEngine::~OpticalFlowEngine() {
    shutdown();
}

bool OpticalFlowEngine::initialize(const DeviceCapabilities& capabilities) {
    std::lock_guard<std::mutex> lock(mutex_);
    qualityController_->setDeviceTier(capabilities.tier);

    // Ajusta o orçamento de RAM do cache baseado na memória do dispositivo
    size_t cacheBudget = (capabilities.totalRamMb > 6000) ? (256 * 1024 * 1024) : (128 * 1024 * 1024);
    cache_->setMaxMemoryBytes(cacheBudget);

    // Inicializa Vulkan e NCNN
    vulkan_->initialize();
    ncnn_->initialize(vulkan_);

    // Carrega o modelo ideal baseado no tier do aparelho
    loadOptimalModel(quality_, true);

    initialized_ = true;
    return true;
}

void OpticalFlowEngine::shutdown() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!initialized_) return;

    if (scheduler_) scheduler_->stop();
    if (textureBridge_) textureBridge_->clear();
    if (cache_) cache_->clear();
    if (ncnn_) ncnn_->shutdown();
    if (vulkan_) vulkan_->shutdown();

    initialized_ = false;
}

bool OpticalFlowEngine::isAvailable() const {
    return initialized_;
}

bool OpticalFlowEngine::isModelLoaded() const {
    return ncnn_ && ncnn_->isModelLoaded();
}

void OpticalFlowEngine::setGPU(std::shared_ptr<GPUProcessor> gpu) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (textureBridge_) {
        textureBridge_->setGPU(gpu);
    }
}

bool OpticalFlowEngine::loadModel(const RIFEModelConfig& config) {
    std::lock_guard<std::mutex> lock(mutex_);
    currentConfig_ = config;
    return ncnn_->loadModel(config);
}

bool OpticalFlowEngine::loadOptimalModel(FlowQuality quality, bool isPreview) {
    int tier = static_cast<int>(qualityController_->getDeviceTier());
    auto config = RIFEModelManager::instance().selectOptimalConfig(quality, isPreview, tier);
    return loadModel(config);
}

std::shared_ptr<InterpolatedFrame> OpticalFlowEngine::interpolate(const DecodedVideoFrame& frameA,
                                                               const DecodedVideoFrame& frameB,
                                                               float t,
                                                               const FlowInterpolationRequest& request) {
    if (frameA.width <= 0 || frameA.height <= 0) {
        return nullptr;
    }

    const int width = frameA.width;
    const int height = frameA.height;

    // 1. Otimização de Extremidades: t == 0.0 -> Frame A, t == 1.0 -> Frame B
    if (t <= 0.001f) {
        auto out = std::make_shared<InterpolatedFrame>();
        out->ptsUs = frameA.ptsUs;
        out->targetPtsUs = request.targetPtsUs;
        out->width = width;
        out->height = height;
        out->rgbaData = frameA.rgbaData;
        out->generationId = request.generationId;
        return out;
    }

    if (t >= 0.999f) {
        auto out = std::make_shared<InterpolatedFrame>();
        out->ptsUs = frameB.ptsUs;
        out->targetPtsUs = request.targetPtsUs;
        out->width = width;
        out->height = height;
        out->rgbaData = frameB.rgbaData;
        out->generationId = request.generationId;
        return out;
    }

    // 2. Consulta de Cache L3 (FlowFrameCache)
    FlowCacheKey key;
    key.ptsAUs = frameA.ptsUs;
    key.ptsBUs = frameB.ptsUs;
    key.quantizedT = FlowFrameCache::quantizeTime(t);
    key.width = width;
    key.height = height;
    key.quality = request.quality;
    key.modelVersion = currentConfig_.modelVersion;

    auto cached = cache_->get(key);
    if (cached) {
        cached->isCached = true;
        return cached;
    }

    auto out = std::make_shared<InterpolatedFrame>();
    out->ptsUs = static_cast<int64_t>(frameA.ptsUs + t * (frameB.ptsUs - frameA.ptsUs));
    out->targetPtsUs = request.targetPtsUs;
    out->width = width;
    out->height = height;
    out->generationId = request.generationId;
    out->rgbaData.resize(static_cast<size_t>(width * height * 4));

    // 3. Detecção de Corte de Cena (Scene Cut Detection)
    // Se houver um corte drástico entre Frame A e Frame B, NUNCA interpola RIFE para evitar deformação/ghosting
    if (sceneCutDetector_->isSceneCut(frameA.rgbaData.data(), frameB.rgbaData.data(), width, height)) {
        out->isSceneCut = true;
        const auto& chosenSource = (t < 0.5f) ? frameA.rgbaData : frameB.rgbaData;
        if (!chosenSource.empty()) {
            std::memcpy(out->rgbaData.data(), chosenSource.data(), out->rgbaData.size());
        }
        cache_->put(key, out);
        return out;
    }

    // 4. Inferência de Optical Flow RIFE
    auto startTime = std::chrono::high_resolution_clock::now();

    bool success = ncnn_->process(frameA.rgbaData.data(),
                                 frameB.rgbaData.data(),
                                 width,
                                 height,
                                 t,
                                 out->rgbaData.data(),
                                 currentConfig_);

    auto endTime = std::chrono::high_resolution_clock::now();
    float elapsedMs = std::chrono::duration<float, std::milli>(endTime - startTime).count();

    out->inferenceTimeMs = elapsedMs;
    qualityController_->recordInferenceTime(elapsedMs);

    if (success) {
        cache_->put(key, out);
    }

    return out;
}

uint32_t OpticalFlowEngine::getInterpolatedTexture(const DecodedVideoFrame& frameA,
                                                 const DecodedVideoFrame& frameB,
                                                 float t,
                                                 const FlowInterpolationRequest& request) {
    auto frame = interpolate(frameA, frameB, t, request);
    if (!frame) return 0;

    if (textureBridge_) {
        return textureBridge_->uploadInterpolatedTexture(*frame);
    }

    return frame->gpuTextureId;
}

void OpticalFlowEngine::requestInterpolationAsync(const DecodedVideoFrame& frameA,
                                                const DecodedVideoFrame& frameB,
                                                float t,
                                                const FlowInterpolationRequest& request,
                                                InterpolationCompleteCallback callback) {
    if (!scheduler_) return;

    // Cópia profunda dos dados de entrada para thread de trabalho independente da UI
    auto capturedFrameA = frameA;
    auto capturedFrameB = frameB;

    scheduler_->enqueueJob(
        request,
        [this, capturedFrameA, capturedFrameB, t](const FlowInterpolationRequest& req) {
            return this->interpolate(capturedFrameA, capturedFrameB, t, req);
        },
        std::move(callback)
    );
}

void OpticalFlowEngine::setScrubbingGeneration(uint64_t generationId) {
    if (scheduler_) {
        scheduler_->setGeneration(generationId);
    }
}

void OpticalFlowEngine::setSceneCutThreshold(float threshold) {
    if (sceneCutDetector_) {
        sceneCutDetector_->setThreshold(threshold);
    }
}

void OpticalFlowEngine::clearCache() {
    if (cache_) cache_->clear();
    if (textureBridge_) textureBridge_->clear();
}

OpticalFlowDiagnostics OpticalFlowEngine::getDiagnostics() const {
    OpticalFlowDiagnostics diag;
    diag.enabled = initialized_;
    diag.modelLoaded = isModelLoaded();
    diag.modelName = currentConfig_.modelName;
    diag.backendName = vulkan_ && vulkan_->isAvailable() ? "Vulkan Compute (GPU)" : "Native CPU Optical Flow";
    diag.vulkanAvailable = vulkan_ ? vulkan_->isAvailable() : false;
    diag.gpuDeviceId = vulkan_ ? vulkan_->getDeviceInfo().deviceId : 0;
    diag.lastInferenceTimeMs = qualityController_ ? qualityController_->getLastInferenceTimeMs() : 0.0f;
    diag.avgInferenceTimeMs = qualityController_ ? qualityController_->getAverageInferenceTimeMs() : 0.0f;
    diag.cacheHits = cache_ ? cache_->getHitCount() : 0;
    diag.cacheMisses = cache_ ? cache_->getMissCount() : 0;
    diag.droppedJobs = scheduler_ ? scheduler_->getDroppedCount() : 0;
    diag.completedJobs = scheduler_ ? scheduler_->getCompletedCount() : 0;
    diag.pendingJobs = scheduler_ ? static_cast<int>(scheduler_->getPendingCount()) : 0;
    return diag;
}

} // namespace aurea
