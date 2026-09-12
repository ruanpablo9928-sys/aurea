#pragma once

#include "FrameScheduler.h"
#include "../core/ProjectCore.h"
#include "../core/TimelineCore.h"
#include "../renderer/RenderEngine.h"
#include "../rendercore/RenderCore.h"
#include <memory>
#include <mutex>

namespace aurea {

class PreviewEngine {
public:
    PreviewEngine();
    ~PreviewEngine();

    bool initialize(int width, int height, int fps = 60);
    void shutdown();

    void setProject(std::shared_ptr<ProjectCore> project) { project_ = project; }
    std::shared_ptr<ProjectCore> getProject() const { return project_; }

    TimelineCore& getTimeline() { return timeline_; }
    const TimelineCore& getTimeline() const { return timeline_; }

    RenderEngine& getRenderEngine() { return renderEngine_; }
    FrameScheduler& getScheduler() { return scheduler_; }

    void renderPreviewFrame(int64_t timeUs = -1);
    void tick(double deltaSeconds);
    uint32_t getPreviewTextureId() const;

private:
    int width_ = 1920;
    int height_ = 1080;
    std::shared_ptr<ProjectCore> project_;
    TimelineCore timeline_;
    RenderEngine renderEngine_;
    FrameScheduler scheduler_;
    RenderCore asyncCore_; // asynchronous render core for preview
    mutable std::mutex mutex_;
};

} // namespace aurea
