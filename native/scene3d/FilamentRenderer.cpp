#include "FilamentRenderer.h"
#include "Scene3D.h"
#include "../renderer/GPUProcessor.h"
#include <chrono>
#include <algorithm>

#if defined(__ANDROID__)
#include <GLES3/gl3.h>
#endif

namespace aurea {

static const char* kVertexShaderPBR = R"(#version 300 es
layout(location = 0) in vec3 aPosition;
layout(location = 1) in vec3 aNormal;
layout(location = 2) in vec2 aTexCoord;

uniform mat4 uViewProj;
uniform mat4 uModel;

out vec3 vNormal;
out vec3 vFragPos;
out vec2 vTexCoord;

void main() {
    vec4 worldPos = uModel * vec4(aPosition, 1.0);
    vFragPos = worldPos.xyz;
    vNormal = mat3(uModel) * aNormal;
    vTexCoord = aTexCoord;
    gl_Position = uViewProj * worldPos;
}
)";

static const char* kFragmentShaderPBR = R"(#version 300 es
precision mediump float;

in vec3 vNormal;
in vec3 vFragPos;
in vec2 vTexCoord;

out vec4 fragColor;

uniform vec4 uAlbedoColor;
uniform vec3 uAmbientColor;
uniform float uAmbientIntensity;
uniform vec3 uLightDir;
uniform vec3 uLightColor;
uniform float uLightIntensity;
uniform vec3 uCameraPos;

void main() {
    vec3 norm = normalize(vNormal);
    vec3 lightDir = normalize(-uLightDir);

    vec3 ambient = uAmbientColor * uAmbientIntensity;
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = uLightColor * (diff * uLightIntensity);

    vec3 viewDir = normalize(uCameraPos - vFragPos);
    vec3 halfwayDir = normalize(lightDir + viewDir);
    float spec = pow(max(dot(norm, halfwayDir), 0.0), 32.0);
    vec3 specular = uLightColor * (spec * 0.5);

    vec3 result = (ambient + diffuse + specular) * uAlbedoColor.rgb;
    fragColor = vec4(result, uAlbedoColor.a);
}
)";

FilamentRenderer::FilamentRenderer() = default;

FilamentRenderer::~FilamentRenderer() {
    shutdown();
}

bool FilamentRenderer::initialize() {
    initShaders();
    return true;
}

void FilamentRenderer::shutdown() {
#if defined(__ANDROID__)
    if (shaderProgram_ != 0) {
        glDeleteProgram(shaderProgram_);
        shaderProgram_ = 0;
    }
#endif
}

void FilamentRenderer::initShaders() {
    shaderProgram_ = GPUProcessor::createProgram(kVertexShaderPBR, kFragmentShaderPBR);
}

void FilamentRenderer::resetMetrics() {
    metrics_ = RenderMetrics3D();
}

void FilamentRenderer::renderScene(const Camera& camera,
                                  const std::vector<std::shared_ptr<SceneNode3D>>& nodes,
                                  const DirectionalLight& dirLight,
                                  const Vec3& ambientColor,
                                  float ambientIntensity,
                                  int viewportWidth,
                                  int viewportHeight) {
    (void)viewportWidth;
    (void)viewportHeight;
    auto startTime = std::chrono::steady_clock::now();
    resetMetrics();

#if defined(__ANDROID__)
    if (!shaderProgram_ || nodes.empty()) return;

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);

    glUseProgram(shaderProgram_);

    GLint locAmbCol = glGetUniformLocation(shaderProgram_, "uAmbientColor");
    glUniform3f(locAmbCol, ambientColor.x, ambientColor.y, ambientColor.z);

    GLint locAmbInt = glGetUniformLocation(shaderProgram_, "uAmbientIntensity");
    glUniform1f(locAmbInt, ambientIntensity);

    GLint locLightDir = glGetUniformLocation(shaderProgram_, "uLightDir");
    glUniform3f(locLightDir, dirLight.direction.x, dirLight.direction.y, dirLight.direction.z);

    GLint locLightCol = glGetUniformLocation(shaderProgram_, "uLightColor");
    glUniform3f(locLightCol, dirLight.color.x, dirLight.color.y, dirLight.color.z);

    GLint locLightInt = glGetUniformLocation(shaderProgram_, "uLightIntensity");
    glUniform1f(locLightInt, dirLight.intensity);

    const auto& camPos = camera.getPosition();
    GLint locCamPos = glGetUniformLocation(shaderProgram_, "uCameraPos");
    glUniform3f(locCamPos, camPos.x, camPos.y, camPos.z);

    Mat4 vp = camera.getViewProjectionMatrix();
    GLint locVP = glGetUniformLocation(shaderProgram_, "uViewProj");
    glUniformMatrix4fv(locVP, 1, GL_FALSE, vp.data());

    GLint locModel = glGetUniformLocation(shaderProgram_, "uModel");
    GLint locAlbedo = glGetUniformLocation(shaderProgram_, "uAlbedoColor");

    for (const auto& node : nodes) {
        if (!node || !node->visible || !node->mesh) continue;

        // 1. Frustum Culling
        float maxDim = std::max({node->scale.x, node->scale.y, node->scale.z});
        if (!camera.isSphereInFrustum(node->position, maxDim)) {
            metrics_.culledNodes++;
            continue;
        }

        // 2. Matriz Model (TRS)
        float model[16] = {
            node->scale.x, 0, 0, 0,
            0, node->scale.y, 0, 0,
            0, 0, node->scale.z, 0,
            node->position.x, node->position.y, node->position.z, 1.0f
        };
        glUniformMatrix4fv(locModel, 1, GL_FALSE, model);

        const auto& col = node->material.albedoColor;
        glUniform4f(locAlbedo, col[0], col[1], col[2], col[3]);

        node->mesh->render();
        metrics_.drawCalls++;
        metrics_.renderedTriangles += static_cast<int>(node->mesh->getIndexCount() / 3);
        metrics_.renderedVertices += static_cast<int>(node->mesh->getVertexCount());
    }

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
#endif

    auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now() - startTime
    ).count();
    metrics_.gpuFrameTimeMs = static_cast<float>(elapsed) / 1000.0f;
}

} // namespace aurea
