#include "KeyframeEngine.h"
#include <algorithm>

namespace aurea {

PropertyTrack::PropertyTrack(const std::string& propertyName, double defaultValue)
    : propertyName_(propertyName), defaultValue_(defaultValue) {
}

void PropertyTrack::addOrUpdateKeyframe(int64_t timeUs, double value,
                                       InterpolationType interp,
                                       const CubicBezierCurve& curve) {
    std::lock_guard<std::mutex> lock(mutex_);
    Keyframe target;
    target.timeUs = timeUs;
    target.value = value;
    target.interpolation = interp;
    target.curve = curve;

    auto it = std::lower_bound(keyframes_.begin(), keyframes_.end(), target);
    if (it != keyframes_.end() && it->timeUs == timeUs) {
        // Atualiza existente
        *it = target;
    } else {
        // Insere mantendo ordenação
        keyframes_.insert(it, target);
    }
}

bool PropertyTrack::removeKeyframe(int64_t timeUs) {
    std::lock_guard<std::mutex> lock(mutex_);
    Keyframe target;
    target.timeUs = timeUs;
    auto it = std::lower_bound(keyframes_.begin(), keyframes_.end(), target);
    if (it != keyframes_.end() && it->timeUs == timeUs) {
        keyframes_.erase(it);
        return true;
    }
    return false;
}

void PropertyTrack::clear() {
    std::lock_guard<std::mutex> lock(mutex_);
    keyframes_.clear();
}

size_t PropertyTrack::getKeyframeCount() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return keyframes_.size();
}

double PropertyTrack::evaluate(int64_t timeUs) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (keyframes_.empty()) {
        return defaultValue_;
    }

    if (keyframes_.size() == 1 || timeUs <= keyframes_.front().timeUs) {
        return keyframes_.front().value;
    }

    if (timeUs >= keyframes_.back().timeUs) {
        return keyframes_.back().value;
    }

    // Busca binária para achar o intervalo [k1, k2]
    Keyframe target;
    target.timeUs = timeUs;
    auto it = std::upper_bound(keyframes_.begin(), keyframes_.end(), target);
    // it aponta para k2 (timeUs < it->timeUs), logo o anterior é k1
    if (it == keyframes_.begin()) {
        return keyframes_.front().value;
    }

    const auto& k2 = *it;
    const auto& k1 = *(it - 1);

    int64_t duration = k2.timeUs - k1.timeUs;
    if (duration <= 0) {
        return k1.value;
    }

    double linearT = static_cast<double>(timeUs - k1.timeUs) / static_cast<double>(duration);
    double progress = MotionGraphEngine::evaluateProgress(k1.interpolation, k1.curve, linearT);

    return k1.value + progress * (k2.value - k1.value);
}

std::shared_ptr<PropertyTrack> KeyframeEngine::getOrCreateTrack(const std::string& layerId, const std::string& propertyName) {
    std::lock_guard<std::mutex> lock(mutex_);
    std::string key = makeKey(layerId, propertyName);
    auto it = tracks_.find(key);
    if (it != tracks_.end()) {
        return it->second;
    }
    auto track = std::make_shared<PropertyTrack>(propertyName);
    tracks_[key] = track;
    return track;
}

std::shared_ptr<PropertyTrack> KeyframeEngine::getTrack(const std::string& layerId, const std::string& propertyName) const {
    std::lock_guard<std::mutex> lock(mutex_);
    std::string key = makeKey(layerId, propertyName);
    auto it = tracks_.find(key);
    if (it != tracks_.end()) {
        return it->second;
    }
    return nullptr;
}

void KeyframeEngine::removeTracksForLayer(const std::string& layerId) {
    std::lock_guard<std::mutex> lock(mutex_);
    std::string prefix = layerId + ":";
    for (auto it = tracks_.begin(); it != tracks_.end(); ) {
        if (it->first.rfind(prefix, 0) == 0) {
            it = tracks_.erase(it);
        } else {
            ++it;
        }
    }
}

double KeyframeEngine::evaluateProperty(const std::string& layerId, const std::string& propertyName, int64_t timeUs, double defaultVal) const {
    auto track = getTrack(layerId, propertyName);
    if (track) {
        return track->evaluate(timeUs);
    }
    return defaultVal;
}

} // namespace aurea
