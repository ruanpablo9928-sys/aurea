#pragma once

#include "MotionGraphEngine.h"
#include <vector>
#include <string>
#include <memory>
#include <mutex>
#include <unordered_map>

namespace aurea {

struct Keyframe {
    int64_t timeUs = 0;
    double value = 0.0;
    InterpolationType interpolation = InterpolationType::Linear;
    CubicBezierCurve curve = CubicBezierCurve::linear();

    bool operator<(const Keyframe& other) const {
        return timeUs < other.timeUs;
    }
};

class PropertyTrack {
public:
    PropertyTrack(const std::string& propertyName, double defaultValue = 0.0);
    ~PropertyTrack() = default;

    const std::string& getPropertyName() const { return propertyName_; }
    double getDefaultValue() const { return defaultValue_; }
    void setDefaultValue(double val) { defaultValue_ = val; }

    void addOrUpdateKeyframe(int64_t timeUs, double value,
                             InterpolationType interp = InterpolationType::Linear,
                             const CubicBezierCurve& curve = CubicBezierCurve::linear());
    bool removeKeyframe(int64_t timeUs);
    void clear();

    size_t getKeyframeCount() const;
    const std::vector<Keyframe>& getKeyframes() const { return keyframes_; }

    // Avaliação analítica em O(log N)
    double evaluate(int64_t timeUs) const;

private:
    std::string propertyName_;
    double defaultValue_;
    std::vector<Keyframe> keyframes_;
    mutable std::mutex mutex_;
};

class KeyframeEngine {
public:
    KeyframeEngine() = default;
    ~KeyframeEngine() = default;

    std::shared_ptr<PropertyTrack> getOrCreateTrack(const std::string& layerId, const std::string& propertyName);
    std::shared_ptr<PropertyTrack> getTrack(const std::string& layerId, const std::string& propertyName) const;
    void removeTracksForLayer(const std::string& layerId);

    // Avalia o valor da propriedade em tempo real
    double evaluateProperty(const std::string& layerId, const std::string& propertyName, int64_t timeUs, double defaultVal = 0.0) const;

private:
    std::string makeKey(const std::string& layerId, const std::string& propertyName) const {
        return layerId + ":" + propertyName;
    }

    std::unordered_map<std::string, std::shared_ptr<PropertyTrack>> tracks_;
    mutable std::mutex mutex_;
};

} // namespace aurea
