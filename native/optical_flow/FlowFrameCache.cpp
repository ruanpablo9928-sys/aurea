#include "FlowFrameCache.h"
#include <algorithm>

namespace aurea {

FlowFrameCache::FlowFrameCache(size_t maxMemoryBytes)
    : maxMemoryBytes_(maxMemoryBytes) {}

FlowFrameCache::~FlowFrameCache() {
    clear();
}

std::shared_ptr<InterpolatedFrame> FlowFrameCache::get(const FlowCacheKey& key) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = map_.find(key);
    if (it == map_.end()) {
        missCount_++;
        return nullptr;
    }

    hitCount_++;
    // Move para o início da lista LRU (mais recentemente usado)
    lruList_.splice(lruList_.begin(), lruList_, it->second);
    return it->second->frame;
}

void FlowFrameCache::put(const FlowCacheKey& key, std::shared_ptr<InterpolatedFrame> frame) {
    if (!frame) return;

    std::lock_guard<std::mutex> lock(mutex_);

    // Tamanho em bytes: dados RGBA brutos em RAM
    size_t frameBytes = frame->rgbaData.size();
    if (frameBytes == 0 && frame->width > 0 && frame->height > 0) {
        frameBytes = static_cast<size_t>(frame->width * frame->height * 4);
    }

    // Se o item sozinho for maior que o cache inteiro, não armazena
    if (frameBytes > maxMemoryBytes_) {
        return;
    }

    auto it = map_.find(key);
    if (it != map_.end()) {
        currentMemoryBytes_ -= it->second->sizeBytes;
        lruList_.erase(it->second);
        map_.erase(it);
    }

    // Libera itens antigos até que o novo quadro caiba
    while (!lruList_.empty() && (currentMemoryBytes_ + frameBytes > maxMemoryBytes_)) {
        evictOldest();
    }

    lruList_.push_front({key, frame, frameBytes});
    map_[key] = lruList_.begin();
    currentMemoryBytes_ += frameBytes;
}

void FlowFrameCache::evictOldest() {
    if (lruList_.empty()) return;
    auto lastIt = std::prev(lruList_.end());
    currentMemoryBytes_ -= lastIt->sizeBytes;
    map_.erase(lastIt->key);
    lruList_.pop_back();
    evictionCount_++;
}

void FlowFrameCache::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    lruList_.clear();
    map_.clear();
    currentMemoryBytes_ = 0;
}

void FlowFrameCache::setMaxMemoryBytes(size_t maxBytes) {
    std::lock_guard<std::mutex> lock(mutex_);
    maxMemoryBytes_ = maxBytes;
    while (!lruList_.empty() && currentMemoryBytes_ > maxMemoryBytes_) {
        evictOldest();
    }
}

size_t FlowFrameCache::getEntryCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return map_.size();
}

double FlowFrameCache::getHitRate() const {
    std::lock_guard<std::mutex> lock(mutex_);
    uint64_t total = hitCount_ + missCount_;
    return total > 0 ? (static_cast<double>(hitCount_) / total) * 100.0 : 0.0;
}

} // namespace aurea
