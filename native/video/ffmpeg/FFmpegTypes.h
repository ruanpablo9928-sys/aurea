#pragma once

#include <cstdint>
#include <vector>
#include <string>
#include <memory>

namespace aurea {

struct Rational {
    int num = 1;
    int den = 1;

    double toDouble() const {
        return den != 0 ? static_cast<double>(num) / static_cast<double>(den) : 0.0;
    }
};

struct VideoStreamInfo {
    int width = 0;
    int height = 0;
    double fps = 30.0;
    int64_t durationUs = 0;
    Rational timeBase{1, 1000000};
    int64_t totalFrames = 0;
    bool isVFR = false;
    std::string codecName;
};

struct DecodedVideoFrame {
    int64_t ptsUs = 0;
    double ptsSeconds = 0.0;
    int width = 0;
    int height = 0;
    std::vector<uint8_t> rgbaData;
    uint64_t generationId = 0;
    bool isKeyframe = false;
    uint32_t gpuTextureId = 0; // Se já alocado em GPU
};

enum class SeekAccuracy {
    NearestKeyframe,
    ExactFrame
};

} // namespace aurea
