#pragma once

#include <cmath>
#include <array>

namespace aurea {

struct Vec3 {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;

    Vec3 operator+(const Vec3& o) const { return {x + o.x, y + o.y, z + o.z}; }
    Vec3 operator-(const Vec3& o) const { return {x - o.x, y - o.y, z - o.z}; }
    Vec3 operator*(float s) const { return {x * s, y * s, z * s}; }
    float dot(const Vec3& o) const { return x * o.x + y * o.y + z * o.z; }
    Vec3 cross(const Vec3& o) const {
        return {
            y * o.z - z * o.y,
            z * o.x - x * o.z,
            x * o.y - y * o.x
        };
    }
    Vec3 normalized() const {
        float len = std::sqrt(x * x + y * y + z * z);
        if (len > 1e-6f) return {x / len, y / len, z / len};
        return {0.0f, 0.0f, 0.0f};
    }
};

using Mat4 = std::array<float, 16>;

class Camera {
public:
    Camera();
    ~Camera() = default;

    void setPerspective(float fovDegrees, float aspect, float nearPlane, float farPlane);
    void setLookAt(const Vec3& eye, const Vec3& target, const Vec3& up);

    const Mat4& getViewMatrix() const { return viewMatrix_; }
    const Mat4& getProjectionMatrix() const { return projectionMatrix_; }
    Mat4 getViewProjectionMatrix() const;

    const Vec3& getPosition() const { return position_; }
    const Vec3& getTarget() const { return target_; }

    // Frustum Culling
    bool isSphereInFrustum(const Vec3& center, float radius) const;

private:
    Vec3 position_{0.0f, 0.0f, 5.0f};
    Vec3 target_{0.0f, 0.0f, 0.0f};
    Vec3 up_{0.0f, 1.0f, 0.0f};

    float fov_ = 60.0f;
    float aspect_ = 16.0f / 9.0f;
    float near_ = 0.1f;
    float far_ = 1000.0f;

    Mat4 viewMatrix_;
    Mat4 projectionMatrix_;

    void updateViewMatrix();
    void updateProjectionMatrix();
};

} // namespace aurea
