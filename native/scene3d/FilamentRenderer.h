#pragma once

#include "Camera.h"
#include "Materials.h"
#include "Assets.h"
#include "LODManager.h"
#include <vector>
#include <memory>
#include <string>

namespace aurea {

struct RenderMetrics3D {
    int drawCalls = 0;
    int renderedTriangles = 0;
    int renderedVertices = 0;
    int culledNodes = 0;
    float gpuFrameTimeMs = 0.0f;
};

class FilamentRenderer {
public:
    FilamentRenderer();
    ~FilamentRenderer();

    bool initialize();
    void shutdown();

    const RenderMetrics3D& getMetrics() const { return metrics_; }
    void resetMetrics();

    // Renderiza a lista de nós com Frustum Culling e hardware Depth Buffer
    void renderScene(const Camera& camera,
                     const std::vector<std::shared_ptr<struct SceneNode3D>>& nodes,
                     const struct DirectionalLight& dirLight,
                     const Vec3& ambientColor,
                     float ambientIntensity,
                     int viewportWidth,
                     int viewportHeight);

private:
    uint32_t shaderProgram_ = 0;
    RenderMetrics3D metrics_;

    void initShaders();
};

} // namespace aurea
