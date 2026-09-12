#include "Materials.h"

namespace aurea {

Material3D MaterialManager::createDefault() {
    Material3D mat;
    mat.name = "Default";
    mat.albedoColor = {0.8f, 0.8f, 0.8f, 1.0f};
    mat.roughness = 0.5f;
    mat.metallic = 0.0f;
    return mat;
}

Material3D MaterialManager::createMetal(const std::array<float, 4>& color) {
    Material3D mat;
    mat.name = "Metal";
    mat.albedoColor = color;
    mat.roughness = 0.2f;
    mat.metallic = 0.9f;
    return mat;
}

Material3D MaterialManager::createGlossy(const std::array<float, 4>& color) {
    Material3D mat;
    mat.name = "Glossy";
    mat.albedoColor = color;
    mat.roughness = 0.1f;
    mat.metallic = 0.0f;
    return mat;
}

} // namespace aurea
