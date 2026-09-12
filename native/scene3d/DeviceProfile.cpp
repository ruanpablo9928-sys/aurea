#include "DeviceProfile.h"
#include <thread>
#include <algorithm>

#if defined(__ANDROID__)
#include <sys/sysinfo.h>
#include <GLES3/gl3.h>
#endif

namespace aurea {

DeviceProfile& DeviceProfile::instance() {
    static DeviceProfile sInstance;
    return sInstance;
}

DeviceProfile::DeviceProfile() {
    detectHardware();
}

void DeviceProfile::detectHardware() {
    caps_.cpuCores = static_cast<int>(std::thread::hardware_concurrency());
    if (caps_.cpuCores <= 0) caps_.cpuCores = 4;

#if defined(__ANDROID__)
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        caps_.totalRamMb = (info.totalram * info.mem_unit) / (1024 * 1024);
    } else {
        caps_.totalRamMb = 4096;
    }
#else
    caps_.totalRamMb = 8192;
#endif

    // Classificação de Tier baseada em RAM e núcleos de CPU
    if (caps_.totalRamMb <= 3072 || caps_.cpuCores <= 4) {
        setCustomTier(DeviceTier::Low);
    } else if (caps_.totalRamMb <= 6144 || caps_.cpuCores <= 6) {
        setCustomTier(DeviceTier::Medium);
    } else if (caps_.totalRamMb <= 10240 || caps_.cpuCores <= 8) {
        setCustomTier(DeviceTier::High);
    } else {
        setCustomTier(DeviceTier::Ultra);
    }
}

void DeviceProfile::setCustomTier(DeviceTier tier) {
    caps_.tier = tier;
    switch (tier) {
        case DeviceTier::Low:
            caps_.maxTextureDimension = 1024;
            caps_.maxTrianglesPerMesh = 100000;
            caps_.maxVramBudgetMb = 256;
            caps_.defaultUploadSliceMs = 1.5f;
            break;
        case DeviceTier::Medium:
            caps_.maxTextureDimension = 2048;
            caps_.maxTrianglesPerMesh = 300000;
            caps_.maxVramBudgetMb = 512;
            caps_.defaultUploadSliceMs = 2.5f;
            break;
        case DeviceTier::High:
            caps_.maxTextureDimension = 4096;
            caps_.maxTrianglesPerMesh = 800000;
            caps_.maxVramBudgetMb = 1024;
            caps_.defaultUploadSliceMs = 3.5f;
            break;
        case DeviceTier::Ultra:
            caps_.maxTextureDimension = 8192;
            caps_.maxTrianglesPerMesh = 2000000;
            caps_.maxVramBudgetMb = 2048;
            caps_.defaultUploadSliceMs = 5.0f;
            break;
    }
}

int DeviceProfile::clampTextureDimension(int width, int height) const {
    int maxDim = std::max(width, height);
    if (maxDim <= caps_.maxTextureDimension) {
        return maxDim;
    }
    return caps_.maxTextureDimension;
}

bool DeviceProfile::isMeshWithinBudget(int triangleCount) const {
    return triangleCount <= caps_.maxTrianglesPerMesh;
}

} // namespace aurea
