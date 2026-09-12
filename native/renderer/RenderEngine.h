#pragma once

#include "GPUProcessor.h"
#include "Renderer2D.h"
#include "RenderTargetPool.h"
#include "../core/ProjectCore.h"
#include "../core/CompositionCore.h"
#include "../animation/AnimationEngine.h"
#include "../video/VideoEngine.h"
#include <memory>

namespace aurea {

class RenderEngine {
public:
    RenderEngine();
    ~RenderEngine();

    bool initialize(int width, int height);
    void shutdown();

    std::shared_ptr<GPUProcessor> getGPU() const { return gpu_; }
    std::shared_ptr<Renderer2D> getRenderer2D() const { return renderer2D_; }
    std::shared_ptr<RenderTargetPool> getTargetPool() const { return targetPool_; }
    AnimationEngine& getAnimationEngine() { return animationEngine_; }
    CompositionCore& getCompositionCore() { return compositionCore_; }
    VideoEngine& getVideoEngine() { return videoEngine_; }

    // Renderiza um quadro completo no instante timeUs
    void renderFrame(ProjectCore& project, int64_t timeUs, const std::shared_ptr<GPUFramebuffer>& targetFbo = nullptr, bool exactSync = false);

    // Obtém o FBO principal de renderização offscreen
    std::shared_ptr<GPUFramebuffer> getMainFramebuffer() const { return mainFbo_; }

private:
    int width_ = 1920;
    int height_ = 1080;

    std::shared_ptr<GPUProcessor> gpu_;
    std::shared_ptr<Renderer2D> renderer2D_;
    std::shared_ptr<GPUFramebuffer> mainFbo_;
    std::shared_ptr<RenderTargetPool> targetPool_;

    VideoEngine videoEngine_;
    AnimationEngine animationEngine_;
    CompositionCore compositionCore_;
};

} // namespace aurea
