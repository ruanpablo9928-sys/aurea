// Artifact builder, run explicitly with flutter test tool/export_flor_scene_test.dart.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as f;
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart'
    as native;
import 'package:aurea/src/features/editor/application/model_import_service.dart';
import 'package:aurea/src/features/editor/application/renderer3d/adaptive_quality.dart';
import 'package:aurea/src/features/editor/application/renderer3d/filament_renderer.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/template_pack.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';

void main() {
  test('export portable flower and render with the actual Aurea backend', () async {
    const folder = 'output/flor';
    final settings = jsonDecode(
      File('$folder/scene-settings.json').readAsStringSync(),
    ) as Map;
    final flower = await readModel3DFiles(['$folder/FLOR.glb']);
    expect(flower.triangleCount, lessThan(50000));
    // Aurea preserves base-color PBR but currently drops glTF transmission/IOR.
    expect(
      flower.warnings.every(
        (w) =>
            w.contains('KHR_materials_transmission') ||
            w.contains('KHR_materials_ior') ||
            w.contains('KHR_materials_specular') ||
            w.startsWith('Mapas normal/'),
      ),
      isTrue,
      reason: flower.warnings.join('\n'),
    );
    final materials = flower.data['materials'] as List;
    expect(
      materials.where((m) => m['image'] != null).length,
      greaterThanOrEqualTo(2),
    );
    const size = 200.0;
    Vec3 point(String name) {
      final p = settings[name] as List;
      return Vec3(
        (p[0] as num).toDouble() * size,
        (p[1] as num).toDouble() * size,
        (p[2] as num).toDouble() * size,
      );
    }

    final eye = point('camera'), target = point('target');
    final normal = (eye - target).normalized;
    final backdrop = target - normal * 600;
    final gardenTexture =
        'data:image/png;base64,${base64Encode(File('$folder/jardim.png').readAsBytesSync())}';
    final camera = Camera3D(
      id: 'flor_camera',
      name: 'Macro • flor ao amanhecer',
      posX: AnimatedDouble(eye.x),
      posY: AnimatedDouble(eye.y),
      posZ: AnimatedDouble(eye.z),
      poiX: AnimatedDouble(target.x),
      poiY: AnimatedDouble(target.y),
      poiZ: AnimatedDouble(target.z),
      focalLength: AnimatedDouble(
        (settings['focalLength'] as num).toDouble() / .8,
      ),
    );
    final scene = Scene3D(
      nodes: [
        SceneNode(
          id: 'flor_cosmos',
          name: 'Cosmos rosa • pétalas, folhas e orvalho',
          modelAsset: flower,
          size: size,
        ),
        SceneNode(
          id: 'flor_fundo',
          name: 'Jardim desfocado • fundo',
          kind: Element3DKind.plane,
          size: 1300,
          x: AnimatedDouble(backdrop.x),
          y: AnimatedDouble(backdrop.y),
          z: AnimatedDouble(backdrop.z),
          rotX: AnimatedDouble(-math.asin(normal.y) * 180 / math.pi),
          rotY: AnimatedDouble(math.atan2(normal.x, normal.z) * 180 / math.pi),
          material: Material3D(
            kind: MaterialKind.unlit,
            imagePath: gardenTexture,
            baseColor: const ui.Color(0xffffffff),
          ),
        ),
      ],
      background: const ui.Color(0xff162315),
      showFloorGrid: false,
      ambient: .38,
      lights: [
        Light3D(
          id: 'flor_sol',
          color: const ui.Color(0xffffe5c9),
          direction: const Vec3(3, -4.68, -4),
          intensity: AnimatedDouble(1.4),
          castsShadow: true,
          softness: .8,
        ),
        // Filament supports one directional sun. Point fills use lumens scaled
        // for this scene's centimeter-like coordinates (not extra suns).
        Light3D(
          id: 'flor_ceu',
          kind: Light3DKind.point,
          position: const Vec3(450, 500, 500),
          range: 4000,
          color: const ui.Color(0xffcfdefa),
          intensity: AnimatedDouble(1100000),
        ),
        Light3D(
          id: 'flor_contorno',
          kind: Light3DKind.point,
          position: const Vec3(-200, 300, -500),
          range: 4000,
          color: const ui.Color(0xffffedcc),
          intensity: AnimatedDouble(750000),
        ),
      ],
    );
    expect(FilamentRenderer.supports(scene), isTrue);
    final project = VideoProject(
      id: 'flor_cosmos_amanhecer',
      name: 'FLOR • Cosmos ao amanhecer',
      createdAt: DateTime(2026, 9, 6),
      aspectRatio: .8,
      resolutionHeight: 1200,
      fps: 30,
      layers: [
        Scene3DLayer(
          id: 'flor_cena',
          name: 'Flor 3D • câmera e luzes',
          startTime: Duration.zero,
          duration: const Duration(seconds: 10),
          position: AnimatedOffset(const ui.Offset(480, 600)),
          showHelpers: false,
          scene: scene,
          camera: camera,
        ),
      ],
    );
    final encoded = jsonEncode(
      TemplatePack(
        name: project.name,
        author: 'Aurea',
        project: project,
        notes:
            'Flor original em 3D com texturas incorporadas. Câmera, transformação e luzes editáveis. '
            'O render de referência Cycles usa translucidez e profundidade de campo adicionais.',
      ).toJson(),
    );
    final reopened = TemplatePack.decode(encoded)!.project;
    final layer = reopened.layers.whereType<Scene3DLayer>().single;
    expect(
      layer.scene.nodes.first.modelAsset!.triangleCount,
      flower.triangleCount,
    );
    expect(layer.camera.renderAt(Duration.zero).position.x, eye.x);
    File('$folder/FLOR.aurea').writeAsStringSync(encoded);

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
        swap = await app.createHeadlessSwapChain(960, 1200);
        final viewer = f.ThermionViewerFFI(app: app);
        await viewer.initialized;
        await app.renderManager.attach(viewer.view, swap);
        await viewer.view.setViewport(960, 1200);
        return viewer;
      },
    );
    try {
      await renderer.initialize();
      for (var i = 0; i < 12; i++) {
        await renderer.synchronize(
          layer.scene,
          layer.camera.renderAt(Duration.zero),
          Duration.zero,
          const ui.Size(960, 1200),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      // Let shader compilation / GPU work finish before the screenshot frame.
      await Future<void>.delayed(const Duration(seconds: 2));
      final capture = await app.capture(
        swap,
        view: renderer.viewer.view,
        pixelDataType: f.PixelDataType.UBYTE,
      );
      final pixels = capture.single.$2;
      expect(pixels.length, 960 * 1200 * 4);
      expect(pixels.toSet().length, greaterThan(100));
      final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: 960,
        height: 1200,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      File('$folder/FLOR-preview-aurea.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      frame.image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      File('$folder/verification.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'triangles': flower.triangleCount,
          'materials': materials.length,
          'portableRoundtrip': true,
          'embeddedTextures': materials.where((m) => m['image'] != null).length,
          'glbBytes': File('$folder/FLOR.glb').lengthSync(),
          'aureaBytes': File('$folder/FLOR.aurea').lengthSync(),
          'renderer': 'Aurea Filament / Vulkan desktop',
          'lastGpuMilliseconds': renderer.lastGpuMilliseconds,
          'mobileDeviceMeasured': false,
          'importWarnings': flower.warnings,
          'reference':
              'Cycles image is a separate reference, not an app screenshot',
        }),
      );
    } finally {
      await renderer.dispose();
      await app.destroySwapChain(swap);
      await app.destroy();
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
