#pragma once

#include <cstdint>
#include <string>

namespace aurea {

enum class TimeRemapInterpolation {
    Linear = 0,
    Hold = 1,
    Bezier = 2,
    EaseIn = 3,
    EaseOut = 4,
    EaseInOut = 5,
    CustomBezier = 6
};

struct BezierHandle {
    double dx = 0.0; // Deslocamento relativo em X (tempo de composição)
    double dy = 0.0; // Deslocamento relativo em Y (tempo de fonte)
};

struct TimeRemapKeyframe {
    double compositionTime = 0.0; // segundos
    double sourceTime = 0.0;      // segundos

    TimeRemapInterpolation interpolation = TimeRemapInterpolation::Linear;

    BezierHandle inHandle;  // Tangente de entrada (à esquerda do ponto)
    BezierHandle outHandle; // Tangente de saída (à direita do ponto)

    bool operator<(const TimeRemapKeyframe& other) const {
        return compositionTime < other.compositionTime;
    }
};

} // namespace aurea
