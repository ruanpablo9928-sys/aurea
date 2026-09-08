import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/measure.dart';
import 'package:aurea/src/features/editor/domain/selection_geometry.dart';
import 'package:aurea/src/features/editor/presentation/widgets/composition_frame.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_hierarchy_test.dart' show openEditor;

void main() {
  for (final scale in [0.5, 2.0, -1.5]) {
    testWidgets('selection follows nonuniform scale $scale and pivot', (
      tester,
    ) async {
      final c = await openEditor(tester);
      final controller = c.read(editorControllerProvider.notifier);
      final id = c.read(editorControllerProvider).layers.first.id;
      for (final l in c.read(editorControllerProvider).layers.toList()) {
        if (l.id != id) controller.removeLayer(l.id);
      }
      controller.editScaleX(id, Duration.zero, scale);
      controller.editScaleY(id, Duration.zero, 1.5);
      controller.editPivot(id, Duration.zero, const Offset(30, -20));
      c.read(selectedLayerProvider.notifier).state = id;
      await tester.pumpAndSettle();
      final project = c.read(editorControllerProvider);
      final layer = project.layerById(id)!;
      final size = measureLayerBox(layer, Duration.zero, scaled: false);
      final stage = tester.getRect(find.byType(PreviewStage));
      final comp = compositionRect(
        stage.size,
        Size(project.outputWidth.toDouble(), project.outputHeight.toDouble()),
      );
      final factor = comp.width / project.outputWidth;
      // Independent arithmetic for the rendered corner: pos + pivot + S*(corner-pivot).
      final pivot = layer.pivot.base;
      final corner =
          layer.position.base +
          pivot +
          Offset(
            (size.width / 2 - pivot.dx) * scale,
            (size.height / 2 - pivot.dy) * 1.5,
          );
      final expected = stage.topLeft + comp.topLeft + corner * factor;
      final handle = tester.getCenter(
        find.byKey(const ValueKey('alca-escala')),
      );
      expect((handle - expected).distance, lessThan(1));
      // Touch a visible inner point near the side of the scaled content.
      c.read(selectedLayerProvider.notifier).state = null;
      await tester.pumpAndSettle();
      final local = Offset(size.width * .4, 0);
      final touch = MatrixUtils.transformPoint(
        selectionTransform(project, layer, Duration.zero),
        local,
      );
      await tester.tapAt(stage.topLeft + comp.topLeft + touch * factor);
      await tester.pumpAndSettle();
      expect(c.read(selectedLayerProvider), id);
      expect(tester.takeException(), isNull);
    });
  }
}
