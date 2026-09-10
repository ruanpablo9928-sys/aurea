// A SELECAO MULTIPLA, e as sete acoes que dependiam dela.
//
// `multiSelectProvider` existia desde sempre e era so LIMPO, nunca
// preenchido: nenhum gesto punha duas camadas no conjunto. A auditoria
// chamou isso de raiz estrutural, e era — sem ele nao ha agrupar varias,
// nem alinhar, nem distribuir, nem escalonar, nem acao em lote.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/repositorio_sem_disco.dart';

/// A tela inteira, com [quantas] camadas de texto e a primeira escolhida.
Future<ProviderContainer> _montar(WidgetTester tester, {int quantas = 3}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider.overrideWithValue(RepositorioSemDisco()),
    ],
  );
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < quantas; i++) {
    c.addTextLayer(Duration.zero, text: 'Camada $i');
  }
  final camadas = container.read(editorControllerProvider).layers;
  container.read(selectedLayerProvider.notifier).state = camadas.first.id;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditorScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// Segura a trilha da camada [id] na pilha.
Future<void> _segurar(WidgetTester tester, String id) async {
  await tester.longPress(find.byKey(ValueKey('trilha-$id')));
  await tester.pump();
}

/// Toca num botao do painel do conjunto.
///
/// O painel tem 300 px e rola: metade das acoes nasce abaixo da dobra,
/// e um toque sem rolar cai no vazio.
Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  // O SEGUNDO INTEIRO E A GRAVACAO ADIADA. A tela grava sozinha com 900
  // ms de atraso; parar antes disso deixa um temporizador vivo depois
  // do fim do teste, e o erro aparece longe de quem o causou.
  await tester.pump(const Duration(seconds: 1));
}

List<Layer> _camadas(ProviderContainer c) =>
    c.read(editorControllerProvider).layers;

void main() {
  group('juntar camadas', () {
    testWidgets('o toque longo leva a selecionada junto', (tester) async {
      final c = await _montar(tester);
      final camadas = _camadas(c);
      expect(c.read(multiSelectProvider), isEmpty);

      // A segunda camada e a de baixo da pilha; a primeira ja esta
      // escolhida. Juntar UMA nao pode dar um conjunto de uma.
      await _segurar(tester, camadas[1].id);

      expect(c.read(multiSelectProvider), {camadas[0].id, camadas[1].id});
      expect(
        c.read(estadoDoPainelProvider),
        EstadoDoPainel.selecao,
        reason: 'juntar sem mostrar o que fazer deixaria o gesto sem resposta',
      );
      expect(find.bySemanticsLabel('2 camadas'), findsOneWidget);
    });

    testWidgets('segurar de novo tira do conjunto, e some com ele', (
      tester,
    ) async {
      final c = await _montar(tester);
      final camadas = _camadas(c);
      await _segurar(tester, camadas[1].id);
      expect(c.read(multiSelectProvider), hasLength(2));

      // Sobrando uma so, o conjunto deixa de existir: "uma camada
      // junta" nao e coisa nenhuma, e o painel de lote nao teria o que
      // fazer.
      await _segurar(tester, camadas[1].id);
      expect(c.read(multiSelectProvider), isEmpty);
      await tester.pump();
      expect(find.bySemanticsLabel('2 camadas'), findsNothing);
    });

    testWidgets('a barra de cima desfaz a juncao', (tester) async {
      final c = await _montar(tester);
      await _segurar(tester, _camadas(c)[1].id);

      await tester.tap(find.bySemanticsLabel('Desfazer a juncao'));
      await tester.pump();

      expect(c.read(multiSelectProvider), isEmpty);
      expect(c.read(estadoDoPainelProvider), EstadoDoPainel.recolhido);
    });
  });

  group('as acoes do conjunto', () {
    testWidgets('agrupar troca as duas por um grupo', (tester) async {
      final c = await _montar(tester);
      final camadas = _camadas(c);
      await _segurar(tester, camadas[1].id);

      await _tocar(tester, 'Agrupar as 2');

      final agora = _camadas(c);
      expect(agora, hasLength(2));
      final grupo = agora.whereType<GroupLayer>().single;
      expect(grupo.children, hasLength(2));
      expect(
        c.read(multiSelectProvider),
        isEmpty,
        reason: 'as camadas juntadas nao existem mais soltas',
      );
    });

    testWidgets('apagar em lote custa UM desfazer', (tester) async {
      final c = await _montar(tester);
      final camadas = _camadas(c);
      await _segurar(tester, camadas[1].id);

      await _tocar(tester, 'Apagar as 2');
      expect(_camadas(c), hasLength(1));

      c.read(editorControllerProvider.notifier).undo();
      expect(
        _camadas(c),
        hasLength(3),
        reason: 'sem o lote, voltar atras custaria um toque por camada',
      );
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('alinhar encosta as duas na mesma borda', (tester) async {
      final c = await _montar(tester);
      final ctrl = c.read(editorControllerProvider.notifier);
      final camadas = _camadas(c);
      ctrl.editPosition(camadas[0].id, Duration.zero, const Offset(100, 100));
      ctrl.editPosition(camadas[1].id, Duration.zero, const Offset(700, 400));
      await tester.pump();

      await _segurar(tester, camadas[1].id);
      await _tocar(tester, 'Topo');

      final a = _camadas(c).firstWhere((l) => l.id == camadas[0].id);
      final b = _camadas(c).firstWhere((l) => l.id == camadas[1].id);
      // Mesmo tipo e mesmo tamanho de texto: alinhar pelo topo encosta
      // os dois centros no mesmo y.
      expect(
        a.position.valueAt(Duration.zero).dy,
        closeTo(b.position.valueAt(Duration.zero).dy, 1),
      );
      expect(
        a.position.valueAt(Duration.zero).dx,
        closeTo(100, 1),
        reason: 'alinhar pelo topo nao mexe no eixo horizontal',
      );
    });

    testWidgets('espalhar so responde com tres camadas', (tester) async {
      final c = await _montar(tester);
      final camadas = _camadas(c);
      await _segurar(tester, camadas[1].id);

      final chip = tester.getSemantics(find.bySemanticsLabel('Na horizontal'));
      expect(chip.hasFlag(SemanticsFlag.isEnabled), isFalse);

      await _segurar(tester, camadas[2].id);
      expect(c.read(multiSelectProvider), hasLength(3));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Na horizontal'))
            .hasFlag(SemanticsFlag.isEnabled),
        isTrue,
      );
    });

    testWidgets('escalonar afasta as marcas de uma camada para a outra', (
      tester,
    ) async {
      final c = await _montar(tester);
      final ctrl = c.read(editorControllerProvider.notifier);
      final camadas = _camadas(c);
      // Duas camadas com a MESMA marca: escalonar tem de separar.
      for (final l in [camadas[0], camadas[1]]) {
        ctrl.toggleKeyframe(l.id, Duration.zero, LayerProp.opacity);
        ctrl.toggleKeyframe(
          l.id,
          const Duration(milliseconds: 500),
          LayerProp.opacity,
        );
      }
      await tester.pump();

      await _segurar(tester, camadas[1].id);
      await _tocar(tester, 'Medio');

      final marcas = [
        for (final id in [camadas[0].id, camadas[1].id])
          _camadas(c)
              .firstWhere((l) => l.id == id)
              .opacity
              .keyframes
              .first
              .time,
      ];
      expect(
        marcas[0],
        isNot(marcas[1]),
        reason: 'a cascata existia no motor e nunca teve quem a chamasse',
      );
    });
  });
}
