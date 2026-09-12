#include "CompositionCore.h"
#include <cmath>

namespace aurea {

std::vector<EvaluatedLayer> CompositionCore::evaluateLayers(
    const std::vector<std::shared_ptr<LayerCore>>& layers,
    int64_t timeUs) {
    
    std::vector<EvaluatedLayer> result;
    result.reserve(layers.size());

    for (const auto& layer : layers) {
        if (!layer) continue;

        if (layer->isVisibleAt(timeUs)) {
            EvaluatedLayer eval;
            eval.layer = layer;
            eval.globalTransform = layer->getTransform();
            eval.globalOpacity = static_cast<float>(layer->getTransform().opacity);
            eval.isVisible = true;
            result.push_back(eval);
        }
    }

    return result;
}

Transform2D CompositionCore::combineTransforms(const Transform2D& parent, const Transform2D& child) {
    Transform2D combined;

    // Escala combinada
    combined.scaleX = parent.scaleX * child.scaleX;
    combined.scaleY = parent.scaleY * child.scaleY;

    // Rotação combinada (graus)
    combined.rotation = parent.rotation + child.rotation;

    // Opacidade combinada
    combined.opacity = parent.opacity * child.opacity;

    // Posição com rotação do pai
    double rad = parent.rotation * (M_PI / 180.0);
    double cosR = std::cos(rad);
    double sinR = std::sin(rad);

    double scaledChildX = child.posX * parent.scaleX;
    double scaledChildY = child.posY * parent.scaleY;

    combined.posX = parent.posX + (scaledChildX * cosR - scaledChildY * sinR);
    combined.posY = parent.posY + (scaledChildX * sinR + scaledChildY * cosR);

    combined.pivotX = child.pivotX;
    combined.pivotY = child.pivotY;
    combined.skewX = parent.skewX + child.skewX;
    combined.skewY = parent.skewY + child.skewY;

    return combined;
}

} // namespace aurea
