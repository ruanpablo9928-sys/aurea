import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/presentation/am/am_timeline.dart';
import 'package:aurea/src/features/editor/application/ui/editor_layout.dart';
import 'package:aurea/src/features/editor/application/ui/editor_session.dart';
import 'package:aurea/src/features/editor/application/ui/pro_mode.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/shell/transport_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_hierarchy_test.dart' show openEditor;

/// FASE 1 DO REDESIGN — A CASCA (docs/UI_REDESIGN_PLAN.md, secao 3.1).
///
/// - As cinco zonas resolvidas de uma vez: o preview so muda pela alca;
///   abrir categoria ou adicionar nunca move o preview; a timeline nunca
///   fica abaixo do minimo (salvo ao adicionar, que e um seletor).
/// - A barra de cima tem UM estado: Voltar, nome, desfazer/refazer, ⚙,
///   Simples/Pro e Exportar — sempre, com ou sem selecao, com ou sem
///   painel aberto.
/// - O transporte tem o timecode tocavel e o ◆ unico.
/// - Sem selecao, o painel contextual e a barra de ADICIONAR (E1).
void main() {
  setUpAll(() async {
    for (final family in ['Aurea Motion Sans', 'Roboto']) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
  });

  group('EditorLayoutMetrics', () {
    test('as zonas somam a altura da tela', () {
      for (final h in [640.0, 667.0, 844.0, 932.0]) {
        final m = EditorLayoutMetrics.solve(
          totalHeight: h,
          previewFraction: 0.401,
          sheetFraction: 0.40,
        );
        expect(m.total, closeTo(h, 0.01), reason: 'altura $h');
      }
    });

    test('o preview nao muda quando o painel muda de nivel', () {
      double preview(double sheet, {bool adding = false}) =>
          EditorLayoutMetrics.solve(
            totalHeight: 844,
            previewFraction: 0.401,
            sheetFraction: sheet,
            sheetMayCoverTimeline: adding,
          ).preview;
      final base = preview(0.22);
      expect(preview(0.40), base);
      expect(preview(0.60), base);
      expect(preview(0.60, adding: true), base);
      expect(preview(0.0), base);
    });

    test('a timeline nunca fica abaixo do minimo: o painel encolhe', () {
      final m = EditorLayoutMetrics.solve(
        totalHeight: 640,
        previewFraction: 0.60,
        sheetFraction: 0.60,
      );
      expect(m.timeline, greaterThanOrEqualTo(EditorLayoutMetrics.timelineMin));
      expect(m.preview, greaterThanOrEqualTo(EditorLayoutMetrics.previewMin));
      final ws = EditorLayoutMetrics.workspace(640);
      expect(m.sheet, lessThan(ws * 0.60), reason: 'o painel cedeu');
    });

    test('ao adicionar, o menu pode cobrir a timeline', () {
      final m = EditorLayoutMetrics.solve(
        totalHeight: 640,
        previewFraction: 0.45,
        sheetFraction: 0.60,
        sheetMayCoverTimeline: true,
      );
      expect(m.timeline, lessThan(EditorLayoutMetrics.timelineMin));
      // O menu toma tudo que sobra abaixo do preview (que nao cede).
      expect(m.preview, closeTo(640 * 0.45, 0.01));
      expect(m.sheet, closeTo(EditorLayoutMetrics.workspace(640) - m.preview, 0.01));
    });

    test('preview expandido toma tudo menos o transporte', () {
      final m = EditorLayoutMetrics.solve(
        totalHeight: 932,
        previewFraction: 0.401,
        sheetFraction: 0.40,
        previewExpanded: true,
      );
      expect(m.preview + m.transport, 932);
      expect(m.timeline, 0);
      expect(m.sheet, 0);
      expect(m.topBar, 0);
    });

    test('a fracao do preview e presa entre 30% e 60% da tela', () {
      final baixo = EditorLayoutMetrics.solve(
        totalHeight: 932,
        previewFraction: 0.05,
        sheetFraction: 0.22,
      );
      expect(baixo.preview, closeTo(932 * 0.30, 0.01));
      final alto = EditorLayoutMetrics.solve(
        totalHeight: 932,
        previewFraction: 0.95,
        sheetFraction: 0.22,
      );
      expect(alto.preview, closeTo(932 * 0.60, 0.01));
    });
  });

  group('EditorSession', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      // Alguem precisa escutar: e autoDispose.
      c.listen(editorSessionProvider, (_, _) {});
      return c;
    }

    test('nasce sem painel, na metade, preview a 40%', () {
      final c = container();
      final s = c.read(editorSessionProvider);
      expect(s.panel, EditorPanel.none);
      expect(s.sheetLevel, SheetLevel.half);
      expect(s.previewFraction, closeTo(0.401, 1e-9));
      expect(s.panelOpen, isFalse);
      expect(s.adding, isFalse);
    });

    test('abrir categoria a partir do espiar sobe para a metade', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.setSheetLevel(SheetLevel.peek);
      n.openPanel(EditorPanel.effects);
      final s = c.read(editorSessionProvider);
      expect(s.panel, EditorPanel.effects);
      expect(s.sheetLevel, SheetLevel.half);
      expect(s.panelOpen, isTrue);
    });

    test('adicionar abre cheio e fechar volta a metade', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.openAdd();
      expect(c.read(editorSessionProvider).adding, isTrue);
      expect(c.read(editorSessionProvider).sheetLevel, SheetLevel.full);
      n.closeAdd();
      expect(c.read(editorSessionProvider).panel, EditorPanel.none);
      expect(c.read(editorSessionProvider).sheetLevel, SheetLevel.half);
    });

    test('a curva volta para o painel de onde veio', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.openTransform(TransformTool.scale);
      n.openCurve(LayerProp.scale);
      expect(c.read(editorSessionProvider).panel, EditorPanel.curve);
      expect(c.read(editorSessionProvider).curveProp, LayerProp.scale);
      n.backFromCurve();
      expect(c.read(editorSessionProvider).panel, EditorPanel.transform);
      expect(c.read(editorSessionProvider).tool, TransformTool.scale);
    });

    test('editar pontos volta para o painel de onde veio e limpa o item', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.openShape(ShapeTool.points);
      n.openEditPoints('item-1', returnTo: EditorPanel.editShape);
      expect(c.read(editorSessionProvider).panel, EditorPanel.editPoints);
      expect(c.read(editorSessionProvider).pointsItemId, 'item-1');
      n.backFromEditPoints();
      expect(c.read(editorSessionProvider).panel, EditorPanel.editShape);
      expect(c.read(editorSessionProvider).pointsItemId, isNull);
    });

    test('a alca do painel encaixa no nivel mais proximo', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.setSheetFraction(0.25);
      n.snapSheet();
      expect(c.read(editorSessionProvider).sheetLevel, SheetLevel.peek);
      expect(c.read(editorSessionProvider).sheetFraction, isNull);
      n.setSheetFraction(0.55);
      n.snapSheet();
      expect(c.read(editorSessionProvider).sheetLevel, SheetLevel.full);
      expect(
        c.read(editorSessionProvider).effectiveSheetFraction,
        EditorSession.fractionOfLevel(SheetLevel.full),
      );
    });

    test('a fracao do preview e presa', () {
      final c = container();
      final n = c.read(editorSessionProvider.notifier);
      n.setPreviewFraction(0.9);
      expect(c.read(editorSessionProvider).previewFraction, 0.60);
      n.setPreviewFraction(0.1);
      expect(c.read(editorSessionProvider).previewFraction, 0.30);
    });
  });

  group('parseTimecodeInput', () {
    test('segundos, minutos e quadros', () {
      expect(parseTimecodeInput('1.5', 30), const Duration(milliseconds: 1500));
      expect(parseTimecodeInput('1,5', 30), const Duration(milliseconds: 1500));
      expect(parseTimecodeInput('1:02.5', 30), const Duration(seconds: 62, milliseconds: 500));
      expect(parseTimecodeInput('00:01:02', 30), const Duration(seconds: 62));
      expect(
        parseTimecodeInput('00:00:01:15', 30),
        const Duration(seconds: 1, milliseconds: 500),
      );
      expect(parseTimecodeInput('', 30), isNull);
      expect(parseTimecodeInput('abc', 30), isNull);
    });
  });

  testWidgets('a barra de cima tem um estado so: Exportar sempre a vista', (tester) async {
    final c = await openEditor(tester);
    void barra(String momento) {
      for (final k in ['editor-back', 'editor-project-name', 'editor-undo', 'editor-redo', 'editor-settings', 'editor-pro', 'editor-export']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: '$k $momento');
      }
    }

    barra('sem selecao');
    // A barra de adicionar so aparece pelo "+": sem selecao o painel fica
    // fechado e a timeline fica com o espaco.
    expect(find.byKey(const ValueKey('adicionar-midia')), findsNothing);
    expect(find.byKey(const ValueKey('editor-fab')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('adicionar-midia')), findsOneWidget, reason: 'E1 pelo +');
    await tester.tap(find.byKey(const ValueKey('editor-back')));
    await tester.pumpAndSettle();

    final id = c.read(editorControllerProvider).layers.first.id;
    c.read(selectedLayerProvider.notifier).state = id;
    await tester.pumpAndSettle();
    barra('com selecao');
    expect(find.byKey(const ValueKey('quick-actions')), findsOneWidget, reason: 'E2 com selecao');
    expect(find.byKey(const ValueKey('camada-nome')), findsOneWidget);

    await tester.tap(find.text('Mover e\ntransf.'));
    await tester.pumpAndSettle();
    barra('com painel aberto');
    expect(find.text('Transformar · Posição'), findsOneWidget);
  });

  testWidgets('o timecode e tocavel: digitar o tempo leva o cabecote', (tester) async {
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('transport-timecode')));
    await tester.pumpAndSettle();
    final campo = find.byKey(const ValueKey('transport-timecode-campo'));
    expect(campo, findsOneWidget);
    await tester.enterText(campo, '1.5');
    await tester.tap(find.text('Ir'));
    await tester.pumpAndSettle();
    // 1.5 s a 30 fps: 00:01:15.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('transport-timecode')),
        matching: find.textContaining('00:01:15'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('o ◆ do transporte crava e tira o keyframe da propriedade ativa', (tester) async {
    final c = await openEditor(tester);
    final id = c.read(editorControllerProvider).layers.first.id;
    c.read(selectedLayerProvider.notifier).state = id;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover e\ntransf.'));
    await tester.pumpAndSettle();

    Layer camada() => c.read(editorControllerProvider).layerById(id)!;
    expect(camada().keyframeTimes, isEmpty);

    final losango = find.byKey(const ValueKey('transport-keyframe'));
    expect(losango, findsOneWidget);
    await tester.tap(losango);
    await tester.pumpAndSettle();
    expect(camada().keyframeTimes, isNotEmpty, reason: 'um keyframe em 0 s');
    expect(find.byTooltip('Keyframe: remover aqui'), findsOneWidget);

    await tester.tap(losango);
    await tester.pumpAndSettle();
    expect(camada().keyframeTimes, isEmpty, reason: 'o mesmo toque tira');
    expect(find.byTooltip('Keyframe: adicionar aqui'), findsOneWidget);
  });

  testWidgets('Simples/Pro: o interruptor so acrescenta acoes', (tester) async {
    final c = await openEditor(tester);
    // Projeto em memoria vazio na lista: nasce Simples.
    expect(c.read(proModeProvider), isFalse);
    final id = c.read(editorControllerProvider).layers.first.id;
    c.read(selectedLayerProvider.notifier).state = id;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('acao-dividir')), findsOneWidget);
    expect(find.byKey(const ValueKey('acao-alinhar')), findsNothing, reason: 'Alinhar e Pro');

    await tester.tap(find.byKey(const ValueKey('editor-pro')));
    await tester.pumpAndSettle();
    expect(c.read(proModeProvider), isTrue);
    expect(find.byKey(const ValueKey('acao-dividir')), findsOneWidget, reason: 'nada saiu do lugar');
    expect(find.byKey(const ValueKey('acao-alinhar')), findsOneWidget, reason: 'Pro acrescenta');
  });

  testWidgets('o + abre a barra; Texto cria em um toque; Midia abre o seletor', (tester) async {
    final c = await openEditor(tester);
    final antes = c.read(editorControllerProvider).layers.length;

    await tester.tap(find.byKey(const ValueKey('editor-fab')));
    await tester.pumpAndSettle();
    expect(c.read(editorSessionProvider).adding, isTrue, reason: 'o + e o unico lugar de adicionar');
    await tester.tap(find.byKey(const ValueKey('adicionar-texto')));
    await tester.pumpAndSettle();
    final camadas = c.read(editorControllerProvider).layers;
    expect(camadas.length, antes + 1);
    expect(camadas.any((l) => l is TextLayer), isTrue, reason: 'um toque, um texto');

    c.read(selectedLayerProvider.notifier).state = null;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adicionar-midia')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fechar adicionar'), findsOneWidget);
    // Fechar o seletor volta um passo, para a barra do "+".
    await tester.tap(find.byTooltip('Fechar adicionar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('adicionar-midia')), findsOneWidget, reason: 'voltou a barra');
    expect(c.read(editorSessionProvider).adding, isTrue);

    // Tocar no vazio da timeline fecha tudo.
    final linha = tester.getRect(find.byType(AmTimeline));
    await tester.tapAt(Offset(linha.left + 20, linha.bottom - 10));
    await tester.pumpAndSettle();
    expect(c.read(editorSessionProvider).adding, isFalse, reason: 'a timeline fecha');
    expect(find.byKey(const ValueKey('adicionar-midia')), findsNothing);
  });

  testWidgets('selecao multipla mostra a barra do conjunto', (tester) async {
    final c = await openEditor(tester);
    final ids = c.read(editorControllerProvider).layers.map((l) => l.id).toList();
    c.read(selectedLayerProvider.notifier).state = ids[0];
    c.read(multiSelectProvider.notifier).state = {ids[0], ids[1]};
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selecao-contagem')), findsOneWidget);
    expect(find.byKey(const ValueKey('selecao-agrupar')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-actions')), findsNothing, reason: 'E2 e de uma camada so');
    await tester.tap(find.byKey(const ValueKey('selecao-limpar')));
    await tester.pumpAndSettle();
    expect(c.read(multiSelectProvider), isEmpty);
  });
}
