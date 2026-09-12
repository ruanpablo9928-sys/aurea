#pragma once

#include "Camera.h"
#include "Materials.h"
#include "Assets.h"
#include "FilamentRenderer.h"
#include "GPUUploadQueue.h"
#include "ModelImportManager.h"
#include "DeviceProfile.h"
#include <vector>
#include <memory>
#include <string>

namespace aurea {

struct SceneNode3D {
    std::string id;
    std::string name;
    Vec3 position{0.0f, 0.0f, 0.0f};
    Vec3 rotation{0.0f, 0.0f, 0.0f}; // Pitch, Yaw, Roll em graus
    Vec3 scale{1.0f, 1.0f, 1.0f};

    std::shared_ptr<Mesh3D> mesh;
    std::shared_ptr<Mesh3D> proxyMesh; // LOD 3 proxy para visualização instantânea
    Material3D material;
    bool visible = true;
};

struct DirectionalLight {
    Vec3 direction{-0.5f, -1.0f, -0.5f};
    Vec3 color{1.0f, 1.0f, 1.0f};
    float intensity = 1.0f;
};

class Scene3D {
public:
    Scene3D();
    ~Scene3D();

    bool initialize();
    void shutdown();

    Camera& getCamera() { return camera_; }
    const Camera& getCamera() const { return camera_; }

    void addNode(const std::shared_ptr<SceneNode3D>& node);
    void removeNode(const std::string& id);
    std::shared_ptr<SceneNode3D> getNode(const std::string& id) const;
    void clearNodes();
    const std::vector<std::shared_ptr<SceneNode3D>>& getNodes() const { return nodes_; }

    void setAmbientLight(const Vec3& color, float intensity) {
        ambientColor_ = color;
        ambientIntensity_ = intensity;
    }

    void setDirectionalLight(const DirectionalLight& light) { dirLight_ = light; }

    // Fila e Orçamento de Upload por frame
    std::shared_ptr<GPUUploadQueue> getUploadQueue() const { return uploadQueue_; }
    void setFrameBudgetMs(float ms) { frameBudgetMs_ = ms; }
    float getFrameBudgetMs() const { return frameBudgetMs_; }

    // Importação de modelo assíncrona desacoplada da UI
    int64_t importModelAsync(const std::string& filePath,
                             const std::string& targetNodeId,
                             ImportProgressCallback progressCallback = nullptr);
    void cancelImport(int64_t jobId);

    // Renderiza a cena 3D completa com Depth Buffer na GPU e processa a fila de uploads
    void render(int viewportWidth, int viewportHeight);

    // Métricas de renderização da GPU
    RenderMetrics3D getMetrics() const { return renderer_.getMetrics(); }

private:
    Camera camera_;
    std::vector<std::shared_ptr<SceneNode3D>> nodes_;
    DirectionalLight dirLight_;
    Vec3 ambientColor_{0.2f, 0.2f, 0.25f};
    float ambientIntensity_ = 0.5f;

    FilamentRenderer renderer_;
    std::shared_ptr<GPUUploadQueue> uploadQueue_;
    float frameBudgetMs_ = 2.5f;
};

} // namespace aurea
