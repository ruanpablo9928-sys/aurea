#pragma once

#include "DeviceProfile.h"
#include <string>
#include <vector>
#include <cstdint>

namespace aurea {

struct ModelAnalysisReport {
    std::string filePath;
    int64_t fileSizeBytes = 0;
    int meshCount = 0;
    int vertexCount = 0;
    int triangleCount = 0;
    int materialCount = 0;
    int textureCount = 0;
    int largestTextureWidth = 0;
    int largestTextureHeight = 0;
    int boneCount = 0;
    int animationCount = 0;
    int nodeCount = 0;

    float estimatedCpuMemoryMb = 0.0f;
    float estimatedGpuMemoryMb = 0.0f;

    bool isSafeForDevice = true;
    int recommendedLOD = 0;
    std::vector<std::string> warnings;
};

class ModelAnalyzer {
public:
    ModelAnalyzer() = default;
    ~ModelAnalyzer() = default;

    // Executa análise rápida sem alocação massiva
    static ModelAnalysisReport analyzeFile(const std::string& filePath, const DeviceProfile& profile);

private:
    static bool analyzeGlb(const std::string& filePath, ModelAnalysisReport& report);
    static bool analyzeGltf(const std::string& filePath, ModelAnalysisReport& report);
    static bool analyzeObj(const std::string& filePath, ModelAnalysisReport& report);
};

} // namespace aurea
