#pragma once

#include "Assets.h"
#include "Camera.h"
#include <memory>
#include <vector>
#include <array>

namespace aurea {

struct BoundingBox {
    Vec3 min{-0.5f, -0.5f, -0.5f};
    Vec3 max{ 0.5f,  0.5f,  0.5f};

    Vec3 getCenter() const {
        return (min + max) * 0.5f;
    }

    Vec3 getSize() const {
        return max - min;
    }

    float getRadius() const {
        Vec3 half = (max - min) * 0.5f;
        return std::sqrt(half.x * half.x + half.y * half.y + half.z * half.z);
    }
};

struct MeshLODGroup {
    std::string name;
    BoundingBox bounds;
    std::shared_ptr<Mesh3D> lod0; // Full
    std::shared_ptr<Mesh3D> lod1; // Medium
    std::shared_ptr<Mesh3D> lod2; // Low
    std::shared_ptr<Mesh3D> lod3; // Proxy (Bounding Box)

    int activeLOD = 0;
};

class LODManager {
public:
    LODManager() = default;
    ~LODManager() = default;

    // Cria instantaneamente uma malha proxy de caixa delimitadora (LOD 3) em < 1ms
    static std::shared_ptr<Mesh3D> createProxyMesh(const BoundingBox& bounds);

    // Seleciona o LOD apropriado com base na distância da câmera e tamanho aparente
    static int selectLOD(const BoundingBox& bounds, const Vec3& nodePos, const Vec3& cameraPos, float fovDegrees, int viewportHeight);
};

} // namespace aurea
