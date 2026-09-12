#pragma once

#include <cstdint>
#include <atomic>
#include <chrono>

namespace aurea {

enum class PlaybackState {
    Paused,
    Playing,
    Seeking
};

class TimelineCore {
public:
    TimelineCore(int fps = 30);
    ~TimelineCore() = default;

    void setFps(int fps);
    int getFps() const { return fps_; }

    void setDurationUs(int64_t durationUs);
    int64_t getDurationUs() const { return durationUs_; }

    void play();
    void pause();
    void togglePlayPause();
    PlaybackState getState() const { return state_; }
    bool isPlaying() const { return state_ == PlaybackState::Playing; }

    void seekToUs(int64_t timeUs);
    void seekToFrame(int frameIndex);
    int64_t getCurrentTimeUs() const { return currentTimeUs_.load(); }
    int getCurrentFrame() const;

    // Avanço de tempo em playback real-time
    int64_t advanceTime(double deltaSeconds);

    // Conversões de tempo de alta precisão
    int64_t frameToUs(int frameIndex) const;
    int usToFrame(int64_t timeUs) const;

    void setLooping(bool loop) { looping_ = loop; }
    bool isLooping() const { return looping_; }

private:
    int fps_ = 30;
    int64_t frameDurationUs_ = 33333; // 1/30s
    int64_t durationUs_ = 5000000;    // 5s padrão
    std::atomic<int64_t> currentTimeUs_{0};
    PlaybackState state_ = PlaybackState::Paused;
    bool looping_ = true;
};

} // namespace aurea
