// O 3D DA CAMADA: o interruptor e os tres eixos de giro.
//
// `toggle3D` existia desde sempre e o unico chamador era um teste — o
// campo de profundidade do painel de transformacao ficava
// permanentemente apagado para texto, forma, imagem, video e legenda, e
// `editRotationX` / `editRotationY` nao tinham superficie nenhuma,
// apesar de o palco ja desenhar a inclinacao com perspectiva.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_transformacao.dart';
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

Future<_Bancada> _montar(WidgetTester tester, String categoria) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.addTextLayer(Duration.zero, text: 'Um');
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

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

Future<void> _digitar(
  WidgetTester tester,
  String rotulo,
  String valor,
) async {
  final alvo = find.bySemanticsLabel('Valor de $rotulo');
  await tester.ensureVisible(alvo);
  await tester.pumpAndSettle();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).last, valor);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
  await tester.pumpAndSettle();
}

void main() {
  group('o interruptor', () {
    testWidgets('liga e desliga o 3D da camada', (tester) async {
      final m = await _montar(tester, 'camada');
      expect(_camada(m.c, m.id).is3D, isFalse);

      await _tocar(tester, 'Ligar o 3D da camada');
      expect(_camada(m.c, m.id).is3D, isTrue);
      expect(
        find.bySemanticsLabel('Desligar o 3D da camada'),
        findsOneWidget,
      );

      await _tocar(tester, 'Desligar o 3D da camada');
      expect(_camada(m.c, m.id).is3D, isFalse);
    });

    testWidgets('a espessura so aparece com o 3D ligado', (tester) async {
      final m = await _montar(tester, 'camada');
      expect(find.bySemanticsLabel('Espessura 3D'), findsNothing);

      await _tocar(tester, 'Ligar o 3D da camada');
      expect(find.bySemanticsLabel('Espessura 3D'), findsOneWidget);

      await _digitar(tester, 'Espessura 3D', '120');
      expect(
        m.c.read(editorControllerProvider).metaOf(m.id).extrude,
        closeTo(120, .01),
      );
    });
  });

  group('o giro em tres eixos', () {
    testWidgets('em 2D continua um dial so', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.girar;
      await tester.pump();

      expect(find.bySemanticsLabel('Girar a camada'), findsOneWidget);
      expect(find.bySemanticsLabel('Girar em X'), findsNothing);
    });

    testWidgets('com 3D viram tres dials e tres campos', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(editorControllerProvider.notifier).toggle3D(m.id);
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.girar;
      await tester.pump();

      expect(find.bySemanticsLabel('Girar a camada'), findsNothing);
      for (final eixo in const ['X', 'Y', 'Z']) {
        expect(find.bySemanticsLabel('Girar em $eixo'), findsOneWidget);
        expect(find.bySemanticsLabel('Valor de Giro em $eixo'), findsOneWidget);
      }
    });

    testWidgets('digitar X e Y escreve nos eixos certos', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(editorControllerProvider.notifier).toggle3D(m.id);
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.girar;
      await tester.pump();

      await _digitar(tester, 'Giro em X', '35');
      await _digitar(tester, 'Giro em Y', '-20');

      final l = _camada(m.c, m.id);
      expect(l.rotationX.valueAt(Duration.zero), closeTo(35, .01));
      expect(l.rotationY.valueAt(Duration.zero), closeTo(-20, .01));
      expect(
        l.rotation.valueAt(Duration.zero),
        0,
        reason: 'mexer em X e Y nao pode girar o Z',
      );
    });

    testWidgets('um losango marca os TRES eixos', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(editorControllerProvider.notifier).toggle3D(m.id);
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.girar;
      m.p.seek(const Duration(milliseconds: 400));
      await tester.pump();

      await _tocar(tester, 'Marcar keyframe aqui');

      // No motor a rotacao e UMA propriedade de tres eixos, e nao tres
      // propriedades: marcar num marca nos tres, e a curva vale para os
      // tres. Um losango so e a promessa correta.
      final l = _camada(m.c, m.id);
      expect(l.rotation.isAnimated, isTrue);
      expect(l.rotationX.isAnimated, isTrue);
      expect(l.rotationY.isAnimated, isTrue);
    });
  });

  group('a profundidade', () {
    testWidgets('o campo z so aceita dedo com o 3D ligado', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.mover;
      await tester.pump();

      // O CAMPO SE ANUNCIA COMO BOTAO SO QUANDO ACEITA O DEDO
      // (`CampoDeValor` usa `button: _digitavel`). Sem 3D ele fica a
      // vista e apagado — some-lo mudaria a largura da fileira toda vez
      // que alguem ligasse o 3D.
      final campo = find.bySemanticsLabel('Valor de z');
      expect(campo, findsOneWidget);
      expect(
        tester.getSemantics(campo).hasFlag(SemanticsFlag.isButton),
        isFalse,
        reason: 'sem 3D o render ignora o z; o campo nao pode aceitar toque',
      );

      m.c.read(editorControllerProvider.notifier).toggle3D(m.id);
      await tester.pump();
      expect(
        tester.getSemantics(campo).hasFlag(SemanticsFlag.isButton),
        isTrue,
      );
    });

    testWidgets('o z segue a mesma regra das irmas: editar nao crava', (
      tester,
    ) async {
      final m = await _montar(tester, 'transformar');
      final c = m.c.read(editorControllerProvider.notifier);
      c.toggle3D(m.id);
      await tester.pump();

      c.editPositionZ(m.id, const Duration(milliseconds: 500), -300);

      final l = _camada(m.c, m.id);
      expect(l.positionZ.isAnimated, isFalse);
      expect(
        l.positionZ.base,
        closeTo(-300, .01),
        reason: 'estatica: a profundidade muda a base, sem marca',
      );
    });

    testWidgets('o losango nao mente quando so o z tem marca', (tester) async {
      final m = await _montar(tester, 'transformar');
      final c = m.c.read(editorControllerProvider.notifier);
      c.toggle3D(m.id);
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.mover;
      m.p.seek(const Duration(milliseconds: 300));
      await tester.pump();

      // Marca so na profundidade: o motor apaga quando QUALQUER uma das
      // duas trilhas tem marca ali, e o rail so olhava X/Y — dizia
      // "marcar aqui" e o toque APAGAVA.
      c.toggleKeyframe(
        m.id,
        const Duration(milliseconds: 300),
        LayerProp.position,
      );
      // A marca de posicao nasce em X/Y e no Z (a camada e 3D); tirar a
      // de X/Y a mao deixa SO a profundidade marcada, que e o caso.
      final l = _camada(m.c, m.id);
      c.openProject(
        m.c.read(editorControllerProvider).copyWith(
          layers: [
            for (final x in m.c.read(editorControllerProvider).layers)
              if (x.id == m.id)
                x.copyLayer(position: AnimatedOffset(l.position.base))
              else
                x,
          ],
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Tirar o keyframe daqui'), findsOneWidget);
      expect(find.bySemanticsLabel('Marcar keyframe aqui'), findsNothing);
    });
  });
}
