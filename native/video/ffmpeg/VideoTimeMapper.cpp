#include "VideoTimeMapper.h"
#include <cmath>

namespace aurea {

VideoTimeMapper::VideoTimeMapper() = default;

void VideoTimeMapper::setStreamInfo(const VideoStreamInfo& info) {
    std::lock_guard<std::mutex> lock(mutex_);
    streamInfo_ = info;
    isVFR_ = info.isVFR;
}

void VideoTimeMapper::registerFrameTimestamp(int64_t ptsUs, int64_t durationUs, bool isKeyframe) {
    std::lock_guard<std::mutex> lock(mutex_);

    FrameTimestampEntry entry{ptsUs, durationUs, isKeyframe};
    auto it = std::lower_bound(frameIndexTable_.begin(), frameIndexTable_.end(), entry);
    if (it != frameIndexTable_.end() && it->ptsUs == ptsUs) {
        *it = entry;
    } else {
        frameIndexTable_.insert(it, entry);
        detectVFR();
    }
}

void VideoTimeMapper::detectVFR() {
    if (frameIndexTable_.size() < 4) return;
    int64_t firstDelta = frameIndexTable_[1].ptsUs - frameIndexTable_[0].ptsUs;
    for (size_t i = 2; i < std::min<size_t>(frameIndexTable_.size(), 20); ++i) {
        int64_t delta = frameIndexTable_[i].ptsUs - frameIndexTable_[i - 1].ptsUs;
        if (std::abs(delta - firstDelta) > 4000) { // variação > 4ms
            isVFR_ = true;
            return;
        }
    }
}

int64_t VideoTimeMapper::findClosestPtsUs(int64_t targetTimeUs) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (frameIndexTable_.empty()) {
        // Fallback baseado no FPS declarado
        double frameDurationUs = 1000000.0 / std::max(1.0, streamInfo_.fps);
        int64_t frameIdx = static_cast<int64_t>(std::round(targetTimeUs / frameDurationUs));
        return static_cast<int64_t>(frameIdx * frameDurationUs);
    }

    FrameTimestampEntry target{targetTimeUs, 0, false};
    auto it = std::lower_bound(frameIndexTable_.begin(), frameIndexTable_.end(), target);

    if (it == frameIndexTable_.end()) {
        return frameIndexTable_.back().ptsUs;
    }
    if (it == frameIndexTable_.begin()) {
        return frameIndexTable_.front().ptsUs;
    }

    auto prev = it - 1;
    if (std::abs(targetTimeUs - prev->ptsUs) <= std::abs(it->ptsUs - targetTimeUs)) {
        return prev->ptsUs;
    }
    return it->ptsUs;
}

int64_t VideoTimeMapper::findPrecedingKeyframePtsUs(int64_t targetTimeUs) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (frameIndexTable_.empty()) {
        return std::max<int64_t>(0, targetTimeUs - 1000000); // 1s antes
    }

    int64_t bestKeyframe = frameIndexTable_.front().ptsUs;
    for (const auto& entry : frameIndexTable_) {
        if (entry.ptsUs > targetTimeUs) break;
        if (entry.isKeyframe) {
            bestKeyframe = entry.ptsUs;
        }
    }
    return bestKeyframe;
}

int64_t VideoTimeMapper::ptsToFrameIndex(int64_t ptsUs) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!frameIndexTable_.empty()) {
        FrameTimestampEntry target{ptsUs, 0, false};
        auto it = std::lower_bound(frameIndexTable_.begin(), frameIndexTable_.end(), target);
        if (it != frameIndexTable_.end()) {
            return std::distance(frameIndexTable_.begin(), it);
        }
    }
    double frameDurationUs = 1000000.0 / std::max(1.0, streamInfo_.fps);
    return static_cast<int64_t>(std::round(ptsUs / frameDurationUs));
}

int64_t VideoTimeMapper::frameIndexToPtsUs(int64_t frameIndex) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (frameIndex >= 0 && static_cast<size_t>(frameIndex) < frameIndexTable_.size()) {
        return frameIndexTable_[frameIndex].ptsUs;
    }
    double frameDurationUs = 1000000.0 / std::max(1.0, streamInfo_.fps);
    return static_cast<int64_t>(frameIndex * frameDurationUs);
}

void VideoTimeMapper::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    frameIndexTable_.clear();
    isVFR_ = false;
}

} // namespace aurea
