#include "VideoFrameCache.h"
#include <cmath>

namespace aurea {

VideoFrameCache::VideoFrameCache(size_t maxMemoryBytes)
    : maxMemoryBytes_(maxMemoryBytes) {
}

std::shared_ptr<DecodedVideoFrame> VideoFrameCache::get(int64_t ptsUs, int64_t toleranceUs) {
    std::lock_guard<std::mutex> lock(mutex_);

    // 1. Procura chave exata
    auto it = indexMap_.find(ptsUs);
    if (it != indexMap_.end()) {
        // Move para a frente da lista LRU (mais recentemente usado)
        lruList_.splice(lruList_.begin(), lruList_, it->second);
        hitCount_++;
        return it->second->frame;
    }

    // 2. Procura com tolerância temporal (para VFR ou desvios menores que 1 quadro)
    for (auto listIt = lruList_.begin(); listIt != lruList_.end(); ++listIt) {
        if (std::abs(listIt->ptsUs - ptsUs) <= toleranceUs) {
            lruList_.splice(lruList_.begin(), lruList_, listIt);
            hitCount_++;
            return listIt->frame;
        }
    }

    missCount_++;
    return nullptr;
}

void VideoFrameCache::put(std::shared_ptr<DecodedVideoFrame> frame) {
    if (!frame) return;

    std::lock_guard<std::mutex> lock(mutex_);

    size_t frameBytes = frame->rgbaData.size() + sizeof(DecodedVideoFrame);

    // Se o quadro já existir no cache, atualiza
    auto it = indexMap_.find(frame->ptsUs);
    if (it != indexMap_.end()) {
        currentMemoryBytes_ -= it->second->sizeBytes;
        it->second->frame = frame;
        it->second->sizeBytes = frameBytes;
        currentMemoryBytes_ += frameBytes;
        lruList_.splice(lruList_.begin(), lruList_, it->second);
        return;
    }

    // Libera espaço até caber no orçamento de memória
    while (currentMemoryBytes_ + frameBytes > maxMemoryBytes_ && !lruList_.empty()) {
        evictOldest();
    }

    // Insere no topo da lista LRU
    CacheEntry entry{frame->ptsUs, frame, frameBytes};
    lruList_.push_front(entry);
    indexMap_[frame->ptsUs] = lruList_.begin();
    currentMemoryBytes_ += frameBytes;
}

void VideoFrameCache::evictOldest() {
    if (lruList_.empty()) return;

    auto lastIt = --lruList_.end();
    currentMemoryBytes_ -= lastIt->sizeBytes;
    indexMap_.erase(lastIt->ptsUs);
    lruList_.pop_back();
}

void VideoFrameCache::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    lruList_.clear();
    indexMap_.clear();
    currentMemoryBytes_ = 0;
}

void VideoFrameCache::setMaxMemoryBytes(size_t bytes) {
    std::lock_guard<std::mutex> lock(mutex_);
    maxMemoryBytes_ = bytes;
    while (currentMemoryBytes_ > maxMemoryBytes_ && !lruList_.empty()) {
        evictOldest();
    }
}

double VideoFrameCache::getHitRate() const {
    uint64_t total = hitCount_ + missCount_;
    return total > 0 ? static_cast<double>(hitCount_) / static_cast<double>(total) : 0.0;
}

} // namespace aurea
