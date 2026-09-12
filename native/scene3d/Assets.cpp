#include "Assets.h"
#include <cmath>

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace aurea {

Mesh3D::Mesh3D(const std::string& name) : name_(name) {}

Mesh3D::~Mesh3D() {
    releaseGPU();
}

void Mesh3D::setGeometry(const std::vector<Vertex3D>& vertices, const std::vector<uint32_t>& indices) {
    vertices_ = vertices;
    indices_ = indices;
    uploaded_ = false;
}

void Mesh3D::uploadToGPU() {
#if defined(__ANDROID__)
    if (uploaded_ || vertices_.empty()) return;

    glGenVertexArrays(1, &vao_);
    glGenBuffers(1, &vbo_);
    glGenBuffers(1, &ebo_);

    glBindVertexArray(vao_);

    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, vertices_.size() * sizeof(Vertex3D), vertices_.data(), GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices_.size() * sizeof(uint32_t), indices_.data(), GL_STATIC_DRAW);

    // Pos (location = 0)
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex3D), (void*)0);
    glEnableVertexAttribArray(0);

    // Norm (location = 1)
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex3D), (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);

    // UV (location = 2)
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex3D), (void*)(6 * sizeof(float)));
    glEnableVertexAttribArray(2);

    glBindVertexArray(0);
    uploaded_ = true;
#endif
}

void Mesh3D::render() {
#if defined(__ANDROID__)
    if (!uploaded_) {
        uploadToGPU();
    }
    if (vao_ != 0 && !indices_.empty()) {
        glBindVertexArray(vao_);
        glDrawElements(GL_TRIANGLES, static_cast<GLsizei>(indices_.size()), GL_UNSIGNED_INT, 0);
        glBindVertexArray(0);
    }
#endif
}

void Mesh3D::releaseGPU() {
#if defined(__ANDROID__)
    if (vao_ != 0) { glDeleteVertexArrays(1, &vao_); vao_ = 0; }
    if (vbo_ != 0) { glDeleteBuffers(1, &vbo_); vbo_ = 0; }
    if (ebo_ != 0) { glDeleteBuffers(1, &ebo_); ebo_ = 0; }
#endif
    uploaded_ = false;
}

std::shared_ptr<Mesh3D> Mesh3D::createCube(float size) {
    auto mesh = std::make_shared<Mesh3D>("Cube");
    float h = size * 0.5f;

    std::vector<Vertex3D> verts = {
        // Front
        {-h, -h,  h,  0,  0,  1, 0, 0},
        { h, -h,  h,  0,  0,  1, 1, 0},
        { h,  h,  h,  0,  0,  1, 1, 1},
        {-h,  h,  h,  0,  0,  1, 0, 1},
        // Back
        { h, -h, -h,  0,  0, -1, 0, 0},
        {-h, -h, -h,  0,  0, -1, 1, 0},
        {-h,  h, -h,  0,  0, -1, 1, 1},
        { h,  h, -h,  0,  0, -1, 0, 1},
        // Top
        {-h,  h,  h,  0,  1,  0, 0, 0},
        { h,  h,  h,  0,  1,  0, 1, 0},
        { h,  h, -h,  0,  1,  0, 1, 1},
        {-h,  h, -h,  0,  1,  0, 0, 1},
        // Bottom
        {-h, -h, -h,  0, -1,  0, 0, 0},
        { h, -h, -h,  0, -1,  0, 1, 0},
        { h, -h,  h,  0, -1,  0, 1, 1},
        {-h, -h,  h,  0, -1,  0, 0, 1},
        // Right
        { h, -h,  h,  1,  0,  0, 0, 0},
        { h, -h, -h,  1,  0,  0, 1, 0},
        { h,  h, -h,  1,  0,  0, 1, 1},
        { h,  h,  h,  1,  0,  0, 0, 1},
        // Left
        {-h, -h, -h, -1,  0,  0, 0, 0},
        {-h, -h,  h, -1,  0,  0, 1, 0},
        {-h,  h,  h, -1,  0,  0, 1, 1},
        {-h,  h, -h, -1,  0,  0, 0, 1}
    };

    std::vector<uint32_t> idxs;
    for (int i = 0; i < 6; ++i) {
        uint32_t offset = i * 4;
        idxs.push_back(offset + 0);
        idxs.push_back(offset + 1);
        idxs.push_back(offset + 2);
        idxs.push_back(offset + 2);
        idxs.push_back(offset + 3);
        idxs.push_back(offset + 0);
    }

    mesh->setGeometry(verts, idxs);
    return mesh;
}

std::shared_ptr<Mesh3D> Mesh3D::createPlane(float width, float depth) {
    auto mesh = std::make_shared<Mesh3D>("Plane");
    float hw = width * 0.5f;
    float hd = depth * 0.5f;

    std::vector<Vertex3D> verts = {
        {-hw, 0.0f,  hd,  0, 1, 0,  0, 0},
        { hw, 0.0f,  hd,  0, 1, 0,  1, 0},
        { hw, 0.0f, -hd,  0, 1, 0,  1, 1},
        {-hw, 0.0f, -hd,  0, 1, 0,  0, 1}
    };

    std::vector<uint32_t> idxs = {0, 1, 2, 2, 3, 0};
    mesh->setGeometry(verts, idxs);
    return mesh;
}

std::shared_ptr<Mesh3D> Mesh3D::createSphere(float radius, int rings, int sectors) {
    auto mesh = std::make_shared<Mesh3D>("Sphere");
    std::vector<Vertex3D> verts;
    std::vector<uint32_t> idxs;

    float const R = 1.0f / static_cast<float>(rings - 1);
    float const S = 1.0f / static_cast<float>(sectors - 1);

    for (int r = 0; r < rings; ++r) {
        for (int s = 0; s < sectors; ++s) {
            float y = std::sin(-1.57079632679f + 3.14159265359f * r * R);
            float x = std::cos(2.0f * 3.14159265359f * s * S) * std::sin(3.14159265359f * r * R);
            float z = std::sin(2.0f * 3.14159265359f * s * S) * std::sin(3.14159265359f * r * R);

            Vertex3D v;
            v.posX = x * radius;
            v.posY = y * radius;
            v.posZ = z * radius;
            v.normX = x;
            v.normY = y;
            v.normZ = z;
            v.u = s * S;
            v.v = r * R;
            verts.push_back(v);
        }
    }

    for (int r = 0; r < rings - 1; ++r) {
        for (int s = 0; s < sectors - 1; ++s) {
            uint32_t cur = r * sectors + s;
            uint32_t next = (r + 1) * sectors + s;

            idxs.push_back(cur);
            idxs.push_back(cur + 1);
            idxs.push_back(next);

            idxs.push_back(cur + 1);
            idxs.push_back(next + 1);
            idxs.push_back(next);
        }
    }

    mesh->setGeometry(verts, idxs);
    return mesh;
}

} // namespace aurea
