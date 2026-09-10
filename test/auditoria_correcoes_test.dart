// AS CORRECOES QUE A AUDITORIA DA UI 1.0 PEDIU.
//
// Cada teste aqui nasceu de um defeito que a auditoria achou com
// arquivo e linha (`docs/auditoria-ui-1.0.md`). Sao todos da mesma
// familia: CONTROLE QUE ACEITA O DEDO E NAO FAZ O QUE PROMETE — o pior
// tipo, porque o ausente manda procurar noutro lugar e o inerte manda
// desconfiar do app inteiro.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
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

Future<({ProviderContainer c, PlaybackController p, String id})> _montar(
  WidgetTester tester,
  String categoria, {
  List<ShapeItem>? forma,
}) async {
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

/// Digita [valor] no campo de [rotulo] e confirma.
Future<void> _digitar(
  WidgetTester tester,
  String rotulo,
  String valor,
) async {
  await tester.tap(find.bySemanticsLabel('Valor de $rotulo'));
  await tester.pumpAndSettle();
  // PELAS CHAVES, e nao pelo texto: 'OK' e 'Cancelar' sao palavras que
  // podem aparecer noutro lugar da arvore, e o teste ficaria fragil por
  // um motivo que nada tem a ver com o que ele cobra.
  await tester.enterText(find.byType(EditableText).last, valor);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
  await tester.pumpAndSettle();
}

void main() {
  group('o campo Altura com a corrente travada', () {
    testWidgets('digitar nele muda a escala, e nao fica inerte', (
      tester,
    ) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.escalar;
      await tester.pump();
      expect(m.c.read(escalaTravadaProvider), isTrue);

      // O DEFEITO: travado, o metodo usava so o primeiro argumento, e
      // o campo Altura mandava (escalaX, novoValor) — o novo valor ia
      // para o lugar ignorado. O teclado abria, aceitava o numero,
      // fechava, e a camada continuava igual.
      await _digitar(tester, 'Altura', '250');

      final l = _camada(m.c, m.id);
      expect(l.scaleY.valueAt(Duration.zero), closeTo(2.5, .01));
      expect(
        l.scaleX.valueAt(Duration.zero),
        closeTo(2.5, .01),
        reason: 'com a corrente travada, os dois eixos andam juntos',
      );
    });

    testWidgets('destravada, a Altura mexe so no Y', (tester) async {
      final m = await _montar(tester, 'transformar');
      m.c.read(modoDeTransformacaoProvider.notifier).state =
          ModoDeTransformacao.escalar;
      m.c.read(escalaTravadaProvider.notifier).state = false;
      await tester.pump();

      await _digitar(tester, 'Altura', '250');
      final l = _camada(m.c, m.id);
      expect(l.scaleY.valueAt(Duration.zero), closeTo(2.5, .01));
      expect(l.scaleX.valueAt(Duration.zero), closeTo(1, .01));
    });
  });

  group('a ficha da forma so mostra o que a forma usa', () {
    testWidgets('retangulo tem Largura e Altura', (tester) async {
      await _montar(tester, 'forma', forma: ShapePresets.paramRect());
      expect(find.text('Largura'), findsOneWidget);
      expect(find.text('Altura'), findsOneWidget);
      expect(find.text('Cantos'), findsOneWidget);
      expect(
        find.text('Pontas'),
        findsNothing,
        reason: 'retangulo nao tem pontas',
      );
    });

    testWidgets('estrela NAO tem Largura nem Altura', (tester) async {
      await _montar(tester, 'forma', forma: ShapePresets.paramStar());
      // O DEFEITO: os dois apareciam e escreviam no projeto sem mudar
      // nada na tela — o desenho da estrela sai de raio e pontas.
      expect(find.text('Largura'), findsNothing);
      expect(find.text('Altura'), findsNothing);
      expect(find.text('Pontas'), findsOneWidget);
      expect(find.text('Raio externo'), findsOneWidget);
      expect(find.text('Raio interno'), findsOneWidget);
    });

    testWidgets('o parametro tocado passa a mirar o rail', (tester) async {
      final m = await _montar(tester, 'forma', forma: ShapePresets.paramRect());
      // Antes: tocar acendia o realce e o losango do rail continuava
      // apagado — o gesto prometia mirar e nao mirava nada.
      final losango = tester.getSemantics(
        find.bySemanticsLabel('Marcar keyframe aqui'),
      );
      expect(losango.hasFlag(SemanticsFlag.isEnabled), isFalse);

      await tester.tap(find.text('Largura'));
      await tester.pump();
      expect(m.c.read(parametroAbertoProvider), 'sizeX');

      await tester.tap(find.bySemanticsLabel('Marcar keyframe aqui'));
      await tester.pump();

      final l = _camada(m.c, m.id) as ShapeLayer;
      final s = l.contents.whereType<ShapeParametric>().first;
      expect(
        s.sizeX.hasKeyframeAt(Duration.zero),
        isTrue,
        reason: 'o losango do rail nao chegou no parametro da forma',
      );
    });
  });

  group('o losango do rail diz o que o toque vai fazer', () {
    testWidgets('perto de uma marca, ele mostra que ha marca', (tester) async {
      final m = await _montar(tester, 'opacidade');
      final c = m.c.read(editorControllerProvider.notifier);
      c.toggleKeyframe(m.id, const Duration(seconds: 1), LayerProp.opacity);

      // Alguns milissegundos DEPOIS da marca. O rail comparava o
      // instante exato e dizia "marcar aqui"; o toque, que usa a
      // tolerancia da trilha, APAGAVA a marca existente.
      m.p.seek(const Duration(milliseconds: 1003));
      await tester.pump();

      final camada = _camada(m.c, m.id);
      final perto = camada.opacity.hasKeyframeAt(
        camada.localTime(const Duration(milliseconds: 1003)),
      );
      expect(
        find.bySemanticsLabel(
          perto ? 'Tirar o keyframe daqui' : 'Marcar keyframe aqui',
        ),
        findsOneWidget,
        reason: 'o rail e a trilha discordam sobre haver marca aqui',
      );
    });
  });

  group('as casas decimais seguem a faixa', () {
    test('a escada cobre o meio, que era onde a regra velha mentia', () {
      // A regra era "faixa <= 4 ? 3 casas : 0". Exposicao vai de -3 a
      // +3 — faixa 6 — e caia em ZERO casa: o numero ficava parado em
      // "0" enquanto o dedo arrastava.
      expect(casasParaFaixa(1), 3);
      expect(casasParaFaixa(6), 2, reason: 'a exposicao precisa de casas');
      expect(casasParaFaixa(100), 1);
      expect(casasParaFaixa(4000), 0);
    });
  });
}
