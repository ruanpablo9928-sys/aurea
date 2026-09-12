#include "FrameScheduler.h"

namespace aurea {

FrameScheduler::FrameScheduler(int targetFps)
    : targetFps_(targetFps > 0 ? targetFps : 60),
      targetIntervalUs_(1000000 / (targetFps > 0 ? targetFps : 60)),
      lastFrameTime_(std::chrono::steady_clock::now()),
      fpsTimer_(std::chrono::steady_clock::now()) {
}

void FrameScheduler::setTargetFps(int fps) {
    if (fps > 0) {
        targetFps_ = fps;
        targetIntervalUs_ = 1000000 / fps;
    }
}

bool FrameScheduler::shouldRenderNextFrame() {
    auto now = std::chrono::steady_clock::now();
    auto elapsedUs = std::chrono::duration_cast<std::chrono::microseconds>(now - lastFrameTime_).count();

    if (elapsedUs >= targetIntervalUs_) {
        // Se demorou mais que 2x o intervalo, contamos como dropped frame
        if (elapsedUs > targetIntervalUs_ * 2) {
            droppedFrames_++;
        }
        return true;
    }
    return false;
}

void FrameScheduler::markFrameRendered() {
    auto now = std::chrono::steady_clock::now();
    lastFrameTime_ = now;
    frameCount_++;

    auto elapsedFps = std::chrono::duration_cast<std::chrono::milliseconds>(now - fpsTimer_).count();
    if (elapsedFps >= 1000) {
        actualFps_ = (static_cast<float>(frameCount_) * 1000.0f) / static_cast<float>(elapsedFps);
        frameCount_ = 0;
        fpsTimer_ = now;
    }
}

void FrameScheduler::resetStats() {
    frameCount_ = 0;
    droppedFrames_ = 0;
    actualFps_ = static_cast<float>(targetFps_);
    fpsTimer_ = std::chrono::steady_clock::now();
    lastFrameTime_ = std::chrono::steady_clock::now();
}

} // namespace aurea
