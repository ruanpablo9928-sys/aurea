#include "GPUProcessor.h"
#include <iostream>
#include <cstring>

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#include <EGL/egl.h>
#include <android/log.h>
#define LOG_TAG "AureaNative"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
#define LOGI(...) do { printf("[INFO] " __VA_ARGS__); printf("\n"); } while(0)
#define LOGE(...) do { fprintf(stderr, "[ERROR] " __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#endif

namespace aurea {

GPUProcessor::GPUProcessor() = default;

GPUProcessor::~GPUProcessor() {
    shutdown();
}

bool GPUProcessor::initialize() {
    initialized_ = true;
    LOGI("GPUProcessor initialized successfully.");
    return true;
}

void GPUProcessor::shutdown() {
    clearTexturePool();
    initialized_ = false;
}

std::shared_ptr<GPUFramebuffer> GPUProcessor::createFramebuffer(int width, int height) {
    auto fbo = std::make_shared<GPUFramebuffer>();
    fbo->width = width;
    fbo->height = height;

#if defined(__ANDROID__)
    glGenFramebuffers(1, &fbo->fboId);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo->fboId);

    glGenTextures(1, &fbo->colorTextureId);
    glBindTexture(GL_TEXTURE_2D, fbo->colorTextureId);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, fbo->colorTextureId, 0);

    glGenRenderbuffers(1, &fbo->depthStencilRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, fbo->depthStencilRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, fbo->depthStencilRenderbuffer);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("Framebuffer creation failed with status: 0x%x", status);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
#else
    static uint32_t sMockId = 1;
    fbo->fboId = sMockId++;
    fbo->colorTextureId = sMockId++;
    fbo->depthStencilRenderbuffer = sMockId++;
#endif

    return fbo;
}

void GPUProcessor::bindFramebuffer(const std::shared_ptr<GPUFramebuffer>& fbo) {
    currentBoundFbo_ = fbo;
#if defined(__ANDROID__)
    if (fbo) {
        glBindFramebuffer(GL_FRAMEBUFFER, fbo->fboId);
        glViewport(0, 0, fbo->width, fbo->height);
    } else {
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
#endif
}

void GPUProcessor::unbindFramebuffer() {
    bindFramebuffer(nullptr);
}

std::shared_ptr<GPUTexture> GPUProcessor::acquireTexture(int width, int height) {
    for (auto& tex : texturePool_) {
        if (!tex->inUse && tex->width == width && tex->height == height) {
            tex->inUse = true;
            return tex;
        }
    }

    auto newTex = std::make_shared<GPUTexture>();
    newTex->width = width;
    newTex->height = height;
    newTex->inUse = true;

#if defined(__ANDROID__)
    glGenTextures(1, &newTex->id);
    glBindTexture(GL_TEXTURE_2D, newTex->id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glBindTexture(GL_TEXTURE_2D, 0);
#else
    static uint32_t sTexId = 100;
    newTex->id = sTexId++;
#endif

    texturePool_.push_back(newTex);
    return newTex;
}

void GPUProcessor::releaseTexture(const std::shared_ptr<GPUTexture>& tex) {
    if (tex) {
        tex->inUse = false;
    }
}

void GPUProcessor::clearTexturePool() {
#if defined(__ANDROID__)
    for (auto& tex : texturePool_) {
        if (tex->id != 0) {
            glDeleteTextures(1, &tex->id);
            tex->id = 0;
        }
    }
#endif
    texturePool_.clear();
}

void GPUProcessor::readPixelsRGBA(int width, int height, uint8_t* outBuffer) {
    if (!outBuffer) return;
#if defined(__ANDROID__)
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, outBuffer);
#else
    std::memset(outBuffer, 0, width * height * 4);
#endif
}

uint32_t GPUProcessor::compileShader(uint32_t type, const char* source) {
#if defined(__ANDROID__)
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    GLint compiled = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled) {
        GLint infoLen = 0;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 0) {
            std::vector<char> infoLog(infoLen);
            glGetShaderInfoLog(shader, infoLen, nullptr, infoLog.data());
            LOGE("Shader compilation error: %s", infoLog.data());
        }
        glDeleteShader(shader);
        return 0;
    }
    return shader;
#else
    (void)type;
    (void)source;
    return 1;
#endif
}

uint32_t GPUProcessor::createProgram(const char* vertexSource, const char* fragmentSource) {
#if defined(__ANDROID__)
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vertexSource);
    if (!vertexShader) return 0;

    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentSource);
    if (!fragmentShader) {
        glDeleteShader(vertexShader);
        return 0;
    }

    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    GLint linked = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked) {
        GLint infoLen = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);
        if (infoLen > 0) {
            std::vector<char> infoLog(infoLen);
            glGetProgramInfoLog(program, infoLen, nullptr, infoLog.data());
            LOGE("Program linking error: %s", infoLog.data());
        }
        glDeleteProgram(program);
        program = 0;
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    return program;
#else
    (void)vertexSource;
    (void)fragmentSource;
    return 1;
#endif
}

} // namespace aurea
