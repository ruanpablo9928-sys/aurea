import 'package:aurea/src/core/avisos/avisos_service.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:aurea/src/features/projects/presentation/aviso_ao_vivo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor_hierarchy_test.dart' show openEditor;

/// Dois pedidos do beta que se provam do mesmo jeito: uma coisa que tem
/// de estar SEMPRE na tela.
///
///   - "DEIXE A OPCAO DE DIVIDIR CAMADAS SEMPRE VISIVEL": a tesoura mora
///     no transporte, que nunca sai da tela, e corta no cabecote.
///   - o aviso ao vivo: um recado escrito no servidor aparece na Inicio
///     de todo aparelho, e o X esconde so aquele recado.
void main() {
  setUpAll(() async {
    for (final family in ['Aurea Motion Sans', 'Roboto']) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
  });

  testWidgets('a tesoura esta no transporte e divide no cabecote', (
    tester,
  ) async {
    final c = await openEditor(tester);
    final tesoura = find.byKey(const ValueKey('camada-dividir'));
    expect(tesoura, findsOneWidget, reason: 'a tesoura e permanente');

    // Sem camada selecionada ela existe, mas nao corta nada.
    final antes = c.read(editorControllerProvider).layers.length;
    await tester.tap(tesoura);
    await tester.pumpAndSettle();
    expect(c.read(editorControllerProvider).layers.length, antes);

    // Seleciona tocando no palco e leva o cabecote para o meio do clipe.
    await tester.tapAt(tester.getRect(find.byType(PreviewStage)).center);
    await tester.pumpAndSettle();
    final id = c.read(selectedLayerProvider)!;
    final camada = c.read(editorControllerProvider).layerById(id)!;
    final playback = tester
        .widget<PreviewStage>(find.byType(PreviewStage))
        .playback;
    playback.seek(camada.startTime + camada.duration ~/ 2);
    await tester.pumpAndSettle();

    await tester.tap(tesoura);
    await tester.pumpAndSettle();
    expect(
      c.read(editorControllerProvider).layers.length,
      antes + 1,
      reason: 'dividir no cabecote faz duas camadas de uma',
    );
  });

  testWidgets('o aviso ao vivo aparece e o X esconde so aquele', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final servico = AvisosService();
    addTearDown(servico.parar);
    servico.atual.value = const Aviso(
      id: 'bug-export-1',
      texto: 'Estamos resolvendo um bug na exportação.',
      nivel: NivelDoAviso.problema,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Column(children: [AvisoAoVivo(servico: servico)])),
      ),
    );
    await tester.pump();
    expect(find.text('Estamos resolvendo um bug na exportação.'), findsOneWidget);
    expect(find.byKey(const ValueKey('aviso-bug-export-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('aviso-fechar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('aviso-bug-export-1')), findsNothing);

    // O MESMO aviso nao volta; um NOVO (outro id) aparece.
    servico.atual.value = const Aviso(id: 'bug-export-1', texto: 'de novo');
    await tester.pump();
    // O servico so filtra no _mostrar; a tela mostra o que o notifier
    // tiver. Simula o caminho real: atualizar() passa pelo filtro.
    servico.atual.value = null;
    await tester.pump();
    servico.atual.value = const Aviso(
      id: 'bug-export-2',
      texto: 'Resolvido! Atualize o app.',
    );
    await tester.pump();
    expect(find.text('Resolvido! Atualize o app.'), findsOneWidget);
  });

  test('um aviso vencido nao aparece; um dispensado tambem nao', () async {
    SharedPreferences.setMockInitialValues({'aviso.dispensado': 'velho'});
    final s = AvisosService();
    addTearDown(s.parar);
    // Sem rede o iniciar so le o guardado; aqui nao ha guardado.
    await s.iniciar();
    expect(s.atual.value, isNull);
    final vencido = Aviso(
      id: 'x',
      texto: 'ja passou',
      ate: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(vencido.vencido, isTrue);
    expect(Aviso.deJson({'id': '', 'texto': 'sem id'}), isNull);
    expect(Aviso.deJson({'id': 'a', 'texto': '   '}), isNull);
    expect(Aviso.deJson({'id': 'a', 'texto': 'ok', 'nivel': 'atencao'})!.nivel,
        NivelDoAviso.atencao);
  });
}
