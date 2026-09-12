#include "Scene3D.h"
#include <algorithm>

namespace aurea {

Scene3D::Scene3D()
    : uploadQueue_(std::make_shared<GPUUploadQueue>()) {
    frameBudgetMs_ = DeviceProfile::instance().getCapabilities().defaultUploadSliceMs;
}

Scene3D::~Scene3D() {
    shutdown();
}

bool Scene3D::initialize() {
    return renderer_.initialize();
}

void Scene3D::shutdown() {
    if (uploadQueue_) {
        uploadQueue_->clear();
    }
    renderer_.shutdown();
    clearNodes();
}

void Scene3D::addNode(const std::shared_ptr<SceneNode3D>& node) {
    if (node) {
        nodes_.push_back(node);
    }
}

void Scene3D::removeNode(const std::string& id) {
    nodes_.erase(
        std::remove_if(nodes_.begin(), nodes_.end(),
                       [&id](const std::shared_ptr<SceneNode3D>& n) { return n->id == id; }),
        nodes_.end()
    );
}

std::shared_ptr<SceneNode3D> Scene3D::getNode(const std::string& id) const {
    for (const auto& node : nodes_) {
        if (node && node->id == id) {
            return node;
        }
    }
    return nullptr;
}

void Scene3D::clearNodes() {
    nodes_.clear();
}

int64_t Scene3D::importModelAsync(const std::string& filePath,
                                 const std::string& targetNodeId,
                                 ImportProgressCallback progressCallback) {
    auto node = getNode(targetNodeId);
    if (!node) {
        node = std::make_shared<SceneNode3D>();
        node->id = targetNodeId;
        node->name = "Node3D_" + targetNodeId;
        addNode(node);
    }

    ImportOptions options;
    options.maxTextureDim = DeviceProfile::instance().getCapabilities().maxTextureDimension;

    return ModelImportManager::instance().startImportAsync(
        filePath,
        options,
        uploadQueue_,
        [node](std::shared_ptr<Mesh3D> proxyMesh, std::shared_ptr<Mesh3D> finalMesh) {
            if (proxyMesh) {
                node->proxyMesh = proxyMesh;
            }
            if (finalMesh) {
                node->mesh = finalMesh;
                node->proxyMesh.reset(); // Descarta o proxy assim que a malha final estiver pronta
            }
        },
        progressCallback
    );
}

void Scene3D::cancelImport(int64_t jobId) {
    ModelImportManager::instance().cancelImport(jobId);
    if (uploadQueue_) {
        uploadQueue_->clear();
    }
}

void Scene3D::render(int viewportWidth, int viewportHeight) {
    // 1. Processa a fila de uploads incrementais respeitando o frame budget
    if (uploadQueue_) {
        uploadQueue_->processFrame(frameBudgetMs_);
    }

    if (viewportHeight <= 0 || viewportWidth <= 0) return;

    // 2. Prepara nós para renderização: se a malha principal não estiver pronta, usa o proxy
    std::vector<std::shared_ptr<SceneNode3D>> renderNodes;
    renderNodes.reserve(nodes_.size());

    for (const auto& node : nodes_) {
        if (!node || !node->visible) continue;

        if (node->mesh) {
            renderNodes.push_back(node);
        } else if (node->proxyMesh) {
            // Renderiza o proxy temporário
            auto proxyNode = std::make_shared<SceneNode3D>(*node);
            proxyNode->mesh = node->proxyMesh;
            renderNodes.push_back(proxyNode);
        }
    }

    // 3. Atualiza câmera e renderiza cena com Depth Buffer e Frustum Culling
    camera_.setPerspective(60.0f, static_cast<float>(viewportWidth) / static_cast<float>(viewportHeight), 0.1f, 1000.0f);
    renderer_.renderScene(camera_, renderNodes, dirLight_, ambientColor_, ambientIntensity_, viewportWidth, viewportHeight);
}

} // namespace aurea
