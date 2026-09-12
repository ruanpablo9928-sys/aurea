import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aurea_meshopt/aurea_meshopt.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/application/scene3d_gpu.dart';
import 'package:aurea/src/features/editor/application/qualidade3d_controller.dart';
import 'package:aurea/src/features/editor/application/optical_flow_preview.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/panorama3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/domain/orcamento_render.dart';
import 'package:aurea/src/features/editor/presentation/estudio/estudio_da_cena.dart';
import 'package:aurea/src/features/enhance/application/enhancement_job.dart';
import 'package:aurea/src/features/enhance/domain/color_look.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MaterialApp(home: _QA())));
}

class _QA extends ConsumerStatefulWidget {
  const _QA();
  @override
  ConsumerState<_QA> createState() => _QAState();
}

class _QAState extends ConsumerState<_QA> with SingleTickerProviderStateMixin {
  late final PlaybackController clock = PlaybackController(
    vsync: this,
    durationOf: () => const Duration(seconds: 5),
  );
  String state = 'Verificando motor nativo';
  bool done = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  Future<void> run() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/beta77-qa');
    await dir.create(recursive: true);
    final results = <String, Object>{};
    try {
      final indices = Uint32List.fromList([0, 1, 2, 2, 1, 3]);
      final out = optimizeVertexCache(indices, 4);
      if (out.length != 6) throw StateError('Native mesh optimizer');
      results['meshoptimizer'] = 'native C++ loaded and executed';
      await Scene3DGpu.preparar();
      if (!Scene3DGpu.pronto)
        throw StateError('GPU unavailable: ${Scene3DGpu.motivo}');
      await ControladorDeQualidade3D.instancia.sondar();
      final layer = Scene3DLayer(
        id: 'qa',
        name: 'Teste de reflexos',
        startTime: Duration.zero,
        duration: const Duration(seconds: 5),
        scene: Scene3D.demo.copyWith(showFloorGrid: false, envReflect: 1),
      );
      final gpu = Scene3DGpu();
      Future<void> capture(String name, Scene3D scene) async {
        for (var i = 0; i < 6; i++) {
          gpu.sincronizar(
            scene,
            Duration.zero,
            receita: ReceitaDeQualidade.alta,
          );
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawColor(const Color(0xFF10141B), BlendMode.src);
          const size = ui.Size(512, 512);
          gpu.desenhar(
            canvas,
            Offset.zero & size,
            gpu.camera(layer.cameraAt(Duration.zero), size),
            exporting: true,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(512, 512);
          picture.dispose();
          if (i == 5) {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('${dir.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          }
          image.dispose();
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }

      await capture('environment', layer.scene);
      final reflected = layer.scene.copyWith(
        reflectionProbe: const ReflectionProbe3D(
          enabled: true,
          updateMode: ProbeUpdateMode.stopped,
          position: ProbePoint3D(0, 120, 160),
        ),
      );
      await capture('reflection-probe', reflected);
      gpu.descartar();
      results['gpu'] = 'PBR scene and local reflection probe rendered';
      results['optimizedGpuMeshes'] = Scene3DGpu.optimizedGeometryCount;
      if (Scene3DGpu.optimizedGeometryCount < 1)
        throw StateError('Optimized mesh did not reach GPU');
      final source = '${dir.path}/motion-source.mp4';
      final generated = await FFmpegKit.executeWithArguments([
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc2=size=160x90:rate=15:duration=2',
        '-c:v',
        'mpeg4',
        source,
      ]);
      if (!ReturnCode.isSuccess(await generated.getReturnCode()))
        throw StateError('Synthetic video failed');
      final video = VideoLayer(
        name: 'motion',
        sourcePath: source,
        startTime: Duration.zero,
        duration: const Duration(seconds: 4),
        speed: .5,
        effects: [EffectInstance(type: EffectType.opticalFlow)],
      );
      await OpticalFlowPreview.instance.ensure(video, retry: true);
      final proxy = OpticalFlowPreview.instance.ready(video);
      if (proxy == null) throw StateError('Optical flow proxy failed');
      await File(proxy).copy('${dir.path}/optical-flow.mp4');
      results['opticalFlow'] =
          'FFmpeg motion compensation produced playable proxy';
      // Optional test bootstrap for an already-installed diagnostic APK.
      // Production loads this same library via the tflite_flutter dependency.
      final lib = File('${docs.path}/libtensorflowlite_jni.so');
      if (Platform.isAndroid && await lib.exists())
        DynamicLibrary.open(lib.path);
      final enhance = EnhancementJob(
        loadModel: () async {
          final bytes = await File('${docs.path}/compressed_esrgan.tflite')
              .readAsBytes();
          return ByteData.sublistView(bytes);
        },
      );
      try {
        final image = await enhance.process(
          '${dir.path}/environment.png',
          false,
          const EnhanceSettings(scale: 2, look: ColorLook.cinema),
        );
        await image.copy('${dir.path}/ai-enhanced.png');
        final videoResult = await enhance.process(
          source,
          true,
          const EnhanceSettings(scale: 2, look: ColorLook.warm),
        );
        await videoResult.copy('${dir.path}/ai-enhanced.mp4');
        results['enhancement'] = 'ESRGAN isolate inference, tiled image, video encoding and CC applied';
      } finally {
        await enhance.close();
      }
      ref
          .read(editorControllerProvider.notifier)
          .openProject(
            VideoProject(
              name: 'QA',
              createdAt: DateTime.now(),
              layers: [layer.copyScene(scene: reflected)],
            ),
          );
      results['ok'] = true;
      if (mounted) setState(() => done = true);
    } catch (error, stack) {
      results['ok'] = false;
      results['error'] = '$error';
      results['stack'] = '$stack';
      if (mounted) setState(() => state = '$error');
    }
    await File('${dir.path}/result.json').writeAsString(jsonEncode(results));
    debugPrint('BETA77_QA ${jsonEncode(results)}');
  }

  @override
  Widget build(BuildContext context) => done
      ? EstudioDaCena(layerId: 'qa', playback: clock)
      : Scaffold(body: Center(child: Text(state)));
}
