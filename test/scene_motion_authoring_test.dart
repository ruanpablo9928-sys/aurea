import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/scene_motion.dart';
import 'package:aurea/src/features/editor/domain/preview_quality.dart';

void main() {
  const t = Duration(seconds: 2);
  test('trilha animada, SOBRE a marca: atualiza a marca, nao cria outra', () {
    // O nome antigo deste teste era "first later edit anchors zero":
    // cobria justamente a ancora que foi removida. Ver
    // `docs/keyframe-explicito.md`.
    final track = AnimatedDouble(10)
        .withKeyframe(Duration.zero, 10)
        .withKeyframe(t, 30);
    expect(track.valueAt(const Duration(seconds: 1)), 20);

    final edited = editMotionValue(track, t, 50);
    expect(edited.keyframes.length, 2);
    expect(edited.valueAt(t), 50);
    expect(edited.valueAt(Duration.zero), 10);
  });
  test('trilha estatica: editar muda a base, sem marca nenhuma', () {
    final track = editMotionValue(AnimatedDouble(10), t, 30);
    expect(track.keyframes, isEmpty);
    expect(track.base, 30);
  });
  test('animada e FORA de marca: a trilha volta intacta', () {
    // Era aqui que morava a ancora: um unico arrasto num instante
    // qualquer deixava DOIS keyframes, um deles em tempo zero — num
    // tempo que a pessoa nunca visitou.
    final track = AnimatedDouble(10).withKeyframe(Duration.zero, 10);
    final edited = editMotionValue(track, const Duration(seconds: 1), 99);
    expect(edited.keyframes, hasLength(1));
    expect(edited.valueAt(const Duration(seconds: 1)), 10);
  });
  test('camera SOBRE a marca: o gesto atualiza, e vizinhas ficam', () {
    final camera = Camera3D(
      posX: AnimatedDouble(0)
          .withKeyframe(Duration.zero, 0)
          .withKeyframe(t, 20)
          .withKeyframe(const Duration(seconds: 4), 40),
    );
    final changed = editCameraMotion(
      camera,
      t,
      (pose) => panCamera(pose, const Offset(-10, 0), t),
    );
    expect(changed.posX.valueAt(Duration.zero), 0);
    expect(changed.posX.valueAt(const Duration(seconds: 4)), 40);
    expect(changed.posX.valueAt(t), isNot(camera.posX.valueAt(t)));
    expect(changed.posX.keyframes, hasLength(3));
  });
  test('camera FORA da marca: o gesto nao inventa marca nenhuma', () {
    // Girar a camera e EDICAO DE VALOR, nao acao nomeada: num instante
    // sem marca, a trilha volta identica.
    final camera = Camera3D(
      posX: AnimatedDouble(0)
          .withKeyframe(Duration.zero, 0)
          .withKeyframe(const Duration(seconds: 4), 40),
    );
    final changed = editCameraMotion(
      camera,
      t,
      (pose) => panCamera(pose, const Offset(-10, 0), t),
    );
    expect(changed.posX.keyframes, hasLength(2));
    expect(changed.posX.valueAt(t), camera.posX.valueAt(t));
  });
  test('screen movement is converted through rotated scaled parent', () {
    final parent = SceneNode(
      id: 'p',
      rotZ: AnimatedDouble(90),
      scale: AnimatedDouble(2),
    );
    final child = SceneNode(id: 'c', parentId: 'p');
    final scene = Scene3D(nodes: [parent, child]);
    final delta = sceneLocalDelta(scene, child, t, const Vec3(10, 0, 0));
    expect(delta.x, closeTo(0, 1e-8));
    expect(delta.y, closeTo(-5, 1e-8));
  });
  test('4K preview has bounded allocation; export keeps full resolution', () {
    expect(scenePreviewScale(2160, 3840, interacting: true) * 3840, 720);
    expect(scenePreviewScale(2160, 3840, interacting: false) * 3840, 1080);
    expect(
      scenePreviewScale(2160, 3840, interacting: true, exporting: true),
      1,
    );
    expect(scenePreviewScale(100, 100, interacting: true), 1);
  });
}
