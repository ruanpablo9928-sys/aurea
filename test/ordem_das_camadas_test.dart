import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_hierarchy_test.dart' show openEditor;

/// "NAO SEI COMO MUDAR A ORDEM DE UMA CAMADA" — o controlador sabia
/// reordenar; nao havia botao. Agora ha dois na barra de acoes (e no
/// menu da camada), e o bloco selecionado anda junto.
///
/// Indice 0 e o TOPO da pilha (o palco pinta `layers.reversed`): "para
/// frente" e delta negativo.
void main() {
  setUpAll(() async {
    for (final family in ['Aurea Motion Sans', 'Roboto']) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
  });

  group('reorderLayers no controlador', () {
    late ProviderContainer container;
    late EditorController c;
    List<String> nomes() => [
      for (final l in container.read(editorControllerProvider).layers) l.name.split(' ').first,
    ];
    String idDe(String nome) => container
        .read(editorControllerProvider)
        .layers
        .firstWhere((l) => l.name.startsWith(nome))
        .id;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      c = container.read(editorControllerProvider.notifier);
      for (final n in ['A', 'B', 'C', 'D']) {
        c.addShapeLayer(Duration.zero, name: n);
      }
    });

    test('duas vizinhas sobem juntas, na mesma ordem, e param no topo', () {
      final ordem = nomes();
      // As duas de baixo da pilha.
      final baixo = [ordem[2], ordem[3]];
      c.reorderLayers([idDe(baixo[0]), idDe(baixo[1])], -1);
      expect(nomes(), [ordem[0], baixo[0], baixo[1], ordem[1]]);
      c.reorderLayers([idDe(baixo[0]), idDe(baixo[1])], -1);
      expect(nomes(), [baixo[0], baixo[1], ordem[0], ordem[1]]);
      // No topo, nao ha para onde ir: nada muda.
      c.reorderLayers([idDe(baixo[0]), idDe(baixo[1])], -1);
      expect(nomes(), [baixo[0], baixo[1], ordem[0], ordem[1]]);
    });

    test('para tras e o espelho, e varios degraus de uma vez', () {
      final ordem = nomes();
      c.reorderLayers([idDe(ordem[0])], 3);
      expect(nomes(), [ordem[1], ordem[2], ordem[3], ordem[0]]);
      c.reorderLayers([idDe(ordem[0])], -10);
      expect(nomes(), ordem, reason: 'volta ao topo mesmo pedindo demais');
    });

    test('uma camada so: o mesmo que reorderLayer', () {
      final ordem = nomes();
      c.reorderLayers([idDe(ordem[1])], -1);
      expect(nomes(), [ordem[1], ordem[0], ordem[2], ordem[3]]);
      c.reorderLayers([idDe(ordem[1])], 1);
      expect(nomes(), ordem);
    });
  });

  testWidgets('a barra de acoes traz para frente e envia para tras', (tester) async {
    final c = await openEditor(tester);
    final camadas = c.read(editorControllerProvider).layers;
    expect(camadas.length, greaterThanOrEqualTo(2));
    final deBaixo = camadas[1].id;
    c.read(selectedLayerProvider.notifier).state = deBaixo;
    await tester.pumpAndSettle();

    final frente = find.byTooltip('Subir camada');
    final tras = find.byTooltip('Descer camada');
    expect(frente, findsOneWidget, reason: 'o botao de trazer para frente');
    expect(tras, findsOneWidget, reason: 'o botao de enviar para tras');

    await tester.tap(frente);
    await tester.pumpAndSettle();
    expect(c.read(editorControllerProvider).layers.first.id, deBaixo,
        reason: 'trazer para frente poe no topo da pilha');

    await tester.tap(tras);
    await tester.pumpAndSettle();
    expect(c.read(editorControllerProvider).layers[1].id, deBaixo);
  });
}
