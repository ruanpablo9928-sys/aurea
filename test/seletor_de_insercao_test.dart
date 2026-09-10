// PROMPT 03 DA ESPECIFICACAO AM ONLY (rev. 02): SELETOR DE INSERCAO.
//
// "Preserve a ordem Forma, Midia, Audio, Objeto / Elemento e Modelo;
// mantenha Desenho a mao livre, Desenho vetorial, Texto e X nas regioes
// da referencia." / "Fechar nao deve criar objeto nem alterar o
// projeto." / "Ao inserir, abrir o contexto correto do objeto novo."
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/freehand_session.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape_library.dart';
import 'package:aurea/src/features/editor/presentation/contexto_do_editor.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/seletor_de_insercao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _montar(WidgetTester tester) async {
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

Future<void> abrirSeletor(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
  await tester.pump();
}

/// A GRAVACAO E ADIADA em 900 ms; sem deixar o relogio andar, o teste
/// termina com um timer pendente e o framework reprova.
Future<void> assentar(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  group('a moldura', () {
    testWidgets('o + abre UMA moldura ancorada no rodape', (tester) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);

      expect(c.read(barraDeAdicaoAbertaProvider), isTrue);
      final r = tester.getRect(find.byType(SeletorDeInsercao));
      final tela = tester.getRect(find.byType(EditorScreen));
      expect(
        r.bottom,
        tela.bottom,
        reason: 'a moldura do AM encosta no rodape; a antiga ficava no meio',
      );
      expect(r.left, tela.left);
      expect(r.right, tela.right);
    });

    testWidgets('cinco abas, nesta ordem, com Forma ativa', (tester) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);

      for (final r in const [
        'Inserir Forma',
        'Inserir Midia',
        'Inserir Audio',
        'Inserir Objeto / Elemento',
        'Inserir Modelo',
      ]) {
        expect(find.bySemanticsLabel(r), findsOneWidget, reason: 'falta $r');
      }
      expect(c.read(abaDeInsercaoProvider), AbaDeInsercao.forma);

      // A ORDEM E DA ESQUERDA PARA A DIREITA, sem rolagem.
      var x = -1.0;
      for (final r in const [
        'Inserir Forma',
        'Inserir Midia',
        'Inserir Audio',
        'Inserir Objeto / Elemento',
        'Inserir Modelo',
      ]) {
        final centro = tester.getCenter(find.bySemanticsLabel(r)).dx;
        expect(centro, greaterThan(x), reason: '$r saiu de ordem');
        x = centro;
      }
    });

    testWidgets('trocar de aba muda so o corpo; o trilho fica', (tester) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);
      final trilho = tester.getRect(find.bySemanticsLabel('Fechar o seletor'));
      final moldura = tester.getRect(find.byType(SeletorDeInsercao));

      await tester.tap(find.bySemanticsLabel('Inserir Objeto / Elemento'));
      await tester.pump();

      expect(c.read(abaDeInsercaoProvider), AbaDeInsercao.objeto);
      expect(tester.getRect(find.bySemanticsLabel('Fechar o seletor')), trilho);
      expect(tester.getRect(find.byType(SeletorDeInsercao)), moldura);
      expect(find.bySemanticsLabel('Camera'), findsOneWidget);
    });
  });

  group('o trilho da direita', () {
    testWidgets('Texto cria a camada sem passar por familia nenhuma', (
      tester,
    ) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);

      await tester.tap(find.bySemanticsLabel('Texto'));
      await assentar(tester);

      final camadas = c.read(editorControllerProvider).layers;
      expect(camadas.single, isA<TextLayer>());
      expect(c.read(barraDeAdicaoAbertaProvider), isFalse);
      expect(
        c.read(contextoDoEditorProvider),
        ContextoDoEditor.camada,
        reason: 'inserir leva ao contexto do objeto novo (pagina 9)',
      );
    });

    testWidgets('o X fecha sem criar objeto nem alterar o projeto', (
      tester,
    ) async {
      final c = await _montar(tester);
      final antes = c.read(editorControllerProvider);
      await abrirSeletor(tester);

      await tester.tap(find.bySemanticsLabel('Fechar o seletor'));
      await tester.pump();

      expect(c.read(barraDeAdicaoAbertaProvider), isFalse);
      expect(c.read(editorControllerProvider), antes);
      expect(c.read(editorControllerProvider).layers, isEmpty);
    });

    testWidgets('o desenho a mao livre tem porta, e ela liga o modo', (
      tester,
    ) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);

      await tester.tap(find.bySemanticsLabel('Desenho a mao livre'));
      await tester.pump();

      expect(c.read(freehandRequestProvider), isTrue);
      expect(c.read(barraDeAdicaoAbertaProvider), isFalse);
      expect(find.byKey(const ValueKey('freehand-canvas')), findsOneWidget);
    });

    testWidgets('o desenho vetorial coloca vertice a vertice', (tester) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);
      await tester.tap(find.bySemanticsLabel('Desenho vetorial'));
      await tester.pump();

      expect(c.read(desenhoVetorialProvider), isTrue);
      final tela = find.byKey(const ValueKey('caneta-vetorial'));
      expect(tela, findsOneWidget);

      final r = tester.getRect(tela);
      await tester.tapAt(r.center - const Offset(40, 30));
      await tester.pump();
      await tester.tapAt(r.center + const Offset(40, -30));
      await tester.pump();
      await tester.tapAt(r.center + const Offset(0, 40));
      await tester.pump();
      expect(
        c.read(editorControllerProvider).layers,
        isEmpty,
        reason: 'pousar pontos ainda nao e criar camada',
      );

      await tester.tap(find.bySemanticsLabel('Concluir o desenho vetorial'));
      await assentar(tester);

      final camadas = c.read(editorControllerProvider).layers;
      expect(camadas.single, isA<ShapeLayer>());
      expect(camadas.single.name, contains('Desenho vetorial'));
      expect(c.read(desenhoVetorialProvider), isFalse);
    });
  });

  group('o catalogo de formas', () {
    testWidgets('as trinta formas da biblioteca tem porta', (tester) async {
      await _montar(tester);
      await abrirSeletor(tester);
      // Tres linhas de cinco por pagina: a primeira pagina mostra 15.
      var achadas = 0;
      for (final e in shapeLibrary.take(15)) {
        if (find.bySemanticsLabel(e.nome).evaluate().isNotEmpty) achadas++;
      }
      expect(achadas, 15, reason: 'a pagina tem 3 x 5 = 15 formas');
    });

    testWidgets('tocar numa forma cria a camada com a geometria DELA', (
      tester,
    ) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);

      await tester.tap(find.bySemanticsLabel('Cruz'));
      await assentar(tester);

      final camada = c.read(editorControllerProvider).layers.single;
      expect(camada, isA<ShapeLayer>());
      expect(camada.name, contains('Cruz'));
      expect(
        (camada as ShapeLayer).contents,
        isNotEmpty,
        reason: 'o glifo da biblioteca e a geometria, nao so um icone',
      );
    });
  });

  group('objeto / elemento', () {
    testWidgets('a grade 2 x 2 tem os quatro objetos da referencia', (
      tester,
    ) async {
      await _montar(tester);
      await abrirSeletor(tester);
      await tester.tap(find.bySemanticsLabel('Inserir Objeto / Elemento'));
      await tester.pump();

      for (final r in const [
        'Camera',
        'Grupo Vazio',
        'Nulo',
        'Elemento / Projeto',
      ]) {
        expect(find.bySemanticsLabel(r), findsOneWidget, reason: 'falta $r');
      }
    });

    testWidgets('camera, grupo e nulo entram pelo mesmo caminho', (
      tester,
    ) async {
      final c = await _montar(tester);
      for (final (rotulo, tipo) in <(String, Type)>[
        ('Camera', CameraLayer),
        ('Grupo Vazio', GroupLayer),
        ('Nulo', NullLayer),
      ]) {
        await abrirSeletor(tester);
        await tester.tap(find.bySemanticsLabel('Inserir Objeto / Elemento'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel(rotulo));
        await assentar(tester);
        final nova = c.read(editorControllerProvider).layers.first;
        expect(
          nova.runtimeType,
          tipo,
          reason: '$rotulo nao criou um objeto de verdade',
        );
        expect(c.read(contextoDoEditorProvider), ContextoDoEditor.camada);
      }
      expect(c.read(editorControllerProvider).layers.length, 3);
    });

    testWidgets('os elementos da Aurea moram na familia correspondente', (
      tester,
    ) async {
      final c = await _montar(tester);
      await abrirSeletor(tester);
      await tester.tap(find.bySemanticsLabel('Inserir Objeto / Elemento'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Elemento / Projeto'));
      await tester.pump();

      for (final r in const ['Cena 3D', 'Particulas', 'Camada de ajuste']) {
        expect(find.bySemanticsLabel(r), findsOneWidget, reason: 'falta $r');
      }
      expect(
        c.read(editorControllerProvider).layers,
        isEmpty,
        reason: 'abrir um nivel nao cria camada nenhuma',
      );

      await tester.tap(find.bySemanticsLabel('Voltar aos objetos'));
      await tester.pump();
      expect(find.bySemanticsLabel('Camera'), findsOneWidget);
    });
  });
}
