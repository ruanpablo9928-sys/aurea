#include "Camera.h"
#include <cmath>
#include <cstring>

namespace aurea {

Camera::Camera() {
    viewMatrix_.fill(0.0f);
    projectionMatrix_.fill(0.0f);
    viewMatrix_[0] = viewMatrix_[5] = viewMatrix_[10] = viewMatrix_[15] = 1.0f;
    projectionMatrix_[0] = projectionMatrix_[5] = projectionMatrix_[10] = projectionMatrix_[15] = 1.0f;

    updateProjectionMatrix();
    updateViewMatrix();
}

void Camera::setPerspective(float fovDegrees, float aspect, float nearPlane, float farPlane) {
    fov_ = fovDegrees;
    aspect_ = aspect;
    near_ = nearPlane;
    far_ = farPlane;
    updateProjectionMatrix();
}

void Camera::setLookAt(const Vec3& eye, const Vec3& target, const Vec3& up) {
    position_ = eye;
    target_ = target;
    up_ = up;
    updateViewMatrix();
}

void Camera::updateProjectionMatrix() {
    float fovRad = fov_ * (3.141592653589793f / 180.0f);
    float tanHalfFov = std::tan(fovRad * 0.5f);

    projectionMatrix_.fill(0.0f);
    projectionMatrix_[0] = 1.0f / (aspect_ * tanHalfFov);
    projectionMatrix_[5] = 1.0f / tanHalfFov;
    projectionMatrix_[10] = -(far_ + near_) / (far_ - near_);
    projectionMatrix_[11] = -1.0f;
    projectionMatrix_[14] = -(2.0f * far_ * near_) / (far_ - near_);
}

void Camera::updateViewMatrix() {
    Vec3 f = (target_ - position_).normalized();
    Vec3 s = f.cross(up_).normalized();
    Vec3 u = s.cross(f);

    viewMatrix_[0] = s.x;
    viewMatrix_[4] = s.y;
    viewMatrix_[8] = s.z;
    viewMatrix_[12] = -s.dot(position_);

    viewMatrix_[1] = u.x;
    viewMatrix_[5] = u.y;
    viewMatrix_[9] = u.z;
    viewMatrix_[13] = -u.dot(position_);

    viewMatrix_[2] = -f.x;
    viewMatrix_[6] = -f.y;
    viewMatrix_[10] = -f.z;
    viewMatrix_[14] = f.dot(position_);

    viewMatrix_[3] = 0.0f;
    viewMatrix_[7] = 0.0f;
    viewMatrix_[11] = 0.0f;
    viewMatrix_[15] = 1.0f;
}

Mat4 Camera::getViewProjectionMatrix() const {
    Mat4 result;
    result.fill(0.0f);
    for (int r = 0; r < 4; ++r) {
        for (int c = 0; c < 4; ++c) {
            for (int k = 0; k < 4; ++k) {
                result[c * 4 + r] += projectionMatrix_[k * 4 + r] * viewMatrix_[c * 4 + k];
            }
        }
    }
    return result;
}

bool Camera::isSphereInFrustum(const Vec3& center, float radius) const {
    // Projeção simples de distância para descarte rápido
    Vec3 f = (target_ - position_).normalized();
    float d = (center - position_).dot(f);
    if (d < (near_ - radius) || d > (far_ + radius)) {
        return false;
    }
    return true;
}

} // namespace aurea
