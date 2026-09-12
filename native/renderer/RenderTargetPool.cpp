#include "RenderTargetPool.h"

namespace aurea {

RenderTargetPool::RenderTargetPool(std::shared_ptr<GPUProcessor> gpu)
    : gpu_(gpu) {
}

RenderTargetPool::~RenderTargetPool() {
    clear();
}

std::shared_ptr<GPUFramebuffer> RenderTargetPool::acquire(int width, int height) {
    std::lock_guard<std::mutex> lock(mutex_);

    // Procura por um FBO disponível com as dimensões idênticas
    for (auto& item : pool_) {
        if (!item.inUse && item.width == width && item.height == height) {
            item.inUse = true;
            return item.fbo;
        }
    }

    // Se não encontrou, aloca um novo via GPUProcessor
    if (!gpu_) return nullptr;

    auto fbo = gpu_->createFramebuffer(width, height);
    if (fbo) {
        PooledRenderTarget item;
        item.fbo = fbo;
        item.width = width;
        item.height = height;
        item.inUse = true;
        pool_.push_back(item);
    }
    return fbo;
}

void RenderTargetPool::release(const std::shared_ptr<GPUFramebuffer>& fbo) {
    if (!fbo) return;

    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& item : pool_) {
        if (item.fbo == fbo) {
            item.inUse = false;
            return;
        }
    }
}

void RenderTargetPool::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    pool_.clear();
}

size_t RenderTargetPool::getPoolSize() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return pool_.size();
}

} // namespace aurea
