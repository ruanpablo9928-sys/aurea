import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "A MESCLAGEM NAO ESTA FUNCIONANDO" — o relato do beta.
///
/// O que se prova aqui e a mescla NO PALCO DE VERDADE (o CompositionView
/// que o editor e a exportacao usam), pixel por pixel: uma camada verde
/// em Multiplicar sobre uma vermelha da preto onde se cruzam; em Tela da
/// amarelo. E o outro lado do relato: a mescla age sobre o que esta POR
/// BAIXO — sobre o fundo vazio da composicao, Multiplicar e Tela nao
/// mudam nada, e nao e defeito. E isso que a dica do painel agora diz.
void main() {
  Future<Uint8List> pintar(WidgetTester tester, List<Layer> layers, {Color? fundo}) async {
    tester.view.physicalSize = const Size(100, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final time = ValueNotifier(Duration.zero);
    addTearDown(time.dispose);
    container.read(editorControllerProvider.notifier).openProject(
      VideoProject(
        name: 'mescla',
        createdAt: DateTime(2026),
        aspectRatio: 1,
        resolutionHeight: 100,
        layers: layers,
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Material(
            color: fundo ?? Colors.transparent,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 100,
                height: 100,
                child: CompositionView(
                  time: time,
                  videos: VideoLayerManager(),
                  selectedId: null,
                  exporting: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    late ByteData data;
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      image.dispose();
    });
    return Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Color em(Uint8List px, int x, int y) {
    final i = (y * 100 + x) * 4;
    return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
  }

  ShapeLayer quadrado(String nome, Color cor, Offset centro, {BlendMode blend = BlendMode.srcOver}) =>
      ShapeLayer(
        name: nome,
        startTime: Duration.zero,
        duration: const Duration(seconds: 5),
        position: AnimatedOffset(centro),
        blendMode: blend,
        contents: [
          ShapePath(primitive: ShapePrimitive.rectangle, width: 60, height: 60),
          ShapeFill(color: cor),
        ],
      );

  testWidgets('Multiplicar escurece onde as camadas se cruzam; Tela clareia', (tester) async {
    // Vermelha embaixo (indice 1), verde por cima (indice 0) — o indice 0
    // e o topo da pilha.
    for (final (modo, esperado) in [
      (BlendMode.multiply, const Color(0xFF000000)),
      (BlendMode.screen, const Color(0xFFFFFF00)),
    ]) {
      final px = await pintar(tester, [
        quadrado('verde', const Color(0xFF00FF00), const Offset(60, 50), blend: modo),
        quadrado('vermelha', const Color(0xFFFF0000), const Offset(40, 50)),
      ]);
      expect(em(px, 50, 50), esperado, reason: 'cruzamento em $modo');
      expect(em(px, 15, 50), const Color(0xFFFF0000), reason: 'a vermelha sozinha nao muda');
      expect(em(px, 85, 50), const Color(0xFF00FF00), reason: 'a verde sozinha nao muda');
    }
  });

  testWidgets('sobre o fundo vazio, Multiplicar nao muda a camada — e o esperado', (tester) async {
    final px = await pintar(tester, [
      quadrado('verde', const Color(0xFF00FF00), const Offset(50, 50), blend: BlendMode.multiply),
    ]);
    expect(em(px, 50, 50), const Color(0xFF00FF00),
        reason: 'sem nada embaixo, nao ha com o que multiplicar');
  });
}
