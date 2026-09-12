#pragma once

#include <cstdint>

#if defined(_WIN32)
    #if defined(AUREA_BUILD_SHARED)
        #define AUREA_EXPORT __declspec(dllexport)
    #else
        #define AUREA_EXPORT
    #endif
#else
    #define AUREA_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef void* AureaEngineHandle;

// Versão do Motor Nativo
AUREA_EXPORT const char* aurea_get_version();

// Ciclo de Vida do Motor Nativo
AUREA_EXPORT AureaEngineHandle aurea_engine_create(int width, int height, int fps);
AUREA_EXPORT void aurea_engine_destroy(AureaEngineHandle handle);

// Gestão de Projeto
AUREA_EXPORT void aurea_project_set_duration(AureaEngineHandle handle, int64_t durationUs);
AUREA_EXPORT void aurea_project_add_layer(AureaEngineHandle handle, const char* layerId, const char* name, int layerType);
AUREA_EXPORT void aurea_project_remove_layer(AureaEngineHandle handle, const char* layerId);

// Camadas e Propriedades
AUREA_EXPORT void aurea_layer_set_transform(AureaEngineHandle handle, const char* layerId,
                                           double posX, double posY,
                                           double scaleX, double scaleY,
                                           double rotation, double opacity);

AUREA_EXPORT void aurea_layer_set_shape(AureaEngineHandle handle, const char* layerId,
                                       int shapeType, uint32_t fillColor,
                                       uint32_t strokeColor, double strokeWidth,
                                       double cornerRadius, double width, double height);

// Motor de Animação e Keyframes
AUREA_EXPORT void aurea_layer_add_keyframe(AureaEngineHandle handle, const char* layerId,
                                          const char* propertyName, int64_t timeUs,
                                          double value, int interpolation,
                                          double x1, double y1, double x2, double y2);

AUREA_EXPORT void aurea_layer_remove_keyframe(AureaEngineHandle handle, const char* layerId,
                                             const char* propertyName, int64_t timeUs);

// Timeline e Playback
AUREA_EXPORT void aurea_timeline_play(AureaEngineHandle handle);
AUREA_EXPORT void aurea_timeline_pause(AureaEngineHandle handle);
AUREA_EXPORT void aurea_timeline_seek(AureaEngineHandle handle, int64_t timeUs);
AUREA_EXPORT int64_t aurea_timeline_get_time(AureaEngineHandle handle);

// Preview Engine
AUREA_EXPORT void aurea_preview_render(AureaEngineHandle handle, int64_t timeUs);
AUREA_EXPORT void aurea_preview_tick(AureaEngineHandle handle, double deltaSeconds);
AUREA_EXPORT uint32_t aurea_preview_get_texture(AureaEngineHandle handle);

// Pipeline de Exportação de Alta Performance (Zero-Wait Offscreen)
AUREA_EXPORT int32_t aurea_export_render_frame(AureaEngineHandle handle, int frameIndex,
                                              int width, int height, int fps,
                                              uint8_t* outRgbaBuffer);

AUREA_EXPORT int32_t aurea_export_start(AureaEngineHandle handle, const char* outputPath,
                                       int width, int height, int fps,
                                       int64_t durationUs, int bitrate);

AUREA_EXPORT float aurea_export_get_progress(AureaEngineHandle handle);
AUREA_EXPORT void aurea_export_cancel(AureaEngineHandle handle);

// Estruturas de 3D Model Pipeline & Filament
typedef struct {
    int64_t fileSizeBytes;
    int32_t meshCount;
    int32_t vertexCount;
    int32_t triangleCount;
    int32_t materialCount;
    int32_t textureCount;
    int32_t largestTextureWidth;
    int32_t largestTextureHeight;
    int32_t boneCount;
    int32_t animationCount;
    int32_t nodeCount;
    float estimatedCpuMemoryMb;
    float estimatedGpuMemoryMb;
    int32_t isSafeForDevice;
    int32_t recommendedLOD;
} AureaModelAnalysis;

typedef struct {
    int32_t drawCalls;
    int32_t renderedTriangles;
    int32_t renderedVertices;
    int32_t culledNodes;
    float gpuFrameTimeMs;
} AureaSceneMetrics;

// Pipeline 3D Assíncrono (Desacoplado da UI)
AUREA_EXPORT int32_t aurea_model_analyze(const char* filePath, AureaModelAnalysis* outAnalysis);
AUREA_EXPORT int64_t aurea_model_import_async(AureaEngineHandle handle, const char* filePath, const char* targetNodeId);
AUREA_EXPORT int32_t aurea_model_import_get_progress(int64_t jobId, float* outProgress, int32_t* outStage, char* outStageName, int32_t stageNameMaxLen);
AUREA_EXPORT void aurea_model_import_cancel(int64_t jobId);
AUREA_EXPORT void aurea_scene3d_set_frame_budget(AureaEngineHandle handle, float budgetMs);
AUREA_EXPORT void aurea_scene3d_get_metrics(AureaEngineHandle handle, AureaSceneMetrics* outMetrics);

// Time Remapping Profissional (After Effects style)
AUREA_EXPORT void aurea_layer_time_remap_enable(AureaEngineHandle handle, const char* layerId, int32_t enable);
AUREA_EXPORT void aurea_layer_time_remap_reset_default(AureaEngineHandle handle, const char* layerId, double durationSeconds);
AUREA_EXPORT void aurea_layer_time_remap_add_keyframe(AureaEngineHandle handle, const char* layerId,
                                                     double compositionTime, double sourceTime,
                                                     int32_t interpolation,
                                                     double inDx, double inDy,
                                                     double outDx, double outDy);
AUREA_EXPORT int32_t aurea_layer_time_remap_remove_keyframe(AureaEngineHandle handle, const char* layerId, int32_t index);
AUREA_EXPORT int32_t aurea_layer_time_remap_remove_keyframe_at(AureaEngineHandle handle, const char* layerId, double compositionTime, double tolerance);
AUREA_EXPORT void aurea_layer_time_remap_clear(AureaEngineHandle handle, const char* layerId);
AUREA_EXPORT int32_t aurea_layer_time_remap_get_keyframe_count(AureaEngineHandle handle, const char* layerId);
AUREA_EXPORT int32_t aurea_layer_time_remap_get_keyframe(AureaEngineHandle handle, const char* layerId, int32_t index,
                                                        double* outCompTime, double* outSourceTime,
                                                        int32_t* outInterp,
                                                        double* outInDx, double* outInDy,
                                                        double* outOutDx, double* outOutDy);
AUREA_EXPORT double aurea_layer_time_remap_evaluate(AureaEngineHandle handle, const char* layerId, double compositionTime);
AUREA_EXPORT double aurea_layer_time_remap_get_speed(AureaEngineHandle handle, const char* layerId, double compositionTime);

#ifdef __cplusplus
}
#endif
