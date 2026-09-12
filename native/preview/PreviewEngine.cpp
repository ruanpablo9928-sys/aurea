#include "PreviewEngine.h"

namespace aurea {

PreviewEngine::PreviewEngine() = default;

PreviewEngine::~PreviewEngine() {
    shutdown();
}

bool PreviewEngine::initialize(int width, int height, int fps) {
    width_ = width;
    height_ = height;
    timeline_.setFps(fps);
    scheduler_.setTargetFps(fps);

    // start async render core for preview
    asyncCore_.start();

    // underlying render engine is still used for occasional sync tasks
    return renderEngine_.initialize(width, height);
}

void PreviewEngine::shutdown() {
    asyncCore_.stop();
    renderEngine_.shutdown();
    project_.reset();
}

void PreviewEngine::renderPreviewFrame(int64_t timeUs) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!project_) return;

    int64_t targetTimeUs = timeUs >= 0 ? timeUs : timeline_.getCurrentTimeUs();
    // Build frame for async core
    Frame frame;
    static uint64_t frameCounter = 0;
    frame.id = ++frameCounter;
    frame.timeUs = targetTimeUs;
    frame.project = project_;
    // No specific target, let RenderCore use its internal framebuffer
    asyncCore_.submit(std::move(frame));
    scheduler_.markFrameRendered();
}

void PreviewEngine::tick(double deltaSeconds) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!project_ || !timeline_.isPlaying()) return;

    if (scheduler_.shouldRenderNextFrame()) {
        int64_t newTimeUs = timeline_.advanceTime(deltaSeconds);
        // Submit async render request
        Frame frame;
        static uint64_t frameCounter = 0;
        frame.id = ++frameCounter;
        frame.timeUs = newTimeUs;
        frame.project = project_;
        asyncCore_.submit(std::move(frame));
        scheduler_.markFrameRendered();
    }
}

uint32_t PreviewEngine::getPreviewTextureId() const {
    // Retrieve texture from async core's internal engine main framebuffer, falling back to sync
    auto fbo = asyncCore_.getMainFramebuffer();
    if (!fbo) {
        fbo = renderEngine_.getMainFramebuffer();
    }
    return fbo ? fbo->colorTextureId : 0;
}

} // namespace aurea
