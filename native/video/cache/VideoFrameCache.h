#pragma once

#include "../ffmpeg/FFmpegTypes.h"
#include <unordered_map>
#include <list>
#include <memory>
#include <mutex>

namespace aurea {

struct CacheEntry {
    int64_t ptsUs = 0;
    std::shared_ptr<DecodedVideoFrame> frame;
    size_t sizeBytes = 0;
};

class VideoFrameCache {
public:
    explicit VideoFrameCache(size_t maxMemoryBytes = 128 * 1024 * 1024); // 128 MB padrão
    ~VideoFrameCache() = default;

    // Tenta obter um quadro em cache com tolerância temporal (ex: dentro do frame duration)
    std::shared_ptr<DecodedVideoFrame> get(int64_t ptsUs, int64_t toleranceUs = 16666);

    // Insere um quadro decodificado no cache LRU respeitando o orçamento de memória
    void put(std::shared_ptr<DecodedVideoFrame> frame);

    // Limpa todo o cache
    void clear();

    // Configura orçamento de RAM
    void setMaxMemoryBytes(size_t bytes);
    size_t getMaxMemoryBytes() const { return maxMemoryBytes_; }
    size_t getCurrentMemoryBytes() const { return currentMemoryBytes_; }

    // Estatísticas de desempenho
    uint64_t getHitCount() const { return hitCount_; }
    uint64_t getMissCount() const { return missCount_; }
    double getHitRate() const;

private:
    size_t maxMemoryBytes_;
    size_t currentMemoryBytes_ = 0;

    // Lista duplamente ligada para LRU (mais recente no início, mais antigo no fim)
    std::list<CacheEntry> lruList_;
    // Mapa rápido PTS -> iterador na lista LRU
    std::unordered_map<int64_t, std::list<CacheEntry>::iterator> indexMap_;

    uint64_t hitCount_ = 0;
    uint64_t missCount_ = 0;
    mutable std::mutex mutex_;

    void evictOldest();
};

} // namespace aurea
