import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/presentation/widgets/dither_layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// PERFIL DA EXPORTACAO, etapa por etapa.
///
/// A queixa: 5 segundos de UM shape animado levam ~5 minutos para
/// exportar — dois segundos por quadro. Antes de trocar arquitetura e
/// preciso saber ONDE esses dois segundos estao. Esta bancada monta a
/// arvore EXATA da exportacao (o mesmo RepaintBoundary no tamanho da
/// composicao, o mesmo DitherLayer, a mesma CompositionView em modo de
/// exportacao) e cronometra as tres etapas do lado Dart:
///
///   COMPOR      reconstruir a arvore no instante t e pintar
///   RASTERIZAR  `toImage` do boundary — o quadro virar imagem
///   LER         `toByteData` — a imagem virar bytes para o codificador
///
/// UMA RESSALVA QUE MUDA A LEITURA: `flutter test` roda sem GPU. A
/// rasterizacao aqui e por software, e num aparelho ela e muito mais
/// barata. Entao o numero de RASTERIZAR e teto, nao medida; os de
/// COMPOR e LER valem como sao. O que a bancada resolve com seguranca e
/// a pergunta "o custo esta no lado Dart ou nao esta" — e essa e a
/// pergunta que decide se a arquitetura precisa mudar.
void main() {
  Duration t(num s) => Duration(microseconds: (s * 1000000).round());

  Future<void> perfil(WidgetTester tester, String nome, int shapes) async {
    const largura = 1080.0, altura = 1920.0;
    const quadros = 20; // amostra; 150 no filme inteiro

    tester.view.physicalSize = const Size(largura, altura);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(editorControllerProvider.notifier);
    for (var i = 0; i < shapes; i++) {
      c.addShapeLayer(Duration.zero);
    }
    // Duas marcas de posicao: a animacao simples do caso relatado.
    c.openProject(
      c.state.copyWith(
        layers: [
          for (final l in c.state.layers)
            l.copyLayer(
              duration: const Duration(seconds: 5),
              position: AnimatedOffset(const Offset(200, 400), [
                Keyframe(time: Duration.zero, value: const Offset(200, 400)),
                Keyframe(time: t(5), value: const Offset(800, 1400)),
              ]),
            ),
        ],
      ),
    );

    final relogio = ValueNotifier<Duration>(Duration.zero);
    addTearDown(relogio.dispose);
    final chave = GlobalKey();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            // A MESMA arvore da tela de exportacao.
            body: FittedBox(
              fit: BoxFit.contain,
              child: RepaintBoundary(
                key: chave,
                child: SizedBox(
                  width: largura,
                  height: altura,
                  child: ColoredBox(
                    color: Colors.black,
                    child: DitherLayer(
                      time: Duration.zero,
                      child: CompositionView(
                        time: relogio,
                        videos: VideoLayerManager(),
                        selectedId: null,
                        exporting: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final obj = chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    var msCompor = 0.0, msRaster = 0.0, msLer = 0.0;
    var bytes = 0;

    // Aquece: o primeiro quadro paga o que nao se repete.
    relogio.value = Duration.zero;
    await tester.pump();
    await tester.runAsync(() async {
      final img = await obj.toImage();
      img.dispose();
    });

    for (var i = 0; i < quadros; i++) {
      final r1 = Stopwatch()..start();
      relogio.value = t(i / 30);
      await tester.pump();
      r1.stop();
      msCompor += r1.elapsedMicroseconds / 1000;

      await tester.runAsync(() async {
        final r2 = Stopwatch()..start();
        final img = await obj.toImage();
        r2.stop();
        msRaster += r2.elapsedMicroseconds / 1000;

        final r3 = Stopwatch()..start();
        final dados = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
        r3.stop();
        msLer += r3.elapsedMicroseconds / 1000;
        bytes = dados?.lengthInBytes ?? 0;
        img.dispose();
      });
    }

    final total = (msCompor + msRaster + msLer) / quadros;
    String p(double v) => (v / quadros).toStringAsFixed(1).padLeft(7);
    // ignore: avoid_print
    print(
      '${nome.padRight(12)} compor ${p(msCompor)} | raster ${p(msRaster)} | '
      'ler ${p(msLer)} | total ${total.toStringAsFixed(1).padLeft(6)} ms | '
      '150 quadros ${(total * 150 / 1000).toStringAsFixed(1)} s | '
      '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('perfil da exportacao, 1080x1920 a 30 fps', (tester) async {
    // ignore: avoid_print
    print('=== PERFIL (raster por SOFTWARE aqui; num aparelho e GPU) ===');
    await perfil(tester, '1 shape', 1);
    await perfil(tester, '10 shapes', 10);
    await perfil(tester, '100 shapes', 100);
  });
}
