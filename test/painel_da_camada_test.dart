// ENTREGA 2A: A ESTRUTURA DO PAINEL, SO LEITURA.
//
// A condicao para avancar para a 2B e uma so, e e severa: abrir,
// navegar e fechar o painel NAO pode alterar conteudo, historico nem o
// resultado renderizado. A maior parte deste arquivo existe para provar
// isso — e o resto, para provar que a linha do tempo continua inteira.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
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
  int textos = 1,
  bool comVideo = false,
  bool selecionar = true,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < textos; i++) {
    c.addTextLayer(Duration(seconds: i), text: 'Camada ${i + 1}');
  }
  if (comVideo) c.addShapeLayer(Duration.zero);
  final camadas = container.read(editorControllerProvider).layers;
  container.read(selectedLayerProvider.notifier).state =
      selecionar && camadas.isNotEmpty ? camadas.first.id : null;

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
              const PainelDaCamada(),
            ],
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback);
}

void main() {
  group('a faixa recolhida', () {
    testWidgets('o painel nasce recolhido', (tester) async {
      final m = await _montar(tester);
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.recolhido);
      expect(find.bySemanticsLabel('Ferramentas da camada'), findsOneWidget);
    });

    testWidgets('sem selecao, diz o que fazer e nao abre', (tester) async {
      final m = await _montar(tester, selecionar: false);
      expect(find.bySemanticsLabel('Selecione uma camada'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Selecione uma camada'));
      await tester.pump();
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.recolhido,
        reason: 'sem camada nao ha ferramentas para mostrar',
      );
    });

    testWidgets('o + tem lugar reservado, mesmo sem selecao', (tester) async {
      await _montar(tester, selecionar: false);
      expect(
        find.bySemanticsLabel('Adicionar conteudo'),
        findsOneWidget,
        reason:
            'o + nao pode aparecer e sumir conforme a selecao: o layout '
            'mudaria debaixo da mao de quem esta usando',
      );
    });
  });

  group('navegacao', () {
    testWidgets('abrir mostra as categorias da camada', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      expect(find.byKey(const ValueKey('cartao-opacidade')), findsOneWidget);
      expect(find.byKey(const ValueKey('cartao-transformar')), findsOneWidget);
    });

    testWidgets('entrar numa categoria e voltar', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categoria);
      expect(m.c.read(categoriaAbertaProvider), 'opacidade');
      expect(find.bySemanticsLabel('Voltar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      expect(m.c.read(categoriaAbertaProvider), isNull);
    });

    testWidgets('recolher mantem a selecao e o tempo', (tester) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider);
      m.p.seek(const Duration(milliseconds: 900));
      await tester.pump();
      final tempo = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Recolher painel'));
      await tester.pump();

      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.recolhido);
      expect(
        m.c.read(selectedLayerProvider),
        id,
        reason: 'fechar uma gaveta nao desfaz o que se escolheu',
      );
      expect(m.p.time.value, tempo);
    });

    testWidgets('o painel aberto ocupa mais altura que a faixa', (
      tester,
    ) async {
      await _montar(tester);
      final antes = tester.getSize(find.byType(PainelDaCamada)).height;
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      expect(
        tester.getSize(find.byType(PainelDaCamada)).height,
        greaterThan(antes),
      );
    });
  });

  group('as ferramentas vem da capacidade real', () {
    testWidgets('texto ganha o cartao de Texto; forma ganha o de Forma', (
      tester,
    ) async {
      final m = await _montar(tester, comVideo: true);
      // A ORDEM DA PILHA E DO MOTOR: camada nova entra no topo. O teste
      // escolhe por TIPO, e nao por posicao, senao ele testa a ordem em
      // vez de testar o painel.
      final camadas = m.c.read(editorControllerProvider).layers;
      final texto = camadas.whereType<TextLayer>().first;
      final forma = camadas.whereType<ShapeLayer>().first;

      m.c.read(selectedLayerProvider.notifier).state = texto.id;
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      expect(find.byKey(const ValueKey('cartao-texto')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cartao-forma')),
        findsNothing,
        reason: 'camada de texto nao tem editor de forma',
      );

      m.c.read(selectedLayerProvider.notifier).state = forma.id;
      await tester.pump();
      expect(find.byKey(const ValueKey('cartao-forma')), findsOneWidget);
      expect(find.byKey(const ValueKey('cartao-texto')), findsNothing);
    });

    testWidgets('camada de audio NAO anuncia volume', (tester) async {
      // `editVideoVolume` recusa o que nao for VideoLayer. O campo existe
      // na camada de audio, o COMANDO nao — e o cartao segue o comando.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      expect(
        categoriasDaCamada(camada).map((x) => x.id),
        isNot(contains('volume')),
      );
    });

    testWidgets('toda camada tem transformar e opacidade', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      final ids = categoriasDaCamada(camada).map((x) => x.id);
      expect(ids, containsAll(['transformar', 'opacidade']));
    });

    testWidgets('efeitos NAO aparecem nesta etapa', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(editorControllerProvider.notifier)
          .addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      expect(
        categoriasDaCamada(camada).map((x) => x.id),
        isNot(contains('efeitos')),
        reason: 'efeitos tem etapa propria; anunciar aqui seria promessa',
      );
    });
  });

  group('a condicao para avancar: 2A nao escreve nada', () {
    testWidgets('abrir, navegar e fechar nao toca no projeto', (tester) async {
      final m = await _montar(tester);
      final antes = m.c.read(editorControllerProvider);
      final podiaDesfazer = m.c.read(editorControllerProvider.notifier).canUndo;

      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-transformar')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Recolher painel'));
      await tester.pump();

      expect(
        identical(m.c.read(editorControllerProvider), antes),
        isTrue,
        reason:
            'a 2A e so leitura: navegar no painel nao pode produzir um '
            'projeto novo',
      );
      expect(
        m.c.read(editorControllerProvider.notifier).canUndo,
        podiaDesfazer,
        reason: 'nem uma entrada de historico',
      );
    });

    testWidgets('abrir Opacidade nao mexe na opacidade', (tester) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      final antes = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id);

      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();

      final depois = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id);
      expect(
        identical(antes, depois),
        isTrue,
        reason:
            'entrar em Opacidade nao pode inicializar a camada em 100% '
            'nem inserir keyframe',
      );
    });

    testWidgets('navegar no painel nao cria nem apaga keyframe', (
      tester,
    ) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      m.c.read(autoKeyframeProvider.notifier).state = true;
      m.c
          .read(editorControllerProvider.notifier)
          .editOpacity(id, const Duration(milliseconds: 400), .5);
      final antes = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id)
          .keyframeTimes;

      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      m.p.seek(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Voltar'));
      await tester.pump();

      expect(
        m.c
            .read(editorControllerProvider)
            .layers
            .firstWhere((l) => l.id == id)
            .keyframeTimes
            .map((t) => t.inMilliseconds),
        antes.map((t) => t.inMilliseconds),
        reason: 'consultar valores no tempo nao escreve no projeto',
      );
    });
  });

  group('selecao e recuperacao', () {
    testWidgets('trocar de camada atualiza o painel', (tester) async {
      final m = await _montar(tester, textos: 2);
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();

      final camadas = m.c.read(editorControllerProvider).layers;
      final outra = camadas.last;
      m.c.read(selectedLayerProvider.notifier).state = outra.id;
      await tester.pump();

      expect(find.text(outra.name), findsWidgets);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.categorias,
        reason: 'trocar de camada nao fecha o painel',
      );
    });

    testWidgets('camada removida recolhe o painel, sem referencia morta', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 2);
      final id = m.c.read(selectedLayerProvider)!;
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);

      m.c.read(editorControllerProvider.notifier).removeLayer(id);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.recolhido,
        reason: 'sem camada, o painel nao tem o que mostrar',
      );
    });
  });

  group('o interruptor de validacao', () {
    testWidgets('desligado, volta a interface anterior', (tester) async {
      final m = await _montar(tester);
      expect(find.byType(PainelDaCamada), findsOneWidget);
      expect(find.bySemanticsLabel('Ferramentas da camada'), findsOneWidget);

      m.c.read(painelDaCamadaLigadoProvider.notifier).state = false;
      await tester.pump();

      expect(
        find.bySemanticsLabel('Ferramentas da camada'),
        findsNothing,
        reason: 'desligar tem de devolver a interface anterior por inteiro',
      );
      expect(
        tester.getSize(find.byType(PainelDaCamada)).height,
        0,
        reason: 'e sem deixar altura sobrando',
      );
    });
  });

  group('regressao: a linha do tempo continua inteira', () {
    testWidgets('os oito botoes seguem la, com o painel aberto', (
      tester,
    ) async {
      await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      for (final rotulo in [
        'Ver todas as camadas',
        'Desfazer',
        'Refazer',
        'Inicio',
        'Reproduzir',
        'Fim',
        'Duplicar camada',
        'Exportar',
      ]) {
        expect(
          find.bySemanticsLabel(rotulo),
          findsOneWidget,
          reason: 'o painel comeu o controle "$rotulo"',
        );
      }
    });

    testWidgets('trocar de modo mantem painel, selecao e tempo', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 2);
      final id = m.c.read(selectedLayerProvider);
      m.p.seek(const Duration(milliseconds: 700));
      await tester.pump();
      final tempo = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Ferramentas da camada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Ver todas as camadas'));
      await tester.pump();

      expect(m.c.read(modoDaLinhaDoTempoProvider), ModoDaLinhaDoTempo.geral);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.categorias,
        reason: 'trocar a vista da timeline nao fecha as ferramentas',
      );
      expect(m.c.read(selectedLayerProvider), id);
      expect(m.p.time.value, tempo);
    });

    testWidgets('o olho continua escondendo, sem abrir o painel', (
      tester,
    ) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      final tempo = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Esconder camada'));
      await tester.pump();

      expect(m.c.read(editorControllerProvider).metaOf(id).hidden, isTrue);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.recolhido,
        reason: 'o olho nao abre ferramentas',
      );
      expect(m.p.time.value, tempo, reason: 'nem desloca o tempo');
    });
  });
}
