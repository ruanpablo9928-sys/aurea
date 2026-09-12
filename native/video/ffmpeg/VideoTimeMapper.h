#pragma once

#include "FFmpegTypes.h"
#include <vector>
#include <mutex>
#include <algorithm>

namespace aurea {

struct FrameTimestampEntry {
    int64_t ptsUs = 0;
    int64_t durationUs = 0;
    bool isKeyframe = false;

    bool operator<(const FrameTimestampEntry& other) const {
        return ptsUs < other.ptsUs;
    }
};

class VideoTimeMapper {
public:
    VideoTimeMapper();
    ~VideoTimeMapper() = default;

    void setStreamInfo(const VideoStreamInfo& info);
    const VideoStreamInfo& getStreamInfo() const { return streamInfo_; }

    // Registra timestamp real obtido do demuxer/decoder
    void registerFrameTimestamp(int64_t ptsUs, int64_t durationUs, bool isKeyframe);

    // Encontra o PTS de quadro mais próximo para um tempo de fonte desejado (em microssegundos)
    int64_t findClosestPtsUs(int64_t targetTimeUs) const;

    // Encontra os dois quadros delimitadores [Frame A, Frame B] e o fator t [0..1] para interpolação
    bool findBoundingFrames(int64_t targetTimeUs, int64_t& outPtsA, int64_t& outPtsB, float& outT) const;

    // Encontra o keyframe anterior mais próximo para seek seguro
    int64_t findPrecedingKeyframePtsUs(int64_t targetTimeUs) const;

    // Converte timestamp para índice aproximado de quadro
    int64_t ptsToFrameIndex(int64_t ptsUs) const;

    // Converte índice de quadro para timestamp previsto
    int64_t frameIndexToPtsUs(int64_t frameIndex) const;

    // Retorna se o fluxo apresenta taxa variável de quadros detectada
    bool isVariableFrameRate() const { return isVFR_; }

    void clear();

private:
    VideoStreamInfo streamInfo_;
    std::vector<FrameTimestampEntry> frameIndexTable_;
    bool isVFR_ = false;
    mutable std::mutex mutex_;

    void detectVFR();
};

} // namespace aurea
