#pragma once

#include "Assets.h"
#include <string>
#include <vector>
#include <memory>
#include <mutex>

namespace aurea {

struct CachedModelData {
    std::string name;
    std::vector<Vertex3D> vertices;
    std::vector<uint32_t> indices;
    float boundsMin[3] = {-0.5f, -0.5f, -0.5f};
    float boundsMax[3] = { 0.5f,  0.5f,  0.5f};
    bool valid = false;
};

class AssetCache {
public:
    static AssetCache& instance();

    AssetCache();
    ~AssetCache() = default;

    void setCacheDirectory(const std::string& dirPath);
    const std::string& getCacheDirectory() const { return cacheDir_; }

    // Gera chave estável baseada no arquivo original
    std::string generateCacheKey(const std::string& filePath, int64_t fileSize, int64_t modTime);

    // Consulta se existe cache válido
    bool hasCache(const std::string& key);

    // Lê dados otimizados do cache em alta velocidade
    CachedModelData loadFromCache(const std::string& key);

    // Grava dados otimizados no cache em disco
    bool saveToCache(const std::string& key, const CachedModelData& data);

private:
    std::string cacheDir_ = ".cache_3d";
    mutable std::mutex mutex_;
};

} // namespace aurea
