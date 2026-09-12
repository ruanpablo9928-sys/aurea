#pragma once

#include <chrono>
#include <cstdint>

namespace aurea {

class FrameScheduler {
public:
    FrameScheduler(int targetFps = 60);
    ~FrameScheduler() = default;

    void setTargetFps(int fps);
    int getTargetFps() const { return targetFps_; }

    // Retorna true se deve renderizar um novo quadro agora
    bool shouldRenderNextFrame();

    // Notifica que o quadro foi renderizado com sucesso
    void markFrameRendered();

    // Estatísticas de FPS real e quadros descartados
    float getActualFps() const { return actualFps_; }
    uint64_t getDroppedFrames() const { return droppedFrames_; }
    void resetStats();

private:
    int targetFps_ = 60;
    int64_t targetIntervalUs_ = 16666; // 1/60s

    std::chrono::steady_clock::time_point lastFrameTime_;
    std::chrono::steady_clock::time_point fpsTimer_;

    int frameCount_ = 0;
    float actualFps_ = 60.0f;
    uint64_t droppedFrames_ = 0;
};

} // namespace aurea
