#pragma once

#include <string>
#include <vector>
#include <memory>
#include <unordered_map>
#include <cstdint>
#include <mutex>

namespace aurea {

enum class DirtyFlags : uint32_t {
    Clean      = 0,
    Transform  = 1 << 0,
    Material   = 1 << 1,
    Animation  = 1 << 2,
    Effect     = 1 << 3,
    Camera     = 1 << 4,
    Video      = 1 << 5,
    Scene      = 1 << 6,
    All        = 0xFFFFFFFF
};

inline DirtyFlags operator|(DirtyFlags a, DirtyFlags b) {
    return static_cast<DirtyFlags>(static_cast<uint32_t>(a) | static_cast<uint32_t>(b));
}

inline DirtyFlags operator&(DirtyFlags a, DirtyFlags b) {
    return static_cast<DirtyFlags>(static_cast<uint32_t>(a) & static_cast<uint32_t>(b));
}

inline DirtyFlags& operator|=(DirtyFlags& a, DirtyFlags b) {
    a = a | b;
    return a;
}

enum class LayerType {
    Shape,
    Video,
    Image,
    Text,
    Scene3D,
    Group,
    Adjustment
};

struct Transform2D {
    double posX = 0.0;
    double posY = 0.0;
    double scaleX = 1.0;
    double scaleY = 1.0;
    double rotation = 0.0; // graus
    double opacity = 1.0;
    double pivotX = 0.0;
    double pivotY = 0.0;
    double skewX = 0.0;
    double skewY = 0.0;
};

struct ShapeData {
    int shapeType = 0; // 0=rect, 1=circle, 2=path, 3=star, 4=polygon
    uint32_t fillColor = 0xFFFFFFFF;
    uint32_t strokeColor = 0x00000000;
    double strokeWidth = 0.0;
    double cornerRadius = 0.0;
    double width = 100.0;
    double height = 100.0;
};

class LayerCore {
public:
    LayerCore(const std::string& id, const std::string& name, LayerType type);
    virtual ~LayerCore() = default;

    const std::string& getId() const { return id_; }
    const std::string& getName() const { return name_; }
    LayerType getType() const { return type_; }

    void setStartTimeUs(int64_t t) { startTimeUs_ = t; }
    int64_t getStartTimeUs() const { return startTimeUs_; }

    void setDurationUs(int64_t d) { durationUs_ = d; }
    int64_t getDurationUs() const { return durationUs_; }

    Transform2D& getTransform() { return transform_; }
    const Transform2D& getTransform() const { return transform_; }

    ShapeData& getShapeData() { return shapeData_; }
    const ShapeData& getShapeData() const { return shapeData_; }

    void setSourcePath(const std::string& path) { sourcePath_ = path; }
    const std::string& getSourcePath() const { return sourcePath_; }

    bool isVisibleAt(int64_t timeUs) const {
        return timeUs >= startTimeUs_ && timeUs < (startTimeUs_ + durationUs_);
    }

private:
    std::string id_;
    std::string name_;
    LayerType type_;
    int64_t startTimeUs_ = 0;
    int64_t durationUs_ = 5000000; // 5s padrão
    Transform2D transform_;
    ShapeData shapeData_;
    std::string sourcePath_;
};

class ProjectCore {
public:
    ProjectCore(const std::string& name, int width, int height, int fps);
    ~ProjectCore();

    const std::string& getName() const { return name_; }
    int getWidth() const { return width_; }
    int getHeight() const { return height_; }
    int getFps() const { return fps_; }
    int64_t getDurationUs() const { return durationUs_; }
    void setDurationUs(int64_t d) { durationUs_ = d; }

    void addLayer(std::shared_ptr<LayerCore> layer);
    void removeLayer(const std::string& layerId);
    std::shared_ptr<LayerCore> getLayer(const std::string& layerId) const;
    const std::vector<std::shared_ptr<LayerCore>>& getLayers() const { return layers_; }

    void markDirty(DirtyFlags flags);
    void clearDirty(DirtyFlags flags = DirtyFlags::All);
    bool isDirty(DirtyFlags flags) const;

    // Avaliação no instante de tempo t
    void evaluate(int64_t timeUs);

private:
    std::string name_;
    int width_;
    int height_;
    int fps_;
    int64_t durationUs_ = 5000000; // 5s

    std::vector<std::shared_ptr<LayerCore>> layers_;
    std::unordered_map<std::string, std::shared_ptr<LayerCore>> layerMap_;
    DirtyFlags dirtyFlags_ = DirtyFlags::All;

    mutable std::mutex mutex_;
};

} // namespace aurea
