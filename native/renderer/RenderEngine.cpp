#include "RenderEngine.h"
#include "../optical_flow/OpticalFlowEngine.h"
#include "../scene3d/DeviceProfile.h"

namespace aurea {

RenderEngine::RenderEngine() = default;

RenderEngine::~RenderEngine() {
    shutdown();
}

bool RenderEngine::initialize(int width, int height) {
    width_ = width;
    height_ = height;

    gpu_ = std::make_shared<GPUProcessor>();
    if (!gpu_->initialize()) {
        return false;
    }

    renderer2D_ = std::make_shared<Renderer2D>(gpu_);
    if (!renderer2D_->initialize()) {
        return false;
    }
    renderer2D_->setViewport(width_, height_);

    targetPool_ = std::make_shared<RenderTargetPool>(gpu_);
    mainFbo_ = targetPool_->acquire(width_, height_);
    videoEngine_.setGPU(gpu_);

    // Inicializa o motor de Optical Flow / RIFE com Vulkan e ncnn
    opticalFlow_ = std::make_shared<OpticalFlowEngine>();
    opticalFlow_->initialize(DeviceProfile::instance().getCapabilities());
    opticalFlow_->setGPU(gpu_);
    videoEngine_.setOpticalFlowEngine(opticalFlow_);

    return true;
}

void RenderEngine::shutdown() {
    if (targetPool_) {
        targetPool_->release(mainFbo_);
        targetPool_->clear();
        targetPool_.reset();
    }
    mainFbo_.reset();
    if (opticalFlow_) {
        opticalFlow_->shutdown();
        opticalFlow_.reset();
    }
    videoEngine_.clearCache();
    if (renderer2D_) {
        renderer2D_->shutdown();
        renderer2D_.reset();
    }
    if (gpu_) {
        gpu_->shutdown();
        gpu_.reset();
    }
}

void RenderEngine::renderFrame(ProjectCore& project, int64_t timeUs, const std::shared_ptr<GPUFramebuffer>& targetFbo, bool exactSync, uint64_t generationId) {
    // 1. Avalia interpolação de keyframes para o tempo atual
    animationEngine_.evaluateProject(project, timeUs);

    // 2. Destino de renderização: FBO fornecido ou FBO interno principal
    auto fbo = targetFbo ? targetFbo : mainFbo_;
    if (gpu_ && fbo) {
        gpu_->bindFramebuffer(fbo);
    }

    // 3. Limpa o framebuffer com transparência (ou cor de fundo)
    if (renderer2D_) {
        renderer2D_->clear(0.0f, 0.0f, 0.0f, 0.0f);
    }

    // 4. Avalia camadas visíveis no instante timeUs
    auto evaluatedLayers = compositionCore_.evaluateLayers(project.getLayers(), timeUs);

    // 5. Renderiza cada camada na ordem Z
    for (const auto& eval : evaluatedLayers) {
        if (!eval.isVisible || !eval.layer) continue;

        if (eval.layer->getType() == LayerType::Shape) {
            renderer2D_->drawShape(eval.layer->getShapeData(), eval.globalTransform);
        } else if (eval.layer->getType() == LayerType::Video) {
            // Obtenção de textura de vídeo com Time Remap e Optical Flow RIFE
            uint32_t tex = videoEngine_.getFrameTexture(
                eval.layer->getSourcePath(),
                timeUs,
                eval.layer->getTimeRemap(),
                generationId,
                exactSync
            );
            if (tex != 0) {
                renderer2D_->drawTexture(tex, eval.globalTransform, width_, height_);
            }
        }
    }

    if (gpu_) {
        gpu_->unbindFramebuffer();
    }
}

} // namespace aurea
