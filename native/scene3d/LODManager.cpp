#include "LODManager.h"
#include <cmath>
#include <algorithm>

namespace aurea {

std::shared_ptr<Mesh3D> LODManager::createProxyMesh(const BoundingBox& bounds) {
    auto mesh = std::make_shared<Mesh3D>("Proxy_BoundingBox");

    float minX = bounds.min.x, minY = bounds.min.y, minZ = bounds.min.z;
    float maxX = bounds.max.x, maxY = bounds.max.y, maxZ = bounds.max.z;

    // 8 vértices de uma caixa
    std::vector<Vertex3D> vertices = {
        // Front face (Z+)
        {minX, minY, maxZ, 0, 0, 1, 0, 0},
        {maxX, minY, maxZ, 0, 0, 1, 1, 0},
        {maxX, maxY, maxZ, 0, 0, 1, 1, 1},
        {minX, maxY, maxZ, 0, 0, 1, 0, 1},
        // Back face (Z-)
        {maxX, minY, minZ, 0, 0, -1, 0, 0},
        {minX, minY, minZ, 0, 0, -1, 1, 0},
        {minX, maxY, minZ, 0, 0, -1, 1, 1},
        {maxX, maxY, minZ, 0, 0, -1, 0, 1},
        // Top face (Y+)
        {minX, maxY, maxZ, 0, 1, 0, 0, 0},
        {maxX, maxY, maxZ, 0, 1, 0, 1, 0},
        {maxX, maxY, minZ, 0, 1, 0, 1, 1},
        {minX, maxY, minZ, 0, 1, 0, 0, 1},
        // Bottom face (Y-)
        {minX, minY, minZ, 0, -1, 0, 0, 0},
        {maxX, minY, minZ, 0, -1, 0, 1, 0},
        {maxX, minY, maxZ, 0, -1, 0, 1, 1},
        {minX, minY, maxZ, 0, -1, 0, 0, 1},
        // Right face (X+)
        {maxX, minY, maxZ, 1, 0, 0, 0, 0},
        {maxX, minY, minZ, 1, 0, 0, 1, 0},
        {maxX, maxY, minZ, 1, 0, 0, 1, 1},
        {maxX, maxY, maxZ, 1, 0, 0, 0, 1},
        // Left face (X-)
        {minX, minY, minZ, -1, 0, 0, 0, 0},
        {minX, minY, maxZ, -1, 0, 0, 1, 0},
        {minX, maxY, maxZ, -1, 0, 0, 1, 1},
        {minX, maxY, minZ, -1, 0, 0, 0, 1}
    };

    std::vector<uint32_t> indices;
    indices.reserve(36);
    for (int i = 0; i < 6; ++i) {
        uint32_t offset = i * 4;
        indices.push_back(offset + 0);
        indices.push_back(offset + 1);
        indices.push_back(offset + 2);
        indices.push_back(offset + 2);
        indices.push_back(offset + 3);
        indices.push_back(offset + 0);
    }

    mesh->setGeometry(vertices, indices);
    return mesh;
}

int LODManager::selectLOD(const BoundingBox& bounds,
                         const Vec3& nodePos,
                         const Vec3& cameraPos,
                         float fovDegrees,
                         int viewportHeight) {
    Vec3 diff = nodePos - cameraPos;
    float dist = std::sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z);
    if (dist < 1e-4f) return 0;

    float radius = bounds.getRadius();
    if (radius <= 0.0f) radius = 1.0f;

    // Cálculo do tamanho projetado em pixels na tela
    float fovRad = fovDegrees * (3.141592653589793f / 180.0f);
    float screenHeightRatio = (2.0f * radius) / (2.0f * dist * std::tan(fovRad * 0.5f));
    float pixelSize = screenHeightRatio * viewportHeight;

    if (pixelSize > 500.0f) {
        return 0; // Alta resolução (LOD 0)
    } else if (pixelSize > 200.0f) {
        return 1; // Resolução média (LOD 1)
    } else if (pixelSize > 50.0f) {
        return 2; // Resolução baixa (LOD 2)
    } else {
        return 3; // Proxy / Distante (LOD 3)
    }
}

} // namespace aurea
