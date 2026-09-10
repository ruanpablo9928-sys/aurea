// PROMPT 04 DA ESPECIFICACAO AM ONLY (rev. 02): TIMELINE, SELECAO E
// EDICAO TEMPORAL.
//
// "Conecte-os ao modelo Aurea sem perda de duracao, efeitos ou
// keyframes." / "Alguns simbolos da barra temporal mudam quando o
// playhead fica fora dos limites do segmento."
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/barra_temporal.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

({ProviderContainer c, EditorController e}) _motor() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return (c: container, e: container.read(editorControllerProvider.notifier));
}

void main() {
  group('aparar o comeco nao arrasta a animacao junto', () {
    test('o keyframe fica no MESMO instante do projeto', () {
      final m = _motor();
      m.e.addTextLayer(Duration.zero, text: 'Um');
      final id = m.c.read(editorControllerProvider).layers.single.id;
      // Uma marca em 2 s do projeto (= 2 s local, a camada comeca em 0).
      m.e.toggleKeyframe(id, const Duration(seconds: 2), LayerProp.opacity);
      m.e.editOpacity(id, const Duration(seconds: 2), 0.2);

      // Apara um segundo do comeco.
      m.e.trimLayerStart(id, const Duration(seconds: 1));
      final camada = m.c.read(editorControllerProvider).layerById(id)!;

      expect(camada.startTime, const Duration(seconds: 1));
      expect(
        camada.opacity.hasKeyframeAt(const Duration(seconds: 1)),
        isTrue,
        reason: 'local 1 s da camada nova = 2 s do projeto, onde a marca era',
      );
      expect(camada.opacity.valueAt(const Duration(seconds: 1)), 0.2);
    });

    test('o que fica antes do novo comeco e PRESO em zero, nao apagado', () {
      final m = _motor();
      m.e.addTextLayer(Duration.zero, text: 'Um');
      final id = m.c.read(editorControllerProvider).layers.single.id;
      m.e.toggleKeyframe(id, Duration.zero, LayerProp.opacity);
      m.e.editOpacity(id, Duration.zero, 0);
      m.e.toggleKeyframe(id, const Duration(seconds: 2), LayerProp.opacity);
      m.e.editOpacity(id, const Duration(seconds: 2), 1);

      // O corte cai no meio da subida: em 1 s a opacidade valia 0,5.
      final antes = m.c
          .read(editorControllerProvider)
          .layerById(id)!
          .opacity
          .valueAt(const Duration(seconds: 1));
      m.e.trimLayerStart(id, const Duration(seconds: 1));
      final camada = m.c.read(editorControllerProvider).layerById(id)!;

      expect(
        camada.opacity.valueAt(Duration.zero),
        closeTo(antes, 0.001),
        reason: 'o valor no comeco da camada e o mesmo de antes de aparar',
      );
      expect(camada.opacity.hasKeyframeAt(Duration.zero), isTrue);
      expect(camada.opacity.hasKeyframeAt(const Duration(seconds: 1)), isTrue);
    });

    test('aparar o FIM nao mexe em keyframe nenhum', () {
      final m = _motor();
      m.e.addTextLayer(Duration.zero, text: 'Um');
      final id = m.c.read(editorControllerProvider).layers.single.id;
      m.e.toggleKeyframe(id, const Duration(seconds: 1), LayerProp.opacity);
      final antes = m.c
          .read(editorControllerProvider)
          .layerById(id)!
          .opacity
          .keyframes
          .map((k) => k.time)
          .toList();

      m.e.trimLayerEnd(id, const Duration(seconds: 2));
      final depois = m.c
          .read(editorControllerProvider)
          .layerById(id)!
          .opacity
          .keyframes
          .map((k) => k.time)
          .toList();

      expect(depois, antes);
    });
  });

  group('dividir preserva a animacao dos dois lados', () {
    test('a segunda metade recomeca o tempo local e a marca acompanha', () {
      final m = _motor();
      m.e.addTextLayer(Duration.zero, text: 'Um');
      final id = m.c.read(editorControllerProvider).layers.single.id;
      // Marcas em 1 s e em 3 s do projeto.
      m.e.toggleKeyframe(id, const Duration(seconds: 1), LayerProp.opacity);
      m.e.editOpacity(id, const Duration(seconds: 1), 0.3);
      m.e.toggleKeyframe(id, const Duration(seconds: 3), LayerProp.opacity);
      m.e.editOpacity(id, const Duration(seconds: 3), 0.9);

      m.e.splitLayer(id, const Duration(seconds: 2));
      final camadas = m.c.read(editorControllerProvider).layers;
      expect(camadas.length, 2);
      final primeira = camadas.firstWhere((l) => l.id == id);
      final segunda = camadas.firstWhere((l) => l.id != id);

      expect(primeira.duration, const Duration(seconds: 2));
      expect(segunda.startTime, const Duration(seconds: 2));
      // 3 s do projeto = 1 s local da segunda metade.
      expect(
        segunda.opacity.hasKeyframeAt(const Duration(seconds: 1)),
        isTrue,
        reason: 'a marca de 3 s do projeto tem de continuar em 3 s do projeto',
      );
      expect(segunda.opacity.valueAt(const Duration(seconds: 1)), 0.9);
      // A marca de 1 s do projeto ficou do lado de la; na segunda metade
      // ela vira o valor do instante zero.
      expect(segunda.opacity.hasKeyframeAt(Duration.zero), isTrue);
    });

    test('a primeira metade fica intacta', () {
      final m = _motor();
      m.e.addTextLayer(Duration.zero, text: 'Um');
      final id = m.c.read(editorControllerProvider).layers.single.id;
      m.e.toggleKeyframe(id, const Duration(seconds: 1), LayerProp.opacity);
      m.e.editOpacity(id, const Duration(seconds: 1), 0.3);

      m.e.splitLayer(id, const Duration(seconds: 2));
      final primeira = m.c.read(editorControllerProvider).layerById(id)!;
      expect(primeira.opacity.hasKeyframeAt(const Duration(seconds: 1)), isTrue);
      expect(primeira.opacity.valueAt(const Duration(seconds: 1)), 0.3);
    });
  });

  group('a barra temporal da camada', () {
    // A BARRA MONTADA SOZINHA, com o relogio do teste. A tela cria o
    // proprio `PlaybackController` la dentro, e um segundo relogio no
    // teste nunca moveria o cabecote que a barra le.
    Future<({ProviderContainer c, PlaybackController p})> montar(
      WidgetTester tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final playback = PlaybackController(
        vsync: _Vsync(),
        durationOf: () => container.read(editorControllerProvider).duration,
      );
      addTearDown(playback.dispose);
      final camada = container.read(editorControllerProvider).layers.single;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: BarraTemporalDaCamada(
                  camada: camada,
                  playback: playback,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (c: container, p: playback);
    }

    testWidgets('as tres acoes temporais estao a UM toque', (tester) async {
      await montar(tester);
      expect(find.bySemanticsLabel('Dividir no cabecote'), findsOneWidget);
      expect(find.bySemanticsLabel('Velocidade'), findsOneWidget);
      expect(find.bySemanticsLabel('Som'), findsOneWidget);
    });

    testWidgets('os simbolos respondem ao cabecote', (tester) async {
      final m = await montar(tester);
      // Cabecote na borda: nao ha o que dividir nem ate onde aparar, e a
      // alca vira "levar o cabecote ate a camada".
      expect(
        find.bySemanticsLabel('Levar o cabecote ate o comeco da camada'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Aparar o comeco ate o cabecote'),
        findsNothing,
      );

      await tester.tap(find.bySemanticsLabel('Dividir no cabecote'));
      await tester.pump();
      expect(
        m.c.read(editorControllerProvider).layers.length,
        1,
        reason: 'com o cabecote na borda, dividir esta apagado e nao age',
      );

      // Com o cabecote DENTRO, os tres alvos trocam de sentido.
      m.p.seek(const Duration(seconds: 2));
      await tester.pump();
      expect(
        find.bySemanticsLabel('Aparar o comeco ate o cabecote'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Aparar o fim ate o cabecote'),
        findsOneWidget,
      );
    });

    testWidgets('dividir pela barra corta de verdade', (tester) async {
      final m = await montar(tester);
      m.p.seek(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Dividir no cabecote'));
      await tester.pump();

      final camadas = m.c.read(editorControllerProvider).layers;
      expect(camadas.length, 2);
      expect(
        camadas.map((l) => l.startTime).toSet(),
        {Duration.zero, const Duration(seconds: 2)},
      );
    });

    testWidgets('aparar o comeco pela barra encurta a camada', (tester) async {
      final m = await montar(tester);
      m.p.seek(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Aparar o comeco ate o cabecote'));
      await tester.pump();

      final camada = m.c.read(editorControllerProvider).layers.single;
      expect(camada.startTime, const Duration(seconds: 2));
    });
  });
}
