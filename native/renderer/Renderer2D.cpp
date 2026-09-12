#include "Renderer2D.h"

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace aurea {

static const char* kVertexShader2D = R"(#version 300 es
layout(location = 0) in vec2 aPosition;
layout(location = 1) in vec2 aTexCoord;

uniform mat4 uProjection;
uniform mat4 uModel;

out vec2 vTexCoord;

void main() {
    vTexCoord = aTexCoord;
    gl_Position = uProjection * uModel * vec4(aPosition, 0.0, 1.0);
}
)";

static const char* kFragmentShaderShape = R"(#version 300 es
precision mediump float;

in vec2 vTexCoord;
out vec4 fragColor;

uniform vec4 uFillColor;
uniform vec4 uStrokeColor;
uniform float uStrokeWidth;
uniform float uCornerRadius;
uniform vec2 uSize;
uniform int uShapeType; // 0=Rect, 1=Circle

void main() {
    vec2 pos = (vTexCoord - 0.5) * uSize;
    vec2 halfSize = uSize * 0.5;

    if (uShapeType == 1) {
        // Círculo / Elipse
        float r = length(pos / halfSize);
        if (r > 1.0) {
            discard;
        }
        float edge = 1.0 - smoothstep(1.0 - (1.5 / min(uSize.x, uSize.y)), 1.0, r);
        fragColor = uFillColor * edge;
    } else {
        // Retângulo com cantos arredondados (SDF)
        vec2 q = abs(pos) - halfSize + vec2(uCornerRadius);
        float dist = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - uCornerRadius;
        if (dist > 0.0) {
            discard;
        }
        float alpha = 1.0 - smoothstep(-1.0, 0.5, dist);
        fragColor = uFillColor * alpha;
    }
}
)";

static const char* kFragmentShaderTexture = R"(#version 300 es
precision mediump float;

in vec2 vTexCoord;
out vec4 fragColor;

uniform sampler2D uTexture;
uniform float uOpacity;

void main() {
    vec4 texColor = texture(uTexture, vTexCoord);
    fragColor = texColor * uOpacity;
}
)";

Renderer2D::Renderer2D(std::shared_ptr<GPUProcessor> gpu)
    : gpu_(gpu) {
}

Renderer2D::~Renderer2D() {
    shutdown();
}

bool Renderer2D::initialize() {
    initShaders();
    initQuadGeometry();
    return true;
}

void Renderer2D::shutdown() {
#if defined(__ANDROID__)
    if (shapeProgram_ != 0) {
        glDeleteProgram(shapeProgram_);
        shapeProgram_ = 0;
    }
    if (textureProgram_ != 0) {
        glDeleteProgram(textureProgram_);
        textureProgram_ = 0;
    }
    if (quadVao_ != 0) {
        glDeleteVertexArrays(1, &quadVao_);
        quadVao_ = 0;
    }
    if (quadVbo_ != 0) {
        glDeleteBuffers(1, &quadVbo_);
        quadVbo_ = 0;
    }
#endif
}

void Renderer2D::setViewport(int width, int height) {
    viewportWidth_ = width;
    viewportHeight_ = height;
#if defined(__ANDROID__)
    glViewport(0, 0, width, height);
#endif
}

void Renderer2D::clear(float r, float g, float b, float a) {
#if defined(__ANDROID__)
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
#else
    (void)r; (void)g; (void)b; (void)a;
#endif
}

void Renderer2D::initQuadGeometry() {
#if defined(__ANDROID__)
    // Vértices do quad: x, y, u, v
    float quadVertices[] = {
        -0.5f, -0.5f, 0.0f, 0.0f,
         0.5f, -0.5f, 1.0f, 0.0f,
        -0.5f,  0.5f, 0.0f, 1.0f,
        -0.5f,  0.5f, 0.0f, 1.0f,
         0.5f, -0.5f, 1.0f, 0.0f,
         0.5f,  0.5f, 1.0f, 1.0f
    };

    glGenVertexArrays(1, &quadVao_);
    glGenBuffers(1, &quadVbo_);

    glBindVertexArray(quadVao_);
    glBindBuffer(GL_ARRAY_BUFFER, quadVbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), quadVertices, GL_STATIC_DRAW);

    // aPosition (location = 0)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // aTexCoord (location = 1)
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
#endif
}

void Renderer2D::initShaders() {
    if (gpu_) {
        shapeProgram_ = GPUProcessor::createProgram(kVertexShader2D, kFragmentShaderShape);
        textureProgram_ = GPUProcessor::createProgram(kVertexShader2D, kFragmentShaderTexture);
    }
}

void Renderer2D::drawShape(const ShapeData& shape, const Transform2D& transform) {
#if defined(__ANDROID__)
    if (!shapeProgram_ || !quadVao_) return;

    glUseProgram(shapeProgram_);
    glBindVertexArray(quadVao_);

    // Habilita Blending para transparência e antialiasing
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Uniforms de cor
    float a = ((shape.fillColor >> 24) & 0xFF) / 255.0f * static_cast<float>(transform.opacity);
    float r = ((shape.fillColor >> 16) & 0xFF) / 255.0f;
    float g = ((shape.fillColor >> 8) & 0xFF) / 255.0f;
    float b = (shape.fillColor & 0xFF) / 255.0f;

    GLint locFill = glGetUniformLocation(shapeProgram_, "uFillColor");
    glUniform4f(locFill, r, g, b, a);

    GLint locSize = glGetUniformLocation(shapeProgram_, "uSize");
    glUniform2f(locSize, static_cast<float>(shape.width), static_cast<float>(shape.height));

    GLint locShapeType = glGetUniformLocation(shapeProgram_, "uShapeType");
    glUniform1i(locShapeType, shape.shapeType);

    GLint locCorner = glGetUniformLocation(shapeProgram_, "uCornerRadius");
    glUniform1f(locCorner, static_cast<float>(shape.cornerRadius));

    // Matriz de projeção ortográfica 2D
    float left = 0.0f;
    float right = static_cast<float>(viewportWidth_);
    float bottom = static_cast<float>(viewportHeight_);
    float top = 0.0f;
    float nearVal = -1.0f;
    float farVal = 1.0f;

    float ortho[16] = {
        2.0f / (right - left), 0.0f, 0.0f, 0.0f,
        0.0f, 2.0f / (top - bottom), 0.0f, 0.0f,
        0.0f, 0.0f, -2.0f / (farVal - nearVal), 0.0f,
        -(right + left) / (right - left), -(top + bottom) / (top - bottom), -(farVal + nearVal) / (farVal - nearVal), 1.0f
    };

    GLint locProj = glGetUniformLocation(shapeProgram_, "uProjection");
    glUniformMatrix4fv(locProj, 1, GL_FALSE, ortho);

    // Matriz Model (Translação, Rotação, Escala da Camada)
    float rad = static_cast<float>(transform.rotation * (3.141592653589793 / 180.0));
    float cosR = std::cos(rad);
    float sinR = std::sin(rad);
    float sx = static_cast<float>(shape.width * transform.scaleX);
    float sy = static_cast<float>(shape.height * transform.scaleY);

    float model[16] = {
        cosR * sx,  sinR * sx, 0.0f, 0.0f,
       -sinR * sy,  cosR * sy, 0.0f, 0.0f,
        0.0f,       0.0f,      1.0f, 0.0f,
        static_cast<float>(transform.posX), static_cast<float>(transform.posY), 0.0f, 1.0f
    };

    GLint locModel = glGetUniformLocation(shapeProgram_, "uModel");
    glUniformMatrix4fv(locModel, 1, GL_FALSE, model);

    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
#else
    (void)shape;
    (void)transform;
#endif
}

void Renderer2D::drawTexture(uint32_t textureId, const Transform2D& transform, double width, double height) {
#if defined(__ANDROID__)
    if (!textureProgram_ || !quadVao_) return;
    (void)width;
    (void)height;

    glUseProgram(textureProgram_);
    glBindVertexArray(quadVao_);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, textureId);
    GLint locTex = glGetUniformLocation(textureProgram_, "uTexture");
    glUniform1i(locTex, 0);

    GLint locOp = glGetUniformLocation(textureProgram_, "uOpacity");
    glUniform1f(locOp, static_cast<float>(transform.opacity));

    glDrawArrays(GL_TRIANGLES, 0, 6);
    glBindVertexArray(0);
#else
    (void)textureId;
    (void)transform;
    (void)width;
    (void)height;
#endif
}

} // namespace aurea
