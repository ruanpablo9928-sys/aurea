// A CAMERA DA COMPOSICAO — o objeto do seletor de insercao do AM
// (V 00:19,5) que o Aurea nao tinha.
//
// A regra que este arquivo protege e a do After Effects, que o AM segue:
// a camera move as camadas com o 3D ligado, e camada 2D nao ve camera.
// E, acima de tudo: com a camera parada na lente neutra, a composicao
// fica EXATAMENTE como estava antes de existir camera nenhuma.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

({ProviderContainer c, EditorController e}) _montar() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return (c: container, e: container.read(editorControllerProvider.notifier));
}

void main() {
  test('sem camera, nada muda', () {
    final m = _montar();
    m.e.addTextLayer(Duration.zero, text: 'Um');
    final camada = m.c.read(editorControllerProvider).layers.single;
    final antes = effectiveTransform(
      m.c.read(editorControllerProvider),
      camada,
      Duration.zero,
    );
    expect(antes.pos, camada.position.valueAt(Duration.zero));
  });

  test('camera parada na lente neutra nao move um pixel', () {
    final m = _montar();
    m.e.addTextLayer(Duration.zero, text: 'Um');
    final id = m.c.read(editorControllerProvider).layers.single.id;
    m.e.toggle3D(id);
    final semCamera = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    m.e.addCameraLayer(Duration.zero);
    final comCamera = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    expect((comCamera.pos - semCamera.pos).distance, lessThan(0.001));
    expect(comCamera.scale, closeTo(semCamera.scale, 0.001));
  });

  test('mover a camera move a camada 3D, e no sentido contrario', () {
    final m = _montar();
    m.e.addTextLayer(Duration.zero, text: 'Um');
    final id = m.c.read(editorControllerProvider).layers.single.id;
    m.e.toggle3D(id);
    m.e.addCameraLayer(Duration.zero);
    final cam = m.c
        .read(editorControllerProvider)
        .layers
        .whereType<CameraLayer>()
        .single;
    final antes = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    // A camera anda 100 px para a direita: o mundo anda 100 para a
    // esquerda na tela. E o que uma camera faz.
    final p = cam.position.valueAt(Duration.zero);
    m.e.editPosition(cam.id, Duration.zero, p + const Offset(100, 0));
    final depois = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    expect(depois.pos.dx - antes.pos.dx, closeTo(-100, 0.001));
    expect(depois.pos.dy, closeTo(antes.pos.dy, 0.001));
  });

  test('camada 2D NAO ve camera', () {
    final m = _montar();
    m.e.addTextLayer(Duration.zero, text: 'Plano');
    final id = m.c.read(editorControllerProvider).layers.single.id;
    m.e.addCameraLayer(Duration.zero);
    final cam = m.c
        .read(editorControllerProvider)
        .layers
        .whereType<CameraLayer>()
        .single;
    final antes = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    final p = cam.position.valueAt(Duration.zero);
    m.e.editPosition(cam.id, Duration.zero, p + const Offset(200, 140));
    final depois = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    expect(
      depois.pos,
      antes.pos,
      reason: 'a mesma regra do AM e do After Effects: 2D nao ve camera',
    );
  });

  test('a lente aproxima e afasta a cena inteira', () {
    final m = _montar();
    m.e.addTextLayer(Duration.zero, text: 'Um');
    final id = m.c.read(editorControllerProvider).layers.single.id;
    m.e.toggle3D(id);
    // Fora do centro, para o zoom ter o que afastar.
    m.e.editPosition(id, Duration.zero, const Offset(100, 100));
    m.e.addCameraLayer(Duration.zero);
    final cam = m.c
        .read(editorControllerProvider)
        .layers
        .whereType<CameraLayer>()
        .single;
    final projeto = m.c.read(editorControllerProvider);
    final centro = Offset(
      projeto.outputWidth / 2,
      projeto.outputHeight / 2,
    );
    final antes = effectiveTransform(
      projeto,
      projeto.layerById(id)!,
      Duration.zero,
    );

    m.e.editCameraZoom(cam.id, Duration.zero, CameraLayer.lenteNeutra * 2);
    final depois = effectiveTransform(
      m.c.read(editorControllerProvider),
      m.c.read(editorControllerProvider).layerById(id)!,
      Duration.zero,
    );

    expect(
      (depois.pos - centro).distance,
      closeTo((antes.pos - centro).distance * 2, 0.01),
      reason: 'dobrar a lente dobra a distancia ao centro',
    );
    expect(depois.scale, closeTo(antes.scale * 2, 0.001));
  });

  test('a lente anima, e sem losango nao nasce keyframe', () {
    final m = _montar();
    m.e.addCameraLayer(Duration.zero);
    final id = m.c
        .read(editorControllerProvider)
        .layers
        .whereType<CameraLayer>()
        .single
        .id;

    m.e.editCameraZoom(id, Duration.zero, 900);
    var cam =
        m.c.read(editorControllerProvider).layerById(id)! as CameraLayer;
    expect(cam.zoom.isAnimated, isFalse, reason: 'mudar valor nao anima');
    expect(cam.zoom.valueAt(Duration.zero), 900);

    m.e.toggleCameraZoomKeyframe(id, Duration.zero);
    cam = m.c.read(editorControllerProvider).layerById(id)! as CameraLayer;
    expect(cam.zoom.hasKeyframeAt(Duration.zero), isTrue);
  });

  test('a camera sobrevive a salvar e reabrir', () {
    final m = _montar();
    m.e.addCameraLayer(Duration.zero);
    final id = m.c
        .read(editorControllerProvider)
        .layers
        .whereType<CameraLayer>()
        .single
        .id;
    m.e.editCameraZoom(id, Duration.zero, 640);
    m.e.editPosition(id, Duration.zero, const Offset(80, 90));

    final json = projectToJson(m.c.read(editorControllerProvider));
    final volta = projectFromJson(json);
    final cam = volta.layers.whereType<CameraLayer>().single;

    expect(cam.zoom.valueAt(Duration.zero), 640);
    expect(cam.position.valueAt(Duration.zero), const Offset(80, 90));
    expect(cam.id, id);
  });

  test('a camera de cima da pilha e a que manda', () {
    final m = _montar();
    m.e.addCameraLayer(Duration.zero);
    m.e.addCameraLayer(Duration.zero);
    final projeto = m.c.read(editorControllerProvider);
    final primeira = projeto.layers.whereType<CameraLayer>().first;
    expect(cameraAtivaEm(projeto, Duration.zero)!.id, primeira.id);
  });
}
