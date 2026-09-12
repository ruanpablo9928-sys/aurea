#pragma once

#include <memory>
#include  GPUProcessor.h

namespace aurea {

// Simple wrapper that owns a GPUFramebuffer and optionally a depth buffer.
class RenderTarget {
public:
    explicit RenderTarget(std::shared_ptr<GPUFramebuffer> fbo) : framebuffer_(std::move(fbo)) {}
    ~RenderTarget() = default;

    std::shared_ptr<GPUFramebuffer> getFramebuffer() const { return framebuffer_; }

private:
    std::shared_ptr<GPUFramebuffer> framebuffer_;
};

} // namespace aurea
