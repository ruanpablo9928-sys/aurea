#pragma once

#include "../renderer/GPUProcessor.h"
#include <memory>
#include <string>

namespace aurea {

enum class EffectType {
    GaussianBlur,
    Glow,
    ColorGrade,
    Vignette,
    ChromaticAberration
};

struct EffectParams {
    EffectType type = EffectType::GaussianBlur;
    float intensity = 1.0f;
    float radius = 5.0f;
    float brightness = 0.0f;
    float contrast = 1.0f;
    float saturation = 1.0f;
    float vignetteRoundness = 0.8f;
    float vignetteFeather = 0.5f;
};

class EffectsEngine {
public:
    EffectsEngine(std::shared_ptr<GPUProcessor> gpu);
    ~EffectsEngine();

    bool initialize();
    void shutdown();

    // Aplica um efeito sobre inputTextureId e retorna o textureId de saída (utilizando ping-pong no GPUProcessor)
    uint32_t applyEffect(uint32_t inputTextureId, int width, int height, const EffectParams& params);

    // Efeitos específicos otimizados
    uint32_t applyGaussianBlur(uint32_t inputTextureId, int width, int height, float radius);
    uint32_t applyColorGrade(uint32_t inputTextureId, int width, int height, float brightness, float contrast, float saturation);
    uint32_t applyVignette(uint32_t inputTextureId, int width, int height, float intensity, float feather);

private:
    std::shared_ptr<GPUProcessor> gpu_;
    uint32_t blurProgram_ = 0;
    uint32_t colorGradeProgram_ = 0;
    uint32_t vignetteProgram_ = 0;
    uint32_t quadVao_ = 0;
    uint32_t quadVbo_ = 0;

    void initShaders();
    void initGeometry();
};

} // namespace aurea
