// O MODELO DE TEMPO DA LINHA DO TEMPO.
//
// A regra que estes testes protegem saiu de medir o Alight Motion real
// quadro a quadro (`docs/linha-do-tempo-alight.md`): a escala e
// CONSTANTE, o cabecote fica PARADO no meio da largura, e quem anda e o
// conteudo.
//
// O modelo anterior — espremer a composicao inteira na largura — fica
// registrado aqui pelo que ele quebrava: um clipe de dois segundos num
// projeto de tres minutos virava um risco de quatro pixels, e a mesma
// camada mudava de tamanho na tela so porque OUTRA camada esticou a
// duracao. Se algum destes testes voltar a falhar, e porque a conta
// velha voltou.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
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

Future<({ProviderContainer c, PlaybackController p})> _montar(
  WidgetTester tester, {
  int camadas = 3,
  ModoDaLinhaDoTempo modo = ModoDaLinhaDoTempo.geral,
  double? zoom = _escala,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < camadas; i++) {
    c.addTextLayer(Duration.zero, text: 'Camada ${i + 1}');
  }
  container.read(modoDaLinhaDoTempoProvider.notifier).state = modo;
  // SEM CAMADA ESCOLHIDA, de proposito.
  //
  // Este arquivo cobra NAVEGAR no tempo, e arrastar sobre o clipe JA
  // escolhido move o clipe — e a regra que faz os dois gestos caberem na
  // mesma superficie. Criar camada ja seleciona, entao a selecao precisa
  // ser limpa para o arrasto voltar a ser navegacao.
  container.read(selectedLayerProvider.notifier).state = null;
  if (zoom != null) {
    container.read(zoomDaLinhaDoTempoProvider.notifier).state = zoom;
  }
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
  return (c: container, p: playback);
}

void main() {
  group('a conta de tempo para pixel', () {
    test('o cabecote mora no meio da largura', () {
      const m = MapaDoTempo(
        largura: 400,
        pxPorSegundo: 50,
        tempo: Duration(seconds: 7),
      );
      expect(m.ancora, 200);
      expect(
        m.xDe(const Duration(seconds: 7)),
        200,
        reason: 'o instante atual E a ancora, seja qual for o valor dele',
      );
    });

    test('cada segundo vale sempre a mesma distancia', () {
      const m = MapaDoTempo(
        largura: 400,
        pxPorSegundo: 50,
        tempo: Duration(seconds: 7),
      );
      expect(m.xDe(const Duration(seconds: 8)), 250);
      expect(m.xDe(const Duration(seconds: 6)), 150);
      // E MESMO NUM PROJETO DE OUTRA DURACAO: o mapa nem sabe qual e a
      // duracao. Era exatamente isso que o modelo velho nao conseguia
      // prometer.
      expect(m.larguraDe(const Duration(seconds: 2)), 100);
    });

    test('ir de pixel para tempo desfaz ir de tempo para pixel', () {
      const m = MapaDoTempo(
        largura: 360,
        pxPorSegundo: 37,
        tempo: Duration(milliseconds: 4321),
      );
      for (final ms in [0, 1000, 4321, 9999]) {
        final t = Duration(milliseconds: ms);
        expect(
          m.tempoEm(m.xDe(t)).inMilliseconds,
          closeTo(ms, 1),
          reason: 'a volta nao caiu no mesmo instante para $ms ms',
        );
      }
    });

    test('a escala que enquadra poe a composicao inteira na largura', () {
      final z = MapaDoTempo.zoomQueCabe(600, const Duration(seconds: 10));
      expect(z, 60);
      const m = MapaDoTempo(
        largura: 600,
        pxPorSegundo: 60,
        tempo: Duration(seconds: 5),
      );
      expect(m.inicioVisivel, Duration.zero);
      expect(m.fimVisivel, const Duration(seconds: 10));
    });

    test('a escala tem chao e teto', () {
      // Um projeto de duas horas numa tela de celular pediria uma
      // escala em que nada e visivel; o chao segura.
      expect(
        MapaDoTempo.zoomQueCabe(360, const Duration(hours: 2)),
        MapaDoTempo.zoomMinimo,
      );
      expect(
        MapaDoTempo.zoomQueCabe(360, const Duration(milliseconds: 200)),
        MapaDoTempo.zoomMaximo,
      );
      // Duracao invalida nao pode virar NaN nem infinito no meio de um
      // calculo de layout.
      expect(MapaDoTempo.zoomQueCabe(360, Duration.zero), isPositive);
      expect(MapaDoTempo.prender(double.nan), MapaDoTempo.zoomPadrao);
    });
  });

  group('o cabecote nao anda', () {
    testWidgets('ele fica no meio, seja qual for o instante', (tester) async {
      final m = await _montar(tester);
      final antes = tester.getRect(find.byKey(const ValueKey('cabecote')));
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      expect(
        antes.center.dx,
        closeTo(faixa.center.dx, 1),
        reason: 'o cabecote nasceu fora do meio',
      );

      m.p.seek(const Duration(seconds: 3));
      await tester.pump();
      final depois = tester.getRect(find.byKey(const ValueKey('cabecote')));
      expect(
        depois,
        antes,
        reason:
            'o cabecote se mexeu com o relogio: quem tinha de andar era o '
            'conteudo',
      );
    });

    testWidgets('ele desce da regua ate o pe das trilhas', (tester) async {
      await _montar(tester);
      final cabecote = tester.getRect(find.byKey(const ValueKey('cabecote')));
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      expect(cabecote.top, faixa.top + LinhaDoTempo.alturaDoTransporte);
      expect(cabecote.bottom, faixa.bottom);
    });
  });

  group('arrastar navega no tempo', () {
    testWidgets('arrastar as trilhas para a esquerda avanca', (tester) async {
      final m = await _montar(tester);
      expect(m.p.time.value, Duration.zero);
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      final y =
          faixa.top +
          LinhaDoTempo.alturaDoTransporte +
          LinhaDoTempo.alturaDaRegua +
          10;

      final gesto = await tester.startGesture(Offset(faixa.center.dx, y));
      // O PRIMEIRO PASSO E GASTO NO RECONHECIMENTO. So depois de uns
      // dezoito pixels o Flutter decide que aquilo e um arrasto
      // horizontal, e e desse ponto que a conta parte. No aparelho o
      // dedo produz dezenas de eventos e a zona morta some no gesto;
      // aqui ela precisa ser pedida.
      await gesto.moveBy(const Offset(-20, 0));
      await tester.pump();
      await gesto.moveBy(const Offset(-120, 0));
      await tester.pump();
      await gesto.up();
      await tester.pump();

      expect(
        m.p.time.value.inMilliseconds,
        closeTo(120 / _escala * 1000, 60),
        reason:
            'empurrar o conteudo cento e vinte pixels para a esquerda tem '
            'de andar dois segundos, nesta escala',
      );
    });

    testWidgets('arrastar para a direita volta, e para no zero', (
      tester,
    ) async {
      final m = await _montar(tester);
      m.p.seek(const Duration(milliseconds: 500));
      await tester.pump();
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      final y =
          faixa.top +
          LinhaDoTempo.alturaDoTransporte +
          LinhaDoTempo.alturaDaRegua +
          10;

      final gesto = await tester.startGesture(Offset(faixa.center.dx, y));
      await gesto.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesto.moveBy(const Offset(300, 0));
      await tester.pump();
      await gesto.up();
      await tester.pump();

      expect(
        m.p.time.value,
        Duration.zero,
        reason: 'antes do zero nao ha composicao para mostrar',
      );
    });
  });

  group('a escala', () {
    testWidgets('sem escolha, a composicao ja aparece inteira', (
      tester,
    ) async {
      final m = await _montar(tester, zoom: null);
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      final duracao = m.c.read(editorControllerProvider).duration;
      expect(
        LinhaDoTempo.zoomPara(
          m.c.read(zoomDaLinhaDoTempoProvider),
          faixa.width,
          duracao,
        ),
        MapaDoTempo.zoomQueCabe(faixa.width, duracao),
      );
    });

    testWidgets('escolhida, ela nao muda quando o projeto estica', (
      tester,
    ) async {
      final m = await _montar(tester, zoom: 90);
      // Uma camada nova la na frente dobra a duracao do projeto.
      m.c
          .read(editorControllerProvider.notifier)
          .addTextLayer(const Duration(seconds: 20), text: 'Tarde');
      await tester.pump();
      expect(
        m.c.read(zoomDaLinhaDoTempoProvider),
        90,
        reason:
            'a escala escolhida pela pessoa nao pode ser desfeita por uma '
            'edicao — era esse o defeito do modelo antigo',
      );
    });

    testWidgets('enquadrar devolve a escala que faz tudo caber', (
      tester,
    ) async {
      final m = await _montar(tester, zoom: 300);
      await tester.tap(find.bySemanticsLabel('Enquadrar'));
      await tester.pump();
      final faixa = tester.getRect(find.byType(LinhaDoTempo));
      final duracao = m.c.read(editorControllerProvider).duration;
      expect(
        m.c.read(zoomDaLinhaDoTempoProvider),
        MapaDoTempo.zoomQueCabe(faixa.width, duracao),
      );
    });
  });
}
