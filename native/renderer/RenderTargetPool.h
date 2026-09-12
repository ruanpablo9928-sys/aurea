#pragma once

#include "GPUProcessor.h"
#include <vector>
#include <memory>
#include <mutex>

namespace aurea {

struct PooledRenderTarget {
    std::shared_ptr<GPUFramebuffer> fbo;
    int width = 0;
    int height = 0;
    bool inUse = false;
};

class RenderTargetPool {
public:
    explicit RenderTargetPool(std::shared_ptr<GPUProcessor> gpu);
    ~RenderTargetPool();

    // Obtém ou aloca um Framebuffer com as dimensões especificadas
    std::shared_ptr<GPUFramebuffer> acquire(int width, int height);

    // Devolve o Framebuffer para reutilização no pool
    void release(const std::shared_ptr<GPUFramebuffer>& fbo);

    // Limpa todos os render targets alocados
    void clear();

    size_t getPoolSize() const;

private:
    std::shared_ptr<GPUProcessor> gpu_;
    std::vector<PooledRenderTarget> pool_;
    mutable std::mutex mutex_;
};

} // namespace aurea
