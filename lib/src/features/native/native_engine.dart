import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import '../editor/domain/keyframe.dart';
import '../editor/domain/layer.dart';
import '../editor/domain/video_project.dart';
import 'aurea_native_bindings.dart';

/// Controlador de alto nível do motor nativo C++ Aurea Core.
class NativeEngine {
  NativeEngine._();
  static final NativeEngine instance = NativeEngine._();

  Pointer<Void>? _handle;
  int _width = 1920;
  int _height = 1080;
  int _fps = 30;

  int get width => _width;
  int get height => _height;
  int get fps => _fps;

  bool get isSupported => AureaNativeBindings.isAvailable;
  bool get isInitialized => _handle != null;

  /// Inicializa o motor nativo C++ com as dimensões e taxa de quadros desejadas
  bool initialize({int width = 1920, int height = 1080, int fps = 30}) {
    if (!isSupported) return false;
    dispose();

    _width = width;
    _height = height;
    _fps = fps;

    final bindings = AureaNativeBindings.instance!;
    _handle = bindings.createEngine(width, height, fps);
    return _handle != null;
  }

  /// Libera recursos alocados pelo motor C++
  void dispose() {
    if (_handle != null && isSupported) {
      AureaNativeBindings.instance!.destroyEngine(_handle!);
      _handle = null;
    }
  }

  /// Sincroniza o projeto Dart (camadas, propriedades e keyframes) com o motor C++
  void syncProject(VideoProject project) {
    if (!isInitialized) return;
    final b = AureaNativeBindings.instance!;

    // Define a duração total
    b.projectSetDuration(_handle!, project.duration.inMicroseconds);

    // Itera camadas do projeto
    for (final layer in project.layers) {
      final layerIdPtr = layer.id.toNativeUtf8();
      final namePtr = layer.name.toNativeUtf8();

      // Tipo de camada: 0=Shape, 1=Video, 2=Image, 3=Text, 4=Scene3D
      int layerType = 0;
      if (layer is VideoLayer) {
        layerType = 1;
      } else if (layer is ImageLayer) {
        layerType = 2;
      } else if (layer is TextLayer) {
        layerType = 3;
      } else if (layer is ShapeLayer) {
        layerType = 0;
      }

      b.projectAddLayer(_handle!, layerIdPtr, namePtr, layerType);

      // Define Transform base
      b.layerSetTransform(
        _handle!,
        layerIdPtr,
        layer.position.base.dx,
        layer.position.base.dy,
        layer.scaleX.base,
        layer.scaleY.base,
        layer.rotation.base,
        layer.opacity.base,
      );

      // Se for ShapeLayer, define propriedades
      if (layer is ShapeLayer) {
        b.layerSetShape(
          _handle!,
          layerIdPtr,
          0, // Retângulo padrão
          0xFFFFFFFF,
          0x00000000,
          0.0,
          0.0,
          200.0,
          200.0,
        );
      }

      // Sincroniza Keyframes de cada canal
      void syncTrack(String propName, List<Keyframe<double>> keyframes) {
        if (keyframes.isEmpty) return;
        final propPtr = propName.toNativeUtf8();
        for (final kf in keyframes) {
          b.layerAddKeyframe(
            _handle!,
            layerIdPtr,
            propPtr,
            kf.time.inMicroseconds,
            kf.value,
            kf.ease.type.index,
            kf.ease.x1,
            kf.ease.y1,
            kf.ease.x2,
            kf.ease.y2,
          );
        }
        calloc.free(propPtr);
      }

      syncTrack('scaleX', layer.scaleX.keyframes);
      syncTrack('scaleY', layer.scaleY.keyframes);
      syncTrack('rotation', layer.rotation.keyframes);
      syncTrack('opacity', layer.opacity.keyframes);

      // Posição Offset
      if (layer.position.keyframes.isNotEmpty) {
        final propX = 'posX'.toNativeUtf8();
        final propY = 'posY'.toNativeUtf8();
        for (final kf in layer.position.keyframes) {
          b.layerAddKeyframe(
            _handle!,
            layerIdPtr,
            propX,
            kf.time.inMicroseconds,
            kf.value.dx,
            kf.ease.type.index,
            kf.ease.x1,
            kf.ease.y1,
            kf.ease.x2,
            kf.ease.y2,
          );
          b.layerAddKeyframe(
            _handle!,
            layerIdPtr,
            propY,
            kf.time.inMicroseconds,
            kf.value.dy,
            kf.ease.type.index,
            kf.ease.x1,
            kf.ease.y1,
            kf.ease.x2,
            kf.ease.y2,
          );
        }
        calloc.free(propX);
        calloc.free(propY);
      }

      calloc.free(layerIdPtr);
      calloc.free(namePtr);
    }
  }

  /// Renderiza diretamente um quadro para um buffer RGBA contíguo de alta performance
  Uint8List? renderFrameDirect({
    required int frameIndex,
    required int width,
    required int height,
    required int fps,
  }) {
    if (!isInitialized) return null;
    final b = AureaNativeBindings.instance!;

    final totalBytes = width * height * 4;
    final bufferPtr = calloc<Uint8>(totalBytes);

    try {
      final res = b.exportRenderFrame(
        _handle!,
        frameIndex,
        width,
        height,
        fps,
        bufferPtr,
      );

      if (res == 1) {
        final bytes = Uint8List.fromList(bufferPtr.asTypedList(totalBytes));
        return bytes;
      }
      return null;
    } finally {
      calloc.free(bufferPtr);
    }
  }

  /// Controles de Playback na Timeline C++
  void play() {
    if (isInitialized) AureaNativeBindings.instance!.timelinePlay(_handle!);
  }

  void pause() {
    if (isInitialized) AureaNativeBindings.instance!.timelinePause(_handle!);
  }

  void seek(Duration position) {
    if (isInitialized) {
      AureaNativeBindings.instance!.timelineSeek(_handle!, position.inMicroseconds);
    }
  }

  Duration getCurrentTime() {
    if (isInitialized) {
      final us = AureaNativeBindings.instance!.timelineGetTime(_handle!);
      return Duration(microseconds: us);
    }
    return Duration.zero;
  }

  // -------------------------------------------------------------
  // Pipeline 3D de Alta Performance (Assíncrono & Thread-Safe)
  // -------------------------------------------------------------

  /// Analisa previamente o arquivo 3D em O(1) sem alocar geometria pesada
  ModelAnalysisResult? analyzeModel(String filePath) {
    if (!isSupported) return null;
    final b = AureaNativeBindings.instance!;
    final pathPtr = filePath.toNativeUtf8();
    final analysisPtr = calloc<NativeModelAnalysis>();

    try {
      final res = b.modelAnalyze(pathPtr, analysisPtr);
      if (res == 1) {
        return ModelAnalysisResult(
          fileSizeBytes: analysisPtr.ref.fileSizeBytes,
          meshCount: analysisPtr.ref.meshCount,
          vertexCount: analysisPtr.ref.vertexCount,
          triangleCount: analysisPtr.ref.triangleCount,
          materialCount: analysisPtr.ref.materialCount,
          textureCount: analysisPtr.ref.textureCount,
          largestTextureWidth: analysisPtr.ref.largestTextureWidth,
          largestTextureHeight: analysisPtr.ref.largestTextureHeight,
          boneCount: analysisPtr.ref.boneCount,
          animationCount: analysisPtr.ref.animationCount,
          nodeCount: analysisPtr.ref.nodeCount,
          estimatedCpuMemoryMb: analysisPtr.ref.estimatedCpuMemoryMb,
          estimatedGpuMemoryMb: analysisPtr.ref.estimatedGpuMemoryMb,
          isSafeForDevice: analysisPtr.ref.isSafeForDevice == 1,
          recommendedLOD: analysisPtr.ref.recommendedLOD,
        );
      }
      return null;
    } finally {
      calloc.free(pathPtr);
      calloc.free(analysisPtr);
    }
  }

  /// Inicia importação assíncrona desacoplada do UI thread / render thread
  int startModelImportAsync(String filePath, {String? targetNodeId}) {
    if (!isInitialized) return -1;
    final b = AureaNativeBindings.instance!;
    final pathPtr = filePath.toNativeUtf8();
    final nodePtr = (targetNodeId ?? 'imported_model').toNativeUtf8();

    try {
      return b.modelImportAsync(_handle!, pathPtr, nodePtr);
    } finally {
      calloc.free(pathPtr);
      calloc.free(nodePtr);
    }
  }

  /// Consulta o progresso atual do job de importação
  ImportProgressStatus getModelImportProgress(int jobId) {
    if (!isSupported) {
      return const ImportProgressStatus(isDone: true, progress: 1.0, stage: 6, stageName: 'Indisponivel');
    }
    final b = AureaNativeBindings.instance!;
    final progressPtr = calloc<Float>();
    final stagePtr = calloc<Int32>();
    final stageNamePtr = calloc<Uint8>(256);

    try {
      final isDone = b.modelImportGetProgress(
        jobId,
        progressPtr,
        stagePtr,
        stageNamePtr.cast<Utf8>(),
        256,
      );
      final stageName = stageNamePtr.cast<Utf8>().toDartString();
      return ImportProgressStatus(
        isDone: isDone == 1,
        progress: progressPtr.value,
        stage: stagePtr.value,
        stageName: stageName,
      );
    } finally {
      calloc.free(progressPtr);
      calloc.free(stagePtr);
      calloc.free(stageNamePtr);
    }
  }

  /// Cancela uma importação em andamento, liberando memória imediatamente
  void cancelModelImport(int jobId) {
    if (isSupported) {
      AureaNativeBindings.instance!.modelImportCancel(jobId);
    }
  }

  /// Define o orçamento de tempo para uploads GPU por frame (padrão: 2.5ms)
  void setScene3DFrameBudget(double budgetMs) {
    if (isInitialized) {
      AureaNativeBindings.instance!.scene3dSetFrameBudget(_handle!, budgetMs);
    }
  }

  /// Consulta as métricas reais de renderização 3D da GPU
  Scene3DMetricsResult getScene3DMetrics() {
    if (!isInitialized) return const Scene3DMetricsResult();
    final b = AureaNativeBindings.instance!;
    final metricsPtr = calloc<NativeSceneMetrics>();

    try {
      b.scene3dGetMetrics(_handle!, metricsPtr);
      return Scene3DMetricsResult(
        drawCalls: metricsPtr.ref.drawCalls,
        renderedTriangles: metricsPtr.ref.renderedTriangles,
        renderedVertices: metricsPtr.ref.renderedVertices,
        culledNodes: metricsPtr.ref.culledNodes,
        gpuFrameTimeMs: metricsPtr.ref.gpuFrameTimeMs,
      );
    } finally {
      calloc.free(metricsPtr);
    }
  }
}

/// Resultado da pré-análise do modelo 3D
class ModelAnalysisResult {
  const ModelAnalysisResult({
    required this.fileSizeBytes,
    required this.meshCount,
    required this.vertexCount,
    required this.triangleCount,
    required this.materialCount,
    required this.textureCount,
    required this.largestTextureWidth,
    required this.largestTextureHeight,
    required this.boneCount,
    required this.animationCount,
    required this.nodeCount,
    required this.estimatedCpuMemoryMb,
    required this.estimatedGpuMemoryMb,
    required this.isSafeForDevice,
    required this.recommendedLOD,
  });

  final int fileSizeBytes;
  final int meshCount;
  final int vertexCount;
  final int triangleCount;
  final int materialCount;
  final int textureCount;
  final int largestTextureWidth;
  final int largestTextureHeight;
  final int boneCount;
  final int animationCount;
  final int nodeCount;
  final double estimatedCpuMemoryMb;
  final double estimatedGpuMemoryMb;
  final bool isSafeForDevice;
  final int recommendedLOD;
}

/// Status de progresso da importação assíncrona
class ImportProgressStatus {
  const ImportProgressStatus({
    required this.isDone,
    required this.progress,
    required this.stage,
    required this.stageName,
  });

  final bool isDone;
  final double progress;
  final int stage;
  final String stageName;
}

/// Métricas de GPU da cena 3D
class Scene3DMetricsResult {
  const Scene3DMetricsResult({
    this.drawCalls = 0,
    this.renderedTriangles = 0,
    this.renderedVertices = 0,
    this.culledNodes = 0,
    this.gpuFrameTimeMs = 0.0,
  });

  final int drawCalls;
  final int renderedTriangles;
  final int renderedVertices;
  final int culledNodes;
  final double gpuFrameTimeMs;
}
