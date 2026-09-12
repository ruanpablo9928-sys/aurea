// RenderCore.cpp implementation
#include "RenderCore.h"
#include "RenderTarget.h"
#include "../renderer/RenderEngine.h"
#include <chrono>
#include <iostream>

namespace aurea {

RenderCore::RenderCore() : engine_(std::make_unique<RenderEngine>()) {
    // Initialize internal render engine with default size (will be overridden per frame)
    // For now we can use a dummy size; actual framebuffer is provided via Frame.target
}

RenderCore::~RenderCore() {
    stop();
}

void RenderCore::start() {
    if (running_) return;
    running_ = true;
    worker_ = std::thread(&RenderCore::loop, this);
}

void RenderCore::stop() {
    if (!running_) return;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        running_ = false;
        cv_.notify_all();
    }
    if (worker_.joinable()) {
        worker_.join();
    }
}

void RenderCore::submit(Frame&& frame) {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        // In PREVIEW mode, keep only the most recent frame to avoid backlog
        if (mode_ == RenderMode::PREVIEW && !queue_.empty()) {
            // discard previous frame(s)
            std::queue<Frame> empty;
            std::swap(queue_, empty);
        }
        queue_.push(std::move(frame));
    }
    cv_.notify_one();
}

void RenderCore::setMode(RenderMode mode) {
    std::lock_guard<std::mutex> lock(mutex_);
    mode_ = mode;
}

void RenderCore::setEffect(int id, float value) {
    // Placeholder: Store effect parameters if needed
    // For now no-op
}

std::shared_ptr<GPUFramebuffer> RenderCore::getMainFramebuffer() const {
    return engine_ ? engine_->getMainFramebuffer() : nullptr;
}

void RenderCore::loop() {
    while (true) {
        Frame frame;
        {
            std::unique_lock<std::mutex> lock(mutex_);
            cv_.wait(lock, [this] { return !queue_.empty() || !running_; });
            if (!running_ && queue_.empty()) break;
            frame = std::move(queue_.front());
            queue_.pop();
        }
        // Apply any effects (stub)
        applyEffects(frame);
        // Determine target framebuffer. If frame.target is provided, use it; otherwise use engine's default.
        std::shared_ptr<GPUFramebuffer> fbo;
        if (frame.target && frame.target->getFramebuffer()) {
            fbo = frame.target->getFramebuffer();
        } else {
            // Create a temporary framebuffer matching project resolution
            auto proj = frame.project;
            if (proj) {
                int w = proj->getWidth();
                int h = proj->getHeight();
                // Use RenderEngine's GPUProcessor via getGPU()
                fbo = engine_->getGPU()->createFramebuffer(w, h);
            }
        }
        // Render using internal engine
        if (frame.project && fbo) {
            engine_->renderFrame(*frame.project, frame.timeUs, fbo);
        }
    }
}

void RenderCore::applyEffects(Frame& frame) {
    // Placeholder for effect processing – currently does nothing
    // In a real implementation, this would read/write pixelBuffer, run shaders, etc.
}

} // namespace aurea
