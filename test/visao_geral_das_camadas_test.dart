// A VISTA DE TODAS AS CAMADAS, e a garantia de que ela nao estragou a
// vista de uma so.
//
// O contrato esta escrito em `docs/linha-do-tempo-gestos.md`. O que este
// arquivo faz e cobrar cada linha dele — inclusive as de REGRESSAO, que
// sao as que dizem que o modo detalhado continua exatamente como estava.
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

Future<({ProviderContainer c, PlaybackController p})> _montar(
  WidgetTester tester, {
  required int camadas,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < camadas; i++) {
    c.addTextLayer(Duration(seconds: i), text: 'Camada ${i + 1}');
  }
  // CRIAR CAMADA JA SELECIONA — e o motor que faz isso, e faz certo.
  // Para exercitar o estado "nada escolhido" e preciso limpar de
  // proposito.
  container.read(selectedLayerProvider.notifier).state = null;
  // Este arquivo cobra a TROCA entre os modos, entao ele comeca no
  // detalhado de proposito, e nao no padrao.
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
  return (c: container, p: playback);
}

void main() {
  group('o alternador de modo', () {
    testWidgets('comeca no detalhado e o botao leva e traz', (tester) async {
      final m = await _montar(tester, camadas: 3);
      expect(
        m.c.read(modoDaLinhaDoTempoProvider),
        ModoDaLinhaDoTempo.detalhado,
        reason: 'o editor abre onde se edita',
      );
      expect(find.bySemanticsLabel('Ver todas as camadas'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      expect(m.c.read(modoDaLinhaDoTempoProvider), ModoDaLinhaDoTempo.geral);

      // O CAMINHO DE VOLTA: o mesmo botao, com o rotulo trocado.
      expect(find.bySemanticsLabel('Ver uma camada'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Ver uma camada'));
      await tester.pump();
      expect(
        m.c.read(modoDaLinhaDoTempoProvider),
        ModoDaLinhaDoTempo.detalhado,
        reason: 'sem volta, o modo geral seria uma armadilha',
      );
    });

    testWidgets('a linha do tempo cresce no modo geral', (tester) async {
      // COM POUCAS CAMADAS OS DOIS MODOS EMPATAM no chao: a pilha so
      // pede mais que a trilha unica quando ha camadas que justifiquem.
      await _montar(tester, camadas: 6);
      final antes = tester.getSize(find.byType(LinhaDoTempo)).height;
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      final depois = tester.getSize(find.byType(LinhaDoTempo)).height;
      expect(
        depois,
        greaterThan(antes),
        reason: 'tres camadas empilhadas nao cabem na altura de uma',
      );
    });

    testWidgets('a pilha para de crescer depois do teto', (tester) async {
      await _montar(tester, camadas: 12);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      final altura = tester.getSize(find.byType(LinhaDoTempo)).height;
      expect(
        altura,
        LinhaDoTempo.alturaDoModo(ModoDaLinhaDoTempo.geral, 12),
        reason: 'doze camadas nao podem tomar a tela: a lista rola',
      );
      expect(
        altura,
        LinhaDoTempo.alturaDoModo(
          ModoDaLinhaDoTempo.geral,
          VisaoGeralDasCamadas.trilhasVisiveis,
        ),
        reason: 'acima do teto a altura e a mesma, e o resto rola',
      );
    });
  });

  group('a vista geral', () {
    testWidgets('mostra uma trilha por camada', (tester) async {
      await _montar(tester, camadas: 3);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      for (final nome in ['Camada 1', 'Camada 2', 'Camada 3']) {
        expect(
          find.bySemanticsLabel(nome),
          findsOneWidget,
          reason: 'faltou a trilha de "$nome" na pilha',
        );
      }
    });

    testWidgets('tocar numa trilha seleciona aquela camada', (tester) async {
      final m = await _montar(tester, camadas: 3);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      final camadas = m.c.read(editorControllerProvider).layers;

      await tester.tap(find.bySemanticsLabel('Camada 2'));
      await tester.pump();
      expect(
        m.c.read(selectedLayerProvider),
        camadas.firstWhere((l) => l.name == 'Camada 2').id,
      );
    });

    testWidgets('tocar numa trilha NAO mexe no cabecote', (tester) async {
      final m = await _montar(tester, camadas: 3);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();

      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      final antes = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Camada 2'));
      await tester.pump();
      expect(
        m.p.time.value,
        antes,
        reason:
            'na trilha o toque seleciona; quem leva o cabecote e a regua. '
            'Se as duas coisas dividirem a area, uma rouba a outra',
      );
    });

    testWidgets('tocar na camada JA selecionada abre o detalhado', (
      tester,
    ) async {
      final m = await _montar(tester, camadas: 3);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();

      final alvo = find.bySemanticsLabel('Camada 3');
      // O PRIMEIRO toque so escolhe, e a vista continua a mesma.
      await tester.tap(alvo);
      await tester.pump();
      expect(
        m.c.read(modoDaLinhaDoTempoProvider),
        ModoDaLinhaDoTempo.geral,
        reason: 'escolher nao pode arrastar a pessoa para outra vista',
      );

      // O SEGUNDO entra.
      await tester.tap(alvo);
      await tester.pump();

      expect(
        m.c.read(modoDaLinhaDoTempoProvider),
        ModoDaLinhaDoTempo.detalhado,
        reason: 'tocar de novo na escolhida e o atalho de "quero mexer"',
      );
      final camadas = m.c.read(editorControllerProvider).layers;
      expect(
        m.c.read(selectedLayerProvider),
        camadas.firstWhere((l) => l.name == 'Camada 3').id,
      );
    });

    testWidgets('o olho de cada linha esconde aquela camada', (tester) async {
      final m = await _montar(tester, camadas: 2);
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();

      final camadas = m.c.read(editorControllerProvider).layers;
      final alvo = camadas.firstWhere((l) => l.name == 'Camada 2');
      expect(
        m.c.read(editorControllerProvider).metaOf(alvo.id).hidden,
        isFalse,
      );

      await tester.tap(find.bySemanticsLabel('Esconder Camada 2'));
      await tester.pump();
      expect(
        m.c.read(editorControllerProvider).metaOf(alvo.id).hidden,
        isTrue,
      );
      expect(find.bySemanticsLabel('Mostrar Camada 2'), findsOneWidget);
      // A OUTRA CAMADA NAO PODE TER SIDO AFETADA.
      expect(
        m.c
            .read(editorControllerProvider)
            .metaOf(camadas.firstWhere((l) => l.name == 'Camada 1').id)
            .hidden,
        isFalse,
      );
    });
  });

  group('estados vazios', () {
    testWidgets('projeto sem camadas: regua no detalhado, aviso no geral', (
      tester,
    ) async {
      await _montar(tester, camadas: 0);
      // NO DETALHADO A REFERENCIA TEMPORAL FICA. O projeto ja tem
      // duracao valida (o minimo do motor e cinco segundos), e e a regua
      // que diz onde o conteudo novo vai entrar.
      expect(find.byKey(const ValueKey('timeline-aviso')), findsOneWidget);
      expect(find.byKey(const ValueKey('visao-geral-vazia')), findsNothing);

      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      // NO GERAL nao ha pilha para mostrar, entao a mensagem ocupa o
      // lugar dela.
      expect(
        find.byKey(const ValueKey('visao-geral-vazia')),
        findsOneWidget,
      );
    });

    testWidgets('detalhado sem selecao aponta o caminho', (tester) async {
      await _montar(tester, camadas: 2);
      expect(
        find.byKey(const ValueKey('detalhado-sem-selecao')),
        findsOneWidget,
        reason:
            'uma trilha vazia sem explicacao parece defeito; a mensagem '
            'diz o que falta e onde resolver',
      );
    });

    testWidgets('escolher uma camada tira a mensagem', (tester) async {
      final m = await _montar(tester, camadas: 2);
      m.c.read(selectedLayerProvider.notifier).state = m.c
          .read(editorControllerProvider)
          .layers
          .first
          .id;
      await tester.pump();
      expect(find.byKey(const ValueKey('detalhado-sem-selecao')), findsNothing);
    });
  });

  group('regressao: o modo detalhado continua inteiro', () {
    testWidgets('os oito controles do transporte estao la', (tester) async {
      await _montar(tester, camadas: 2);
      for (final rotulo in [
        'Ver todas as camadas',
        'Desfazer',
        'Refazer',
        'Inicio',
        'Reproduzir',
        'Fim',
        'Duplicar camada',
        // EXPORTAR SAIU DO TRANSPORTE e virou o botao do cabecalho: ele
        // nao e um controle de tempo, e a saida do trabalho. No lugar
        // dele entrou "Enquadrar", que e de tempo.
        'Enquadrar',
      ]) {
        expect(
          find.bySemanticsLabel(rotulo),
          findsOneWidget,
          reason: 'o transporte perdeu "$rotulo"',
        );
      }
    });

    testWidgets('as setas de trocar camada continuam funcionando', (
      tester,
    ) async {
      final m = await _montar(tester, camadas: 3);
      final camadas = m.c.read(editorControllerProvider).layers;
      m.c.read(selectedLayerProvider.notifier).state = camadas.first.id;
      await tester.pump();

      expect(find.bySemanticsLabel('Camada anterior'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Proxima camada'));
      await tester.pump();
      expect(m.c.read(selectedLayerProvider), camadas[1].id);
    });

    testWidgets('o modo geral nao mexe na selecao ao ser aberto', (
      tester,
    ) async {
      final m = await _montar(tester, camadas: 3);
      final id = m.c.read(editorControllerProvider).layers[1].id;
      m.c.read(selectedLayerProvider.notifier).state = id;
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      expect(
        m.c.read(selectedLayerProvider),
        id,
        reason: 'trocar de vista nao e trocar de camada',
      );

      await tester.tap(find.bySemanticsLabel('Ver uma camada'));
      await tester.pump();
      expect(m.c.read(selectedLayerProvider), id);
    });

    testWidgets('o modo geral nao mexe no relogio ao ser aberto', (
      tester,
    ) async {
      final m = await _montar(tester, camadas: 3);
      m.p.seek(const Duration(milliseconds: 1500));
      await tester.pump();
      final antes = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      expect(m.p.time.value, antes, reason: 'trocar de vista nao anda no tempo');
    });

    testWidgets('o modo geral nao altera o projeto', (tester) async {
      final m = await _montar(tester, camadas: 3);
      final antes = m.c.read(editorControllerProvider);

      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Camada 2'));
      await tester.pump();

      final depois = m.c.read(editorControllerProvider);
      expect(
        identical(antes, depois),
        isTrue,
        reason:
            'a vista geral LE o projeto. Selecionar nao e edicao, e nao '
            'pode entrar no desfazer',
      );
    });
  });
}
