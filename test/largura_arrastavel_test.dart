import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/ui/editor_session.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_hierarchy_test.dart' show openEditor;

/// O QUE ESTE TESTE PEGA: uma regua que existe, aparece e nao anda.
///
/// O teste antigo chamava `onChanged` na mao — provava que a conta
/// estava certa, e nao que o DEDO chega ate ela. O relato do beta foi
/// exatamente esse: "nao da pra mexer no botao de largura, so no de
/// altura". Aqui o arrasto e de verdade, nos dois.
void main() {
  for (final size in [const Size(375, 667), const Size(430, 844)]) {
    testWidgets('largura e altura andam com o dedo, em $size', (tester) async {
      final c = await openEditor(tester, size: size);
      final id = c.read(editorControllerProvider).layers.first.id;
      c.read(selectedLayerProvider.notifier).state = id;
      c.read(editorSessionProvider.notifier).openTransform(TransformTool.scale);
      await tester.pumpAndSettle();

      final largura = find.byKey(const ValueKey('scale-width-ruler'));
      final altura = find.byKey(const ValueKey('scale-height-ruler'));
      expect(largura.hitTestable(), findsOneWidget, reason: 'regua de largura');
      expect(altura.hitTestable(), findsOneWidget, reason: 'regua de altura');

      // O QUE PRECISA SER LARGO E A SUPERFICIE DE ARRASTO, e nao a
      // faixa de riscos. Abaixo de uns cem pixels o gesto vira toque, e
      // a pessoa jura que o controle esta quebrado — foi o que
      // aconteceu com a linha "Largura", que sobrava com vinte e tres.
      Finder superficieDe(Finder regua) =>
          find.ancestor(of: regua, matching: find.byType(AmArrastoDeValor));
      for (final (nome, regua) in [('largura', largura), ('altura', altura)]) {
        expect(superficieDe(regua), findsOneWidget, reason: nome);
        expect(
          tester.getSize(superficieDe(regua)).width,
          greaterThan(100),
          reason: 'a superficie de arrasto de $nome ficou estreita demais',
        );
      }

      double sx() =>
          c.read(editorControllerProvider).layerById(id)!.scaleX.base;
      double sy() =>
          c.read(editorControllerProvider).layerById(id)!.scaleY.base;

      final antesX = sx();
      await tester.drag(largura, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(
        sx(),
        isNot(closeTo(antesX, 1e-6)),
        reason: 'arrastar a regua de largura nao mudou a largura',
      );

      final antesY = sy();
      await tester.drag(altura, const Offset(-60, 0));
      await tester.pumpAndSettle();
      expect(
        sy(),
        isNot(closeTo(antesY, 1e-6)),
        reason: 'arrastar a regua de altura nao mudou a altura',
      );
    });
  }
}
