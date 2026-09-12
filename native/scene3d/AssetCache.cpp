#include "AssetCache.h"
#include <fstream>
#include <sstream>
#include <filesystem>

namespace aurea {

AssetCache& AssetCache::instance() {
    static AssetCache sInstance;
    return sInstance;
}

AssetCache::AssetCache() = default;

void AssetCache::setCacheDirectory(const std::string& dirPath) {
    std::lock_guard<std::mutex> lock(mutex_);
    cacheDir_ = dirPath;
    try {
        std::filesystem::create_directories(cacheDir_);
    } catch (...) {}
}

std::string AssetCache::generateCacheKey(const std::string& filePath, int64_t fileSize, int64_t modTime) {
    std::hash<std::string> hasher;
    std::string composite = filePath + "_" + std::to_string(fileSize) + "_" + std::to_string(modTime) + "_v1.0";
    size_t h = hasher(composite);
    std::stringstream ss;
    ss << std::hex << h;
    return ss.str();
}

bool AssetCache::hasCache(const std::string& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    std::string path = cacheDir_ + "/" + key + ".a3d";
    return std::filesystem::exists(path);
}

CachedModelData AssetCache::loadFromCache(const std::string& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    CachedModelData data;
    std::string path = cacheDir_ + "/" + key + ".a3d";

    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) return data;

    // Header: magic "A3D1"
    char magic[4];
    file.read(magic, 4);
    if (file.gcount() < 4 || std::memcmp(magic, "A3D1", 4) != 0) {
        return data;
    }

    uint32_t nameLen = 0;
    file.read(reinterpret_cast<char*>(&nameLen), sizeof(nameLen));
    if (nameLen > 0 && nameLen < 1024) {
        std::vector<char> nameChars(nameLen);
        file.read(nameChars.data(), nameLen);
        data.name.assign(nameChars.data(), nameLen);
    }

    file.read(reinterpret_cast<char*>(data.boundsMin), sizeof(data.boundsMin));
    file.read(reinterpret_cast<char*>(data.boundsMax), sizeof(data.boundsMax));

    uint32_t vertCount = 0;
    file.read(reinterpret_cast<char*>(&vertCount), sizeof(vertCount));
    if (vertCount > 0 && vertCount < 20000000) {
        data.vertices.resize(vertCount);
        file.read(reinterpret_cast<char*>(data.vertices.data()), vertCount * sizeof(Vertex3D));
    }

    uint32_t idxCount = 0;
    file.read(reinterpret_cast<char*>(&idxCount), sizeof(idxCount));
    if (idxCount > 0 && idxCount < 60000000) {
        data.indices.resize(idxCount);
        file.read(reinterpret_cast<char*>(data.indices.data()), idxCount * sizeof(uint32_t));
    }

    data.valid = true;
    return data;
}

bool AssetCache::saveToCache(const std::string& key, const CachedModelData& data) {
    std::lock_guard<std::mutex> lock(mutex_);
    try {
        std::filesystem::create_directories(cacheDir_);
    } catch (...) {}

    std::string path = cacheDir_ + "/" + key + ".a3d";
    std::ofstream file(path, std::ios::binary);
    if (!file.is_open()) return false;

    // Magic
    file.write("A3D1", 4);

    uint32_t nameLen = static_cast<uint32_t>(data.name.length());
    file.write(reinterpret_cast<const char*>(&nameLen), sizeof(nameLen));
    if (nameLen > 0) {
        file.write(data.name.data(), nameLen);
    }

    file.write(reinterpret_cast<const char*>(data.boundsMin), sizeof(data.boundsMin));
    file.write(reinterpret_cast<const char*>(data.boundsMax), sizeof(data.boundsMax));

    uint32_t vertCount = static_cast<uint32_t>(data.vertices.size());
    file.write(reinterpret_cast<const char*>(&vertCount), sizeof(vertCount));
    if (vertCount > 0) {
        file.write(reinterpret_cast<const char*>(data.vertices.data()), vertCount * sizeof(Vertex3D));
    }

    uint32_t idxCount = static_cast<uint32_t>(data.indices.size());
    file.write(reinterpret_cast<const char*>(&idxCount), sizeof(idxCount));
    if (idxCount > 0) {
        file.write(reinterpret_cast<const char*>(data.indices.data()), idxCount * sizeof(uint32_t));
    }

    return true;
}

} // namespace aurea
