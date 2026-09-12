#pragma once

#include "ProjectCore.h"
#include <vector>
#include <memory>
#include <string>

namespace aurea {

enum class BlendMode {
    Normal,
    Multiply,
    Screen,
    Overlay,
    Darken,
    Lighten,
    ColorDodge,
    ColorBurn,
    HardLight,
    SoftLight,
    Difference,
    Exclusion,
    Add
};

enum class MatteMode {
    None,
    AlphaMatte,
    AlphaInvertedMatte,
    LumaMatte,
    LumaInvertedMatte
};

struct EvaluatedLayer {
    std::shared_ptr<LayerCore> layer;
    Transform2D globalTransform;
    BlendMode blendMode = BlendMode::Normal;
    MatteMode matteMode = MatteMode::None;
    float globalOpacity = 1.0f;
    bool isVisible = true;
};

class CompositionCore {
public:
    CompositionCore() = default;
    ~CompositionCore() = default;

    // Avalia e gera a lista de camadas ativas e ordenadas para renderização no instante timeUs
    std::vector<EvaluatedLayer> evaluateLayers(const std::vector<std::shared_ptr<LayerCore>>& layers, int64_t timeUs);

    // Combina transformações hierárquicas
    static Transform2D combineTransforms(const Transform2D& parent, const Transform2D& child);
};

} // namespace aurea
