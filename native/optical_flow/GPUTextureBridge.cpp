#include "GPUTextureBridge.h"

namespace aurea {

GPUTextureBridge::GPUTextureBridge(std::shared_ptr<GPUProcessor> gpu)
    : gpu_(gpu) {}

GPUTextureBridge::~GPUTextureBridge() {
    clear();
}

uint32_t GPUTextureBridge::uploadInterpolatedTexture(InterpolatedFrame& frame) {
    if (!gpu_) return 0;
    if (frame.width <= 0 || frame.height <= 0) return 0;

    std::lock_guard<std::mutex> lock(mutex_);

    // Se já possui textura atribuída e válida, retorna-a diretamente (Zero-Upload)
    if (frame.gpuTextureId != 0) {
        return frame.gpuTextureId;
    }

    if (frame.rgbaData.empty()) {
        return 0;
    }

    // Reutiliza textura do pool GPU do tamanho exato
    if (!cachedTexture_ || cachedTexture_->width != frame.width || cachedTexture_->height != frame.height) {
        if (cachedTexture_) {
            gpu_->releaseTexture(cachedTexture_);
        }
        cachedTexture_ = gpu_->acquireTexture(frame.width, frame.height);
    }

    if (cachedTexture_) {
        gpu_->uploadTextureRGBA(cachedTexture_->id, frame.width, frame.height, frame.rgbaData.data());
        frame.gpuTextureId = cachedTexture_->id;
        return cachedTexture_->id;
    }

    return 0;
}

void GPUTextureBridge::releaseFrameTexture(uint32_t textureId) {
    // Gerenciado pelo pool do GPUProcessor
    (void)textureId;
}

void GPUTextureBridge::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (gpu_ && cachedTexture_) {
        gpu_->releaseTexture(cachedTexture_);
        cachedTexture_.reset();
    }
}

} // namespace aurea
