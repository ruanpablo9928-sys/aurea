// PROMPT 05 DA ESPECIFICACAO AM ONLY (rev. 02): BORDA E SOMBRA.
//
// O tile existia APAGADO, com "Chega numa proxima entrega" escrito nele.
// E nao era falta de motor: `LayerStyles` ja tinha traco, duas sombras,
// brilho e duas sobreposicoes, e o palco ja desenhava tudo — nenhum
// deles tinha um unico chamador na interface.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_borda.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

Future<_Bancada> _montar(
  WidgetTester tester, {
  List<ShapeItem>? forma,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  if (forma != null) {
    c.addShapeLayer(Duration.zero, contents: forma);
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
                categoriaId: 'borda',
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
  await tester.pump();
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

void main() {
  test('o tile deixou de ser uma promessa apagada', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .addTextLayer(Duration.zero, text: 'Um');
    final camada = container.read(editorControllerProvider).layers.single;
    final borda = categoriasDaCamada(
      camada,
    ).firstWhere((x) => x.id == 'borda');
    expect(borda.disponivel, isTrue);
    expect(borda.porQueNao, isNull);
  });

  group('a coluna de submodos', () {
    testWidgets('sao TRES, e o Traco nasce aberto', (tester) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      expect(m.c.read(submodoDaBordaProvider), SubmodoDaBorda.traco);
      // "Traco" e o nome do submodo E o titulo do subpainel aberto.
      for (final r in const ['Traco', 'Sombra', 'Brilho']) {
        expect(find.bySemanticsLabel(r), findsWidgets, reason: 'falta $r');
      }
    });

    testWidgets('trocar de submodo troca so o miolo', (tester) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      final antes = _camada(m.c, m.id);

      await _tocar(tester, 'Sombra');
      expect(m.c.read(submodoDaBordaProvider), SubmodoDaBorda.sombra);
      expect(find.bySemanticsLabel('Ligar Sombra projetada'), findsOneWidget);
      expect(
        _camada(m.c, m.id),
        antes,
        reason: 'escolher um submodo nao pode alterar o projeto',
      );
    });
  });

  group('traco de forma', () {
    testWidgets('o interruptor cria o contorno, e o traco anima', (
      tester,
    ) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      expect(
        (_camada(m.c, m.id) as ShapeLayer).contents.whereType<ShapeStroke>(),
        isEmpty,
      );

      await _tocar(tester, 'Ligar Traco');
      expect(
        (_camada(m.c, m.id) as ShapeLayer).contents.whereType<ShapeStroke>(),
        hasLength(1),
      );
      expect(find.bySemanticsLabel('Espessura do traco'), findsOneWidget);

      await _tocar(tester, 'Espessura do traco');
      expect(m.c.read(parametroDaBordaProvider), 'width');
      m.p.seek(const Duration(milliseconds: 300));
      await tester.pump();
      await _tocar(tester, 'Marcar keyframe aqui');

      final traco = (_camada(m.c, m.id) as ShapeLayer)
          .contents
          .whereType<ShapeStroke>()
          .first;
      expect(traco.width.isAnimated, isTrue);
    });

    testWidgets('as SEIS opcoes graficas mexem em ponta e junta', (
      tester,
    ) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      await _tocar(tester, 'Ligar Traco');

      for (final r in const [
        'Ponta reta',
        'Ponta redonda',
        'Ponta quadrada',
        'Junta em bico',
        'Junta redonda',
        'Junta chanfrada',
      ]) {
        expect(find.bySemanticsLabel(r), findsOneWidget, reason: 'falta $r');
      }

      await _tocar(tester, 'Ponta quadrada');
      var traco = (_camada(m.c, m.id) as ShapeLayer)
          .contents
          .whereType<ShapeStroke>()
          .first;
      expect(traco.cap, StrokeCap.square);

      await _tocar(tester, 'Junta chanfrada');
      traco = (_camada(m.c, m.id) as ShapeLayer)
          .contents
          .whereType<ShapeStroke>()
          .first;
      expect(traco.join, StrokeJoin.bevel);
    });

    testWidgets('"Iniciar" e "Fim" desenham o traco de verdade', (
      tester,
    ) async {
      final m = await _montar(tester, forma: ShapePresets.paramRect());
      await _tocar(tester, 'Ligar Traco');
      expect(
        (_camada(m.c, m.id) as ShapeLayer).contents.whereType<TrimOperator>(),
        isEmpty,
      );

      await _tocar(tester, 'Iniciar e Fim');
      expect(
        (_camada(m.c, m.id) as ShapeLayer).contents.whereType<TrimOperator>(),
        hasLength(1),
        reason: 'o TrimOperator existia no motor com zero chamadores',
      );
      expect(find.bySemanticsLabel('Iniciar o traco'), findsOneWidget);
      expect(find.bySemanticsLabel('Fim do traco'), findsOneWidget);
    });
  });

  group('estilos de camada', () {
    testWidgets('o traco de um texto passa pelo LayerStyles', (tester) async {
      final m = await _montar(tester);
      expect(m.c.read(editorControllerProvider).metaOf(m.id).styles.stroke,
          isNull);

      await _tocar(tester, 'Ligar Traco');
      final estilo =
          m.c.read(editorControllerProvider).metaOf(m.id).styles.stroke;
      expect(estilo, isNotNull);
      expect(estilo!.enabled, isTrue);
    });

    testWidgets('sombra e brilho ligam e desligam sem perder os numeros', (
      tester,
    ) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Sombra');
      await _tocar(tester, 'Ligar Sombra projetada');
      var sombra =
          m.c.read(editorControllerProvider).metaOf(m.id).styles.dropShadow;
      expect(sombra, isNotNull);
      expect(sombra!.enabled, isTrue);
      final distancia = sombra.distance.valueAt(Duration.zero);

      await _tocar(tester, 'Desligar Sombra projetada');
      sombra =
          m.c.read(editorControllerProvider).metaOf(m.id).styles.dropShadow;
      expect(sombra!.enabled, isFalse);
      expect(
        sombra.distance.valueAt(Duration.zero),
        distancia,
        reason: 'desligar guarda os numeros; nao e comecar de novo',
      );

      await _tocar(tester, 'Brilho');
      await _tocar(tester, 'Ligar Brilho externo');
      expect(
        m.c.read(editorControllerProvider).metaOf(m.id).styles.outerGlow,
        isNotNull,
      );
    });
  });
}
