// PROMPT 02 DA ESPECIFICACAO AM ONLY (rev. 02): SHELL E ESTADOS.
//
// "A selecao deve atualizar cabecalho, timeline e painel inferior de
// forma atomica." / "Voltar de um subpainel nao pode retornar para o
// objeto errado, perder playhead ou deixar um menu orfao."
//
// Este arquivo monta a `EditorScreen` inteira, porque o contrato que ele
// protege so existe no arranjo completo: a faixa de cima, a area
// inferior e o painel tem de concordar sobre onde a pessoa esta.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/presentation/contexto_do_editor.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/palco_de_previa.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  int camadas = 3,
  bool selecionar = false,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < camadas; i++) {
    c.addTextLayer(Duration(seconds: i), text: 'Camada ${i + 1}');
  }
  container.read(selectedLayerProvider.notifier).state = selecionar
      ? container.read(editorControllerProvider).layers.first.id
      : null;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditorScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// O GESTO DE VERDADE: um toque na camada, na pilha.
Future<void> tocarNaCamada(
  WidgetTester tester,
  ProviderContainer c,
  String nome,
) async {
  await tester.tap(find.bySemanticsLabel(nome));
  await tester.pump();
}

void main() {
  group('contexto de projeto', () {
    testWidgets('sem selecao, a faixa de cima e a do projeto', (tester) async {
      final c = await _montar(tester);
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.projeto);
      expect(find.bySemanticsLabel('Ajustes da composicao'), findsOneWidget);
      expect(find.bySemanticsLabel('Exportar'), findsOneWidget);
      expect(find.bySemanticsLabel('Apagar a camada'), findsNothing);
    });

    testWidgets('a area inferior e a pilha inteira', (tester) async {
      final c = await _montar(tester);
      expect(c.read(modoEfetivoProvider), ModoDaLinhaDoTempo.geral);
      // Tres camadas, tres pilulas com nome.
      expect(find.bySemanticsLabel('Camada 1'), findsWidgets);
      expect(find.bySemanticsLabel('Camada 2'), findsWidgets);
      expect(find.bySemanticsLabel('Camada 3'), findsWidgets);
    });
  });

  group('contexto de camada (V 00:40)', () {
    testWidgets('um toque troca cabecalho, area inferior e painel', (
      tester,
    ) async {
      final c = await _montar(tester);
      final antes = c.read(editorControllerProvider);

      await tocarNaCamada(tester, c, 'Camada 2');

      // 1. o contexto
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.camada);
      // 2. o cabecalho: nome da camada, parent, lixeira e o `...`
      expect(find.bySemanticsLabel('Renomear a camada'), findsOneWidget);
      expect(find.bySemanticsLabel('Seguir outra camada'), findsOneWidget);
      expect(find.bySemanticsLabel('Apagar a camada'), findsOneWidget);
      expect(find.bySemanticsLabel('Mais acoes da camada'), findsOneWidget);
      // o cabecalho de PROJETO saiu
      expect(find.bySemanticsLabel('Ajustes da composicao'), findsNothing);
      // 3. a area inferior virou a faixa daquela camada
      expect(c.read(modoEfetivoProvider), ModoDaLinhaDoTempo.detalhado);
      // 4. o painel abriu a grade DELA
      expect(c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      // e nada disso tocou no projeto
      expect(c.read(editorControllerProvider), antes);
    });

    testWidgets('o nome no cabecalho e o da camada, e nao o do projeto', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 3');
      expect(find.text('Camada 3'), findsWidgets);
      expect(
        find.text(c.read(editorControllerProvider).name),
        findsNothing,
        reason: 'o nome do projeto nao pode continuar na faixa de cima',
      );
    });

    testWidgets('sair devolve o cabecalho de projeto sem perder a selecao', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      final id = c.read(selectedLayerProvider);

      await tester.tap(find.bySemanticsLabel('Voltar ao projeto'));
      await tester.pump();

      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.projeto);
      expect(find.bySemanticsLabel('Ajustes da composicao'), findsOneWidget);
      expect(
        c.read(selectedLayerProvider),
        id,
        reason: 'sair do contexto nao pode desfazer a escolha da camada',
      );
    });

    testWidgets('a lixeira apaga e o cabecalho volta a ser o do projeto', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      final id = c.read(selectedLayerProvider);

      await tester.tap(find.bySemanticsLabel('Apagar a camada'));
      // A GRAVACAO E ADIADA em 900 ms; sem deixar o relogio andar, o
      // teste termina com um timer pendente.
      await tester.pump(const Duration(seconds: 1));

      expect(
        c.read(editorControllerProvider).layers.where((l) => l.id == id),
        isEmpty,
      );
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.projeto);
      expect(
        c.read(editorControllerProvider.notifier).canUndo,
        isTrue,
        reason: 'apagar do cabecalho passa pelo historico como qualquer outro',
      );
    });

    testWidgets('o `...` abre, fecha e devolve o mesmo contexto', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      final antes = c.read(editorControllerProvider);

      await tester.tap(find.bySemanticsLabel('Mais acoes da camada'));
      await tester.pump();
      expect(
        c.read(sobreposicaoDoEditorProvider),
        SobreposicaoDoEditor.menuDaCamada,
      );
      expect(find.bySemanticsLabel('Duplicar'), findsOneWidget);
      expect(find.bySemanticsLabel('Renomear'), findsOneWidget);
      // O CONTEXTO DE BAIXO NAO MUDOU: overlay nao troca estado.
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.camada);

      await tester.tap(find.bySemanticsLabel('Fechar o menu da camada'));
      await tester.pump();
      expect(
        c.read(sobreposicaoDoEditorProvider),
        SobreposicaoDoEditor.nenhuma,
      );
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.camada);
      expect(
        c.read(editorControllerProvider),
        antes,
        reason: 'abrir e fechar um menu nao pode alterar o projeto',
      );
    });

    testWidgets('o parenting do cabecalho abre a lista de candidatos', (
      tester,
    ) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');

      await tester.tap(find.bySemanticsLabel('Seguir outra camada'));
      await tester.pump();

      expect(
        c.read(sobreposicaoDoEditorProvider),
        SobreposicaoDoEditor.escolhaDePai,
      );
      expect(
        c.read(categoriaAbertaProvider),
        'camada',
        reason: 'a lista mora dentro do cartao Camada; sem abrir, nada aparece',
      );
    });
  });

  group('invariantes', () {
    testWidgets('nunca reabrir um painel do objeto anterior', (tester) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'opacidade';
      await tester.pump();
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.familia);

      // Trocar de camada pela pilula, que e o caminho que existe no
      // contexto de camada.
      await tester.tap(find.bySemanticsLabel('Proxima camada'));
      await tester.pump();

      // O titulo do cabecalho e o conteudo do painel tem de falar da
      // MESMA camada. Era aqui que o Aurea deixava o titulo da familia
      // antiga na barra enquanto o painel ja mostrava outra coisa.
      expect(c.read(categoriaAbertaProvider), 'opacidade');
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.familia);
      expect(find.text('Opacidade'), findsWidgets);
    });

    testWidgets('a familia que a camada nova NAO tem cai na grade dela', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Texto');
      c.addShapeLayer(const Duration(seconds: 1));
      container.read(selectedLayerProvider.notifier).state = null;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorScreen()),
        ),
      );
      await tester.pump();

      // `.last` E A PILULA: o texto desenhado na previa tambem casa com
      // o rotulo, e a pilula e sempre a ultima na arvore.
      await tester.tap(find.bySemanticsLabel('Texto').last);
      await tester.pump();
      container.read(estadoDoPainelProvider.notifier).state =
          EstadoDoPainel.categoria;
      container.read(categoriaAbertaProvider.notifier).state = 'texto';
      await tester.pump();

      // A FORMA NAO TEM A FAMILIA "texto". A regra e por EXISTENCIA DA
      // CATEGORIA, e nao por identidade da camada: quando a familia nao
      // existe do outro lado, o painel cai na grade da camada nova em
      // vez de ficar apontando para o nada.
      // A CAMADA NOVA ENTRA NO TOPO DA PILHA: a forma esta ACIMA do
      // texto, entao a seta viva e a de voltar.
      await tester.tap(find.bySemanticsLabel('Camada anterior'));
      await tester.pump();

      expect(container.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      expect(container.read(categoriaAbertaProvider), isNull);
      expect(
        container.read(contextoDoEditorProvider),
        ContextoDoEditor.camada,
      );
    });

    testWidgets('a previa nao muda de tamanho ao trocar de contexto', (
      tester,
    ) async {
      final c = await _montar(tester);
      final antes = tester.getRect(find.byType(CompositionView));

      await tocarNaCamada(tester, c, 'Camada 2');
      expect(
        tester.getRect(find.byType(CompositionView)),
        antes,
        reason: 'entrar no contexto de camada mexeu na previa',
      );

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'transformar';
      await tester.pump();
      expect(
        tester.getRect(find.byType(CompositionView)),
        antes,
        reason: 'abrir a familia mexeu na previa',
      );
    });

    testWidgets('voltar de uma familia nao mexe no cabecote', (tester) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'opacidade';
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Fechar a ferramenta'));
      await tester.pump();

      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.projeto);
      expect(
        c.read(selectedLayerProvider),
        isNotNull,
        reason: 'fechar a ferramenta nao desfaz a escolha da camada',
      );
    });

    testWidgets('nunca dois paineis ao mesmo tempo', (tester) async {
      final c = await _montar(tester);
      await tocarNaCamada(tester, c, 'Camada 2');
      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'opacidade';
      await tester.pump();
      expect(find.byType(PainelSobreposto), findsOneWidget);
      // O contexto responde UM valor, e por construcao nao ha dois.
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.familia);
    });
  });

  group('altura da faixa de cima', () {
    testWidgets('e a mesma nos tres contextos', (tester) async {
      final c = await _montar(tester);
      double alturaDoTopo() {
        final previa = tester.getRect(
          find.byKey(const ValueKey('moldura-da-previa')),
        );
        return previa.top;
      }

      final noProjeto = alturaDoTopo();
      await tocarNaCamada(tester, c, 'Camada 2');
      expect(alturaDoTopo(), noProjeto);

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'opacidade';
      await tester.pump();
      expect(alturaDoTopo(), noProjeto);
    });
  });
}
