#pragma once

#include <cstdint>
#include <array>
#include <string>

namespace aurea {

struct Material3D {
    std::string name = "DefaultMaterial";
    std::array<float, 4> albedoColor = {0.8f, 0.8f, 0.8f, 1.0f};
    float roughness = 0.5f;
    float metallic = 0.0f;
    float emissive = 0.0f;
    uint32_t albedoTextureId = 0;
    uint32_t normalTextureId = 0;
    bool doubleSided = false;
};

class MaterialManager {
public:
    MaterialManager() = default;
    ~MaterialManager() = default;

    static Material3D createDefault();
    static Material3D createMetal(const std::array<float, 4>& color);
    static Material3D createGlossy(const std::array<float, 4>& color);
};

} // namespace aurea
