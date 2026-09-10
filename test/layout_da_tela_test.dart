// A DIVISAO VERTICAL DA TELA DE EDICAO, montada por inteiro.
//
// Os outros testes montam pecas soltas; este monta a `EditorScreen` de
// verdade, porque a regra que ele protege so existe no arranjo completo:
//
//   A PREVIA NAO MUDA DE TAMANHO QUANDO UMA FERRAMENTA ABRE.
//
// Ela encolhia. No Alight a composicao fica do mesmo tamanho com a aba
// de transformacao, de efeito ou de curva aberta — e faz sentido: a
// previa e o que se olha enquanto o dedo mexe no controle, e muda-la de
// tamanho no exato momento em que a atencao vai para ela e o pior
// momento possivel. Quem cede espaco e a linha do tempo.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/presentation/widgets/editor_de_curva.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/palco_de_previa.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _montar(
  WidgetTester tester, {
  double proporcao = 9 / 16,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.setComposition(aspectRatio: proporcao, resolutionHeight: 1920);
  c.addTextLayer(Duration.zero, text: 'Um');
  c.addTextLayer(const Duration(seconds: 1), text: 'Dois');
  final camada = container.read(editorControllerProvider).layers.first;
  container.read(selectedLayerProvider.notifier).state = camada.id;

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
  group('a previa fica parada', () {
    testWidgets('abrir as ferramentas nao mexe num pixel dela', (tester) async {
      final c = await _montar(tester);
      final antes = tester.getRect(find.byType(CompositionView));

      c.read(estadoDoPainelProvider.notifier).state =
          EstadoDoPainel.categorias;
      await tester.pump();
      expect(
        tester.getRect(find.byType(CompositionView)),
        antes,
        reason: 'a grade de categorias mexeu na previa',
      );

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'transformar';
      await tester.pump();
      expect(
        tester.getRect(find.byType(CompositionView)),
        antes,
        reason: 'a ferramenta aberta mexeu na previa',
      );
    });

    testWidgets('abrir a curva tambem nao', (tester) async {
      final c = await _montar(tester);
      final antes = tester.getRect(find.byType(CompositionView));

      c.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
        titulo: 'Opacidade',
        atual: Easing.linear,
        aoAplicar: (_) {},
      );
      await tester.pump();

      expect(tester.getRect(find.byType(CompositionView)), antes);
    });

    testWidgets('vale tambem num projeto deitado', (tester) async {
      final c = await _montar(tester, proporcao: 16 / 9);
      final antes = tester.getRect(find.byType(CompositionView));

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'efeitos';
      await tester.pump();

      expect(tester.getRect(find.byType(CompositionView)), antes);
    });
  });

  group('quem cede e a linha do tempo', () {
    testWidgets('ela encolhe, mas nunca abaixo do chao', (tester) async {
      final c = await _montar(tester);
      final antes = tester.getSize(find.byType(LinhaDoTempo)).height;

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'transformar';
      await tester.pump();
      final depois = tester.getSize(find.byType(LinhaDoTempo)).height;

      expect(
        depois,
        lessThan(antes),
        reason: 'o espaco da ferramenta tem de sair de algum lugar',
      );
      // O CHAO: transporte, regua e uma trilha. Abaixo disso nao da mais
      // para ver onde o cabecote esta enquanto se edita — e ver o
      // cabecote e metade do motivo de a ferramenta existir.
      expect(
        depois,
        greaterThanOrEqualTo(
          LinhaDoTempo.alturaDoTransporte + LinhaDoTempo.alturaDaRegua,
        ),
        reason: 'a linha do tempo cedeu ate deixar de ser util',
      );
    });

    testWidgets('fechar a ferramenta devolve a altura', (tester) async {
      final c = await _montar(tester);
      final antes = tester.getSize(find.byType(LinhaDoTempo)).height;

      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categoria;
      c.read(categoriaAbertaProvider.notifier).state = 'transformar';
      await tester.pump();
      c.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.recolhido;
      c.read(categoriaAbertaProvider.notifier).state = null;
      await tester.pump();

      expect(tester.getSize(find.byType(LinhaDoTempo)).height, antes);
    });
  });
}
