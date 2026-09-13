import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_transformacao.dart';
import 'package:aurea/src/features/editor/presentation/widgets/campo_de_valor.dart';
import 'package:aurea/src/features/editor/presentation/widgets/rails_do_painel.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/editor/presentation/am/am_timeline.dart';
import 'editor_hierarchy_test.dart' show openEditor;

void main() {
  testWidgets('timeline ignores immediate drag and moves after holding', (tester) async {
    final c = await openEditor(tester);
    final layer = c.read(editorControllerProvider).layers.first;
    c.read(selectedLayerProvider.notifier).state = layer.id;
    await tester.pumpAndSettle();
    var rect = tester.getRect(find.byKey(ValueKey(layer.id)));
    var point = Offset(rect.left + 35, rect.top + kAmBarHeight / 2);
    await tester.dragFrom(point, const Offset(45, 0));
    await tester.pumpAndSettle();
    expect(c.read(editorControllerProvider).layerById(layer.id)!.startTime, layer.startTime);
    rect = tester.getRect(find.byKey(ValueKey(layer.id)));
    point = Offset(rect.left + 35, rect.top + kAmBarHeight / 2);
    final gesture = await tester.startGesture(point);
    await tester.pump(const Duration(milliseconds: 650));
    await gesture.moveBy(const Offset(65, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.read(editorControllerProvider).layerById(layer.id)!.startTime, greaterThan(layer.startTime));
  });
  testWidgets('tap Z switches the drag pad to depth without changing XY', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final editor = c.read(editorControllerProvider.notifier);
    editor.addNullLayer(Duration.zero);
    final initial = c.read(editorControllerProvider).layers.last;
    final playback = PlaybackController(
      vsync: const TestVSync(),
      durationOf: () => c.read(editorControllerProvider).duration,
    );
    addTearDown(playback.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, ref, _) => SizedBox(
                height: 280,
                child: PainelDeTransformacao(
                  camada: ref
                      .watch(projetoVisivelProvider)
                      .layerById(initial.id)!,
                  tempo: Duration.zero,
                  playback: playback,
                  aoVoltar: () {},
                  alvoDoRail: (_) => const AlvoDoRail(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(
      find.byWidgetPredicate((w) => w is CampoDeValor && w.rotulo == 'z'),
    );
    await tester.pump();
    expect(find.textContaining('Deslize para ajustar Z'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('position-drag-pad')),
      const Offset(0, -60),
    );
    await tester.pump();
    final result = c.read(projetoVisivelProvider).layerById(initial.id)!;
    expect(
      result.positionZ.valueAt(Duration.zero),
      greaterThan(initial.positionZ.valueAt(Duration.zero)),
    );
    expect(
      result.position.valueAt(Duration.zero),
      initial.position.valueAt(Duration.zero),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('ruler dragged right can increase zero opacity', (tester) async {
    double value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AmTickRuler(
            value: value,
            min: 0,
            max: 100,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );
    await tester.drag(find.byType(AmTickRuler), const Offset(80, 0));
    expect(value, greaterThan(0));
  });
}
