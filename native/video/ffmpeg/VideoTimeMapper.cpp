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

bool VideoTimeMapper::findBoundingFrames(int64_t targetTimeUs, int64_t& outPtsA, int64_t& outPtsB, float& outT) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (frameIndexTable_.empty()) {
        double frameDurUs = 1000000.0 / std::max(1.0, streamInfo_.fps);
        int64_t idxA = static_cast<int64_t>(std::floor(static_cast<double>(targetTimeUs) / frameDurUs));
        if (idxA < 0) idxA = 0;
        int64_t idxB = idxA + 1;
        outPtsA = static_cast<int64_t>(idxA * frameDurUs);
        outPtsB = static_cast<int64_t>(idxB * frameDurUs);
        double delta = static_cast<double>(targetTimeUs - outPtsA);
        outT = static_cast<float>(std::clamp(delta / frameDurUs, 0.0, 1.0));
        return true;
    }

    if (targetTimeUs <= frameIndexTable_.front().ptsUs) {
        outPtsA = frameIndexTable_.front().ptsUs;
        outPtsB = frameIndexTable_.size() > 1 ? frameIndexTable_[1].ptsUs : outPtsA;
        outT = 0.0f;
        return true;
    }

    if (targetTimeUs >= frameIndexTable_.back().ptsUs) {
        outPtsA = frameIndexTable_.back().ptsUs;
        outPtsB = outPtsA;
        outT = 0.0f;
        return true;
    }

    FrameTimestampEntry target{targetTimeUs, 0, false};
    auto it = std::lower_bound(frameIndexTable_.begin(), frameIndexTable_.end(), target);
    if (it != frameIndexTable_.end() && it->ptsUs == targetTimeUs) {
        outPtsA = it->ptsUs;
        outPtsB = it->ptsUs;
        outT = 0.0f;
        return true;
    }

    auto nextIt = it;
    auto prevIt = it - 1;
    outPtsA = prevIt->ptsUs;
    outPtsB = nextIt->ptsUs;
    int64_t span = outPtsB - outPtsA;
    if (span <= 0) {
        outT = 0.0f;
    } else {
        outT = static_cast<float>(std::clamp(static_cast<double>(targetTimeUs - outPtsA) / span, 0.0, 1.0));
    }
    return true;
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
