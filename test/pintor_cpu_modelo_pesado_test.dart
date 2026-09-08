import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/motor3d_modo.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/model_asset3d.dart';
import 'package:aurea/src/features/editor/domain/model_import3d.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O MODELO "SIMPLES" QUE TRAVAVA TUDO.
///
/// O relato do beta: um iPhone 12 Pro de loja (73 mil triângulos, quatro
/// texturas pequenas, sem esqueleto) deixava o app a 1 fps num iPhone 13.
/// A medida, num desktop: 484–794 ms por quadro no pintor de CPU. Num
/// telefone isso é um quadro por segundo — e o pintor de CPU era o que
/// estava desenhando, porque `showHelpers` nasce ligado em toda cena nova
/// e a porta do preview exigia `!ajudas` para usar a GPU.
///
/// Três coisas fixam o conserto aqui:
///   1. o mesmo quadro parado NÃO é redesenhado — volta do guardado;
///   2. modelo importado ganha o LOD que não trouxe: um teto de faces no
///      pintor de CPU, com o material de cada face alinhado;
///   3. a migalha da queda em GPU expira, em vez de condenar o aparelho
///      ao pintor de CPU para sempre.

/// Um quadro de modelo com [faces] triângulos e um material por face,
/// numerado — para conferir que a decimação mantém cada face com o seu.
ModelFrame3D _quadro(int faces) {
  final verts = <List<double>>[];
  final tris = <List<int>>[];
  final materiais = <Material3D>[];
  for (var i = 0; i < faces; i++) {
    final b = verts.length;
    final x = (i % 300) / 300 - .5, y = (i ~/ 300) / 300 - .5;
    verts
      ..add([x, y, 0])
      ..add([x + .003, y, 0])
      ..add([x, y + .003, 0]);
    tris.add([b, b + 1, b + 2]);
    materiais.add(Material3D(name: 'm$i'));
  }
  return ModelFrame3D(
    Element3DMesh(verts, tris),
    List.filled(verts.length, null),
    List.filled(verts.length, null),
    materiais,
    const {},
  );
}

void main() {
  setUp(esvaziarQuadrosGuardados);

  test('o rascunho de um modelo pesado respeita o teto e alinha materiais', () {
    final cheio = _quadro(73000);
    final raso = cheio.rascunho(tetoDeFacesCpuRascunho);
    expect(raso.mesh.faces.length, lessThanOrEqualTo(tetoDeFacesCpuRascunho));
    expect(raso.mesh.faces.length, greaterThan(tetoDeFacesCpuRascunho ~/ 2));
    expect(raso.materials.length, raso.mesh.faces.length);
    // Cada face que sobrou continua com o material que era dela.
    for (var k = 0; k < raso.mesh.faces.length; k++) {
      final original = raso.mesh.faces[k][0] ~/ 3;
      expect(raso.materials[k].name, 'm$original');
    }
    // Abaixo do teto, o quadro é o mesmo objeto: nada é copiado à toa.
    expect(identical(_quadro(100).rascunho(tetoDeFacesCpu), null), isFalse);
    final pequeno = _quadro(100);
    expect(identical(pequeno.rascunho(tetoDeFacesCpu), pequeno), isTrue);
    // Pedir o mesmo rascunho duas vezes devolve o mesmo objeto.
    expect(identical(cheio.rascunho(12000), cheio.rascunho(12000)), isTrue);
  });

  test('uma cena parada volta do guardado no segundo desenho', () {
    final asset = _assetSintetico(30000);
    final scene = Scene3D(
      nodes: [SceneNode(name: 'pesado', modelAsset: asset, size: 300)],
      lights: Scene3D.tresPontos,
    );
    final camera = Camera3D();
    expect(cenaDependeDoTempo(scene, camera), isFalse);

    int desenhar(Duration t) {
      final rec = ui.PictureRecorder();
      final sw = Stopwatch()..start();
      Scene3DPainter(
        scene: scene,
        camera: camera,
        view: SceneView.camera,
        time: t,
      ).paint(Canvas(rec), const Size(390, 844));
      rec.endRecording().dispose();
      return sw.elapsedMilliseconds;
    }

    final primeiro = desenhar(Duration.zero);
    expect(quadrosGuardadosServidos(), 0);
    // O CABEÇOTE ANDOU e a cena não depende do tempo: mesmo quadro.
    final segundo = desenhar(const Duration(milliseconds: 500));
    expect(quadrosGuardadosServidos(), 1, reason: 'o segundo desenho não veio do guardado');
    // Dez vezes mais rápido é o mínimo que se espera de "não desenhar".
    expect(segundo * 10, lessThanOrEqualTo(primeiro + 5),
        reason: 'primeiro=${primeiro}ms segundo=${segundo}ms');

    // Um tamanho diferente é outro quadro.
    final rec = ui.PictureRecorder();
    Scene3DPainter(scene: scene, camera: camera, view: SceneView.camera, time: Duration.zero)
        .paint(Canvas(rec), const Size(200, 200));
    rec.endRecording().dispose();
    expect(quadrosGuardadosServidos(), 1);
  });

  test('duas RenderCamera iguais por valor contam como o mesmo quadro', () {
    // O CASO DO PREVIEW: a camada e imutavel, mas a camera resolvida
    // (`cameraDaCena`) e um objeto NOVO a cada build. Se a chave a
    // comparasse por identidade, o guardado erraria em toda reconstrucao
    // da tela — e o conserto nao existiria onde mais importa.
    final asset = _assetSintetico(20000);
    final scene = Scene3D(
      nodes: [SceneNode(name: 'pesado', modelAsset: asset, size: 300)],
      lights: Scene3D.tresPontos,
    );
    final camera = Camera3D();
    RenderCamera resolvida() => const RenderCamera(
      position: Vec3(10, 20, 900),
      target: Vec3(0, 0, 0),
    );
    for (var i = 0; i < 2; i++) {
      final rec = ui.PictureRecorder();
      Scene3DPainter(
        scene: scene,
        camera: camera,
        resolvedCamera: resolvida(),
        view: SceneView.camera,
        time: Duration.zero,
      ).paint(Canvas(rec), const Size(390, 844));
      rec.endRecording().dispose();
    }
    expect(quadrosGuardadosServidos(), 1,
        reason: 'camera resolvida igual por valor tem de reaproveitar o quadro');
  });

  test('uma cena animada NÃO reaproveita o quadro de outro instante', () {
    final scene = Scene3D(
      nodes: [
        SceneNode(
          name: 'gira',
          rotY: AnimatedDouble(0, [
            const Keyframe(time: Duration(seconds: 1), value: 90.0),
          ]),
        ),
      ],
    );
    final camera = Camera3D();
    expect(cenaDependeDoTempo(scene, camera), isTrue);
    for (final t in [Duration.zero, const Duration(milliseconds: 500)]) {
      final rec = ui.PictureRecorder();
      Scene3DPainter(scene: scene, camera: camera, view: SceneView.camera, time: t)
          .paint(Canvas(rec), const Size(200, 200));
      rec.endRecording().dispose();
    }
    expect(quadrosGuardadosServidos(), 0);
  });

  test('a migalha da queda expira depois de tres sessoes em CPU', () async {
    SharedPreferences.setMockInitialValues({'motor3d_caiu': true});
    for (var sessao = 1; sessao <= Motor3DPreferencia.sessoesAteTentarDeNovo; sessao++) {
      final prefs = await SharedPreferences.getInstance();
      final p = await Motor3DPreferencia.carregar(prefs);
      final ultima = sessao == Motor3DPreferencia.sessoesAteTentarDeNovo;
      expect(
        p.permiteGpu,
        ultima,
        reason: 'sessao $sessao: a GPU deve voltar a ser tentada só na última',
      );
    }
  });

  test(
    'iphone_12_pro.glb: o custo real, se o arquivo estiver na máquina',
    () {
      final f = File(r'C:\Users\SnyX\Downloads\iphone_12_pro.glb');
      if (!f.existsSync()) return;
      final asset = importGltf3D(f.readAsBytesSync());
      final cheio = asset.evaluate(Duration.zero, const ModelMotion3D(clip: -1));
      final raso = cheio.rascunho(tetoDeFacesCpuRascunho);
      debugPrint('iphone_12_pro: ${cheio.mesh.faces.length} faces → rascunho ${raso.mesh.faces.length}');
      expect(raso.mesh.faces.length, lessThanOrEqualTo(tetoDeFacesCpuRascunho));

      // OS NUMEROS DO CONSERTO, no arquivo que motivou tudo: quadro cheio
      // parado, quadro em rascunho (tocando) e o segundo quadro parado —
      // que deve voltar do guardado por quase nada.
      // A MESMA camera nos tres desenhos: e a identidade dela que entra na
      // chave do guardado, como no editor, onde a camada e imutavel.
      final camera = Camera3D();
      int desenhar(Scene3D scene, Duration t) {
        final rec = ui.PictureRecorder();
        final sw = Stopwatch()..start();
        Scene3DPainter(scene: scene, camera: camera, view: SceneView.camera, time: t)
            .paint(Canvas(rec), const Size(390, 844));
        rec.endRecording().dispose();
        return sw.elapsedMilliseconds;
      }

      final no = SceneNode(name: 'iphone', modelAsset: asset, size: 300);
      final parada = Scene3D(nodes: [no], lights: Scene3D.tresPontos);
      final tocando = parada.copyWith(draftMode: true);
      esvaziarQuadrosGuardados();
      final cheioMs = desenhar(parada, Duration.zero);
      final guardadoMs = desenhar(parada, const Duration(milliseconds: 500));
      final rascunhoMs = desenhar(tocando, Duration.zero);
      debugPrint(
        'iphone_12_pro: parado cheio=${cheioMs}ms, segundo quadro (guardado)=${guardadoMs}ms, '
        'tocando (rascunho)=${rascunhoMs}ms',
      );
      expect(quadrosGuardadosServidos(), 1);
      expect(guardadoMs * 10, lessThanOrEqualTo(cheioMs + 5));
    },
  );
}

ModelAsset3D _assetSintetico(int faces) {
  final positions = <List<double>>[];
  final indices = <int>[];
  for (var i = 0; i < faces; i++) {
    final b = positions.length;
    final x = (i % 300) / 300 - .5, y = (i ~/ 300) / 300 - .5;
    positions
      ..add([x, y, 0])
      ..add([x + .003, y, 0])
      ..add([x, y + .003, 0]);
    indices.addAll([b, b + 1, b + 2]);
  }
  return ModelAsset3D({
    'name': 'sintetico',
    'nodes': [
      {'name': 'raiz', 'translation': [0, 0, 0], 'rotation': [0, 0, 0, 1], 'scale': [1, 1, 1], 'weights': []},
    ],
    'primitives': [
      {'node': 0, 'positions': positions, 'indices': indices, 'material': 0},
    ],
    'materials': [
      {'name': 'liso', 'color': [0.53, 0.6, 0.67, 1.0], 'metallic': 0, 'roughness': 0.6},
    ],
    'skins': [],
    'clips': [],
  });
}
