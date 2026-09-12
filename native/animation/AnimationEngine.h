#pragma once

#include "KeyframeEngine.h"
#include "../core/ProjectCore.h"
#include <memory>

namespace aurea {

class AnimationEngine {
public:
    AnimationEngine();
    ~AnimationEngine() = default;

    KeyframeEngine& getKeyframeEngine() { return keyframeEngine_; }
    const KeyframeEngine& getKeyframeEngine() const { return keyframeEngine_; }

    // Avalia todas as propriedades animadas para uma camada no tempo timeUs e aplica no LayerCore
    void evaluateLayer(LayerCore& layer, int64_t timeUs);

    // Avalia todo o projeto
    void evaluateProject(ProjectCore& project, int64_t timeUs);

private:
    KeyframeEngine keyframeEngine_;
};

} // namespace aurea
