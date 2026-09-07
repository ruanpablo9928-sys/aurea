import 'dart:math' as math;
import 'dart:ui';

import '../../editor/domain/camera3d.dart';
import '../../editor/domain/camera_cuts.dart';
import '../../editor/domain/element3d.dart';
import '../../editor/domain/keyframe.dart';
import '../../editor/domain/layer.dart';
import '../../editor/domain/model_asset3d.dart';
import '../../editor/domain/scene3d.dart';
import '../../editor/domain/video_project.dart';

const voidShotNames = [
  '01 • À deriva',
  '02 • Sem direção',
  '03 • Última luz',
  '04 • O vazio',
];
Duration _time(double s) => Duration(microseconds: (s * 1000000).round());

Vec3 voidPosition(double t) =>
    Vec3(35 * math.sin(t * .4), -28 * t - 1.5 * t * t, -10 * t);

/// Same Euler order as the native scene transform: X, then Y, then Z.
Vec3 _turn(Vec3 v, double t) {
  final rx = (12 + 5 * t) * math.pi / 180,
      ry = (-18 + 10 * t) * math.pi / 180,
      rz = (-25 + 12 * t) * math.pi / 180;
  final y = v.y * math.cos(rx) - v.z * math.sin(rx),
      z = v.y * math.sin(rx) + v.z * math.cos(rx);
  final x2 = v.x * math.cos(ry) + z * math.sin(ry),
      z2 = -v.x * math.sin(ry) + z * math.cos(ry);
  return Vec3(
    x2 * math.cos(rz) - y * math.sin(rz),
    x2 * math.sin(rz) + y * math.cos(rz),
    z2,
  );
}

VideoProject buildVoidAstronautTemplate(ModelAsset3D astronaut) {
  AnimatedDouble motion(
    double Function(double) f, {
    double start = 0,
    double end = 10,
    int samples = 40,
  }) => AnimatedDouble(f(start), [
    for (var i = 0; i <= samples; i++)
      Keyframe(
        time: _time(start + (end - start) * i / samples),
        value: f(start + (end - start) * i / samples),
      ),
  ]);
  final body = SceneNode(
    id: 'void_astronauta',
    name: 'Astronauta • queda e rotação',
    modelAsset: astronaut,
    size: 100,
    x: motion((t) => voidPosition(t).x),
    y: motion((t) => voidPosition(t).y),
    z: motion((t) => voidPosition(t).z),
    rotX: motion((t) => 12 + 5 * t),
    rotY: motion((t) => -18 + 10 * t),
    rotZ: motion((t) => -25 + 12 * t),
  );
  final cameras = <Camera3D>[];
  for (var shot = 0; shot < 4; shot++) {
    final start = shot * 2.5, end = start + 2.5;
    Vec3 eye(double t) {
      final u = (t - start) / 2.5, p = voidPosition(t);
      return switch (shot) {
        0 => p + Vec3(110 - 65 * u, 55 + 10 * u, 390 + 100 * u),
        1 =>
          p +
              Vec3(
                330 * math.sin(-.65 + 1.20 * u),
                65 - 40 * u,
                330 * math.cos(-.65 + 1.20 * u),
              ),
        2 => p + _turn(Vec3(12 - 28 * u, 83, 205 - 25 * u), t),
        _ => p + Vec3(-100 + 80 * u, 100 + 280 * u, 510 + 1390 * u * u),
      };
    }

    Vec3 aim(double t) {
      final p = voidPosition(t), u = (t - start) / 2.5;
      return switch (shot) {
        0 => p + Vec3(-20 + 20 * u, 15, 0),
        1 => p + const Vec3(0, 4, 0),
        2 => p + _turn(const Vec3(0, 58, 12), t),
        _ => p + Vec3(-20 * u, 170 * u, 0),
      };
    }

    AnimatedDouble track(double Function(double) f) =>
        motion(f, start: start, end: end, samples: 30);
    cameras.add(
      Camera3D(
        id: 'void_camera_$shot',
        name: voidShotNames[shot],
        posX: track((t) => eye(t).x),
        posY: track((t) => eye(t).y),
        posZ: track((t) => eye(t).z),
        poiX: track((t) => aim(t).x),
        poiY: track((t) => aim(t).y),
        poiZ: track((t) => aim(t).z),
        focalLength: AnimatedDouble(
          shot == 2
              ? 62
              : shot == 3
              ? 40
              : 50,
        ),
      ),
    );
  }
  final random = math.Random(813);
  List<Vec3> stars(int count) => [
    for (var i = 0; i < count; i++)
      (() {
        final y = random.nextDouble() * 2 - 1,
            a = random.nextDouble() * math.pi * 2,
            r = 1700 + random.nextDouble() * 2300;
        final s = math.sqrt(1 - y * y);
        return Vec3(r * s * math.cos(a), r * y - 150, r * s * math.sin(a));
      })(),
  ];
  final starMesh = Element3DMesh(
    [
      [1, 0, 0],
      [-1, 0, 0],
      [0, 1, 0],
      [0, -1, 0],
      [0, 0, 1],
      [0, 0, -1],
    ],
    [
      [0, 2, 4],
      [2, 1, 4],
      [1, 3, 4],
      [3, 0, 4],
      [2, 0, 5],
      [1, 2, 5],
      [3, 1, 5],
      [0, 3, 5],
    ],
  );
  final scene = Scene3D(
    background: const Color(0xff010207),
    showFloorGrid: false,
    ambient: .08,
    nodes: [
      body,
      SceneNode(
        id: 'void_estrelas',
        name: 'Estrelas distantes',
        size: 1.3,
        mesh: starMesh,
        instances: stars(900),
        material: const Material3D(
          kind: MaterialKind.unlit,
          baseColor: Color(0xffadc5d7),
        ),
      ),
      SceneNode(
        id: 'void_estrelas_azuis',
        name: 'Estrelas frias',
        size: 2.2,
        mesh: starMesh,
        instances: stars(85),
        material: const Material3D(
          kind: MaterialKind.unlit,
          baseColor: Color(0xff83c5ff),
        ),
      ),
      SceneNode(
        id: 'void_estrelas_quentes',
        name: 'Estrelas quentes',
        size: 1.9,
        mesh: starMesh,
        instances: stars(35),
        material: const Material3D(
          kind: MaterialKind.unlit,
          baseColor: Color(0xffffdeb5),
        ),
      ),
    ],
    lights: [
      Light3D(
        id: 'void_sol',
        color: const Color(0xffd8ebff),
        direction: const Vec3(-.6, -.45, -.8),
        intensity: AnimatedDouble(1.8),
        castsShadow: true,
      ),
      Light3D(
        id: 'void_reflexo',
        kind: Light3DKind.point,
        position: const Vec3(-380, 300, 450),
        range: 5000,
        color: const Color(0xff73a5eb),
        intensity: AnimatedDouble(850000),
      ),
      Light3D(
        id: 'void_contraluz',
        kind: Light3DKind.point,
        position: const Vec3(400, 50, -400),
        range: 5000,
        color: const Color(0xffffa968),
        intensity: AnimatedDouble(700000),
      ),
    ],
  );
  return VideoProject(
    id: 'void_astronauta_10s',
    name: 'VOID • A última luz',
    createdAt: DateTime(2026, 9, 6),
    aspectRatio: 9 / 16,
    resolutionHeight: 1280,
    fps: 30,
    markers: [
      for (var i = 0; i < 4; i++)
        Marker(time: _time(i * 2.5), label: voidShotNames[i]),
    ],
    layers: [
      Scene3DLayer(
        id: 'void_cena',
        name: 'Astronauta no vazio • 4 tomadas',
        startTime: Duration.zero,
        duration: const Duration(seconds: 10),
        position: AnimatedOffset(const Offset(360, 640)),
        showHelpers: false,
        scene: scene,
        camera: cameras.first,
        extraCameras: cameras.skip(1).toList(),
        shots: [
          for (var i = 0; i < 4; i++)
            CameraShot(time: _time(i * 2.5), cameraId: cameras[i].id),
        ],
      ),
    ],
  );
}
