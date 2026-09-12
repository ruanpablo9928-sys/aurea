#include "RenderEngine.h"

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

    mainFbo_ = gpu_->createFramebuffer(width_, height_);
    return true;
}

void RenderEngine::shutdown() {
    mainFbo_.reset();
    if (renderer2D_) {
        renderer2D_->shutdown();
        renderer2D_.reset();
    }
    if (gpu_) {
        gpu_->shutdown();
        gpu_.reset();
    }
}

void RenderEngine::renderFrame(ProjectCore& project, int64_t timeUs, const std::shared_ptr<GPUFramebuffer>& targetFbo) {
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
        }
        // Camadas de Vídeo / Imagem / 3D são desenhadas de acordo com o tipo
    }

    if (gpu_) {
        gpu_->unbindFramebuffer();
    }
}

} // namespace aurea
