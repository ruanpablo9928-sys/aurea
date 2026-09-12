#include "ProjectCore.h"
#include <algorithm>

namespace aurea {

LayerCore::LayerCore(const std::string& id, const std::string& name, LayerType type)
    : id_(id), name_(name), type_(type) {
}

ProjectCore::ProjectCore(const std::string& name, int width, int height, int fps)
    : name_(name), width_(width), height_(height), fps_(fps) {
}

ProjectCore::~ProjectCore() = default;

void ProjectCore::addLayer(std::shared_ptr<LayerCore> layer) {
    if (!layer) return;
    std::lock_guard<std::mutex> lock(mutex_);
    layers_.push_back(layer);
    layerMap_[layer->getId()] = layer;
    markDirty(DirtyFlags::Scene | DirtyFlags::Transform);
}

void ProjectCore::removeLayer(const std::string& layerId) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = layerMap_.find(layerId);
    if (it != layerMap_.end()) {
        layerMap_.erase(it);
        layers_.erase(
            std::remove_if(layers_.begin(), layers_.end(),
                           [&layerId](const std::shared_ptr<LayerCore>& l) {
                               return l->getId() == layerId;
                           }),
            layers_.end()
        );
        markDirty(DirtyFlags::Scene);
    }
}

std::shared_ptr<LayerCore> ProjectCore::getLayer(const std::string& layerId) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = layerMap_.find(layerId);
    if (it != layerMap_.end()) {
        return it->second;
    }
    return nullptr;
}

void ProjectCore::markDirty(DirtyFlags flags) {
    dirtyFlags_ = dirtyFlags_ | flags;
}

void ProjectCore::clearDirty(DirtyFlags flags) {
    dirtyFlags_ = static_cast<DirtyFlags>(
        static_cast<uint32_t>(dirtyFlags_) & ~static_cast<uint32_t>(flags)
    );
}

bool ProjectCore::isDirty(DirtyFlags flags) const {
    return (static_cast<uint32_t>(dirtyFlags_) & static_cast<uint32_t>(flags)) != 0;
}

void ProjectCore::evaluate(int64_t timeUs) {
    std::lock_guard<std::mutex> lock(mutex_);
    // Pacing and evaluation of layers active at timeUs
    (void)timeUs;
    // Clearing dirty flags will be done by renderer after consuming
}

} // namespace aurea
