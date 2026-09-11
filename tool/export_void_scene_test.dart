// Explicit native artifact render; not part of the routine unit-test suite.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as f;
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart'
    as native;
import 'package:aurea/src/features/editor/application/model_import_service.dart';
import 'package:aurea/src/features/editor/application/renderer3d/adaptive_quality.dart';
import 'package:aurea/src/features/editor/application/renderer3d/filament_renderer.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/template_pack.dart';
import 'package:aurea/src/features/projects/domain/void_astronaut_template.dart';

Future<void> png(Uint8List pixels, String path) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: 720,
    height: 1280,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  frame.image.dispose();
  codec.dispose();
  descriptor.dispose();
  buffer.dispose();
}

void main() {
  test(
    'VOID: four editable animated cameras and native video render',
    () async {
      const folder = 'output/void';
      final model = await readModel3DFiles(['$folder/ASTRONAUTA.glb']);
      final project = buildVoidAstronautTemplate(model);
      final encoded = jsonEncode(
        TemplatePack(
          name: project.name,
          project: project,
          author: 'Aurea',
          notes: '10 segundos. Quatro tomadas de 2,5 s, astronauta em queda e rotação, câmeras e estrelas 3D.',
        ).toJson(),
      );
      final reopened = TemplatePack.decode(encoded)!.project;
      final layer = reopened.layers.whereType<Scene3DLayer>().single;
      expect(reopened.duration, const Duration(seconds: 10));
      expect(layer.allCameras.length, 4);
      expect(layer.shots.map((s) => s.time.inMilliseconds), [
        0,
        2500,
        5000,
        7500,
      ]);
      expect(
        layer.scene.nodes.first.y.valueAt(Duration.zero),
        isNot(layer.scene.nodes.first.y.valueAt(const Duration(seconds: 9))),
      );
      expect(FilamentRenderer.supports(layer.scene), true);
      expect(model.triangleCount, lessThan(100000));
      File('$folder/VOID.aurea').writeAsStringSync(encoded);
      await native.FFIFilamentApp.create(
        config: native.FFIFilamentConfig(
          backend: f.Backend.VULKAN,
          loadResource: (path) =>
              File(path.replaceFirst('file://', '')).readAsBytes(),
        ),
      );
      final app = f.FilamentApp.instance! as native.FFIFilamentApp;
      late f.SwapChain swap;
      final renderer = FilamentRenderer(
        AdaptiveQuality(),
        viewerFactory: () async {
          swap = await app.createHeadlessSwapChain(720, 1280);
          final viewer = f.ThermionViewerFFI(app: app);
          await viewer.initialized;
          await app.renderManager.attach(viewer.view, swap);
          await viewer.view.setViewport(720, 1280);
          return viewer;
        },
      );
      final full = Platform.environment['AUREA_VOID_VIDEO'] == '1';
      Process? encoder;
      Future<String>? stderr;
      try {
        await renderer.initialize();
        if (full) {
          encoder = await Process.start(
            r'C:\Users\SnyX\Downloads\Motion 2.0\tools\ffmpeg\bin\ffmpeg.exe',
            [
              '-hide_banner',
              '-loglevel',
              'error',
              '-y',
              '-f',
              'rawvideo',
              '-pixel_format',
              'rgba',
              '-video_size',
              '720x1280',
              '-framerate',
              '30',
              '-i',
              'pipe:0',
              '-an',
              '-vf',
              'scale=in_range=full:out_range=tv:out_color_matrix=bt709',
              '-c:v',
              'libx264',
              '-preset',
              'medium',
              '-crf',
              '18',
              '-pix_fmt',
              'yuv420p',
              '-color_primaries',
              'bt709',
              '-color_trc',
              'bt709',
              '-colorspace',
              'bt709',
              '-movflags',
              '+faststart',
              '$folder/VOID.mp4',
            ],
          );
          stderr = encoder.stderr.transform(utf8.decoder).join();
          encoder.stdout.drain<void>();
        }
        final samples = full
            ? [for (var i = 0; i < 300; i++) i]
            : [0, 37, 74, 75, 112, 149, 150, 187, 224, 225, 262, 299];
        var nonEmpty = 0;
        for (final frame in samples) {
          final t = Duration(microseconds: (frame * 1000000 / 30).round());
          await renderer.synchronize(
            layer.scene,
            layer.cameraAt(t),
            t,
            const ui.Size(720, 1280),
          );
          await app.flush();
          if (frame == 0) {
            await Future<void>.delayed(const Duration(seconds: 2));
          }
          final capture = await app.capture(
            swap,
            view: renderer.viewer.view,
            pixelDataType: f.PixelDataType.UBYTE,
          );
          final pixels = capture.single.$2;
          expect(pixels.length, 720 * 1280 * 4);
          if (pixels.toSet().length > 30) nonEmpty++;
          if (encoder != null) {
            encoder.stdin.add(pixels);
            await encoder.stdin.flush();
          }
          if (!full || [37, 112, 187, 262, 299].contains(frame)) {
            await png(
              pixels,
              '$folder/frame-${frame.toString().padLeft(3, '0')}.png',
            );
          }
          if (frame % 75 == 0) {
            // ignore: avoid_print
            print('VOID ${frame + 1}/300: ${voidShotNames[frame ~/ 75]}');
          }
        }
        expect(nonEmpty, samples.length);
        if (encoder != null) {
          await encoder.stdin.close();
          expect(await encoder.exitCode, 0, reason: await stderr);
        }
        File('$folder/verification.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'duration': 10,
            'fps': 30,
            'resolution': [720, 1280],
            'cutsSeconds': [0, 2.5, 5, 7.5],
            'astronautTriangles': model.triangleCount,
            'nativeRenderedFrames': samples.length,
            'portableRoundtrip': true,
            'renderer': 'Aurea Filament / Vulkan desktop',
            'animatedObject': true,
            'animatedCameras': 4,
            'importWarnings': model.warnings,
          }),
        );
      } finally {
        if (encoder != null && encoder.pid > 0) encoder.kill();
        await renderer.dispose();
        await app.destroySwapChain(swap);
        await app.destroy();
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
