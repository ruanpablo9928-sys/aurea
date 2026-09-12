#pragma once

#include "OpticalFlowTypes.h"
#include "../renderer/GPUProcessor.h"
#include "../renderer/RenderTargetPool.h"
#include <memory>
#include <mutex>

namespace aurea {

class GPUTextureBridge {
public:
    explicit GPUTextureBridge(std::shared_ptr<GPUProcessor> gpu);
    ~GPUTextureBridge();

    void setGPU(std::shared_ptr<GPUProcessor> gpu) { gpu_ = gpu; }
    std::shared_ptr<GPUProcessor> getGPU() const { return gpu_; }

    // Cria ou atualiza a textura GPU para o quadro interpolado sem recriação contínua
    uint32_t uploadInterpolatedTexture(InterpolatedFrame& frame);

    // Libera texturas GPU associadas
    void releaseFrameTexture(uint32_t textureId);

    void clear();

private:
    std::shared_ptr<GPUProcessor> gpu_;
    std::shared_ptr<GPUTexture> cachedTexture_;
    mutable std::mutex mutex_;
};

} // namespace aurea
