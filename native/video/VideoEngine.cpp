#include "VideoEngine.h"

#if defined(__ANDROID__)
#include <media/NdkMediaCodec.h>
#include <media/NdkMediaExtractor.h>
#include <media/NdkMediaFormat.h>
#include <GLES3/gl3.h>
#endif

namespace aurea {

VideoTrack::VideoTrack(const std::string& filePath)
    : filePath_(filePath) {
}

VideoTrack::~VideoTrack() {
    close();
}

bool VideoTrack::open() {
    if (isOpen_) return true;

#if defined(__ANDROID__)
    AMediaExtractor* ex = AMediaExtractor_new();
    media_status_t err = AMediaExtractor_setDataSource(ex, filePath_.c_str());
    if (err != AMEDIA_OK) {
        AMediaExtractor_delete(ex);
        return false;
    }

    size_t numTracks = AMediaExtractor_getTrackCount(ex);
    for (size_t i = 0; i < numTracks; ++i) {
        AMediaFormat* format = AMediaExtractor_getTrackFormat(ex, i);
        const char* mime;
        if (AMediaFormat_getString(format, AMEDIAFORMAT_KEY_MIME, &mime)) {
            if (strncmp(mime, "video/", 6) == 0) {
                AMediaExtractor_selectTrack(ex, i);
                AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_WIDTH, &width_);
                AMediaFormat_getInt32(format, AMEDIAFORMAT_KEY_HEIGHT, &height_);
                AMediaFormat_getInt64(format, AMEDIAFORMAT_KEY_DURATION, &durationUs_);

                AMediaCodec* codec = AMediaCodec_createDecoderByType(mime);
                AMediaCodec_configure(codec, format, nullptr, nullptr, 0);
                AMediaCodec_start(codec);

                mediaExtractor_ = ex;
                mediaCodec_ = codec;
                AMediaFormat_delete(format);
                isOpen_ = true;
                return true;
            }
        }
        AMediaFormat_delete(format);
    }
    AMediaExtractor_delete(ex);
    return false;
#else
    isOpen_ = true;
    width_ = 1920;
    height_ = 1080;
    durationUs_ = 10000000;
    return true;
#endif
}

void VideoTrack::close() {
#if defined(__ANDROID__)
    if (mediaCodec_) {
        AMediaCodec_stop(static_cast<AMediaCodec*>(mediaCodec_));
        AMediaCodec_delete(static_cast<AMediaCodec*>(mediaCodec_));
        mediaCodec_ = nullptr;
    }
    if (mediaExtractor_) {
        AMediaExtractor_delete(static_cast<AMediaExtractor*>(mediaExtractor_));
        mediaExtractor_ = nullptr;
    }
    if (currentTextureId_ != 0) {
        glDeleteTextures(1, &currentTextureId_);
        currentTextureId_ = 0;
    }
#endif
    isOpen_ = false;
}

bool VideoTrack::seekTo(int64_t timeUs) {
    if (!isOpen_) return false;

#if defined(__ANDROID__)
    if (mediaExtractor_) {
        AMediaExtractor_seekTo(static_cast<AMediaExtractor*>(mediaExtractor_), timeUs, AMEDIAEXTRACTOR_SEEK_CLOSEST_SYNC);
        return true;
    }
#else
    (void)timeUs;
#endif
    return true;
}

VideoEngine::VideoEngine() = default;

VideoEngine::~VideoEngine() {
    clearCache();
}

std::shared_ptr<VideoTrack> VideoEngine::loadVideo(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = tracks_.find(filePath);
    if (it != tracks_.end()) {
        return it->second;
    }

    auto track = std::make_shared<VideoTrack>(filePath);
    track->open();
    tracks_[filePath] = track;
    return track;
}

void VideoEngine::releaseVideo(const std::string& filePath) {
    std::lock_guard<std::mutex> lock(mutex_);
    tracks_.erase(filePath);
}

void VideoEngine::seekAll(int64_t timeUs) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& pair : tracks_) {
        if (pair.second) {
            pair.second->seekTo(timeUs);
        }
    }
}

void VideoEngine::clearCache() {
    std::lock_guard<std::mutex> lock(mutex_);
    tracks_.clear();
}

} // namespace aurea
