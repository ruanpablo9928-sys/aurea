#include "NativeExportPipeline.h"
#include "optical_flow/OpticalFlowEngine.h"
#include <chrono>
#include <thread>

namespace aurea {

NativeExportPipeline::NativeExportPipeline()
    : exportRenderEngine_(std::make_unique<RenderEngine>()) {
}

NativeExportPipeline::~NativeExportPipeline() {
    cancelExport();
    if (exportRenderEngine_) {
        exportRenderEngine_->shutdown();
    }
}

void NativeExportPipeline::cancelExport() {
    cancelRequested_.store(true);
}

bool NativeExportPipeline::exportProject(std::shared_ptr<ProjectCore> project,
                                        const ExportConfig& config,
                                        ExportProgressCallback progressCallback) {
    if (!project) return false;

    isExporting_.store(true);
    cancelRequested_.store(false);
    progress_.store(0.0f);

    if (!exportRenderEngine_->initialize(config.width, config.height)) {
        isExporting_.store(false);
        return false;
    }

    if (exportRenderEngine_->getOpticalFlowEngine()) {
        exportRenderEngine_->getOpticalFlowEngine()->setQuality(FlowQuality::Ultra);
        exportRenderEngine_->getOpticalFlowEngine()->loadOptimalModel(FlowQuality::Ultra, false);
    }

    int totalFrames = static_cast<int>((config.durationUs * config.fps) / 1000000LL);
    if (totalFrames <= 0) totalFrames = 1;

    auto fbo = exportRenderEngine_->getMainFramebuffer();

    for (int frame = 0; frame < totalFrames; ++frame) {
        if (cancelRequested_.load()) {
            isExporting_.store(false);
            return false;
        }

        int64_t timeUs = (static_cast<int64_t>(frame) * 1000000LL) / config.fps;

        // 1. Avalia projeto e animação
        // 2. Renderiza no FBO da GPU de forma ultrarrápida com sincronismo exato de frames (exactSync = true)
        exportRenderEngine_->renderFrame(*project, timeUs, fbo, true);

        float currentProgress = static_cast<float>(frame + 1) / static_cast<float>(totalFrames);
        progress_.store(currentProgress);

        if (progressCallback) {
            progressCallback(currentProgress, frame + 1, totalFrames);
        }
    }

    isExporting_.store(false);
    progress_.store(1.0f);
    return true;
}

bool NativeExportPipeline::renderFrameDirect(std::shared_ptr<ProjectCore> project,
                                             int frameIndex,
                                             int width,
                                             int height,
                                             int fps,
                                             uint8_t* outRgbaBuffer) {
    if (!project || !outRgbaBuffer || width <= 0 || height <= 0 || fps <= 0 || frameIndex < 0) return false;

    // Inicializa render engine para a resolução requerida se ainda não inicializado

    if (renderWidth_ != width || renderHeight_ != height) {
        exportRenderEngine_->shutdown();
        if (!exportRenderEngine_->initialize(width, height)) {
            return false;
        }
        renderWidth_ = width;
        renderHeight_ = height;
    }

    int64_t timeUs = (static_cast<int64_t>(frameIndex) * 1000000LL) / (fps > 0 ? fps : 30);
    auto fbo = exportRenderEngine_->getMainFramebuffer();

    // Renderiza quadro diretamente na GPU com sincronismo exato de frames
    exportRenderEngine_->renderFrame(*project, timeUs, fbo, true);

    // Lê pixels diretamente para o buffer contíguo
    if (exportRenderEngine_->getGPU()) {
        exportRenderEngine_->getGPU()->readPixelsRGBA(width, height, outRgbaBuffer);
    }

    return true;
}

} // namespace aurea
