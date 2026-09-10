// OS CONTROLES DE VERDADE: o painel deixou de ser so estrutura.
//
// Ate a entrega anterior as categorias abriam e nao faziam nada. Estes
// testes cobram as tres regras que valem para todo controle:
//
//   1. UM GESTO, UM DESFAZER;
//   2. o valor mostrado e o do CABECOTE;
//   3. quem decide se a edicao vira keyframe e o motor, pelo
//      interruptor do keyframe automatico.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Monta UMA categoria aberta, sozinha, com um projeto de verdade atras.
Future<({ProviderContainer c, PlaybackController p, String id})> _montar(
  WidgetTester tester,
  String categoria, {
  bool forma = false,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  if (forma) {
    // O MESMO PRESET QUE O MENU DE ADICAO USA. Uma camada de forma sem
    // desenho parametrico existe (SVG importado, por exemplo) e tem
    // aviso proprio — mas nao e o que o `+` cria.
    c.addShapeLayer(Duration.zero, contents: ShapePresets.paramRect());
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
              if (atual == null) {
                return const Text('sem camada', key: ValueKey('sem-camada'));
              }
              return ControlesDaCategoria(
                categoriaId: categoria,
                camada: atual,
                playback: playback,
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

void main() {
  group('opacidade', () {
    testWidgets('arrastar o deslizante muda a opacidade da camada', (
      tester,
    ) async {
      final m = await _montar(tester, 'opacidade');
      expect(_camada(m.c, m.id).opacity.valueAt(Duration.zero), 1);

      await tester.drag(find.byType(Slider), const Offset(-200, 0));
      await tester.pump();

      expect(
        _camada(m.c, m.id).opacity.valueAt(Duration.zero),
        lessThan(1),
        reason: 'o deslizante nao chegou no comando',
      );
    });

    testWidgets('um arrasto, um desfazer', (tester) async {
      final m = await _montar(tester, 'opacidade');
      final antes = _camada(m.c, m.id).opacity.valueAt(Duration.zero);

      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();
      expect(_camada(m.c, m.id).opacity.valueAt(Duration.zero), isNot(antes));

      m.c.read(editorControllerProvider.notifier).undo();
      await tester.pump();

      expect(
        _camada(m.c, m.id).opacity.valueAt(Duration.zero),
        antes,
        reason:
            'o arrasto manda dezenas de valores; desfazer tem de devolver '
            'o movimento INTEIRO, e nao um pedaco dele',
      );
    });
  });

  group('o keyframe', () {
    testWidgets('desligado, editar muda o valor base e nao cria marca', (
      tester,
    ) async {
      final m = await _montar(tester, 'opacidade');
      expect(m.c.read(autoKeyframeProvider), isFalse);
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();

      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();

      expect(
        _camada(m.c, m.id).opacity.isAnimated,
        isFalse,
        reason: 'sem keyframe automatico, editar nao anima nada',
      );
    });

    testWidgets('ligado, editar crava a marca no cabecote', (tester) async {
      final m = await _montar(tester, 'opacidade');
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Keyframe automatico'));
      await tester.pump();
      expect(m.c.read(autoKeyframeProvider), isTrue);

      await tester.drag(find.byType(Slider), const Offset(-150, 0));
      await tester.pump();

      final l = _camada(m.c, m.id);
      expect(l.opacity.isAnimated, isTrue);
      expect(
        l.opacity.hasKeyframeAt(const Duration(seconds: 1)),
        isTrue,
        reason: 'a marca tem de nascer EM CIMA do cabecote',
      );
    });

    testWidgets('o losango marca e desmarca no cabecote', (tester) async {
      final m = await _montar(tester, 'opacidade');
      m.p.seek(const Duration(milliseconds: 800));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Marcar keyframe de Opacidade'));
      await tester.pump();
      expect(
        _camada(m.c, m.id).opacity.hasKeyframeAt(
          const Duration(milliseconds: 800),
        ),
        isTrue,
      );

      await tester.tap(find.bySemanticsLabel('Tirar keyframe de Opacidade'));
      await tester.pump();
      expect(
        _camada(m.c, m.id).opacity.hasKeyframeAt(
          const Duration(milliseconds: 800),
        ),
        isFalse,
      );
    });

    testWidgets('o valor mostrado e o do CABECOTE', (tester) async {
      final m = await _montar(tester, 'opacidade');
      final c = m.c.read(editorControllerProvider.notifier);
      // Uma animacao de 100% a 0% ao longo de dois segundos.
      c.toggleKeyframe(m.id, Duration.zero, LayerProp.opacity);
      c.editOpacity(m.id, const Duration(seconds: 2), 0);
      m.p.seek(Duration.zero);
      await tester.pump();

      double valorNaTela() {
        final t = tester.widget<Slider>(find.byType(Slider));
        return t.value;
      }

      final noZero = valorNaTela();
      m.p.seek(const Duration(seconds: 2));
      await tester.pump();
      expect(
        valorNaTela(),
        lessThan(noZero),
        reason:
            'a propriedade e animada: o controle tem de mostrar o que a '
            'previa mostra NAQUELE instante',
      );
    });
  });

  group('transformar', () {
    testWidgets('os quatro parametros estao la e mexem na camada', (
      tester,
    ) async {
      final m = await _montar(tester, 'transformar');
      for (final rotulo in ['Posicao X', 'Posicao Y', 'Escala', 'Rotacao']) {
        expect(
          find.text(rotulo),
          findsOneWidget,
          reason: 'transformar perdeu "$rotulo"',
        );
      }

      final antes = _camada(m.c, m.id);
      await tester.drag(find.byType(Slider).at(3), const Offset(120, 0));
      await tester.pump();
      expect(
        _camada(m.c, m.id).rotation.valueAt(Duration.zero),
        isNot(antes.rotation.valueAt(Duration.zero)),
        reason: 'o quarto deslizante e a rotacao',
      );
    });
  });

  group('texto', () {
    testWidgets('digitar muda o texto da camada', (tester) async {
      final m = await _montar(tester, 'texto');
      await tester.enterText(find.byType(TextField), 'Comprar agora');
      await tester.pump();
      expect((_camada(m.c, m.id) as TextLayer).text, 'Comprar agora');
    });

    testWidgets('o tamanho da fonte e um deslizante', (tester) async {
      final m = await _montar(tester, 'texto');
      final antes = (_camada(m.c, m.id) as TextLayer).fontSize;
      await tester.drag(find.byType(Slider), const Offset(120, 0));
      await tester.pump();
      expect((_camada(m.c, m.id) as TextLayer).fontSize, greaterThan(antes));
    });
  });

  group('forma', () {
    testWidgets('largura e altura chegam no desenho', (tester) async {
      final m = await _montar(tester, 'forma', forma: true);
      expect(find.text('Largura'), findsOneWidget);
      expect(find.text('Altura'), findsOneWidget);

      double largura() {
        final l = _camada(m.c, m.id) as ShapeLayer;
        final s = l.contents.whereType<ShapeParametric>().first;
        return s.sizeX.valueAt(Duration.zero);
      }

      final antes = largura();
      // O DESLIZANTE PULA PARA ONDE O DEDO POUSA — e comportamento do
      // proprio `Slider`, e nao do controle. Entao o que o teste cobra e
      // que o valor CHEGOU no desenho, e nao para que lado ele foi.
      await tester.drag(find.byType(Slider).first, const Offset(-100, 0));
      await tester.pump();
      expect(
        largura(),
        isNot(antes),
        reason: 'o deslizante da largura nao chegou no desenho',
      );
    });
  });

  group('acoes da camada', () {
    testWidgets('duplicar cria a segunda; apagar tira as duas', (tester) async {
      final m = await _montar(tester, 'camada');
      await tester.tap(find.bySemanticsLabel('Duplicar'));
      await tester.pump();
      expect(m.c.read(editorControllerProvider).layers.length, 2);

      await tester.tap(find.bySemanticsLabel('Apagar'));
      await tester.pump();
      expect(m.c.read(editorControllerProvider).layers.length, 1);
    });

    testWidgets('dividir so com o cabecote DENTRO da camada', (tester) async {
      final m = await _montar(tester, 'camada');
      // No zero o cabecote esta na borda: dividir ali faria uma camada de
      // duracao zero.
      expect(m.p.time.value, Duration.zero);
      await tester.tap(find.bySemanticsLabel('Dividir no cabecote'));
      await tester.pump();
      expect(
        m.c.read(editorControllerProvider).layers.length,
        1,
        reason: 'o controle estava apagado, e apagado nao age',
      );

      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Dividir no cabecote'));
      await tester.pump();
      expect(
        m.c.read(editorControllerProvider).layers.length,
        2,
        reason: 'com o cabecote dentro, o corte faz duas camadas',
      );
    });
  });
}
