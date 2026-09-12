#include "AnimationEngine.h"

namespace aurea {

AnimationEngine::AnimationEngine() = default;

void AnimationEngine::evaluateLayer(LayerCore& layer, int64_t timeUs) {
    const std::string& id = layer.getId();
    Transform2D& t = layer.getTransform();

    // Avalia canais de Transform2D se houver keyframes definidos
    auto trackPosX = keyframeEngine_.getTrack(id, "posX");
    if (trackPosX && trackPosX->getKeyframeCount() > 0) {
        t.posX = trackPosX->evaluate(timeUs);
    }

    auto trackPosY = keyframeEngine_.getTrack(id, "posY");
    if (trackPosY && trackPosY->getKeyframeCount() > 0) {
        t.posY = trackPosY->evaluate(timeUs);
    }

    auto trackScaleX = keyframeEngine_.getTrack(id, "scaleX");
    if (trackScaleX && trackScaleX->getKeyframeCount() > 0) {
        t.scaleX = trackScaleX->evaluate(timeUs);
    }

    auto trackScaleY = keyframeEngine_.getTrack(id, "scaleY");
    if (trackScaleY && trackScaleY->getKeyframeCount() > 0) {
        t.scaleY = trackScaleY->evaluate(timeUs);
    }

    auto trackRotation = keyframeEngine_.getTrack(id, "rotation");
    if (trackRotation && trackRotation->getKeyframeCount() > 0) {
        t.rotation = trackRotation->evaluate(timeUs);
    }

    auto trackOpacity = keyframeEngine_.getTrack(id, "opacity");
    if (trackOpacity && trackOpacity->getKeyframeCount() > 0) {
        t.opacity = trackOpacity->evaluate(timeUs);
    }

    // Avalia propriedades de Shape se for do tipo Shape
    if (layer.getType() == LayerType::Shape) {
        ShapeData& s = layer.getShapeData();

        auto trackWidth = keyframeEngine_.getTrack(id, "width");
        if (trackWidth && trackWidth->getKeyframeCount() > 0) {
            s.width = trackWidth->evaluate(timeUs);
        }

        auto trackHeight = keyframeEngine_.getTrack(id, "height");
        if (trackHeight && trackHeight->getKeyframeCount() > 0) {
            s.height = trackHeight->evaluate(timeUs);
        }

        auto trackCornerRadius = keyframeEngine_.getTrack(id, "cornerRadius");
        if (trackCornerRadius && trackCornerRadius->getKeyframeCount() > 0) {
            s.cornerRadius = trackCornerRadius->evaluate(timeUs);
        }

        auto trackStrokeWidth = keyframeEngine_.getTrack(id, "strokeWidth");
        if (trackStrokeWidth && trackStrokeWidth->getKeyframeCount() > 0) {
            s.strokeWidth = trackStrokeWidth->evaluate(timeUs);
        }
    }
}

void AnimationEngine::evaluateProject(ProjectCore& project, int64_t timeUs) {
    for (const auto& layer : project.getLayers()) {
        if (layer) {
            evaluateLayer(*layer, timeUs);
        }
    }
}

} // namespace aurea
