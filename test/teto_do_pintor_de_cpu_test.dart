// O PINTOR DE CPU NAO PODE PARAR O APLICATIVO.
//
// A CAUSA do relato "clicar em algo so clica depois de uns 2 seg, mover
// trava tudo, e so em projeto com cena 3D": quando o motor em GPU nao
// esta em uso, a cena e desenhada pelo pintor em CPU, e ele nao da conta
// de um modelo importado.
//
// Medido por `test/ferramenta_custo_cena3d_test.dart`, em DESKTOP:
//
//     6.174 triangulos ->  65 ms por quadro  (15 fps)
//    10.449 triangulos -> 101 ms por quadro  (10 fps)
//
// No iPhone e duas a tres vezes mais. Um modelo de 60 mil triangulos da
// perto de dois segundos POR QUADRO — e enquanto o quadro nao sai, nada
// responde: nem o toque, nem a linha do tempo, nem a rolagem. Nao e uma
// previa lenta, e o aplicativo parado.
//
// Entao existe um teto. Acima dele a previa mostra um substituto e o
// aplicativo continua andando. Na EXPORTACAO o teto nao vale: la o
// quadro pode demorar o que precisar, e o arquivo entregue sai completo.
//
// Este teste cobra as duas metades, porque uma sem a outra e um bug:
// proteger a previa e entregar video furado seria pior que travar.
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

/// Uma malha com [triangulos] faces, toda dentro da camera.
Element3DMesh _malha(int triangulos) {
  final verts = <List<double>>[];
  final faces = <List<int>>[];
  for (var i = 0; i < triangulos; i++) {
    final a = verts.length;
    final f = (i % 40) / 40 - 0.5;
    final g = (i ~/ 40) / 40 - 0.5;
    verts
      ..add([f, g, 0])
      ..add([f + 0.02, g, 0])
      ..add([f, g + 0.02, 0]);
    faces.add([a, a + 1, a + 2]);
  }
  return Element3DMesh(verts, faces);
}

Scene3D _cena(int triangulos) => Scene3D(
  nodes: [
    SceneNode(
      id: 'no',
      name: 'Modelo',
      size: 300,
      mesh: _malha(triangulos),
      material: const Material3D(baseColor: Color(0xFF22DD55)),
    ),
  ],
  lights: Scene3D.tresPontos,
);

/// Desenha a cena e conta quantos pixels ficaram verdes (o modelo).
Future<int> _pixeisDoModelo(
  WidgetTester tester,
  Scene3D cena, {
  required bool respeitarOrcamento,
}) async {
  final chave = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: chave,
          child: SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(
              color: const Color(0xFF000000),
              child: CustomPaint(
                painter: Scene3DPainter(
                  scene: cena,
                  camera: Camera3D(),
                  view: SceneView.camera,
                  time: Duration.zero,
                  respeitarOrcamento: respeitarOrcamento,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  final boundary =
      chave.currentContext!.findRenderObject() as RenderRepaintBoundary;
  late int verdes;
  await tester.runAsync(() async {
    final imagem = await boundary.toImage();
    final bytes = (await imagem.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    imagem.dispose();
    verdes = 0;
    for (var i = 0; i + 3 < bytes.lengthInBytes; i += 4) {
      final r = bytes.getUint8(i);
      final g = bytes.getUint8(i + 1);
      final b = bytes.getUint8(i + 2);
      if (g > 90 && g > r + 30 && g > b + 30) verdes++;
    }
  });
  return verdes;
}

void main() {
  testWidgets('cena leve e desenhada normalmente na previa', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final verdes = await _pixeisDoModelo(
      tester,
      _cena(400),
      respeitarOrcamento: true,
    );
    expect(
      verdes,
      greaterThan(0),
      reason: 'o teto nao pode atrapalhar uma cena que cabe no processador',
    );
  });

  testWidgets('cena pesada NAO e desenhada na previa', (tester) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pesada = _cena(Scene3DPainter.orcamentoDeCpu * 3);
    expect(
      trianglesEstimados(pesada),
      greaterThan(Scene3DPainter.orcamentoDeCpu),
      reason: 'a cena de teste tinha de estourar o teto',
    );
    final verdes = await _pixeisDoModelo(
      tester,
      pesada,
      respeitarOrcamento: true,
    );
    expect(
      verdes,
      0,
      reason:
          'a cena pesada foi desenhada mesmo assim: no aparelho isso e '
          'mais de um segundo por quadro, com o app inteiro parado',
    );
  });

  testWidgets('na EXPORTACAO a mesma cena pesada e desenhada inteira', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final verdes = await _pixeisDoModelo(
      tester,
      _cena(Scene3DPainter.orcamentoDeCpu * 3),
      respeitarOrcamento: false,
    );
    expect(
      verdes,
      greaterThan(0),
      reason:
          'proteger a previa nao pode entregar video furado: sem teto, o '
          'modelo tem de aparecer',
    );
  });

  test('a estimativa conta o que seria desenhado', () {
    expect(trianglesEstimados(_cena(1000)), 1000);
    // No invisivel nao custa nada.
    final escondido = Scene3D(
      nodes: [
        SceneNode(
          id: 'n',
          name: 'N',
          size: 100,
          mesh: _malha(5000),
          visible: false,
        ),
      ],
      lights: Scene3D.tresPontos,
    );
    expect(trianglesEstimados(escondido), 0);
  });
}
