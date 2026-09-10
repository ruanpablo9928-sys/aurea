// COR E PREENCHIMENTO: o cartao que passou a existencia inteira
// desligado.
//
// Ele estava reservado em `categoriasDaCamada` com `disponivel: false` e
// "Chega numa proxima entrega". Enquanto isso todo texto do app era
// branco e todo retangulo nascia e morria no mesmo azul, com
// `setShapePrimaryColor`, `updateShapeGradient` e `updateShapeStroke`
// parados no motor sem um unico chamador. Sem cor nao ha peca grafica.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/escolha_de_cor.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_cor.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/repositorio_sem_disco.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

Future<_Bancada> _montar(
  WidgetTester tester, {
  List<ShapeItem>? forma,
  bool particulas = false,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  if (forma != null) {
    c.addShapeLayer(Duration.zero, contents: forma);
  } else if (particulas) {
    c.addParticlesLayer(Duration.zero);
  } else {
    c.addTextLayer(Duration.zero, text: 'Um');
  }
  final camada = container.read(editorControllerProvider).layers.single;
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
                categoriaId: 'cor',
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

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

/// O label da amostra pronta de indice [i], dentro do seletor [dono].
String _amostra(String dono, int i) {
  final cor = EscolhaDeCor.prontas[i];
  return '$dono ${(cor.r * 255).round()} ${(cor.g * 255).round()} '
      '${(cor.b * 255).round()}';
}

void main() {
  group('o cartao', () {
    test('existe em quem tem cor, e nao no resto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      c.addShapeLayer(Duration.zero);
      final id = c.addAudioLayer(
        Duration.zero,
        'a.m4a',
        'Audio',
        const Duration(seconds: 2),
      );
      final camadas = container.read(editorControllerProvider).layers;
      for (final l in camadas.where((x) => x.id != id)) {
        expect(
          categoriasDaCamada(l).map((x) => x.id),
          contains('cor'),
          reason: '${l.runtimeType} tem cor e nao tem cartao',
        );
      }
      // Audio nao tem cor propria; o cartao abriria num painel vazio.
      expect(
        categoriasDaCamada(camadas.firstWhere((l) => l.id == id))
            .map((x) => x.id),
        isNot(contains('cor')),
      );
    });

    test('o cartao deixou de nascer desabilitado', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(editorControllerProvider.notifier)
          .addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      final cartao = categoriasDaCamada(
        camada,
      ).firstWhere((x) => x.id == 'cor');
      expect(cartao.disponivel, isTrue);
      expect(cartao.porQueNao, isNull);
    });
  });

  group('texto', () {
    testWidgets('uma amostra pronta pinta o texto', (tester) async {
      final m = await _montar(tester);
      expect((_camada(m.c, m.id) as TextLayer).color, const Color(0xFFFFFFFF));

      // O indice 4 e o amarelo da paleta.
      await _tocar(tester, _amostra('Cor do texto', 4));
      expect(
        (_camada(m.c, m.id) as TextLayer).color.toARGB32(),
        EscolhaDeCor.prontas[4].toARGB32(),
      );
    });

    testWidgets('digitar um canal muda so aquele canal', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, _amostra('Cor do texto', 1)); // preto

      final campo = find.bySemanticsLabel('Valor de Cor do texto Verde');
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      await tester.tap(campo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '200');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
      await tester.pumpAndSettle();

      final cor = (_camada(m.c, m.id) as TextLayer).color;
      expect((cor.g * 255).round(), 200);
      expect((cor.r * 255).round(), 0);
      expect((cor.b * 255).round(), 0);
    });
  });

  group('forma', () {
    testWidgets('o preenchimento chapado muda de cor', (tester) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      final antes = (_camada(m.c, m.id) as ShapeLayer)
          .contents
          .whereType<ShapeFill>()
          .first
          .color;

      await _tocar(tester, _amostra('Preenchimento', 2)); // vermelho
      final depois = (_camada(m.c, m.id) as ShapeLayer)
          .contents
          .whereType<ShapeFill>()
          .first
          .color;
      expect(depois.toARGB32(), isNot(antes.toARGB32()));
      expect(depois.toARGB32(), EscolhaDeCor.prontas[2].toARGB32());
    });

    // OS TESTES DO CONTORNO MUDARAM DE ARQUIVO.
    //
    // A especificacao e explicita (pagina 13): o painel de Cor e
    // preenchimento contem os controles de COR, e o traco pertence a
    // familia Borda e sombra. Eles vivem em `borda_e_sombra_test.dart`.
  });

  group('particulas', () {
    testWidgets('a cor do fim da vida fica atras de um interruptor', (
      tester,
    ) async {
      final m = await _montar(tester, particulas: true);
      expect(find.bySemanticsLabel('Cor no fim da vida'), findsNothing);

      await _tocar(tester, 'Mudar de cor ao apagar');
      expect(
        (_camada(m.c, m.id) as ParticlesLayer).colorEnd,
        isNotNull,
      );
      expect(find.bySemanticsLabel('Cor no fim da vida'), findsOneWidget);
    });
  });

  group('o fundo da composicao', () {
    testWidgets('abre pelo nome do projeto, e pinta a previa', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(RepositorioSemDisco()),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(editorControllerProvider.notifier)
          .addTextLayer(Duration.zero, text: 'Um');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorScreen()),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Ajustes da composicao'));
      await tester.pump();
      expect(
        container.read(estadoDoPainelProvider),
        EstadoDoPainel.composicao,
      );
      expect(find.bySemanticsLabel('Fundo da composicao'), findsOneWidget);

      await _tocar(tester, _amostra('Fundo da composicao', 9)); // roxo
      expect(
        container.read(editorControllerProvider).backgroundColor.toARGB32(),
        EscolhaDeCor.prontas[9].toARGB32(),
      );

      // A EXPORTACAO SEMPRE PINTOU ESTA COR; a previa tinha um preto
      // cravado. Escolher amarelo mudaria o arquivo e nao mudaria um
      // pixel da tela em que a pessoa esta olhando.
      final moldura = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('moldura-da-previa')),
      );
      expect(
        (moldura.decoration as BoxDecoration).color?.toARGB32(),
        EscolhaDeCor.prontas[9].toARGB32(),
      );
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
