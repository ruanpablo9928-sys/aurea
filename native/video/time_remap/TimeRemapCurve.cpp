#include "TimeRemapCurve.h"
#include "BezierEvaluator.h"
#include <algorithm>
#include <cmath>

namespace aurea {

TimeRemapCurve::TimeRemapCurve() = default;

void TimeRemapCurve::resetDefault(double durationSeconds) {
    std::lock_guard<std::mutex> lock(mutex_);
    keyframes_.clear();

    double dur = std::max(0.1, durationSeconds);
    // Keyframe inicial 0s -> 0s
    TimeRemapKeyframe k0;
    k0.compositionTime = 0.0;
    k0.sourceTime = 0.0;
    k0.interpolation = TimeRemapInterpolation::Linear;

    // Keyframe final dur -> dur
    TimeRemapKeyframe k1;
    k1.compositionTime = dur;
    k1.sourceTime = dur;
    k1.interpolation = TimeRemapInterpolation::Linear;

    keyframes_.push_back(k0);
    keyframes_.push_back(k1);
}

void TimeRemapCurve::addKeyframe(const TimeRemapKeyframe& kf) {
    std::lock_guard<std::mutex> lock(mutex_);

    auto it = std::lower_bound(keyframes_.begin(), keyframes_.end(), kf);
    if (it != keyframes_.end() && std::abs(it->compositionTime - kf.compositionTime) < 1e-4) {
        // Atualiza keyframe existente no mesmo instante
        *it = kf;
    } else {
        keyframes_.insert(it, kf);
    }
}

bool TimeRemapCurve::removeKeyframe(size_t index) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (index >= keyframes_.size()) return false;
    keyframes_.erase(keyframes_.begin() + index);
    return true;
}

bool TimeRemapCurve::removeKeyframeAt(double compositionTime, double tolerance) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto it = keyframes_.begin(); it != keyframes_.end(); ++it) {
        if (std::abs(it->compositionTime - compositionTime) <= tolerance) {
            keyframes_.erase(it);
            return true;
        }
    }
    return false;
}

void TimeRemapCurve::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    keyframes_.clear();
}

size_t TimeRemapCurve::getKeyframeCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return keyframes_.size();
}

std::vector<TimeRemapKeyframe> TimeRemapCurve::getKeyframes() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return keyframes_;
}

bool TimeRemapCurve::getKeyframe(size_t index, TimeRemapKeyframe& outKf) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (index >= keyframes_.size()) return false;
    outKf = keyframes_[index];
    return true;
}

bool TimeRemapCurve::setKeyframe(size_t index, const TimeRemapKeyframe& kf) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (index >= keyframes_.size()) return false;
    keyframes_[index] = kf;
    // Re-ordena se o tempo de composição tiver sido alterado
    std::sort(keyframes_.begin(), keyframes_.end());
    return true;
}

size_t TimeRemapCurve::findSegmentIndex(double compositionTime) const {
    // Retorna i tal que keyframes_[i].compositionTime <= compositionTime < keyframes_[i+1].compositionTime
    if (keyframes_.size() < 2) return 0;

    TimeRemapKeyframe target;
    target.compositionTime = compositionTime;

    auto it = std::upper_bound(keyframes_.begin(), keyframes_.end(), target);
    if (it == keyframes_.begin()) return 0;

    size_t idx = std::distance(keyframes_.begin(), it) - 1;
    if (idx >= keyframes_.size() - 1) {
        idx = keyframes_.size() - 2;
    }
    return idx;
}

double TimeRemapCurve::evaluate(double compositionTime) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (keyframes_.empty()) return compositionTime;
    if (keyframes_.size() == 1) return keyframes_[0].sourceTime;

    const auto& first = keyframes_.front();
    const auto& last = keyframes_.back();

    // Antes do primeiro keyframe
    if (compositionTime < first.compositionTime) {
        if (extrapolation_ == ExtrapolationMode::Hold) {
            return first.sourceTime;
        }
        // Continue linear com a inclinação do primeiro segmento
        const auto& next = keyframes_[1];
        double dt = next.compositionTime - first.compositionTime;
        if (dt > 1e-6) {
            double slope = (next.sourceTime - first.sourceTime) / dt;
            return first.sourceTime + (compositionTime - first.compositionTime) * slope;
        }
        return first.sourceTime;
    }

    // Depois do último keyframe
    if (compositionTime > last.compositionTime) {
        if (extrapolation_ == ExtrapolationMode::Hold) {
            return last.sourceTime;
        }
        if (extrapolation_ == ExtrapolationMode::Loop) {
            double span = last.compositionTime - first.compositionTime;
            if (span > 1e-6) {
                double offset = std::fmod(compositionTime - first.compositionTime, span);
                if (offset < 0) offset += span;
                return evaluate(first.compositionTime + offset);
            }
        }
        // Continue linear com a inclinação do último segmento
        const auto& prev = keyframes_[keyframes_.size() - 2];
        double dt = last.compositionTime - prev.compositionTime;
        if (dt > 1e-6) {
            double slope = (last.sourceTime - prev.sourceTime) / dt;
            return last.sourceTime + (compositionTime - last.compositionTime) * slope;
        }
        return last.sourceTime;
    }

    // Dentro do intervalo: avalia o segmento Bézier correspondente
    size_t seg = findSegmentIndex(compositionTime);
    double outSourceTime = 0.0;
    double outSpeed = 1.0;
    BezierEvaluator::evaluateSegment(keyframes_[seg], keyframes_[seg + 1], compositionTime, outSourceTime, outSpeed);
    return outSourceTime;
}

double TimeRemapCurve::evaluateSpeed(double compositionTime) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (keyframes_.size() < 2) return 0.0;

    const auto& first = keyframes_.front();
    const auto& last = keyframes_.back();

    if (compositionTime < first.compositionTime) {
        if (extrapolation_ == ExtrapolationMode::Hold) return 0.0;
        double dt = keyframes_[1].compositionTime - first.compositionTime;
        return dt > 1e-6 ? (keyframes_[1].sourceTime - first.sourceTime) / dt : 0.0;
    }

    if (compositionTime > last.compositionTime) {
        if (extrapolation_ == ExtrapolationMode::Hold) return 0.0;
        size_t n = keyframes_.size();
        double dt = last.compositionTime - keyframes_[n - 2].compositionTime;
        return dt > 1e-6 ? (last.sourceTime - keyframes_[n - 2].sourceTime) / dt : 0.0;
    }

    size_t seg = findSegmentIndex(compositionTime);
    double outSourceTime = 0.0;
    double outSpeed = 0.0;
    BezierEvaluator::evaluateSegment(keyframes_[seg], keyframes_[seg + 1], compositionTime, outSourceTime, outSpeed);
    return outSpeed;
}

} // namespace aurea
