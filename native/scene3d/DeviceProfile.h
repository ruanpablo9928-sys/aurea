#pragma once

#include <cstdint>
#include <string>

namespace aurea {

enum class DeviceTier {
    Low = 0,
    Medium = 1,
    High = 2,
    Ultra = 3
};

struct DeviceCapabilities {
    DeviceTier tier = DeviceTier::Medium;
    int cpuCores = 4;
    int64_t totalRamMb = 4096;
    int maxTextureDimension = 2048;
    int maxTrianglesPerMesh = 250000;
    int64_t maxVramBudgetMb = 512;
    float defaultUploadSliceMs = 2.5f;
    bool supportsAstc = true;
    bool supportsDepth24Stencil8 = true;
    std::string gpuRendererName = "Generic Mobile GPU";
};

class DeviceProfile {
public:
    static DeviceProfile& instance();

    DeviceProfile();
    ~DeviceProfile() = default;

    const DeviceCapabilities& getCapabilities() const { return caps_; }
    DeviceTier getTier() const { return caps_.tier; }

    void detectHardware();
    void setCustomTier(DeviceTier tier);

    // Avalia e adapta limites para uma textura
    int clampTextureDimension(int width, int height) const;

    // Avalia se o modelo ultrapassa os limites recomendados
    bool isMeshWithinBudget(int triangleCount) const;

private:
    DeviceCapabilities caps_;
};

} // namespace aurea
