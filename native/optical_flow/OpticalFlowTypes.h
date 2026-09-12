#pragma once

#include <cstdint>
#include <vector>
#include <string>
#include <memory>

namespace aurea {

enum class FlowQuality {
    Low = 0,      // Preview rápido, resolução reduzida, escala 0.5x
    Medium = 1,   // Equilibrado para playback interativo (escala 0.75x)
    High = 2,     // Alta fidelidade para timeline precisa e export intermediário
    Ultra = 3     // Máxima qualidade sem concessões (Export 4K/60/120fps)
};

enum class FlowResolution {
    Res480p,
    Res720p,
    Res1080p,
    Res1440p,
    Res4K,
    Original
};

struct RIFEModelConfig {
    std::string modelName = "rife-v4.6";
    std::string modelVersion = "4.6";
    std::string modelPath;
    std::string paramFile;
    std::string binFile;
    float scale = 1.0f;
    bool useFp16 = true;
    bool useTta = false;
    int numThreads = 4;
    int targetGpuId = 0;
};

struct FlowInterpolationRequest {
    uint64_t requestId = 0;
    uint64_t generationId = 0;
    int64_t ptsAUs = 0;
    int64_t ptsBUs = 0;
    int64_t targetPtsUs = 0;
    float t = 0.5f; // [0.0 .. 1.0]
    FlowQuality quality = FlowQuality::High;
    FlowResolution resolution = FlowResolution::Original;
    bool preview = true;
    bool exportMode = false;
};

struct InterpolatedFrame {
    int64_t ptsUs = 0;
    int64_t targetPtsUs = 0;
    int width = 0;
    int height = 0;
    std::vector<uint8_t> rgbaData;
    uint32_t gpuTextureId = 0;
    uint64_t generationId = 0;
    bool isSceneCut = false;
    bool isCached = false;
    float inferenceTimeMs = 0.0f;
};

struct FlowCacheKey {
    int64_t ptsAUs = 0;
    int64_t ptsBUs = 0;
    int32_t quantizedT = 0; // t multiplicado por 1000 (0..1000)
    int width = 0;
    int height = 0;
    FlowQuality quality = FlowQuality::High;
    std::string modelVersion;

    bool operator==(const FlowCacheKey& other) const {
        return ptsAUs == other.ptsAUs &&
               ptsBUs == other.ptsBUs &&
               quantizedT == other.quantizedT &&
               width == other.width &&
               height == other.height &&
               quality == other.quality &&
               modelVersion == other.modelVersion;
    }
};

struct FlowCacheKeyHash {
    std::size_t operator()(const FlowCacheKey& k) const {
        std::size_t h1 = std::hash<int64_t>{}(k.ptsAUs);
        std::size_t h2 = std::hash<int64_t>{}(k.ptsBUs);
        std::size_t h3 = std::hash<int32_t>{}(k.quantizedT);
        std::size_t h4 = std::hash<int>{}(k.width ^ (k.height << 16));
        std::size_t h5 = std::hash<int>{}(static_cast<int>(k.quality));
        std::size_t h6 = std::hash<std::string>{}(k.modelVersion);
        return h1 ^ (h2 << 1) ^ (h3 << 2) ^ (h4 << 3) ^ (h5 << 4) ^ (h6 << 5);
    }
};

struct OpticalFlowDiagnostics {
    bool enabled = false;
    bool modelLoaded = false;
    std::string modelName;
    std::string backendName;
    bool vulkanAvailable = false;
    int gpuDeviceId = 0;
    float lastInferenceTimeMs = 0.0f;
    float avgInferenceTimeMs = 0.0f;
    uint64_t cacheHits = 0;
    uint64_t cacheMisses = 0;
    uint64_t droppedJobs = 0;
    uint64_t completedJobs = 0;
    uint64_t sceneCutsDetected = 0;
    int activeWorkers = 0;
    int pendingJobs = 0;
};

} // namespace aurea
