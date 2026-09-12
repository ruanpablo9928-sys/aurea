import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Typedefs FFI C
typedef CAureaGetVersion = Pointer<Utf8> Function();
typedef DAureaGetVersion = Pointer<Utf8> Function();

typedef CAureaEngineCreate = Pointer<Void> Function(Int32 width, Int32 height, Int32 fps);
typedef DAureaEngineCreate = Pointer<Void> Function(int width, int height, int fps);

typedef CAureaEngineDestroy = Void Function(Pointer<Void> handle);
typedef DAureaEngineDestroy = void Function(Pointer<Void> handle);

typedef CAureaProjectSetDuration = Void Function(Pointer<Void> handle, Int64 durationUs);
typedef DAureaProjectSetDuration = void Function(Pointer<Void> handle, int durationUs);

typedef CAureaProjectAddLayer = Void Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, Pointer<Utf8> name, Int32 layerType);
typedef DAureaProjectAddLayer = void Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, Pointer<Utf8> name, int layerType);

typedef CAureaProjectRemoveLayer = Void Function(Pointer<Void> handle, Pointer<Utf8> layerId);
typedef DAureaProjectRemoveLayer = void Function(Pointer<Void> handle, Pointer<Utf8> layerId);

typedef CAureaLayerSetTransform = Void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Double posX,
    Double posY,
    Double scaleX,
    Double scaleY,
    Double rotation,
    Double opacity);
typedef DAureaLayerSetTransform = void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    double posX,
    double posY,
    double scaleX,
    double scaleY,
    double rotation,
    double opacity);

typedef CAureaLayerSetShape = Void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Int32 shapeType,
    Uint32 fillColor,
    Uint32 strokeColor,
    Double strokeWidth,
    Double cornerRadius,
    Double width,
    Double height);
typedef DAureaLayerSetShape = void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    int shapeType,
    int fillColor,
    int strokeColor,
    double strokeWidth,
    double cornerRadius,
    double width,
    double height);

typedef CAureaLayerAddKeyframe = Void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Pointer<Utf8> propertyName,
    Int64 timeUs,
    Double value,
    Int32 interpolation,
    Double x1,
    Double y1,
    Double x2,
    Double y2);
typedef DAureaLayerAddKeyframe = void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Pointer<Utf8> propertyName,
    int timeUs,
    double value,
    int interpolation,
    double x1,
    double y1,
    double x2,
    double y2);

typedef CAureaLayerRemoveKeyframe = Void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Pointer<Utf8> propertyName,
    Int64 timeUs);
typedef DAureaLayerRemoveKeyframe = void Function(
    Pointer<Void> handle,
    Pointer<Utf8> layerId,
    Pointer<Utf8> propertyName,
    int timeUs);

typedef CAureaTimelinePlay = Void Function(Pointer<Void> handle);
typedef DAureaTimelinePlay = void Function(Pointer<Void> handle);

typedef CAureaTimelinePause = Void Function(Pointer<Void> handle);
typedef DAureaTimelinePause = void Function(Pointer<Void> handle);

typedef CAureaTimelineSeek = Void Function(Pointer<Void> handle, Int64 timeUs);
typedef DAureaTimelineSeek = void Function(Pointer<Void> handle, int timeUs);

typedef CAureaTimelineGetTime = Int64 Function(Pointer<Void> handle);
typedef DAureaTimelineGetTime = int Function(Pointer<Void> handle);

typedef CAureaPreviewRender = Void Function(Pointer<Void> handle, Int64 timeUs);
typedef DAureaPreviewRender = void Function(Pointer<Void> handle, int timeUs);

typedef CAureaPreviewTick = Void Function(Pointer<Void> handle, Double deltaSeconds);
typedef DAureaPreviewTick = void Function(Pointer<Void> handle, double deltaSeconds);

typedef CAureaPreviewGetTexture = Uint32 Function(Pointer<Void> handle);
typedef DAureaPreviewGetTexture = int Function(Pointer<Void> handle);

typedef CAureaExportRenderFrame = Int32 Function(
    Pointer<Void> handle, Int32 frameIndex, Int32 width, Int32 height, Int32 fps, Pointer<Uint8> outBuffer);
typedef DAureaExportRenderFrame = int Function(
    Pointer<Void> handle, int frameIndex, int width, int height, int fps, Pointer<Uint8> outBuffer);

typedef CAureaExportStart = Int32 Function(
    Pointer<Void> handle,
    Pointer<Utf8> outputPath,
    Int32 width,
    Int32 height,
    Int32 fps,
    Int64 durationUs,
    Int32 bitrate);
typedef DAureaExportStart = int Function(
    Pointer<Void> handle,
    Pointer<Utf8> outputPath,
    int width,
    int height,
    int fps,
    int durationUs,
    int bitrate);

typedef CAureaExportGetProgress = Float Function(Pointer<Void> handle);
typedef DAureaExportGetProgress = double Function(Pointer<Void> handle);

typedef CAureaExportCancel = Void Function(Pointer<Void> handle);
typedef DAureaExportCancel = void Function(Pointer<Void> handle);

// 3D Model Pipeline Structs
final class NativeModelAnalysis extends Struct {
  @Int64()
  external int fileSizeBytes;
  @Int32()
  external int meshCount;
  @Int32()
  external int vertexCount;
  @Int32()
  external int triangleCount;
  @Int32()
  external int materialCount;
  @Int32()
  external int textureCount;
  @Int32()
  external int largestTextureWidth;
  @Int32()
  external int largestTextureHeight;
  @Int32()
  external int boneCount;
  @Int32()
  external int animationCount;
  @Int32()
  external int nodeCount;
  @Float()
  external double estimatedCpuMemoryMb;
  @Float()
  external double estimatedGpuMemoryMb;
  @Int32()
  external int isSafeForDevice;
  @Int32()
  external int recommendedLOD;
}

final class NativeSceneMetrics extends Struct {
  @Int32()
  external int drawCalls;
  @Int32()
  external int renderedTriangles;
  @Int32()
  external int renderedVertices;
  @Int32()
  external int culledNodes;
  @Float()
  external double gpuFrameTimeMs;
}

typedef CAureaModelAnalyze = Int32 Function(Pointer<Utf8> filePath, Pointer<NativeModelAnalysis> outAnalysis);
typedef DAureaModelAnalyze = int Function(Pointer<Utf8> filePath, Pointer<NativeModelAnalysis> outAnalysis);

typedef CAureaModelImportAsync = Int64 Function(Pointer<Void> handle, Pointer<Utf8> filePath, Pointer<Utf8> targetNodeId);
typedef DAureaModelImportAsync = int Function(Pointer<Void> handle, Pointer<Utf8> filePath, Pointer<Utf8> targetNodeId);

typedef CAureaModelImportGetProgress = Int32 Function(
    Int64 jobId, Pointer<Float> outProgress, Pointer<Int32> outStage, Pointer<Utf8> outStageName, Int32 stageNameMaxLen);
typedef DAureaModelImportGetProgress = int Function(
    int jobId, Pointer<Float> outProgress, Pointer<Int32> outStage, Pointer<Utf8> outStageName, int stageNameMaxLen);

typedef CAureaModelImportCancel = Void Function(Int64 jobId);
typedef DAureaModelImportCancel = void Function(int jobId);

typedef CAureaScene3DSetFrameBudget = Void Function(Pointer<Void> handle, Float budgetMs);
typedef DAureaScene3DSetFrameBudget = void Function(Pointer<Void> handle, double budgetMs);

typedef CAureaScene3DGetMetrics = Void Function(Pointer<Void> handle, Pointer<NativeSceneMetrics> outMetrics);
typedef DAureaScene3DGetMetrics = void Function(Pointer<Void> handle, Pointer<NativeSceneMetrics> outMetrics);

// Time Remap FFI Typedefs
typedef CAureaLayerTimeRemapEnable = Void Function(Pointer<Void> handle, Pointer<Utf8> layerId, Int32 enable);
typedef DAureaLayerTimeRemapEnable = void Function(Pointer<Void> handle, Pointer<Utf8> layerId, int enable);

typedef CAureaLayerTimeRemapResetDefault = Void Function(Pointer<Void> handle, Pointer<Utf8> layerId, Double durationSeconds);
typedef DAureaLayerTimeRemapResetDefault = void Function(Pointer<Void> handle, Pointer<Utf8> layerId, double durationSeconds);

typedef CAureaLayerTimeRemapAddKeyframe = Void Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, Double compositionTime, Double sourceTime, Int32 interpolation, Double inDx, Double inDy, Double outDx, Double outDy);
typedef DAureaLayerTimeRemapAddKeyframe = void Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, double compositionTime, double sourceTime, int interpolation, double inDx, double inDy, double outDx, double outDy);

typedef CAureaLayerTimeRemapRemoveKeyframe = Int32 Function(Pointer<Void> handle, Pointer<Utf8> layerId, Int32 index);
typedef DAureaLayerTimeRemapRemoveKeyframe = int Function(Pointer<Void> handle, Pointer<Utf8> layerId, int index);

typedef CAureaLayerTimeRemapRemoveKeyframeAt = Int32 Function(Pointer<Void> handle, Pointer<Utf8> layerId, Double compositionTime, Double tolerance);
typedef DAureaLayerTimeRemapRemoveKeyframeAt = int Function(Pointer<Void> handle, Pointer<Utf8> layerId, double compositionTime, double tolerance);

typedef CAureaLayerTimeRemapClear = Void Function(Pointer<Void> handle, Pointer<Utf8> layerId);
typedef DAureaLayerTimeRemapClear = void Function(Pointer<Void> handle, Pointer<Utf8> layerId);

typedef CAureaLayerTimeRemapGetKeyframeCount = Int32 Function(Pointer<Void> handle, Pointer<Utf8> layerId);
typedef DAureaLayerTimeRemapGetKeyframeCount = int Function(Pointer<Void> handle, Pointer<Utf8> layerId);

typedef CAureaLayerTimeRemapGetKeyframe = Int32 Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, Int32 index,
    Pointer<Double> outCompTime, Pointer<Double> outSourceTime,
    Pointer<Int32> outInterp,
    Pointer<Double> outInDx, Pointer<Double> outInDy,
    Pointer<Double> outOutDx, Pointer<Double> outOutDy);
typedef DAureaLayerTimeRemapGetKeyframe = int Function(
    Pointer<Void> handle, Pointer<Utf8> layerId, int index,
    Pointer<Double> outCompTime, Pointer<Double> outSourceTime,
    Pointer<Int32> outInterp,
    Pointer<Double> outInDx, Pointer<Double> outInDy,
    Pointer<Double> outOutDx, Pointer<Double> outOutDy);

typedef CAureaLayerTimeRemapEvaluate = Double Function(Pointer<Void> handle, Pointer<Utf8> layerId, Double compositionTime);
typedef DAureaLayerTimeRemapEvaluate = double Function(Pointer<Void> handle, Pointer<Utf8> layerId, double compositionTime);

typedef CAureaLayerTimeRemapGetSpeed = Double Function(Pointer<Void> handle, Pointer<Utf8> layerId, Double compositionTime);
typedef DAureaLayerTimeRemapGetSpeed = double Function(Pointer<Void> handle, Pointer<Utf8> layerId, double compositionTime);

/// Bindings FFI do Aurea Native Core
class AureaNativeBindings {
  AureaNativeBindings._(this._dylib) {
    version = _dylib.lookupFunction<CAureaGetVersion, DAureaGetVersion>('aurea_get_version');
    createEngine = _dylib.lookupFunction<CAureaEngineCreate, DAureaEngineCreate>('aurea_engine_create');
    destroyEngine = _dylib.lookupFunction<CAureaEngineDestroy, DAureaEngineDestroy>('aurea_engine_destroy');
    projectSetDuration = _dylib.lookupFunction<CAureaProjectSetDuration, DAureaProjectSetDuration>('aurea_project_set_duration');
    projectAddLayer = _dylib.lookupFunction<CAureaProjectAddLayer, DAureaProjectAddLayer>('aurea_project_add_layer');
    projectRemoveLayer = _dylib.lookupFunction<CAureaProjectRemoveLayer, DAureaProjectRemoveLayer>('aurea_project_remove_layer');
    layerSetTransform = _dylib.lookupFunction<CAureaLayerSetTransform, DAureaLayerSetTransform>('aurea_layer_set_transform');
    layerSetShape = _dylib.lookupFunction<CAureaLayerSetShape, DAureaLayerSetShape>('aurea_layer_set_shape');
    layerAddKeyframe = _dylib.lookupFunction<CAureaLayerAddKeyframe, DAureaLayerAddKeyframe>('aurea_layer_add_keyframe');
    layerRemoveKeyframe = _dylib.lookupFunction<CAureaLayerRemoveKeyframe, DAureaLayerRemoveKeyframe>('aurea_layer_remove_keyframe');
    timelinePlay = _dylib.lookupFunction<CAureaTimelinePlay, DAureaTimelinePlay>('aurea_timeline_play');
    timelinePause = _dylib.lookupFunction<CAureaTimelinePause, DAureaTimelinePause>('aurea_timeline_pause');
    timelineSeek = _dylib.lookupFunction<CAureaTimelineSeek, DAureaTimelineSeek>('aurea_timeline_seek');
    timelineGetTime = _dylib.lookupFunction<CAureaTimelineGetTime, DAureaTimelineGetTime>('aurea_timeline_get_time');
    previewRender = _dylib.lookupFunction<CAureaPreviewRender, DAureaPreviewRender>('aurea_preview_render');
    previewTick = _dylib.lookupFunction<CAureaPreviewTick, DAureaPreviewTick>('aurea_preview_tick');
    previewGetTexture = _dylib.lookupFunction<CAureaPreviewGetTexture, DAureaPreviewGetTexture>('aurea_preview_get_texture');
    exportRenderFrame = _dylib.lookupFunction<CAureaExportRenderFrame, DAureaExportRenderFrame>('aurea_export_render_frame');
    exportStart = _dylib.lookupFunction<CAureaExportStart, DAureaExportStart>('aurea_export_start');
    exportGetProgress = _dylib.lookupFunction<CAureaExportGetProgress, DAureaExportGetProgress>('aurea_export_get_progress');
    exportCancel = _dylib.lookupFunction<CAureaExportCancel, DAureaExportCancel>('aurea_export_cancel');

    modelAnalyze = _dylib.lookupFunction<CAureaModelAnalyze, DAureaModelAnalyze>('aurea_model_analyze');
    modelImportAsync = _dylib.lookupFunction<CAureaModelImportAsync, DAureaModelImportAsync>('aurea_model_import_async');
    modelImportGetProgress = _dylib.lookupFunction<CAureaModelImportGetProgress, DAureaModelImportGetProgress>('aurea_model_import_get_progress');
    modelImportCancel = _dylib.lookupFunction<CAureaModelImportCancel, DAureaModelImportCancel>('aurea_model_import_cancel');
    scene3dSetFrameBudget = _dylib.lookupFunction<CAureaScene3DSetFrameBudget, DAureaScene3DSetFrameBudget>('aurea_scene3d_set_frame_budget');
    scene3dGetMetrics = _dylib.lookupFunction<CAureaScene3DGetMetrics, DAureaScene3DGetMetrics>('aurea_scene3d_get_metrics');

    timeRemapEnable = _dylib.lookupFunction<CAureaLayerTimeRemapEnable, DAureaLayerTimeRemapEnable>('aurea_layer_time_remap_enable');
    timeRemapResetDefault = _dylib.lookupFunction<CAureaLayerTimeRemapResetDefault, DAureaLayerTimeRemapResetDefault>('aurea_layer_time_remap_reset_default');
    timeRemapAddKeyframe = _dylib.lookupFunction<CAureaLayerTimeRemapAddKeyframe, DAureaLayerTimeRemapAddKeyframe>('aurea_layer_time_remap_add_keyframe');
    timeRemapRemoveKeyframe = _dylib.lookupFunction<CAureaLayerTimeRemapRemoveKeyframe, DAureaLayerTimeRemapRemoveKeyframe>('aurea_layer_time_remap_remove_keyframe');
    timeRemapRemoveKeyframeAt = _dylib.lookupFunction<CAureaLayerTimeRemapRemoveKeyframeAt, DAureaLayerTimeRemapRemoveKeyframeAt>('aurea_layer_time_remap_remove_keyframe_at');
    timeRemapClear = _dylib.lookupFunction<CAureaLayerTimeRemapClear, DAureaLayerTimeRemapClear>('aurea_layer_time_remap_clear');
    timeRemapGetKeyframeCount = _dylib.lookupFunction<CAureaLayerTimeRemapGetKeyframeCount, DAureaLayerTimeRemapGetKeyframeCount>('aurea_layer_time_remap_get_keyframe_count');
    timeRemapGetKeyframe = _dylib.lookupFunction<CAureaLayerTimeRemapGetKeyframe, DAureaLayerTimeRemapGetKeyframe>('aurea_layer_time_remap_get_keyframe');
    timeRemapEvaluate = _dylib.lookupFunction<CAureaLayerTimeRemapEvaluate, DAureaLayerTimeRemapEvaluate>('aurea_layer_time_remap_evaluate');
    timeRemapGetSpeed = _dylib.lookupFunction<CAureaLayerTimeRemapGetSpeed, DAureaLayerTimeRemapGetSpeed>('aurea_layer_time_remap_get_speed');
  }

  final DynamicLibrary _dylib;

  late final DAureaGetVersion version;
  late final DAureaEngineCreate createEngine;
  late final DAureaEngineDestroy destroyEngine;
  late final DAureaProjectSetDuration projectSetDuration;
  late final DAureaProjectAddLayer projectAddLayer;
  late final DAureaProjectRemoveLayer projectRemoveLayer;
  late final DAureaLayerSetTransform layerSetTransform;
  late final DAureaLayerSetShape layerSetShape;
  late final DAureaLayerAddKeyframe layerAddKeyframe;
  late final DAureaLayerRemoveKeyframe layerRemoveKeyframe;
  late final DAureaTimelinePlay timelinePlay;
  late final DAureaTimelinePause timelinePause;
  late final DAureaTimelineSeek timelineSeek;
  late final DAureaTimelineGetTime timelineGetTime;
  late final DAureaPreviewRender previewRender;
  late final DAureaPreviewTick previewTick;
  late final DAureaPreviewGetTexture previewGetTexture;
  late final DAureaExportRenderFrame exportRenderFrame;
  late final DAureaExportStart exportStart;
  late final DAureaExportGetProgress exportGetProgress;
  late final DAureaExportCancel exportCancel;

  late final DAureaModelAnalyze modelAnalyze;
  late final DAureaModelImportAsync modelImportAsync;
  late final DAureaModelImportGetProgress modelImportGetProgress;
  late final DAureaModelImportCancel modelImportCancel;
  late final DAureaScene3DSetFrameBudget scene3dSetFrameBudget;
  late final DAureaScene3DGetMetrics scene3dGetMetrics;

  late final DAureaLayerTimeRemapEnable timeRemapEnable;
  late final DAureaLayerTimeRemapResetDefault timeRemapResetDefault;
  late final DAureaLayerTimeRemapAddKeyframe timeRemapAddKeyframe;
  late final DAureaLayerTimeRemapRemoveKeyframe timeRemapRemoveKeyframe;
  late final DAureaLayerTimeRemapRemoveKeyframeAt timeRemapRemoveKeyframeAt;
  late final DAureaLayerTimeRemapClear timeRemapClear;
  late final DAureaLayerTimeRemapGetKeyframeCount timeRemapGetKeyframeCount;
  late final DAureaLayerTimeRemapGetKeyframe timeRemapGetKeyframe;
  late final DAureaLayerTimeRemapEvaluate timeRemapEvaluate;
  late final DAureaLayerTimeRemapGetSpeed timeRemapGetSpeed;

  static AureaNativeBindings? _instance;
  static bool _initAttempted = false;

  static AureaNativeBindings? get instance {
    if (!_initAttempted) {
      _initAttempted = true;
      try {
        DynamicLibrary lib;
        if (Platform.isAndroid) {
          lib = DynamicLibrary.open('libaurea_native.so');
        } else if (Platform.isIOS || Platform.isMacOS) {
          lib = DynamicLibrary.process();
        } else if (Platform.isWindows) {
          lib = DynamicLibrary.open('aurea_native.dll');
        } else if (Platform.isLinux) {
          lib = DynamicLibrary.open('libaurea_native.so');
        } else {
          return null;
        }
        _instance = AureaNativeBindings._(lib);
      } catch (_) {
        // Fallback gracioso se biblioteca compartilhada não estiver no path de execução de testes
        _instance = null;
      }
    }
    return _instance;
  }

  static bool get isAvailable => instance != null;
}
