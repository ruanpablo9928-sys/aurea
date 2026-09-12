#include "VulkanBackend.h"
#include <algorithm>
#include <cmath>

#if defined(__ANDROID__)
#include <vulkan/vulkan.h>
#elif defined(__APPLE__)
// No iOS/macOS, o suporte a Vulkan é opcional através de MoltenVK
#if __has_include(<vulkan/vulkan.h>)
#include <vulkan/vulkan.h>
#define AUREA_HAS_VULKAN_HEADERS 1
#endif
#elif defined(_WIN32) || defined(__linux__)
#if __has_include(<vulkan/vulkan.h>)
#include <vulkan/vulkan.h>
#define AUREA_HAS_VULKAN_HEADERS 1
#endif
#endif

namespace aurea {

VulkanBackend::VulkanBackend() = default;

VulkanBackend::~VulkanBackend() {
    shutdown();
}

bool VulkanBackend::initialize() {
    if (initialized_) return deviceInfo_.isSupported;

    queryCapabilities();
    initialized_ = true;
    return deviceInfo_.isSupported;
}

void VulkanBackend::shutdown() {
    initialized_ = false;
    deviceInfo_.isSupported = false;
}

void VulkanBackend::queryCapabilities() {
    deviceInfo_.isSupported = false;
    deviceInfo_.deviceName = "Vulkan Compute Device";
    deviceInfo_.supportsCompute = false;

#if defined(AUREA_HAS_VULKAN_HEADERS) || defined(__ANDROID__)
    // Verificação de biblioteca Vulkan em tempo de execução
    VkInstance instance = VK_NULL_HANDLE;
    VkApplicationInfo appInfo{};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "Aurea Optical Flow";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "Aurea RIFE Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_1;

    VkInstanceCreateInfo createInfo{};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;

    // Tenta criar instância leve apenas para interrogar dispositivos físicos
    if (vkCreateInstance(&createInfo, nullptr, &instance) == VK_SUCCESS) {
        uint32_t deviceCount = 0;
        vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);

        if (deviceCount > 0) {
            std::vector<VkPhysicalDevice> devices(deviceCount);
            vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data());

            for (const auto& dev : devices) {
                VkPhysicalDeviceProperties props;
                vkGetPhysicalDeviceProperties(dev, &props);

                // Procura por fila com suporte a COMPUTE
                uint32_t queueFamilyCount = 0;
                vkGetPhysicalDeviceQueueFamilyProperties(dev, &queueFamilyCount, nullptr);
                std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
                vkGetPhysicalDeviceQueueFamilyProperties(dev, &queueFamilyCount, queueFamilies.data());

                bool hasCompute = false;
                for (const auto& qf : queueFamilies) {
                    if (qf.queueFlags & VK_QUEUE_COMPUTE_BIT) {
                        hasCompute = true;
                        break;
                    }
                }

                if (hasCompute) {
                    deviceInfo_.isSupported = true;
                    deviceInfo_.deviceName = props.deviceName;
                    deviceInfo_.apiVersion = props.apiVersion;
                    deviceInfo_.driverVersion = props.driverVersion;
                    deviceInfo_.deviceId = static_cast<int>(props.deviceID);
                    deviceInfo_.supportsCompute = true;
                    deviceInfo_.supportsFp16Packed = true;
                    deviceInfo_.supportsFp16Storage = true;
                    deviceInfo_.supportsFp16Arithmetic = true;
                    deviceInfo_.maxComputeWorkGroupSize[0] = props.limits.maxComputeWorkGroupSize[0];
                    deviceInfo_.maxComputeWorkGroupSize[1] = props.limits.maxComputeWorkGroupSize[1];
                    deviceInfo_.maxComputeWorkGroupSize[2] = props.limits.maxComputeWorkGroupSize[2];
                    break;
                }
            }
        }
        vkDestroyInstance(instance, nullptr);
    }
#else
    // Plataforma sem runtime Vulkan: marca como não suportado para acionar fallback transparente
    deviceInfo_.isSupported = false;
    deviceInfo_.deviceName = "Software / Fallback Engine";
#endif
}

std::vector<TileInfo> VulkanBackend::computeTiling(int imageWidth, int imageHeight, int maxTileSize, int overlap) const {
    std::vector<TileInfo> tiles;
    if (imageWidth <= maxTileSize && imageHeight <= maxTileSize) {
        TileInfo singleTile;
        singleTile.x = 0;
        singleTile.y = 0;
        singleTile.width = imageWidth;
        singleTile.height = imageHeight;
        tiles.push_back(singleTile);
        return tiles;
    }

    int step = maxTileSize - overlap * 2;
    if (step <= 0) step = maxTileSize / 2;

    for (int y = 0; y < imageHeight; y += step) {
        int tileY = std::max(0, y - overlap);
        int tileH = std::min(maxTileSize, imageHeight - tileY);

        for (int x = 0; x < imageWidth; x += step) {
            int tileX = std::max(0, x - overlap);
            int tileW = std::min(maxTileSize, imageWidth - tileX);

            TileInfo t;
            t.x = tileX;
            t.y = tileY;
            t.width = tileW;
            t.height = tileH;
            t.padLeft = (tileX > 0) ? overlap : 0;
            t.padTop = (tileY > 0) ? overlap : 0;
            t.padRight = (tileX + tileW < imageWidth) ? overlap : 0;
            t.padBottom = (tileY + tileH < imageHeight) ? overlap : 0;
            tiles.push_back(t);
        }
    }

    return tiles;
}

} // namespace aurea
