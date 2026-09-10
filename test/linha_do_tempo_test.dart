// A LINHA DO TEMPO NOVA: UMA CAMADA POR VEZ.
//
// A timeline anterior empilhava todas as camadas e era o pedaco da
// interface que mais dava problema num celular. A nova segue o modelo do
// Alight Motion: mostra a camada SELECIONADA sozinha, com a largura
// inteira, e a troca de camada sai pelas setas nas pontas da trilha.
//
// Estes testes cobram o que essa decisao implica — se a trilha volta a
// mostrar varias camadas, ou se a seta some, o modelo quebrou.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Monta a linha do tempo sozinha, com um projeto de verdade por tras.
Future<ProviderContainer> _montar(
  WidgetTester tester, {
  required int camadas,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final controller = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < camadas; i++) {
    controller.addTextLayer(Duration.zero, text: 'Camada ${i + 1}');
  }
  // A LINHA DO TEMPO ABRE NA PILHA; este arquivo cobra o DETALHADO.
  container.read(modoDaLinhaDoTempoProvider.notifier).state =
      ModoDaLinhaDoTempo.detalhado;
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
            children: [
              const Spacer(),
              LinhaDoTempo(playback: playback),
            ],
          ),
        ),
      ),
    ),
  );
  return container;
}

void main() {
  testWidgets('o transporte tem os cinco controles, e o play e o maior', (
    tester,
  ) async {
    await _montar(tester, camadas: 1);
    for (final rotulo in ['Desfazer', 'Refazer', 'Inicio', 'Fim']) {
      expect(
        find.bySemanticsLabel(rotulo),
        findsOneWidget,
        reason: 'faltou o controle "$rotulo" no transporte',
      );
    }
    expect(find.bySemanticsLabel('Reproduzir'), findsOneWidget);

    final play = tester.widget<Icon>(
      find.descendant(
        of: find.bySemanticsLabel('Reproduzir'),
        matching: find.byType(Icon),
      ),
    );
    final inicio = tester.widget<Icon>(
      find.descendant(
        of: find.bySemanticsLabel('Inicio'),
        matching: find.byType(Icon),
      ),
    );
    expect(
      play.size! > inicio.size!,
      isTrue,
      reason:
          'o play e o alvo que a mao mais repete: ele tem de ser maior '
          'que os saltos ao lado',
    );
  });

  testWidgets('com uma camada so, nao ha seta para lugar nenhum', (
    tester,
  ) async {
    final container = await _montar(tester, camadas: 1);
    final projeto = container.read(editorControllerProvider);
    container.read(selectedLayerProvider.notifier).state =
        projeto.layers.single.id;
    await tester.pump();

    expect(find.bySemanticsLabel('Camada anterior'), findsNothing);
    expect(find.bySemanticsLabel('Proxima camada'), findsNothing);
  });

  testWidgets('a seta troca a camada selecionada, e some na ponta', (
    tester,
  ) async {
    final container = await _montar(tester, camadas: 3);
    final camadas = container.read(editorControllerProvider).layers;
    expect(camadas.length, 3);

    // Comeca na primeira: so ha caminho para a frente.
    container.read(selectedLayerProvider.notifier).state = camadas.first.id;
    await tester.pump();
    expect(
      find.bySemanticsLabel('Camada anterior'),
      findsNothing,
      reason: 'na primeira camada nao existe anterior',
    );
    expect(find.bySemanticsLabel('Proxima camada'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Proxima camada'));
    await tester.pump();
    expect(container.read(selectedLayerProvider), camadas[1].id);

    // No meio, os dois lados existem.
    expect(find.bySemanticsLabel('Camada anterior'), findsOneWidget);
    expect(find.bySemanticsLabel('Proxima camada'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Camada anterior'));
    await tester.pump();
    expect(container.read(selectedLayerProvider), camadas.first.id);
  });

  testWidgets('o olho esconde e mostra a camada selecionada', (tester) async {
    final container = await _montar(tester, camadas: 1);
    final id = container.read(editorControllerProvider).layers.single.id;
    container.read(selectedLayerProvider.notifier).state = id;
    await tester.pump();

    expect(container.read(editorControllerProvider).metaOf(id).hidden, isFalse);
    await tester.tap(find.bySemanticsLabel('Esconder camada'));
    await tester.pump();
    expect(container.read(editorControllerProvider).metaOf(id).hidden, isTrue);

    // O rotulo acompanha o estado — quem nao enxerga o icone depende dele.
    expect(find.bySemanticsLabel('Mostrar camada'), findsOneWidget);
  });

  testWidgets('tocar na faixa move o cabecote no tempo', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .addTextLayer(Duration.zero, text: 'Um');
    container.read(modoDaLinhaDoTempoProvider.notifier).state =
        ModoDaLinhaDoTempo.detalhado;
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

    expect(playback.time.value, Duration.zero);
    final faixa = tester.getRect(find.byType(LinhaDoTempo));
    // Um toque perto do fim da faixa tem de levar o cabecote para perto
    // do fim da composicao. A REGUA fica logo abaixo do transporte, e e
    // ela que navega no tempo — mirar no rodape da faixa cai no vazio
    // sob a trilha.
    await tester.tapAt(Offset(faixa.right - 12, faixa.top + 70));
    await tester.pump();
    final duracao = container.read(editorControllerProvider).duration;
    expect(
      playback.time.value.inMilliseconds,
      greaterThan((duracao.inMilliseconds * 0.5).round()),
      reason: 'tocar perto do fim tem de levar o cabecote para perto do fim',
    );
  });

  testWidgets('sem camada selecionada a faixa nao quebra', (tester) async {
    await _montar(tester, camadas: 2);
    // Nada selecionado: a trilha fica vazia, o transporte continua de pe.
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Reproduzir'), findsOneWidget);
  });

  // ------------------------------------------------- keyframes

  /// Monta a faixa com uma camada de 5 s e keyframes em instantes
  /// conhecidos, e devolve o retangulo util da trilha para mirar o dedo.
  Future<({ProviderContainer c, String id, Rect faixa, PlaybackController p})>
  comKeyframes(WidgetTester tester, List<int> ms) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(editorControllerProvider.notifier);
    c.addTextLayer(Duration.zero, text: 'Um');
    final id = container.read(editorControllerProvider).layers.single.id;
    container.read(selectedLayerProvider.notifier).state = id;
    // Os losangos so existem no modo DETALHADO; na pilha os keyframes
    // sao riscos, e riscos nao se pegam.
    container.read(modoDaLinhaDoTempoProvider.notifier).state =
        ModoDaLinhaDoTempo.detalhado;
    container.read(autoKeyframeProvider.notifier).state = true;
    for (final m in ms) {
      c.editOpacity(id, Duration(milliseconds: m), m / 10000);
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
    return (
      c: container,
      id: id,
      faixa: tester.getRect(find.byType(LinhaDoTempo)),
      p: playback,
    );
  }

  /// Onde, na tela, esta o keyframe do instante local [ms].
  Offset pontoDoKeyframe(ProviderContainer c, Rect faixa, int ms) {
    final duracao = c.read(editorControllerProvider).duration;
    final camada = c.read(editorControllerProvider).layers.single;
    final quando = camada.startTime + Duration(milliseconds: ms);
    final util = faixa.width - LinhaDoTempo.larguraDaCabeca;
    final x =
        faixa.left +
        LinhaDoTempo.larguraDaCabeca +
        util * (quando.inMicroseconds / duracao.inMicroseconds);
    // A trilha e centrada no espaco que sobra depois da regua, e a
    // altura dela acompanha a da faixa. O centro vertical da area util
    // e uma mira estavel para qualquer altura.
    final alturaDaFaixa = faixa.height - 48;
    final centro = 48 + 46 + (alturaDaFaixa - 46) / 2;
    return Offset(x, faixa.top + centro);
  }

  testWidgets('tocar num keyframe leva o cabecote exatamente ate ele', (
    tester,
  ) async {
    final m = await comKeyframes(tester, [500, 2000]);
    expect(m.p.time.value, Duration.zero);

    await tester.tapAt(pontoDoKeyframe(m.c, m.faixa, 2000));
    await tester.pump();
    expect(
      m.p.time.value.inMilliseconds,
      closeTo(2000, 60),
      reason:
          'tocar na marca tem de cair EM CIMA dela: e assim que se edita '
          'o valor daquele instante',
    );
  });

  testWidgets('arrastar um keyframe muda o instante dele', (tester) async {
    final m = await comKeyframes(tester, [500, 2000]);
    final antes = m.c.read(editorControllerProvider).layers.single.keyframeTimes;
    expect(antes.map((t) => t.inMilliseconds), containsAll([500, 2000]));

    final de = pontoDoKeyframe(m.c, m.faixa, 2000);
    final gesto = await tester.startGesture(de);
    // O PRIMEIRO MOVIMENTO E GASTO no reconhecimento do gesto: dele sai
    // o `dragStart` e mais nada. Sem um segundo passo, nenhum `update`
    // chega e a marca nao anda — no aparelho o dedo produz dezenas de
    // eventos, aqui e preciso pedir.
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.up();
    await tester.pump();

    final depois =
        m.c.read(editorControllerProvider).layers.single.keyframeTimes;
    expect(
      depois.map((t) => t.inMilliseconds).contains(2000),
      isFalse,
      reason: 'a marca continuou no instante velho: o arrasto nao pegou',
    );
    expect(
      depois.length,
      antes.length,
      reason: 'arrastar move a marca, nao cria nem apaga',
    );
  });

  testWidgets('o keyframe nao escapa da propria camada', (tester) async {
    final m = await comKeyframes(tester, [500]);
    final de = pontoDoKeyframe(m.c, m.faixa, 500);
    final gesto = await tester.startGesture(de);
    // Puxa muito para a esquerda, para bem antes do inicio.
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.moveBy(const Offset(-4000, 0));
    await tester.pump();
    await gesto.up();
    await tester.pump();

    final camada = m.c.read(editorControllerProvider).layers.single;
    for (final t in camada.keyframeTimes) {
      expect(
        t >= Duration.zero && t <= camada.duration,
        isTrue,
        reason: 'a marca saiu da camada: ficou em $t',
      );
    }
  });

  testWidgets('toque longo apaga o keyframe', (tester) async {
    final m = await comKeyframes(tester, [500, 2000]);
    // Quantas marcas existem e assunto do motor: ligar o auto keyframe e
    // editar cria tambem a marca que guarda o valor de antes. O teste le
    // o numero real em vez de fingir saber.
    final antes =
        m.c.read(editorControllerProvider).layers.single.keyframeTimes;
    expect(antes.map((t) => t.inMilliseconds), contains(2000));

    await tester.longPressAt(pontoDoKeyframe(m.c, m.faixa, 2000));
    await tester.pump();

    final restantes =
        m.c.read(editorControllerProvider).layers.single.keyframeTimes;
    expect(
      restantes.length,
      antes.length - 1,
      reason: 'o toque longo tinha de apagar exatamente uma marca',
    );
    expect(
      restantes.map((t) => t.inMilliseconds),
      isNot(contains(2000)),
      reason: 'apagou a marca errada',
    );
  });

  testWidgets('tocar longe de qualquer marca so move o cabecote', (
    tester,
  ) async {
    final m = await comKeyframes(tester, [500]);
    final antes = m.c.read(editorControllerProvider).layers.single.keyframeTimes;

    // Um ponto na trilha, mas bem longe da unica marca.
    final ponto = pontoDoKeyframe(m.c, m.faixa, 4200);
    final gesto = await tester.startGesture(ponto);
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.moveBy(const Offset(-25, 0));
    await tester.pump();
    await gesto.up();
    await tester.pump();

    expect(
      m.c
          .read(editorControllerProvider)
          .layers
          .single
          .keyframeTimes
          .map((t) => t.inMilliseconds),
      antes.map((t) => t.inMilliseconds),
      reason: 'arrastar no vazio e navegar no tempo, nao mexer em marca',
    );
  });
}
