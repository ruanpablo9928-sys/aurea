#include "TimeRemapProperty.h"

namespace aurea {

TimeRemapProperty::TimeRemapProperty() {
    curve_.resetDefault(5.0);
}

TimeRemapProperty::TimeRemapProperty(double durationSeconds)
    : durationSeconds_(durationSeconds) {
    curve_.resetDefault(durationSeconds_);
}

void TimeRemapProperty::setEnabled(bool enabled) {
    enabled_ = enabled;
}

double TimeRemapProperty::evaluate(double compositionTime) const {
    if (!enabled_) {
        // Modo 1:1 linear quando desligado
        return compositionTime;
    }
    return curve_.evaluate(compositionTime);
}

double TimeRemapProperty::getSpeed(double compositionTime) const {
    if (!enabled_) {
        return 1.0;
    }
    return curve_.evaluateSpeed(compositionTime);
}

void TimeRemapProperty::reset(double durationSeconds) {
    durationSeconds_ = durationSeconds;
    curve_.resetDefault(durationSeconds_);
}

} // namespace aurea
