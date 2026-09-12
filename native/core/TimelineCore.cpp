#include "TimelineCore.h"
#include <algorithm>

namespace aurea {

TimelineCore::TimelineCore(int fps)
    : fps_(fps > 0 ? fps : 30),
      frameDurationUs_(1000000 / (fps > 0 ? fps : 30)) {
}

void TimelineCore::setFps(int fps) {
    if (fps > 0) {
        fps_ = fps;
        frameDurationUs_ = 1000000 / fps;
    }
}

void TimelineCore::setDurationUs(int64_t durationUs) {
    durationUs_ = std::max(int64_t(0), durationUs);
    if (currentTimeUs_.load() > durationUs_) {
        currentTimeUs_.store(durationUs_);
    }
}

void TimelineCore::play() {
    state_ = PlaybackState::Playing;
}

void TimelineCore::pause() {
    state_ = PlaybackState::Paused;
}

void TimelineCore::togglePlayPause() {
    if (state_ == PlaybackState::Playing) {
        pause();
    } else {
        play();
    }
}

void TimelineCore::seekToUs(int64_t timeUs) {
    int64_t clamped = std::clamp(timeUs, int64_t(0), durationUs_);
    currentTimeUs_.store(clamped);
}

void TimelineCore::seekToFrame(int frameIndex) {
    seekToUs(frameToUs(frameIndex));
}

int TimelineCore::getCurrentFrame() const {
    return usToFrame(currentTimeUs_.load());
}

int64_t TimelineCore::advanceTime(double deltaSeconds) {
    if (state_ != PlaybackState::Playing) {
        return currentTimeUs_.load();
    }

    int64_t deltaUs = static_cast<int64_t>(deltaSeconds * 1000000.0);
    int64_t nextTime = currentTimeUs_.load() + deltaUs;

    if (nextTime >= durationUs_) {
        if (looping_ && durationUs_ > 0) {
            nextTime = nextTime % durationUs_;
        } else {
            nextTime = durationUs_;
            pause();
        }
    }

    currentTimeUs_.store(nextTime);
    return nextTime;
}

int64_t TimelineCore::frameToUs(int frameIndex) const {
    if (fps_ <= 0) return 0;
    return (static_cast<int64_t>(frameIndex) * 1000000LL) / fps_;
}

int TimelineCore::usToFrame(int64_t timeUs) const {
    if (frameDurationUs_ <= 0) return 0;
    return static_cast<int>((timeUs + (frameDurationUs_ / 2)) / frameDurationUs_);
}

} // namespace aurea
