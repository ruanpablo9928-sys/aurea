#pragma once

#include <cstdint>
#include <vector>
#include <memory>
#include <string>

namespace aurea {

struct GPUTexture {
    uint32_t id = 0;
    int width = 0;
    int height = 0;
    bool inUse = false;
};

struct GPUFramebuffer {
    uint32_t fboId = 0;
    uint32_t colorTextureId = 0;
    uint32_t depthStencilRenderbuffer = 0;
    int width = 0;
    int height = 0;
};

class GPUProcessor {
public:
    GPUProcessor();
    ~GPUProcessor();

    bool initialize();
    void shutdown();
    bool isInitialized() const { return initialized_; }

    // Criação e gestão de Framebuffer (FBO) para renderização offscreen
    std::shared_ptr<GPUFramebuffer> createFramebuffer(int width, int height);
    void bindFramebuffer(const std::shared_ptr<GPUFramebuffer>& fbo);
    void unbindFramebuffer();

    // Pool de texturas intermediárias (Zero-alloc no playback e export)
    std::shared_ptr<GPUTexture> acquireTexture(int width, int height);
    void releaseTexture(const std::shared_ptr<GPUTexture>& tex);
    void clearTexturePool();

    // Leitura rápida de pixels do framebuffer atual
    void readPixelsRGBA(int width, int height, uint8_t* outBuffer);

    // Utilitários de Shaders
    static uint32_t compileShader(uint32_t type, const char* source);
    static uint32_t createProgram(const char* vertexSource, const char* fragmentSource);

private:
    bool initialized_ = false;
    std::vector<std::shared_ptr<GPUTexture>> texturePool_;
    std::shared_ptr<GPUFramebuffer> currentBoundFbo_;
};

} // namespace aurea
