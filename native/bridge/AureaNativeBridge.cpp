#include "AureaNativeBridge.h"
#include "../core/ProjectCore.h"
#include "../preview/PreviewEngine.h"
#include "../export/NativeExportPipeline.h"
#include "../scene3d/Scene3D.h"
#include "../scene3d/ModelAnalyzer.h"
#include "../scene3d/ModelImportManager.h"
#include <memory>
#include <string>
#include <cstring>

using namespace aurea;

struct AureaEngineContext {
    std::shared_ptr<ProjectCore> project;
    std::unique_ptr<PreviewEngine> preview;
    std::unique_ptr<NativeExportPipeline> exportPipeline;
    std::shared_ptr<Scene3D> scene3d;

    AureaEngineContext(int width, int height, int fps) {
        project = std::make_shared<ProjectCore>("AureaProject", width, height, fps);
        preview = std::make_unique<PreviewEngine>();
        preview->initialize(width, height, fps);
        preview->setProject(project);
        exportPipeline = std::make_unique<NativeExportPipeline>();
        scene3d = std::make_shared<Scene3D>();
        scene3d->initialize();
    }
};

const char* aurea_get_version() {
    return "1.0.0-native-core";
}

AureaEngineHandle aurea_engine_create(int width, int height, int fps) {
    auto* ctx = new AureaEngineContext(width, height, fps);
    return static_cast<AureaEngineHandle>(ctx);
}

void aurea_engine_destroy(AureaEngineHandle handle) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    delete ctx;
}

void aurea_project_set_duration(AureaEngineHandle handle, int64_t durationUs) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->project) {
        ctx->project->setDurationUs(durationUs);
    }
    if (ctx->preview) {
        ctx->preview->getTimeline().setDurationUs(durationUs);
    }
}

void aurea_project_add_layer(AureaEngineHandle handle, const char* layerId, const char* name, int layerType) {
    if (!handle || !layerId) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->project) {
        auto layer = std::make_shared<LayerCore>(
            layerId,
            name ? name : "Layer",
            static_cast<LayerType>(layerType)
        );
        ctx->project->addLayer(layer);
    }
}

void aurea_project_remove_layer(AureaEngineHandle handle, const char* layerId) {
    if (!handle || !layerId) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->project) {
        ctx->project->removeLayer(layerId);
    }
}

void aurea_layer_set_transform(AureaEngineHandle handle, const char* layerId,
                              double posX, double posY,
                              double scaleX, double scaleY,
                              double rotation, double opacity) {
    if (!handle || !layerId) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->project) {
        auto layer = ctx->project->getLayer(layerId);
        if (layer) {
            auto& t = layer->getTransform();
            t.posX = posX;
            t.posY = posY;
            t.scaleX = scaleX;
            t.scaleY = scaleY;
            t.rotation = rotation;
            t.opacity = opacity;
            ctx->project->markDirty(DirtyFlags::Transform);
        }
    }
}

void aurea_layer_set_shape(AureaEngineHandle handle, const char* layerId,
                          int shapeType, uint32_t fillColor,
                          uint32_t strokeColor, double strokeWidth,
                          double cornerRadius, double width, double height) {
    if (!handle || !layerId) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->project) {
        auto layer = ctx->project->getLayer(layerId);
        if (layer) {
            auto& s = layer->getShapeData();
            s.shapeType = shapeType;
            s.fillColor = fillColor;
            s.strokeColor = strokeColor;
            s.strokeWidth = strokeWidth;
            s.cornerRadius = cornerRadius;
            s.width = width;
            s.height = height;
            ctx->project->markDirty(DirtyFlags::Material);
        }
    }
}

void aurea_layer_add_keyframe(AureaEngineHandle handle, const char* layerId,
                             const char* propertyName, int64_t timeUs,
                             double value, int interpolation,
                             double x1, double y1, double x2, double y2) {
    if (!handle || !layerId || !propertyName) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        auto& anim = ctx->preview->getRenderEngine().getAnimationEngine();
        auto track = anim.getKeyframeEngine().getOrCreateTrack(layerId, propertyName);
        CubicBezierCurve curve{x1, y1, x2, y2};
        track->addOrUpdateKeyframe(timeUs, value, static_cast<InterpolationType>(interpolation), curve);
        if (ctx->project) {
            ctx->project->markDirty(DirtyFlags::Animation);
        }
    }
}

void aurea_layer_remove_keyframe(AureaEngineHandle handle, const char* layerId,
                                const char* propertyName, int64_t timeUs) {
    if (!handle || !layerId || !propertyName) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        auto& anim = ctx->preview->getRenderEngine().getAnimationEngine();
        auto track = anim.getKeyframeEngine().getTrack(layerId, propertyName);
        if (track) {
            track->removeKeyframe(timeUs);
            if (ctx->project) {
                ctx->project->markDirty(DirtyFlags::Animation);
            }
        }
    }
}

void aurea_timeline_play(AureaEngineHandle handle) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        ctx->preview->getTimeline().play();
    }
}

void aurea_timeline_pause(AureaEngineHandle handle) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        ctx->preview->getTimeline().pause();
    }
}

void aurea_timeline_seek(AureaEngineHandle handle, int64_t timeUs) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        ctx->preview->getTimeline().seekToUs(timeUs);
        ctx->preview->renderPreviewFrame(timeUs);
    }
}

int64_t aurea_timeline_get_time(AureaEngineHandle handle) {
    if (!handle) return 0;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        return ctx->preview->getTimeline().getCurrentTimeUs();
    }
    return 0;
}

void aurea_preview_render(AureaEngineHandle handle, int64_t timeUs) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        ctx->preview->renderPreviewFrame(timeUs);
    }
}

void aurea_preview_tick(AureaEngineHandle handle, double deltaSeconds) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        ctx->preview->tick(deltaSeconds);
    }
}

uint32_t aurea_preview_get_texture(AureaEngineHandle handle) {
    if (!handle) return 0;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->preview) {
        return ctx->preview->getPreviewTextureId();
    }
    return 0;
}

int32_t aurea_export_render_frame(AureaEngineHandle handle, int frameIndex,
                                 int width, int height, int fps,
                                 uint8_t* outRgbaBuffer) {
    if (!handle || !outRgbaBuffer) return 0;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->exportPipeline && ctx->project) {
        bool ok = ctx->exportPipeline->renderFrameDirect(
            ctx->project, frameIndex, width, height, fps, outRgbaBuffer
        );
        return ok ? 1 : 0;
    }
    return 0;
}

int32_t aurea_export_start(AureaEngineHandle handle, const char* outputPath,
                          int width, int height, int fps,
                          int64_t durationUs, int bitrate) {
    if (!handle) return 0;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->exportPipeline && ctx->project) {
        ExportConfig cfg;
        cfg.width = width;
        cfg.height = height;
        cfg.fps = fps;
        cfg.durationUs = durationUs;
        cfg.bitrate = bitrate;
        if (outputPath) cfg.outputPath = outputPath;

        bool ok = ctx->exportPipeline->exportProject(ctx->project, cfg, nullptr);
        return ok ? 1 : 0;
    }
    return 0;
}

float aurea_export_get_progress(AureaEngineHandle handle) {
    if (!handle) return 0.0f;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->exportPipeline) {
        return ctx->exportPipeline->getProgress();
    }
    return 0.0f;
}

void aurea_export_cancel(AureaEngineHandle handle) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->exportPipeline) {
        ctx->exportPipeline->cancelExport();
    }
}

int32_t aurea_model_analyze(const char* filePath, AureaModelAnalysis* outAnalysis) {
    if (!filePath || !outAnalysis) return 0;
    auto report = ModelAnalyzer::analyzeFile(filePath, DeviceProfile::instance());

    outAnalysis->fileSizeBytes = report.fileSizeBytes;
    outAnalysis->meshCount = report.meshCount;
    outAnalysis->vertexCount = report.vertexCount;
    outAnalysis->triangleCount = report.triangleCount;
    outAnalysis->materialCount = report.materialCount;
    outAnalysis->textureCount = report.textureCount;
    outAnalysis->largestTextureWidth = report.largestTextureWidth;
    outAnalysis->largestTextureHeight = report.largestTextureHeight;
    outAnalysis->boneCount = report.boneCount;
    outAnalysis->animationCount = report.animationCount;
    outAnalysis->nodeCount = report.nodeCount;
    outAnalysis->estimatedCpuMemoryMb = report.estimatedCpuMemoryMb;
    outAnalysis->estimatedGpuMemoryMb = report.estimatedGpuMemoryMb;
    outAnalysis->isSafeForDevice = report.isSafeForDevice ? 1 : 0;
    outAnalysis->recommendedLOD = report.recommendedLOD;

    return 1;
}

int64_t aurea_model_import_async(AureaEngineHandle handle, const char* filePath, const char* targetNodeId) {
    if (!handle || !filePath) return -1;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (!ctx->scene3d) return -1;

    std::string nodeId = targetNodeId ? targetNodeId : "imported_root";
    return ctx->scene3d->importModelAsync(filePath, nodeId, nullptr);
}

int32_t aurea_model_import_get_progress(int64_t jobId, float* outProgress, int32_t* outStage, char* outStageName, int32_t stageNameMaxLen) {
    auto prog = ModelImportManager::instance().getProgress(jobId);
    if (outProgress) *outProgress = prog.progress;
    if (outStage) *outStage = static_cast<int32_t>(prog.stage);
    if (outStageName && stageNameMaxLen > 0) {
        std::strncpy(outStageName, prog.stageDescription.c_str(), stageNameMaxLen - 1);
        outStageName[stageNameMaxLen - 1] = '\0';
    }
    return prog.isDone ? 1 : 0;
}

void aurea_model_import_cancel(int64_t jobId) {
    ModelImportManager::instance().cancelImport(jobId);
}

void aurea_scene3d_set_frame_budget(AureaEngineHandle handle, float budgetMs) {
    if (!handle) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->scene3d) {
        ctx->scene3d->setFrameBudgetMs(budgetMs);
    }
}

void aurea_scene3d_get_metrics(AureaEngineHandle handle, AureaSceneMetrics* outMetrics) {
    if (!handle || !outMetrics) return;
    auto* ctx = static_cast<AureaEngineContext*>(handle);
    if (ctx->scene3d) {
        auto m = ctx->scene3d->getMetrics();
        outMetrics->drawCalls = m.drawCalls;
        outMetrics->renderedTriangles = m.renderedTriangles;
        outMetrics->renderedVertices = m.renderedVertices;
        outMetrics->culledNodes = m.culledNodes;
        outMetrics->gpuFrameTimeMs = m.gpuFrameTimeMs;
    }
}
