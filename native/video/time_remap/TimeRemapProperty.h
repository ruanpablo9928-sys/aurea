#pragma once

#include "TimeRemapCurve.h"
#include <memory>

namespace aurea {

class TimeRemapProperty {
public:
    TimeRemapProperty();
    explicit TimeRemapProperty(double durationSeconds);
    ~TimeRemapProperty() = default;

    bool isEnabled() const { return enabled_; }
    void setEnabled(bool enabled);

    TimeRemapCurve& getCurve() { return curve_; }
    const TimeRemapCurve& getCurve() const { return curve_; }

    // Avalia o sourceTime correspondente (se desabilitado, avalia 1:1 linear)
    double evaluate(double compositionTime) const;

    // Avalia a velocidade instantânea (1.0 se desabilitado)
    double getSpeed(double compositionTime) const;

    // Redefine para curva linear padrão de 0s a durationSeconds
    void reset(double durationSeconds);

private:
    bool enabled_ = false;
    TimeRemapCurve curve_;
    double durationSeconds_ = 5.0;
};

} // namespace aurea
