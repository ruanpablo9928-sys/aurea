// O SOM: volume, entrada, saida, mudo, emparelhar e batidas.
//
// O cartao existia so para video e chamava-se "Volume" porque so havia
// volume. Tudo o resto ja estava no motor e sem porta nenhuma:
// `updateAudioSpec` (fades, mudo, ganho), `normalizeAudio` e a familia
// inteira de batida.
//
// A camada de AUDIO ficava de fora por um `is!`: `editVideoVolume`
// recusa o que nao for video, e o cartao seguia o comando. O campo
// `volume` sempre esteve na camada, o mixer sempre leu e a exportacao
// sempre respeitou.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/audio_mix.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/mapa_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

Future<_Bancada> _montar(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  final id = c.addAudioLayer(
    Duration.zero,
    'musica.m4a',
    'Musica',
    const Duration(seconds: 10),
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
                categoriaId: 'som',
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

Future<void> _digitar(
  WidgetTester tester,
  String rotulo,
  String valor,
) async {
  await tester.tap(find.bySemanticsLabel('Valor de $rotulo'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).last, valor);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
  await tester.pumpAndSettle();
}

void main() {
  group('o cartao', () {
    test('a camada de audio ganhou o cartao de som', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addAudioLayer(
        Duration.zero,
        'som.m4a',
        'Som',
        const Duration(seconds: 4),
      );
      final camada = container.read(editorControllerProvider).layers.single;
      expect(categoriasDaCamada(camada).map((x) => x.id), contains('som'));
    });

    test('camada de texto nao tem, porque nao tem som', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      expect(
        categoriasDaCamada(camada).map((x) => x.id),
        isNot(contains('som')),
      );
    });
  });

  group('volume da camada de audio', () {
    testWidgets('digitar muda o volume de verdade', (tester) async {
      final m = await _montar(tester);
      expect((_camada(m.c, m.id) as AudioLayer).volume, 1);

      await _digitar(tester, 'Volume', '40');
      expect((_camada(m.c, m.id) as AudioLayer).volume, closeTo(.4, .01));
    });
  });

  group('entrada e saida', () {
    testWidgets('os dois fades entram no spec', (tester) async {
      final m = await _montar(tester);
      await _digitar(tester, 'Aparecer', '1,5');
      await _digitar(tester, 'Sumir', '2');

      final spec = audioSpecOf(_camada(m.c, m.id))!;
      expect(spec.fadeIn, const Duration(milliseconds: 1500));
      expect(spec.fadeOut, const Duration(seconds: 2));
    });

    testWidgets('o fade nao passa da metade do clipe', (tester) async {
      final m = await _montar(tester);
      // O clipe tem 10 s. Pedir 30 s de entrada faria o som sumir sem
      // nunca ter aparecido.
      await _digitar(tester, 'Aparecer', '30');
      expect(audioSpecOf(_camada(m.c, m.id))!.fadeIn.inSeconds, 5);
    });

    testWidgets('o fade abaixa o ganho de verdade no mixer', (tester) async {
      final m = await _montar(tester);
      await _digitar(tester, 'Aparecer', '2');
      final l = _camada(m.c, m.id);

      // No comeco do fade o ganho e zero; depois dele, cheio.
      expect(layerAudioGainAt(l, Duration.zero), lessThan(.05));
      expect(
        layerAudioGainAt(l, const Duration(seconds: 4)),
        closeTo(1, .01),
      );
    });
  });

  group('mudo', () {
    testWidgets('zera o ganho sem sumir com a camada', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Tirar o som desta camada'));
      await tester.pump();

      final l = _camada(m.c, m.id);
      expect(audioSpecOf(l)!.muted, isTrue);
      expect(layerAudioGainAt(l, const Duration(seconds: 5)), 0);
      expect(
        m.c.read(editorControllerProvider).metaOf(m.id).hidden,
        isFalse,
        reason: 'mudo nao e olho fechado: guarda a imagem e larga o som',
      );
    });
  });

  group('a onda na trilha', () {
    testWidgets('a pilha aguenta um arquivo que nao da para analisar', (
      tester,
    ) async {
      // A onda so aparece quando a analise fica pronta, e a analise
      // pode nunca ficar: arquivo movido, formato que o decodificador
      // recusa, aparelho sem espaco. O desenho pede a piramide e segue
      // com o clipe liso — o que nao pode e a pilha quebrar por causa
      // de um arquivo.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addAudioLayer(
        Duration.zero,
        'nao-existe.m4a',
        'Musica',
        const Duration(seconds: 10),
      );
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
              body: SizedBox(
                height: 200,
                child: VisaoGeralDasCamadas(
                  playback: playback,
                  mapa: (t) => MapaDoTempo(
                    tempo: t,
                    largura: 360,
                    pxPorSegundo: MapaDoTempo.zoomPadrao,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(VisaoGeralDasCamadas), findsOneWidget);
    });
  });

  group('batidas', () {
    testWidgets('sem batidas, os comandos que dependem delas nao aparecem', (
      tester,
    ) async {
      await _montar(tester);
      expect(find.bySemanticsLabel('Achar as batidas'), findsOneWidget);
      expect(find.bySemanticsLabel('Cortar tudo nas batidas'), findsNothing);
      expect(find.bySemanticsLabel('Tirar as batidas'), findsNothing);
    });

    testWidgets('com batidas, o painel diz quantas e oferece o corte', (
      tester,
    ) async {
      final m = await _montar(tester);
      // O detector precisa do arquivo; aqui o que se cobra e a PORTA —
      // que a grade, uma vez achada, apareca e possa ser usada.
      m.c.read(editorControllerProvider.notifier).setBpm(120);
      await tester.pump();

      expect(find.textContaining('120 BPM'), findsOneWidget);
      expect(find.bySemanticsLabel('Cortar tudo nas batidas'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Tirar as batidas'));
      await tester.pump();
      expect(m.c.read(editorControllerProvider).beats, isEmpty);
      expect(find.bySemanticsLabel('Cortar tudo nas batidas'), findsNothing);
    });
  });
}
