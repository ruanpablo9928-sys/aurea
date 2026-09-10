// COMPOSICAO: mistura, recorte, parentesco e grupo.
//
// Quatro motores completos que nao tinham porta nenhuma. `setBlendMode`
// e `setCustomBlend` (27 modos, com o compositor de dois andares
// pronto), `setMatteFromAbove` (com o grupo isolado e a conversao de
// canal ja no palco), `linkProperty(..., LayerProp.parent, ...)` e
// `groupLayer`/`enterGroup`/`exitGroup`: zero chamadores na interface.
//
// Estes testes cobram a PORTA. O caso mais importante e o ultimo: sair
// do grupo nao pode depender de lembrar um gesto — quem entra tem de
// conseguir sair pelo mesmo lugar por onde sai de tudo.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_mistura.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/blend_extra.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/mask.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

/// Monta a categoria [categoria] com [quantas] camadas de texto; a
/// selecionada e a de indice [indice] (0 = a de cima da pilha).
Future<_Bancada> _montar(
  WidgetTester tester,
  String categoria, {
  int quantas = 1,
  int indice = 0,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < quantas; i++) {
    c.addTextLayer(Duration.zero, text: 'Camada $i');
  }
  final camada = container.read(editorControllerProvider).layers[indice];
  container.read(selectedLayerProvider.notifier).state = camada.id;

  final playback = PlaybackController(
    vsync: _Vsync(),
    durationOf: () => container.read(editorControllerProvider).duration,
  );
  addTearDown(playback.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final atual = ref
                  .watch(editorControllerProvider)
                  .layers
                  .where((l) => l.id == camada.id)
                  .firstOrNull;
              if (atual == null) return const SizedBox.shrink();
              return ControlesDaCategoria(
                categoriaId: categoria,
                camada: atual,
                playback: playback,
                aoVoltar: () {},
              );
            },
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback, id: camada.id);
}

/// ABRE UMA CATEGORIA DO ACCORDION de mistura.
///
/// O painel virou "Homogeneizacao e opacidade": a opacidade fica fixa no
/// topo e as categorias de blend sao linhas que expandem no lugar. Um
/// chip so existe na tela com a categoria dele aberta.
Future<void> _abrirCategoria(
  WidgetTester tester,
  ProviderContainer c,
  String nome,
) async {
  c.read(categoriaDeMisturaProvider.notifier).state = nome;
  await tester.pump();
}

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

void main() {
  group('modo de mistura', () {
    testWidgets('um modo nativo entra', (tester) async {
      final m = await _montar(tester, 'opacidade');
      expect(_camada(m.c, m.id).blendMode, BlendMode.srcOver);

      await _abrirCategoria(tester, m.c, 'Escurecer');
      await tester.tap(find.bySemanticsLabel('Modo Multiplicar'));
      await tester.pump();
      expect(_camada(m.c, m.id).blendMode, BlendMode.multiply);
      expect(_camada(m.c, m.id).customBlend, isNull);
    });

    testWidgets('um modo proprio entra, e desliga o nativo', (tester) async {
      final m = await _montar(tester, 'opacidade');
      await _abrirCategoria(tester, m.c, 'Escurecer');
      await tester.tap(find.bySemanticsLabel('Modo Multiplicar'));
      await tester.pump();

      // OS PROPRIOS SAO METADE DA LISTA e nao existem no Flutter: eles
      // passam pelo compositor de dois andares. Um so pode mandar.
      await _abrirCategoria(tester, m.c, 'Contraste');
      await tester.tap(find.bySemanticsLabel('Modo Vivid Light'));
      await tester.pump();
      expect(_camada(m.c, m.id).customBlend, AureaBlend.vividLight);
      expect(_camada(m.c, m.id).blendMode, BlendMode.srcOver);

      await _abrirCategoria(tester, m.c, 'Normal');
      await tester.tap(find.bySemanticsLabel('Modo Normal'));
      await tester.pump();
      expect(_camada(m.c, m.id).customBlend, isNull);
    });

    testWidgets('todos os 27 modos tem um chip', (tester) async {
      final m = await _montar(tester, 'opacidade');
      // O ACCORDION MOSTRA UMA CATEGORIA POR VEZ: a conta e feita
      // abrindo as sete, que e o caminho que a pessoa tem.
      final vistos = <String>{};
      for (final (familia, modos) in familiasDeMistura) {
        await _abrirCategoria(tester, m.c, familia);
        for (final modo in modos) {
          if (find
              .bySemanticsLabel('Modo ${modo.nome}')
              .evaluate()
              .isNotEmpty) {
            vistos.add(modo.nome);
          }
        }
      }
      for (final b in AureaBlend.values) {
        expect(
          vistos,
          contains(aureaBlendLabel(b)),
          reason: '${aureaBlendLabel(b)} existe no motor e nao na tela',
        );
      }
      for (final nome in const [
        'Normal',
        'Escurecer',
        'Multiplicar',
        'Clarear',
        'Sobrepor',
        'Diferenca',
        'Luminosidade',
      ]) {
        expect(vistos, contains(nome));
      }
    });

    testWidgets('as sete categorias do AM, na ordem, com Mascara no fim', (
      tester,
    ) async {
      await _montar(tester, 'opacidade');
      var x = -1.0;
      for (final nome in const [
        'Normal',
        'Escurecer',
        'Clarear',
        'Contraste',
        'Diferenca',
        'Cor',
        'Mascara',
      ]) {
        final alvo = find.bySemanticsLabel('Categoria $nome');
        expect(alvo, findsOneWidget, reason: 'falta a categoria $nome');
        final y = tester.getCenter(alvo).dy;
        expect(y, greaterThan(x), reason: '$nome saiu de ordem');
        x = y;
      }
    });

    testWidgets('a opacidade fica FIXA acima da lista', (tester) async {
      await _montar(tester, 'opacidade');
      expect(find.bySemanticsLabel('Valor de Opacidade'), findsOneWidget);
      final antes = tester.getRect(find.bySemanticsLabel('Valor de Opacidade'));

      await tester.drag(
        find.bySemanticsLabel('Categoria Cor'),
        const Offset(0, -80),
      );
      await tester.pump();

      expect(
        tester.getRect(find.bySemanticsLabel('Valor de Opacidade')),
        antes,
        reason: 'so a lista rola; a opacidade e o controle mais usado',
      );
    });
  });

  group('recorte pela camada de cima', () {
    testWidgets('sem camada acima, so "Nenhum" responde', (tester) async {
      final m = await _montar(tester, 'opacidade');
      await _abrirCategoria(tester, m.c, 'Mascara');
      await tester.ensureVisible(find.bySemanticsLabel('Recorte Alfa'));
      await tester.pump();
      final chip = tester.getSemantics(find.bySemanticsLabel('Recorte Alfa'));
      expect(chip.hasFlag(SemanticsFlag.isEnabled), isFalse);

      await tester.tap(find.bySemanticsLabel('Recorte Alfa'), warnIfMissed: false);
      await tester.pump();
      expect(
        _camada(m.c, m.id).matteMode,
        MatteMode.none,
        reason: 'um chip apagado nao pode escrever no projeto',
      );
    });

    testWidgets('com camada acima, o alfa entra e diz quem recorta', (
      tester,
    ) async {
      // A segunda camada adicionada fica NO TOPO da pilha, entao a de
      // indice 1 e a de baixo — a que pode ser recortada.
      final m = await _montar(tester, 'opacidade', quantas: 2, indice: 1);
      await _abrirCategoria(tester, m.c, 'Mascara');
      final acima = m.c.read(editorControllerProvider).layers.first;
      expect(find.textContaining(acima.name), findsOneWidget);

      await tester.ensureVisible(
        find.bySemanticsLabel('Recorte Luma invertido'),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Recorte Luma invertido'));
      await tester.pump();

      final l = _camada(m.c, m.id);
      expect(l.matteMode, MatteMode.lumaInvert);
      expect(l.matteSourceId, acima.id);
    });
  });

  group('seguir outra camada', () {
    testWidgets('sozinha, nao ha quem seguir', (tester) async {
      await _montar(tester, 'camada');
      final acao = tester.getSemantics(
        find.bySemanticsLabel('Seguir outra camada'),
      );
      expect(acao.hasFlag(SemanticsFlag.isEnabled), isFalse);
    });

    testWidgets('escolher um pai cria o vinculo, e soltar tira', (
      tester,
    ) async {
      final m = await _montar(tester, 'camada', quantas: 2, indice: 1);
      final pai = m.c.read(editorControllerProvider).layers.first;

      await tester.tap(find.bySemanticsLabel('Seguir outra camada'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel(pai.name));
      await tester.pump();

      final vinculo = m.c
          .read(editorControllerProvider)
          .linkFor(m.id, LayerProp.parent);
      expect(vinculo, isNotNull);
      expect(vinculo!.sourceLayerId, pai.id);
      expect(find.bySemanticsLabel('Segue "${pai.name}"'), findsOneWidget);
      expect(
        m.c.read(escolhendoPaiProvider),
        isFalse,
        reason: 'escolher fecha a lista; ficar nela obrigaria a um voltar',
      );

      await tester.tap(find.bySemanticsLabel('Parar de seguir'));
      await tester.pump();
      expect(
        m.c.read(editorControllerProvider).linkFor(m.id, LayerProp.parent),
        isNull,
      );
    });

    testWidgets('a lista de candidatos nao inclui a propria camada', (
      tester,
    ) async {
      final m = await _montar(tester, 'camada', quantas: 3, indice: 1);
      final eu = _camada(m.c, m.id);

      await tester.tap(find.bySemanticsLabel('Seguir outra camada'));
      await tester.pump();
      expect(find.bySemanticsLabel(eu.name), findsNothing);
      for (final l in m.c.read(editorControllerProvider).layers) {
        if (l.id == m.id) continue;
        expect(find.bySemanticsLabel(l.name), findsOneWidget);
      }
    });
  });

  group('grupo', () {
    testWidgets('agrupar troca a camada por um grupo', (tester) async {
      final m = await _montar(tester, 'camada');
      await tester.tap(find.bySemanticsLabel('Agrupar'));
      await tester.pump();

      final camadas = m.c.read(editorControllerProvider).layers;
      expect(camadas.single, isA<GroupLayer>());
      expect((camadas.single as GroupLayer).children, hasLength(1));
    });
  });

  group('sair do grupo pela barra de cima', () {
    testWidgets('a seta vira "Sair do grupo", e sai', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final id = container.read(editorControllerProvider).layers.single.id;
      c.groupLayer(id);
      final grupo = container.read(editorControllerProvider).layers.single.id;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorScreen()),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Voltar'), findsOneWidget);

      c.enterGroup(grupo);
      await tester.pump();
      // ENTRAR SEM SAIDA SERIA UMA ARMADILHA: as edicoes feitas dentro
      // do grupo so voltam para ele em `exitGroup`.
      expect(find.bySemanticsLabel('Voltar'), findsNothing);
      expect(find.bySemanticsLabel('Sair do grupo'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Sair do grupo'));
      await tester.pump();

      expect(container.read(editorControllerProvider).layers.single.id, grupo);
      expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
      // A tela grava sozinha, com 900 ms de atraso; deixar o relogio
      // passar por ele evita um temporizador vivo depois do teste.
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
