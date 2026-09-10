// PROMPTS 07, 09 E 10 DA ESPECIFICACAO AM ONLY (rev. 02).
//
// Curvas com familia e parametros reais; grades especificas por tipo de
// camada; presets da camada com os dois caminhos reais; e o sheet de
// configuracoes do projeto pela engrenagem.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/layer_preset_store.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/contexto_do_editor.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/ajustes_do_projeto.dart';
import 'package:aurea/src/features/editor/presentation/widgets/editor_de_curva.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/presets_da_camada.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _tela(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditorScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('PROMPT 07 — familias de curva', () {
    test('as quatro familias existem, e saem da curva aplicada', () {
      expect(FamiliaDeCurva.values, hasLength(4));
      expect(familiaDe(Easing.linear), FamiliaDeCurva.bezier);
      expect(familiaDe(Easing.bounce), FamiliaDeCurva.saltar);
      expect(familiaDe(Easing.elastic), FamiliaDeCurva.elastico);
      expect(
        familiaDe(const Easing(type: EasingType.cyclic)),
        FamiliaDeCurva.ciclico,
      );
    });

    test('cada familia tem presets com PARAMETRO de verdade', () {
      for (final f in FamiliaDeCurva.values) {
        final presets = presetsDaFamilia(f);
        expect(presets, isNotEmpty, reason: 'familia ${rotuloDaFamilia(f)}');
        for (final (nome, e) in presets) {
          expect(nome, isNotEmpty);
          // Cada preset tem de produzir uma curva que o motor executa.
          expect(e.transform(0.5), isA<double>());
        }
      }
      // Saltar e Ciclico variam pela contagem; Elastico pela forca.
      final saltos = presetsDaFamilia(FamiliaDeCurva.saltar);
      expect(saltos.map((p) => p.$2.count).toSet().length, greaterThan(1));
    });

    test('o seletor reflete a curva, e nao um estado guardado', () {
      // Duas curvas de familias diferentes nao podem cair na mesma
      // familia: era assim que o botao ficava apontando para a anterior.
      expect(
        familiaDe(Easing.bounce),
        isNot(familiaDe(Easing.elastic)),
      );
    });

    test('inverter curva troca as alcas e a direcao do easing', () {
      const original = Easing(
        type: EasingType.cubicBezier,
        x1: 0.2,
        y1: 0.0,
        x2: 0.3,
        y2: 1.0,
      );
      final invertida = inverterCurva(original);
      expect(invertida.type, EasingType.cubicBezier);
      expect(invertida.x1, closeTo(1 - 0.3, 0.001));
      expect(invertida.y1, closeTo(1 - 1.0, 0.001));
      expect(invertida.x2, closeTo(1 - 0.2, 0.001));
      expect(invertida.y2, closeTo(1 - 0.0, 0.001));
    });

    testWidgets('o botao inverter altera a curva no EditorDeCurva', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Easing? aplicada;
      container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
        titulo: 'Opacidade',
        atual: const Easing(
          type: EasingType.cubicBezier,
          x1: 0.2,
          y1: 0.0,
          x2: 0.3,
          y2: 1.0,
        ),
        aoAplicar: (e) => aplicada = e,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EditorDeCurva(),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Inverter a curva'));
      await tester.pump();

      expect(aplicada, isNotNull);
      expect(aplicada!.x1, closeTo(0.7, 0.001));
      expect(aplicada!.y1, closeTo(0.0, 0.001));
    });

    testWidgets('trocar de familia muda a curva e exibe parametros amarelos', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Easing aplicada = Easing.linear;
      container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
        titulo: 'Opacidade',
        atual: aplicada,
        aoAplicar: (e) {
          aplicada = e;
          container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
            titulo: 'Opacidade',
            atual: e,
            aoAplicar: (e2) => aplicada = e2,
          );
        },
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EditorDeCurva(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tocar na familia Saltar
      await tester.tap(find.bySemanticsLabel('Curva Saltar'));
      await tester.pump();
      expect(aplicada.type, EasingType.bounce);

      // Controle amarelo de repeticoes
      expect(
        find.bySemanticsLabel(RegExp(r'Repeticoes da curva')),
        findsWidgets,
      );

      // Aumentar repeticoes
      await tester.tap(find.bySemanticsLabel('Aumentar: Repeticoes da curva'));
      await tester.pump();
      expect(aplicada.count, greaterThan(1));
    });

    testWidgets('familia elastico exibe controle de forca do elastico', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Easing aplicada = const Easing(
        type: EasingType.elastic,
        intensity: 0.5,
      );
      container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
        titulo: 'Opacidade',
        atual: aplicada,
        aoAplicar: (e) {
          aplicada = e;
          container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
            titulo: 'Opacidade',
            atual: e,
            aoAplicar: (e2) => aplicada = e2,
          );
        },
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: EditorDeCurva(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Curva Elastico'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Forca do elastico')),
        findsWidgets,
      );

      await tester.tap(find.bySemanticsLabel('Aumentar: Forca do elastico'));
      await tester.pump();
      expect(aplicada.intensity, closeTo(0.6, 0.01));
    });
  });

  group('PROMPT 09 — grades por tipo', () {
    test('camera: quatro familias, e nenhuma delas e de preenchimento', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addCameraLayer(Duration.zero);
      final cam = container.read(editorControllerProvider).layers.single;
      final ids = categoriasDaCamada(cam).map((x) => x.id).toList();
      expect(ids, ['transformar', 'lente', 'presets', 'efeitos']);
      expect(ids, isNot(contains('cor')));
      expect(ids, isNot(contains('mascara')));
    });

    test('nulo: grade reduzida, sem preenchimento', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).addNullLayer(
        Duration.zero,
      );
      final nulo = container.read(editorControllerProvider).layers.single;
      final ids = categoriasDaCamada(nulo).map((x) => x.id).toList();
      expect(ids, contains('transformar'));
      expect(ids, contains('presets'));
      expect(ids, contains('efeitos'));
      expect(ids, isNot(contains('cor')));
      expect(ids, isNot(contains('opacidade')));
    });

    test('grupo troca "Editar Forma" por "Editar grupo"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).addEmptyGroup(
        Duration.zero,
      );
      final grupo = container.read(editorControllerProvider).layers.single;
      final cats = categoriasDaCamada(grupo);
      expect(cats.map((x) => x.id), contains('grupo'));
      expect(
        cats.firstWhere((x) => x.id == 'grupo').rotulo,
        'Editar grupo',
      );
      expect(cats.map((x) => x.id), isNot(contains('forma')));
    });

    test('a forma chama o tile de "Editar Forma"', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).addShapeLayer(
        Duration.zero,
      );
      final forma = container.read(editorControllerProvider).layers.single;
      final cats = categoriasDaCamada(forma);
      expect(
        cats.firstWhere((x) => x.id == 'forma').rotulo,
        'Editar Forma',
      );
      expect(cats.map((x) => x.id), contains('presets'));
      expect(cats.map((x) => x.id), contains('borda'));
    });
  });

  group('PROMPT 09 — presets da camada', () {
    setUp(() {
      LayerPresetStore.semArquivo = true;
      LayerPresetStore.instance.limparParaTeste();
    });

    testWidgets('o vazio oferece os DOIS caminhos reais', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(body: PresetsDaCamada(camada: camada)),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('presets-vazio')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Salvar esta camada como preset'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Importar preset copiado'),
        findsOneWidget,
      );
    });

    test('salvar guarda os keyframes, e aplicar devolve a animacao', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Origem');
      final origem = container.read(editorControllerProvider).layers.single;
      c.toggleKeyframe(origem.id, Duration.zero, LayerProp.opacity);
      c.editOpacity(origem.id, Duration.zero, 0.2);
      c.toggleKeyframe(origem.id, const Duration(seconds: 1), LayerProp.opacity);
      c.editOpacity(origem.id, const Duration(seconds: 1), 1);

      final comAnimacao = container.read(editorControllerProvider).layerById(
        origem.id,
      )!;
      await LayerPresetStore.instance.salvar(comAnimacao, 'Aparecer', 'Texto');
      expect(LayerPresetStore.instance.presets, hasLength(1));

      c.addShapeLayer(const Duration(seconds: 2));
      final alvo = container
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id != origem.id);
      expect(alvo.opacity.isAnimated, isFalse);

      c.aplicarPresetDeCamada(alvo.id, comAnimacao);
      final depois = container.read(editorControllerProvider).layerById(
        alvo.id,
      )!;
      expect(depois.opacity.isAnimated, isTrue);
      expect(depois.opacity.valueAt(Duration.zero), 0.2);
      // O TEMPO E O CONTEUDO NAO SAO TOCADOS.
      expect(depois.startTime, const Duration(seconds: 2));
      expect(depois, isA<ShapeLayer>());
    });

    test('aplicar um preset custa UM desfazer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'A');
      c.addTextLayer(Duration.zero, text: 'B');
      final camadas = container.read(editorControllerProvider).layers;
      final antes = container.read(editorControllerProvider);

      c.aplicarPresetDeCamada(camadas.first.id, camadas.last);
      c.undo();
      expect(container.read(editorControllerProvider), antes);
    });
  });

  group('PROMPT 10 — configuracoes do projeto', () {
    testWidgets('a engrenagem do cabecalho abre o sheet, sem sair do editor', (
      tester,
    ) async {
      final c = await _tela(tester);
      expect(find.bySemanticsLabel('Ajustes do projeto'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();

      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.composicao);
      // O EDITOR CONTINUA ATRAS: a faixa de cima e a timeline nao saem.
      expect(find.bySemanticsLabel('Exportar'), findsOneWidget);
      expect(find.byType(AjustesDoProjeto), findsOneWidget);
    });

    testWidgets('a ordem do sheet e a da referencia', (tester) async {
      final c = await _tela(tester);
      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();

      final proporcao = tester.getCenter(find.bySemanticsLabel('16:9')).dy;
      final resolucao = tester.getCenter(find.bySemanticsLabel('Resolucao')).dy;
      final fps = tester
          .getCenter(find.bySemanticsLabel('Quadros por segundo'))
          .dy;
      final fundo = tester
          .getCenter(find.bySemanticsLabel('Plano de fundo').first)
          .dy;
      expect(proporcao, lessThan(resolucao));
      expect(resolucao, lessThan(fps));
      expect(fps, lessThan(fundo));
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.composicao);
    });

    testWidgets('os cinco presets de proporcao, na ordem, mudam o projeto', (
      tester,
    ) async {
      final c = await _tela(tester);
      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();

      var x = -1.0;
      for (final (rotulo, _) in AjustesDoProjeto.proporcoes) {
        final alvo = find.bySemanticsLabel(rotulo);
        expect(alvo, findsOneWidget, reason: 'falta o preset $rotulo');
        final centro = tester.getCenter(alvo).dx;
        expect(centro, greaterThan(x), reason: '$rotulo saiu de ordem');
        x = centro;
      }
      expect(
        find.bySemanticsLabel('Proporcao personalizada'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('1:1'));
      await tester.pump(const Duration(seconds: 1));
      final p = c.read(editorControllerProvider);
      expect(p.outputWidth, p.outputHeight);
    });

    testWidgets('resolucao e fps abrem no lugar e escrevem de verdade', (
      tester,
    ) async {
      final c = await _tela(tester);
      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Resolucao'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('720p'));
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(editorControllerProvider).outputHeight, 720);

      await tester.tap(find.bySemanticsLabel('Quadros por segundo'));
      await tester.pump();
      await tester.ensureVisible(find.bySemanticsLabel('60 fps'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('60 fps'));
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(editorControllerProvider).fps, 60);
    });

    testWidgets('o X do sheet fecha e restaura o editor', (tester) async {
      final c = await _tela(tester);
      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();
      expect(find.byType(AjustesDoProjeto), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Fechar ajustes'));
      await tester.pump();
      expect(find.byType(AjustesDoProjeto), findsNothing);
      expect(c.read(contextoDoEditorProvider), ContextoDoEditor.projeto);
    });

    testWidgets('o sheet exibe Tempo Total de Edicao', (tester) async {
      await _tela(tester);
      await tester.tap(find.bySemanticsLabel('Ajustes do projeto'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.textContaining('Tempo Total de Edição:'),
        100.0,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Tempo Total de Edição:'), findsOneWidget);
    });

    testWidgets('mudar a resolucao NAO mexe em keyframe', (tester) async {
      final c = await _tela(tester);
      final e = c.read(editorControllerProvider.notifier);
      e.addTextLayer(Duration.zero, text: 'Um');
      final id = c.read(editorControllerProvider).layers.single.id;
      e.toggleKeyframe(id, const Duration(seconds: 1), LayerProp.opacity);
      final antes = c
          .read(editorControllerProvider)
          .layerById(id)!
          .opacity
          .keyframes
          .map((k) => k.time)
          .toList();
      await tester.pump();

      e.setComposition(resolutionHeight: 480, fps: 24);
      await tester.pump(const Duration(seconds: 1));

      expect(
        c.read(editorControllerProvider).layerById(id)!.opacity.keyframes
            .map((k) => k.time)
            .toList(),
        antes,
      );
    });
  });
}
