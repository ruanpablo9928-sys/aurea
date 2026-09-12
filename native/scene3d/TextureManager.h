#pragma once

#include "DeviceProfile.h"
#include "GPUUploadQueue.h"
#include <string>
#include <unordered_map>
#include <memory>
#include <mutex>
#include <vector>

namespace aurea {

struct TextureStreamInfo {
    uint32_t gpuTextureId = 0;
    int originalWidth = 0;
    int originalHeight = 0;
    int loadedWidth = 0;
    int loadedHeight = 0;
    bool isLoaded = false;
};

class TextureManager {
public:
    static TextureManager& instance();

    TextureManager();
    ~TextureManager();

    // Carrega ou recupera textura do cache
    uint32_t loadTextureFromMemory(const std::string& key,
                                   const uint8_t* rawData,
                                   size_t dataSize,
                                   int width,
                                   int height,
                                   GPUUploadQueue* uploadQueue = nullptr);

    // Registra textura já existente na GPU
    void registerTexture(const std::string& key, uint32_t textureId, int width, int height);

    // Consulta se uma textura já está pronta
    bool hasTexture(const std::string& key) const;
    uint32_t getTextureId(const std::string& key) const;

    void releaseTexture(const std::string& key);
    void clear();

    // Rescale de imagem simples por bilinear sampling em CPU antes do upload (para memory saving)
    static std::vector<uint8_t> downscaleImageRGBA(const uint8_t* src,
                                                  int srcW, int srcH,
                                                  int dstW, int dstH);

private:
    std::unordered_map<std::string, TextureStreamInfo> textures_;
    mutable std::mutex mutex_;
};

} // namespace aurea
