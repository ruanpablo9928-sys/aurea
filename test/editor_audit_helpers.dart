import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Follow visible controls, including secondary transform tools in Options.
Future<void> selectTransformTool(WidgetTester tester, String label) async {
  if (label == 'Pivo' || label == 'Opacid.') {
    await tester.tap(find.byTooltip('Opções de transformação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label == 'Pivo' ? 'Editar pivô' : 'Opacidade'));
  } else {
    await tester.tap(find.byTooltip(label));
  }
  await tester.pumpAndSettle();
}

Future<void> openLayerActions(WidgetTester tester) async {
  await tester.tap(find.text('Mais').last);
  await tester.pumpAndSettle();
}

Future<void> closeEditorPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('editor-back')));
  await tester.pumpAndSettle();
}
