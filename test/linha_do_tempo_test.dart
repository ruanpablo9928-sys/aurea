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
    // do fim da composicao.
    await tester.tapAt(
      Offset(faixa.right - 12, faixa.bottom - 20),
    );
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
}
