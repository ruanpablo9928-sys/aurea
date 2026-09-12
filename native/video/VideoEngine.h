#pragma once

#include <string>
#include <memory>
#include <cstdint>
#include <unordered_map>
#include <mutex>

namespace aurea {

struct VideoFrame {
    int64_t ptsUs = 0;
    int width = 0;
    int height = 0;
    uint32_t textureId = 0;
};

class VideoTrack {
public:
    VideoTrack(const std::string& filePath);
    ~VideoTrack();

    bool open();
    void close();
    bool isOpen() const { return isOpen_; }

    int getWidth() const { return width_; }
    int getHeight() const { return height_; }
    int64_t getDurationUs() const { return durationUs_; }

    // Busca rápida para timestamp
    bool seekTo(int64_t timeUs);

    // Recupera a textura do quadro atual
    uint32_t getCurrentTextureId() const { return currentTextureId_; }

private:
    std::string filePath_;
    bool isOpen_ = false;
    int width_ = 0;
    int height_ = 0;
    int64_t durationUs_ = 0;
    uint32_t currentTextureId_ = 0;

    void* mediaExtractor_ = nullptr;
    void* mediaCodec_ = nullptr;
};

class VideoEngine {
public:
    VideoEngine();
    ~VideoEngine();

    std::shared_ptr<VideoTrack> loadVideo(const std::string& filePath);
    void releaseVideo(const std::string& filePath);

    void seekAll(int64_t timeUs);
    void clearCache();

private:
    std::unordered_map<std::string, std::shared_ptr<VideoTrack>> tracks_;
    mutable std::mutex mutex_;
};

} // namespace aurea
