// VELOCIDADE, E A ALCA QUE PASSAVA DO FIM DO ARQUIVO.
//
// Dois assuntos no mesmo teste porque sao o mesmo defeito visto de dois
// lados: a camada nao guardava quanto o ARQUIVO tem. A duracao real
// chegava do probe no import e era jogada fora; sobrava so quanto do
// arquivo estava em uso.
//
// Sem essa medida, `trimLayerEnd` nao tinha contra o que travar —
// arrastar a ponta direita esticava o clipe para alem da midia, e o
// resultado era quadro parado (ou silencio) ate o fim da barra, sem
// nada na tela dizendo que aquilo tinha acabado.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

/// Um clipe de audio de 10 s vindo de um arquivo de 10 s.
Future<_Bancada> _montar(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  final id = c.addAudioLayer(
    Duration.zero,
    'musica.m4a',
    'Musica',
    const Duration(seconds: 10),
    fonte: const Duration(seconds: 10),
  );
  container.read(selectedLayerProvider.notifier).state = id;

  final playback = PlaybackController(
    vsync: _Vsync(),
    durationOf: () => container.read(editorControllerProvider).duration,
  );
  addTearDown(playback.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final atual = ref
                  .watch(editorControllerProvider)
                  .layers
                  .where((l) => l.id == id)
                  .firstOrNull;
              if (atual == null) return const SizedBox.shrink();
              return ControlesDaCategoria(
                categoriaId: 'velocidade',
                camada: atual,
                playback: playback,
                aoVoltar: () {},
              );
            },
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback, id: id);
}

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

void main() {
  group('a alca nao passa do arquivo', () {
    late ProviderContainer container;
    late EditorController c;
    late String id;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      c = container.read(editorControllerProvider.notifier);
      id = c.addAudioLayer(
        Duration.zero,
        'musica.m4a',
        'Musica',
        const Duration(seconds: 10),
        fonte: const Duration(seconds: 10),
      );
    });

    test('esticar a ponta direita para na duracao da fonte', () {
      c.trimLayerEnd(id, const Duration(seconds: 30));
      expect(
        _camada(container, id).duration,
        const Duration(seconds: 10),
        reason: 'o clipe ficou mais longo que a midia que ele mostra',
      );
    });

    test('encurtar continua livre', () {
      c.trimLayerEnd(id, const Duration(seconds: 4));
      expect(_camada(container, id).duration, const Duration(seconds: 4));
    });

    test('depois de aparar o comeco, o teto anda junto', () {
      // Cortar 3 s do inicio deixa 7 s de arquivo pela frente.
      c.trimLayerStart(id, const Duration(seconds: 3));
      expect(
        (_camada(container, id) as AudioLayer).sourceOffset,
        const Duration(seconds: 3),
      );

      c.trimLayerEnd(id, const Duration(seconds: 30));
      expect(_camada(container, id).duration, const Duration(seconds: 7));
    });

    test('a ponta esquerda nao vai para tras do comeco do arquivo', () {
      c.moveLayer(id, const Duration(seconds: 5));
      c.trimLayerStart(id, Duration.zero);
      final l = _camada(container, id) as AudioLayer;
      expect(
        l.sourceOffset,
        Duration.zero,
        reason: 'o recuo ja era travado em zero',
      );
      expect(
        l.duration,
        const Duration(seconds: 10),
        reason: 'a duracao continuava crescendo com o recuo parado no zero',
      );
    });

    test('acelerar encolhe o teto na mesma medida', () {
      c.setClipSpeed(id, 2);
      // 10 s de arquivo a 2x sao 5 s de barra.
      expect(_camada(container, id).duration, const Duration(seconds: 5));
      c.trimLayerEnd(id, const Duration(seconds: 30));
      expect(_camada(container, id).duration, const Duration(seconds: 5));
    });

    test('sem a medida da fonte, nao ha teto — como antes', () {
      final semMedida = c.addAudioLayer(
        Duration.zero,
        'outra.m4a',
        'Outra',
        const Duration(seconds: 10),
      );
      c.trimLayerEnd(semMedida, const Duration(seconds: 30));
      expect(
        _camada(container, semMedida).duration,
        const Duration(seconds: 30),
        reason: 'projeto antigo nao guardava a medida; travar seria inventar',
      );
    });
  });

  group('a medida da fonte sobrevive ao arquivo do projeto', () {
    test('ida e volta pelo JSON', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addAudioLayer(
        Duration.zero,
        'musica.m4a',
        'Musica',
        const Duration(seconds: 4),
        fonte: const Duration(seconds: 42),
      );
      final projeto = container.read(editorControllerProvider);
      final volta = projectFromJson(projectToJson(projeto));
      expect(
        (volta.layers.single as AudioLayer).sourceDuration,
        const Duration(seconds: 42),
      );
    });

    test('projeto antigo, sem o campo, continua abrindo', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addAudioLayer(
        Duration.zero,
        'musica.m4a',
        'Musica',
        const Duration(seconds: 4),
        fonte: const Duration(seconds: 42),
      );
      final json = projectToJson(container.read(editorControllerProvider));
      (json['layers'] as List).cast<Map<String, dynamic>>().single.remove(
        'srcDur',
      );
      final volta = projectFromJson(json);
      expect((volta.layers.single as AudioLayer).sourceDuration, isNull);
    });
  });

  group('o painel de velocidade', () {
    testWidgets('o cartao existe para video e audio, e nao para texto', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      final audio = c.addAudioLayer(
        Duration.zero,
        'm.m4a',
        'M',
        const Duration(seconds: 4),
      );
      c.addTextLayer(Duration.zero, text: 'Um');
      final projeto = container.read(editorControllerProvider);
      final camadaAudio = projeto.layers.firstWhere((l) => l.id == audio);
      final texto = projeto.layers.firstWhere((l) => l.id != audio);
      expect(
        categoriasDaCamada(camadaAudio).map((x) => x.id),
        contains('velocidade'),
      );
      expect(
        categoriasDaCamada(texto).map((x) => x.id),
        isNot(contains('velocidade')),
      );
    });

    testWidgets('um atalho muda a velocidade e a duracao junto', (
      tester,
    ) async {
      final m = await _montar(tester);
      expect(_camada(m.c, m.id).duration, const Duration(seconds: 10));

      await tester.tap(find.bySemanticsLabel('Atalhos 2x'));
      await tester.pump();

      expect((_camada(m.c, m.id) as AudioLayer).speed, 2);
      expect(
        _camada(m.c, m.id).duration,
        const Duration(seconds: 5),
        reason: 'a barra mostra o tempo FINAL: acelerar encurta a barra',
      );
    });

    testWidgets('voltar para 1x devolve o clipe inteiro', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Atalhos 4x'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Atalhos 1x'));
      await tester.pump();

      expect((_camada(m.c, m.id) as AudioLayer).speed, 1);
      expect(_camada(m.c, m.id).duration, const Duration(seconds: 10));
    });

    testWidgets('o tom pode subir e descer, e o controle avisa', (
      tester,
    ) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Mantendo o tom da voz'));
      await tester.pump();

      final l = _camada(m.c, m.id) as AudioLayer;
      expect(l.audio.preservePitch, isFalse);
      expect(
        find.bySemanticsLabel('Deixar o tom subir e descer'),
        findsOneWidget,
      );
    });

    testWidgets('a camada de audio nao ganha rampa nem inversao', (
      tester,
    ) async {
      await _montar(tester);
      // Sao comandos que o motor recusa fora de video (`is! VideoLayer`);
      // oferece-los aqui seria um botao que aceita o toque e nao faz
      // nada.
      expect(find.bySemanticsLabel('Tocar de tras para a frente'), findsNothing);
      expect(find.bySemanticsLabel('Impacto'), findsNothing);
    });
  });
}
