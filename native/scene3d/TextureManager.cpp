#include "TextureManager.h"
#include <algorithm>
#include <cstring>

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace aurea {

TextureManager& TextureManager::instance() {
    static TextureManager sInstance;
    return sInstance;
}

TextureManager::TextureManager() = default;

TextureManager::~TextureManager() {
    clear();
}

std::vector<uint8_t> TextureManager::downscaleImageRGBA(const uint8_t* src,
                                                        int srcW, int srcH,
                                                        int dstW, int dstH) {
    if (!src || srcW <= 0 || srcH <= 0 || dstW <= 0 || dstH <= 0) {
        return {};
    }

    std::vector<uint8_t> dst(dstW * dstH * 4);
    float xRatio = static_cast<float>(srcW) / dstW;
    float yRatio = static_cast<float>(srcH) / dstH;

    for (int y = 0; y < dstH; ++y) {
        int srcY = std::min(static_cast<int>(y * yRatio), srcH - 1);
        for (int x = 0; x < dstW; ++x) {
            int srcX = std::min(static_cast<int>(x * xRatio), srcW - 1);
            int srcIdx = (srcY * srcW + srcX) * 4;
            int dstIdx = (y * dstW + x) * 4;

            dst[dstIdx + 0] = src[srcIdx + 0];
            dst[dstIdx + 1] = src[srcIdx + 1];
            dst[dstIdx + 2] = src[srcIdx + 2];
            dst[dstIdx + 3] = src[srcIdx + 3];
        }
    }
    return dst;
}

uint32_t TextureManager::loadTextureFromMemory(const std::string& key,
                                              const uint8_t* rawData,
                                              size_t dataSize,
                                              int width,
                                              int height,
                                              GPUUploadQueue* uploadQueue) {
    (void)dataSize;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = textures_.find(key);
        if (it != textures_.end() && it->second.isLoaded) {
            return it->second.gpuTextureId;
        }
    }

    if (!rawData || width <= 0 || height <= 0) {
        return 0;
    }

    // Adapta resolução conforme o perfil do aparelho
    int maxAllowed = DeviceProfile::instance().clampTextureDimension(width, height);
    int targetW = width;
    int targetH = height;

    std::vector<uint8_t> downscaledBuffer;
    const uint8_t* uploadBuffer = rawData;

    if (width > maxAllowed || height > maxAllowed) {
        float scale = static_cast<float>(maxAllowed) / std::max(width, height);
        targetW = std::max(1, static_cast<int>(width * scale));
        targetH = std::max(1, static_cast<int>(height * scale));
        downscaledBuffer = downscaleImageRGBA(rawData, width, height, targetW, targetH);
        uploadBuffer = downscaledBuffer.data();
    }

    // Se houver fila de upload e estivermos em thread background, agenda o upload incremental
    if (uploadQueue) {
        auto capturedBuffer = std::make_shared<std::vector<uint8_t>>(
            uploadBuffer, uploadBuffer + (targetW * targetH * 4)
        );

        uploadQueue->enqueueUpload(
            "Tex_" + key,
            targetW * targetH * 4,
            [this, key, capturedBuffer, targetW, targetH, width, height]() -> bool {
                uint32_t tex = 0;
#if defined(__ANDROID__)
                glGenTextures(1, &tex);
                glBindTexture(GL_TEXTURE_2D, tex);
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, targetW, targetH, 0, GL_RGBA, GL_UNSIGNED_BYTE, capturedBuffer->data());
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
                glGenerateMipmap(GL_TEXTURE_2D);
                glBindTexture(GL_TEXTURE_2D, 0);
#else
                static uint32_t sTexGen = 2000;
                tex = sTexGen++;
#endif
                registerTexture(key, tex, targetW, targetH);
                return true;
            }
        );
        return 0; // Carregamento progressivo (será atribuído quando pronto)
    }

    // Upload direto caso estejamos na render thread
    uint32_t tex = 0;
#if defined(__ANDROID__)
    glGenTextures(1, &tex);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, targetW, targetH, 0, GL_RGBA, GL_UNSIGNED_BYTE, uploadBuffer);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);
    glBindTexture(GL_TEXTURE_2D, 0);
#else
    static uint32_t sTexGen = 2000;
    tex = sTexGen++;
#endif

    registerTexture(key, tex, targetW, targetH);
    return tex;
}

void TextureManager::registerTexture(const std::string& key, uint32_t textureId, int width, int height) {
    std::lock_guard<std::mutex> lock(mutex_);
    TextureStreamInfo info;
    info.gpuTextureId = textureId;
    info.loadedWidth = width;
    info.loadedHeight = height;
    info.isLoaded = true;
    textures_[key] = info;
}

bool TextureManager::hasTexture(const std::string& key) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = textures_.find(key);
    return it != textures_.end() && it->second.isLoaded;
}

uint32_t TextureManager::getTextureId(const std::string& key) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = textures_.find(key);
    if (it != textures_.end() && it->second.isLoaded) {
        return it->second.gpuTextureId;
    }
    return 0;
}

void TextureManager::releaseTexture(const std::string& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = textures_.find(key);
    if (it != textures_.end()) {
#if defined(__ANDROID__)
        if (it->second.gpuTextureId != 0) {
            glDeleteTextures(1, &it->second.gpuTextureId);
        }
#endif
        textures_.erase(it);
    }
}

void TextureManager::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
#if defined(__ANDROID__)
    for (auto& pair : textures_) {
        if (pair.second.gpuTextureId != 0) {
            glDeleteTextures(1, &pair.second.gpuTextureId);
        }
    }
#endif
    textures_.clear();
}

} // namespace aurea
