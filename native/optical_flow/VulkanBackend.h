#pragma once

#include "OpticalFlowTypes.h"
#include <string>
#include <vector>

namespace aurea {

struct VulkanDeviceInfo {
    bool isSupported = false;
    std::string deviceName;
    uint32_t apiVersion = 0;
    uint32_t driverVersion = 0;
    int deviceId = 0;
    bool supportsCompute = false;
    bool supportsFp16Packed = false;
    bool supportsFp16Storage = false;
    bool supportsFp16Arithmetic = false;
    int64_t dedicatedVramMb = 0;
    uint32_t maxComputeWorkGroupSize[3] = {0, 0, 0};
};

struct TileInfo {
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;
    int padLeft = 0;
    int padTop = 0;
    int padRight = 0;
    int padBottom = 0;
};

class VulkanBackend {
public:
    VulkanBackend();
    ~VulkanBackend();

    // Inicializa e verifica capacidades da GPU e runtime Vulkan
    bool initialize();
    void shutdown();

    bool isAvailable() const { return initialized_ && deviceInfo_.isSupported; }
    const VulkanDeviceInfo& getDeviceInfo() const { return deviceInfo_; }

    // Calcula divisão de ladrilhos (tiling) com sobreposição para evitar artefatos de emenda em 4K
    std::vector<TileInfo> computeTiling(int imageWidth, int imageHeight, int maxTileSize = 1024, int overlap = 32) const;

private:
    bool initialized_ = false;
    VulkanDeviceInfo deviceInfo_;

    void queryCapabilities();
};

} // namespace aurea
