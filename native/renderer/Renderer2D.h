#pragma once

#include "GPUProcessor.h"
#include "../core/ProjectCore.h"
#include <memory>

namespace aurea {

class Renderer2D {
public:
    Renderer2D(std::shared_ptr<GPUProcessor> gpu);
    ~Renderer2D();

    bool initialize();
    void shutdown();

    void setViewport(int width, int height);

    // Renderiza uma camada 2D do tipo Shape com aceleração por GPU
    void drawShape(const ShapeData& shape, const Transform2D& transform);

    // Renderiza uma textura (para imagem ou vídeo) com transformação 2D
    void drawTexture(uint32_t textureId, const Transform2D& transform, double width, double height);

    // Limpa a tela com cor RGBA
    void clear(float r, float g, float b, float a);

private:
    std::shared_ptr<GPUProcessor> gpu_;
    int viewportWidth_ = 1920;
    int viewportHeight_ = 1080;

    uint32_t shapeProgram_ = 0;
    uint32_t textureProgram_ = 0;
    uint32_t quadVao_ = 0;
    uint32_t quadVbo_ = 0;

    void initQuadGeometry();
    void initShaders();
};

} // namespace aurea
