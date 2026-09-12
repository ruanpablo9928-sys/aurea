#pragma once

#include <vector>
#include <string>
#include <cstdint>
#include <memory>

namespace aurea {

struct Vertex3D {
    float posX, posY, posZ;
    float normX, normY, normZ;
    float u, v;
};

class Mesh3D {
public:
    Mesh3D(const std::string& name);
    ~Mesh3D();

    const std::string& getName() const { return name_; }

    void setGeometry(const std::vector<Vertex3D>& vertices, const std::vector<uint32_t>& indices);
    void uploadToGPU();
    void render();
    void releaseGPU();

    size_t getVertexCount() const { return vertices_.size(); }
    size_t getIndexCount() const { return indices_.size(); }

    // Geradores de Primitivas 3D
    static std::shared_ptr<Mesh3D> createCube(float size = 1.0f);
    static std::shared_ptr<Mesh3D> createSphere(float radius = 1.0f, int rings = 16, int sectors = 16);
    static std::shared_ptr<Mesh3D> createPlane(float width = 10.0f, float depth = 10.0f);

private:
    std::string name_;
    std::vector<Vertex3D> vertices_;
    std::vector<uint32_t> indices_;

    uint32_t vao_ = 0;
    uint32_t vbo_ = 0;
    uint32_t ebo_ = 0;
    bool uploaded_ = false;
};

} // namespace aurea
