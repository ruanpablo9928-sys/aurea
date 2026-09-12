#pragma once

#include "OpticalFlowTypes.h"
#include <unordered_map>
#include <list>
#include <memory>
#include <mutex>
#include <cstddef>

namespace aurea {

struct FlowCacheEntry {
    FlowCacheKey key;
    std::shared_ptr<InterpolatedFrame> frame;
    size_t sizeBytes = 0;
};

class FlowFrameCache {
public:
    explicit FlowFrameCache(size_t maxMemoryBytes = 192 * 1024 * 1024); // 192 MB padrão para mobile
    ~FlowFrameCache();

    // Consulta se o quadro interpolado já existe no cache
    std::shared_ptr<InterpolatedFrame> get(const FlowCacheKey& key);

    // Insere um novo quadro interpolado no cache LRU
    void put(const FlowCacheKey& key, std::shared_ptr<InterpolatedFrame> frame);

    // Remove entradas e limpa texturas associadas
    void clear();

    // Orçamento dinâmico de memória
    void setMaxMemoryBytes(size_t maxBytes);
    size_t getMaxMemoryBytes() const { return maxMemoryBytes_; }
    size_t getCurrentMemoryBytes() const { return currentMemoryBytes_; }
    size_t getEntryCount() const;

    // Métricas de desempenho
    uint64_t getHitCount() const { return hitCount_; }
    uint64_t getMissCount() const { return missCount_; }
    uint64_t getEvictionCount() const { return evictionCount_; }
    double getHitRate() const;

    static int32_t quantizeTime(float t) {
        // Quantiza t com resolução de 0.001 (ex: t=0.5 -> 500)
        return static_cast<int32_t>(std::clamp(t, 0.0f, 1.0f) * 1000.0f + 0.5f);
    }

private:
    size_t maxMemoryBytes_;
    size_t currentMemoryBytes_ = 0;

    std::list<FlowCacheEntry> lruList_;
    std::unordered_map<FlowCacheKey, std::list<FlowCacheEntry>::iterator, FlowCacheKeyHash> map_;

    uint64_t hitCount_ = 0;
    uint64_t missCount_ = 0;
    uint64_t evictionCount_ = 0;
    mutable std::mutex mutex_;

    void evictOldest();
};

} // namespace aurea
