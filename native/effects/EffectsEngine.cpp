#include "EffectsEngine.h"

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace aurea {

static const char* kVertexShaderEffect = R"(#version 300 es
layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec2 aTexCoord;
out vec2 vTexCoord;
void main() {
    vTexCoord = aTexCoord;
    gl_Position = vec4(aPosition, 0.0, 1.0);
}
)";

static const char* kFragmentShaderBlur = R"(#version 300 es
precision mediump float;
in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uTexture;
uniform vec2 uDirection; // (1.0/width, 0.0) ou (0.0, 1.0/height)
uniform float uRadius;

void main() {
    vec4 sum = vec4(0.0);
    vec2 step = uDirection * uRadius;

    sum += texture(uTexture, vTexCoord - step * 4.0) * 0.0162162162;
    sum += texture(uTexture, vTexCoord - step * 3.0) * 0.0540540541;
    sum += texture(uTexture, vTexCoord - step * 2.0) * 0.1216216216;
    sum += texture(uTexture, vTexCoord - step * 1.0) * 0.1945945946;
    sum += texture(uTexture, vTexCoord)              * 0.2270270270;
    sum += texture(uTexture, vTexCoord + step * 1.0) * 0.1945945946;
    sum += texture(uTexture, vTexCoord + step * 2.0) * 0.1216216216;
    sum += texture(uTexture, vTexCoord + step * 3.0) * 0.0540540541;
    sum += texture(uTexture, vTexCoord + step * 4.0) * 0.0162162162;

    fragColor = sum;
}
)";

static const char* kFragmentShaderColorGrade = R"(#version 300 es
precision mediump float;
in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uTexture;
uniform float uBrightness;
uniform float uContrast;
uniform float uSaturation;

void main() {
    vec4 color = texture(uTexture, vTexCoord);

    // Brilho
    color.rgb += uBrightness;

    // Contraste
    color.rgb = (color.rgb - 0.5) * uContrast + 0.5;

    // Saturação
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(vec3(luma), color.rgb, uSaturation);

    fragColor = color;
}
)";

static const char* kFragmentShaderVignette = R"(#version 300 es
precision mediump float;
in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uTexture;
uniform float uIntensity;
uniform float uFeather;

void main() {
    vec4 color = texture(uTexture, vTexCoord);
    vec2 uv = (vTexCoord - 0.5) * 2.0;
    float dist = length(uv);
    float vignette = smoothstep(1.0, 1.0 - uFeather, dist * uIntensity);
    color.rgb *= vignette;
    fragColor = color;
}
)";

EffectsEngine::EffectsEngine(std::shared_ptr<GPUProcessor> gpu)
    : gpu_(gpu) {
}

EffectsEngine::~EffectsEngine() {
    shutdown();
}

bool EffectsEngine::initialize() {
    initShaders();
    initGeometry();
    return true;
}

void EffectsEngine::shutdown() {
#if defined(__ANDROID__)
    if (blurProgram_) { glDeleteProgram(blurProgram_); blurProgram_ = 0; }
    if (colorGradeProgram_) { glDeleteProgram(colorGradeProgram_); colorGradeProgram_ = 0; }
    if (vignetteProgram_) { glDeleteProgram(vignetteProgram_); vignetteProgram_ = 0; }
    if (quadVao_) { glDeleteVertexArrays(1, &quadVao_); quadVao_ = 0; }
    if (quadVbo_) { glDeleteBuffers(1, &quadVbo_); quadVbo_ = 0; }
#endif
}

void EffectsEngine::initGeometry() {
#if defined(__ANDROID__)
    float quadVertices[] = {
        -1.0f, -1.0f, 0.0f, 0.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 1.0f,
        -1.0f,  1.0f, 0.0f, 1.0f,
         1.0f, -1.0f, 1.0f, 0.0f,
         1.0f,  1.0f, 1.0f, 1.0f
    };

    glGenVertexArrays(1, &quadVao_);
    glGenBuffers(1, &quadVbo_);

    glBindVertexArray(quadVao_);
    glBindBuffer(GL_ARRAY_BUFFER, quadVbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
#endif
}

void EffectsEngine::initShaders() {
    if (gpu_) {
        blurProgram_ = GPUProcessor::createProgram(kVertexShaderEffect, kFragmentShaderBlur);
        colorGradeProgram_ = GPUProcessor::createProgram(kVertexShaderEffect, kFragmentShaderColorGrade);
        vignetteProgram_ = GPUProcessor::createProgram(kVertexShaderEffect, kFragmentShaderVignette);
    }
}

uint32_t EffectsEngine::applyEffect(uint32_t inputTextureId, int width, int height, const EffectParams& params) {
    switch (params.type) {
        case EffectType::GaussianBlur:
            return applyGaussianBlur(inputTextureId, width, height, params.radius);
        case EffectType::ColorGrade:
            return applyColorGrade(inputTextureId, width, height, params.brightness, params.contrast, params.saturation);
        case EffectType::Vignette:
            return applyVignette(inputTextureId, width, height, params.intensity, params.vignetteFeather);
        default:
            return inputTextureId;
    }
}

uint32_t EffectsEngine::applyGaussianBlur(uint32_t inputTextureId, int width, int height, float radius) {
    // Retorna a textura processada ou inputTextureId
    (void)width; (void)height; (void)radius;
    return inputTextureId;
}

uint32_t EffectsEngine::applyColorGrade(uint32_t inputTextureId, int width, int height, float brightness, float contrast, float saturation) {
    (void)width; (void)height; (void)brightness; (void)contrast; (void)saturation;
    return inputTextureId;
}

uint32_t EffectsEngine::applyVignette(uint32_t inputTextureId, int width, int height, float intensity, float feather) {
    (void)width; (void)height; (void)intensity; (void)feather;
    return inputTextureId;
}

} // namespace aurea
