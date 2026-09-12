#pragma once

#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <atomic>
#include <memory>

#include "GPUProcessor.h"
#include "../renderer/RenderEngine.h"

namespace aurea {

enum class RenderMode {
    PREVIEW,
    EXPORT
};

// Forward declaration of RenderTarget (wrapper around GPUFramebuffer)
class RenderTarget;
class ProjectCore; // forward declaration for ProjectCore

struct Frame {
    // Unique identifier for caching / debugging
    uint64_t id = 0;
    // Timestamp in microseconds
    int64_t timeUs = 0;
    // Desired render resolution (full, half, quarter)
    enum class Resolution { FULL, HALF, QUARTER } resolution = Resolution::FULL;
    // Target render target (offscreen framebuffer)
    std::shared_ptr<RenderTarget> target;
    // Pointer to GPU processor for low‑level ops
    std::shared_ptr<GPUProcessor> gpu;
    // Optional raw pixel buffer for effect processing (owned)
    std::vector<uint8_t> pixelBuffer;
    // Project associated with this frame (needed for rendering)
    std::shared_ptr<ProjectCore> project;
};

class RenderCore {
public:
    RenderCore();
    ~RenderCore();

    // Starts the worker thread
    void start();
    // Requests graceful shutdown
    void stop();

    // Submit a frame for asynchronous processing. Thread‑safe.
    void submit(Frame&& frame);

    // Set rendering mode (preview vs export)
    void setMode(RenderMode mode);

    // Set effect parameters – delegated to effect processor (placeholder)
    void setEffect(int id, float value);

    // Obtém o framebuffer principal do motor de renderização interno
    std::shared_ptr<GPUFramebuffer> getMainFramebuffer() const;

private:
    void loop();

    std::atomic<bool> running_{false};
    std::thread worker_;
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<Frame> queue_; // frame queue for async processing
    std::unique_ptr<RenderEngine> engine_; // internal render engine used by async core
    RenderMode mode_ = RenderMode::PREVIEW;

    // Simple effect stub – real implementation will call the existing effect pipeline
    void applyEffects(Frame& frame);
};

} // namespace aurea
