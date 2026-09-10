// ARRUMAR O CONTEUDO NO TEMPO: mover e aparar clipe na pilha.
//
// Sem isto o editor nao e um editor — da para criar camada e animar
// propriedade, mas nao para dizer QUANDO cada coisa acontece.
//
// A regra que estes testes protegem: mover e aparar so valem no clipe JA
// ESCOLHIDO. Se qualquer clipe respondesse ao arrasto, navegar no tempo
// viraria sorte, porque quase toda a largura da pilha tem clipe em cima.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/mapa_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

const _escala = 60.0;

Future<({ProviderContainer c, PlaybackController p, String id})> _montar(
  WidgetTester tester, {
  bool selecionar = true,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.addTextLayer(const Duration(seconds: 1), text: 'Alvo');
  c.addTextLayer(const Duration(seconds: 1), text: 'Outra');
  final alvo = container
      .read(editorControllerProvider)
      .layers
      .firstWhere((l) => l.name == 'Alvo');
  container.read(selectedLayerProvider.notifier).state = selecionar
      ? alvo.id
      : null;
  container.read(modoDaLinhaDoTempoProvider.notifier).state =
      ModoDaLinhaDoTempo.geral;
  container.read(zoomDaLinhaDoTempoProvider.notifier).state = _escala;

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
          body: Column(
            children: [const Spacer(), LinhaDoTempo(playback: playback)],
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback, id: alvo.id);
}

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

/// O ponto na tela de um instante, na trilha [linha].
///
/// A conta e a do [MapaDoTempo]: cabecote parado no meio da largura, e
/// cada segundo de distancia dele vale [_escala] pixels.
Offset _pontoNaTrilha(
  WidgetTester tester,
  Duration quando,
  int linha, {
  double folga = 0,
}) {
  final faixa = tester.getRect(find.byType(LinhaDoTempo));
  final mapa = MapaDoTempo(
    largura: faixa.width,
    pxPorSegundo: _escala,
    tempo: Duration.zero,
  );
  final topo =
      faixa.top + LinhaDoTempo.alturaDoTransporte + LinhaDoTempo.alturaDaRegua;
  return Offset(
    faixa.left + mapa.xDe(quando) + folga,
    topo +
        linha * VisaoGeralDasCamadas.alturaDaTrilha +
        VisaoGeralDasCamadas.alturaDaTrilha / 2,
  );
}

/// Em que linha da pilha mora a camada [id].
int _linhaDe(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.indexWhere((l) => l.id == id);

Future<void> _arrastar(WidgetTester tester, Offset de, double dx) async {
  final gesto = await tester.startGesture(de);
  // O PRIMEIRO PASSO E GASTO NO RECONHECIMENTO. So depois de uns dezoito
  // pixels o Flutter decide que aquilo e um arrasto horizontal, e a
  // conta parte DESSE ponto — entao ele nao conta como deslocamento. No
  // aparelho o dedo produz dezenas de eventos e a zona morta some no
  // gesto; aqui ela precisa ser pedida.
  await gesto.moveBy(const Offset(20, 0));
  await tester.pump();
  await gesto.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesto.up();
  await tester.pump();
}

void main() {
  group('mover o clipe no tempo', () {
    testWidgets('arrastar o clipe ESCOLHIDO muda quando ele entra', (
      tester,
    ) async {
      final m = await _montar(tester);
      final antes = _camada(m.c, m.id).startTime;
      final duracao = _camada(m.c, m.id).duration;
      expect(antes, const Duration(seconds: 1));

      final linha = _linhaDe(m.c, m.id);
      // Bem dentro do clipe, longe das duas pontas.
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, const Duration(seconds: 2), linha),
        60,
      );

      expect(
        _camada(m.c, m.id).startTime.inMilliseconds,
        closeTo(2000, 120),
        reason: 'sessenta pixels nesta escala sao um segundo',
      );
      expect(
        _camada(m.c, m.id).duration,
        duracao,
        reason: 'mover nao estica nem encolhe a camada',
      );
    });

    testWidgets('o clipe NAO escolhido nao se move: o dedo navega', (
      tester,
    ) async {
      final m = await _montar(tester, selecionar: false);
      final antes = _camada(m.c, m.id).startTime;
      expect(m.p.time.value, Duration.zero);

      final linha = _linhaDe(m.c, m.id);
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, const Duration(seconds: 2), linha),
        -60,
      );

      expect(
        _camada(m.c, m.id).startTime,
        antes,
        reason: 'sem escolher, arrastar num clipe e navegar no tempo',
      );
      expect(
        m.p.time.value.inMilliseconds,
        greaterThan(400),
        reason: 'e o cabecote tem de ter andado',
      );
    });

    testWidgets('um arrasto, um desfazer', (tester) async {
      final m = await _montar(tester);
      final antes = _camada(m.c, m.id).startTime;
      final linha = _linhaDe(m.c, m.id);
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, const Duration(seconds: 2), linha),
        90,
      );
      expect(_camada(m.c, m.id).startTime, isNot(antes));

      m.c.read(editorControllerProvider.notifier).undo();
      await tester.pump();
      expect(
        _camada(m.c, m.id).startTime,
        antes,
        reason:
            'o arrasto manda dezenas de posicoes; desfazer devolve o '
            'movimento INTEIRO',
      );
    });

    testWidgets('o clipe nao entra antes do zero', (tester) async {
      final m = await _montar(tester);
      final linha = _linhaDe(m.c, m.id);
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, const Duration(seconds: 2), linha),
        -600,
      );
      expect(_camada(m.c, m.id).startTime, Duration.zero);
    });
  });

  group('aparar as pontas', () {
    testWidgets('arrastar a ponta ESQUERDA muda o inicio, e nao o fim', (
      tester,
    ) async {
      final m = await _montar(tester);
      final fimAntes = _camada(m.c, m.id).endTime;
      final linha = _linhaDe(m.c, m.id);
      // Em cima da propria borda de entrada.
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, const Duration(seconds: 1), linha, folga: 2),
        60,
      );

      final l = _camada(m.c, m.id);
      expect(
        l.startTime.inMilliseconds,
        closeTo(2000, 150),
        reason: 'a ponta esquerda apara a entrada',
      );
      expect(
        l.endTime,
        fimAntes,
        reason: 'aparar a entrada nao pode mexer na saida',
      );
    });

    testWidgets('arrastar a ponta DIREITA muda o fim, e nao o inicio', (
      tester,
    ) async {
      final m = await _montar(tester);
      final inicioAntes = _camada(m.c, m.id).startTime;
      final fimAntes = _camada(m.c, m.id).endTime;
      final linha = _linhaDe(m.c, m.id);
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, fimAntes, linha, folga: -2),
        -60,
      );

      final l = _camada(m.c, m.id);
      expect(l.startTime, inicioAntes);
      expect(
        l.endTime.inMilliseconds,
        closeTo(fimAntes.inMilliseconds - 1000, 150),
        reason: 'a ponta direita apara a saida',
      );
    });

    testWidgets('aparar nunca deixa a camada com duracao zero', (tester) async {
      final m = await _montar(tester);
      final linha = _linhaDe(m.c, m.id);
      final fim = _camada(m.c, m.id).endTime;
      await _arrastar(
        tester,
        _pontoNaTrilha(tester, fim, linha, folga: -2),
        -900,
      );
      expect(
        _camada(m.c, m.id).duration,
        greaterThan(Duration.zero),
        reason: 'uma camada de duracao zero e invisivel e intocavel',
      );
    });
  });
}
