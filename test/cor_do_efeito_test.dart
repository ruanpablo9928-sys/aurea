// A COR E O PONTO NA FICHA DO EFEITO.
//
// A cor era uma linha de LEITURA: os tres numeros e o quadradinho, sem
// como trocar. Metade da pergunta respondida, com `setEffectColor` e
// `setEffectExtraColor` parados no motor sem um unico chamador.
//
// O ponto era pior: `Centro X` e `Centro Y` sao numeros comuns, de 0 a
// 1, e caiam no balde do "ajuste chega numa proxima entrega" — a ficha
// avisava que nao desenhava dois parametros que ela ja sabia desenhar.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/escolha_de_cor.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, String camada, String efeito});

Future<_Bancada> _montar(WidgetTester tester, EffectType tipo) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.addTextLayer(Duration.zero, text: 'Um');
  final camada = container.read(editorControllerProvider).layers.single;
  container.read(selectedLayerProvider.notifier).state = camada.id;
  c.addEffect(camada.id, tipo);
  final efeito = container
      .read(editorControllerProvider)
      .layers
      .single
      .effects
      .single;
  container.read(efeitoAbertoProvider.notifier).state = efeito.id;

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
                categoriaId: 'efeitos',
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
  return (c: container, camada: camada.id, efeito: efeito.id);
}

EffectInstance _efeito(_Bancada m) => m.c
    .read(editorControllerProvider)
    .layers
    .firstWhere((l) => l.id == m.camada)
    .effects
    .firstWhere((e) => e.id == m.efeito);

Future<void> _digitar(
  WidgetTester tester,
  String rotulo,
  String valor,
) async {
  await tester.ensureVisible(find.bySemanticsLabel('Valor de $rotulo'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Valor de $rotulo'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(EditableText).last, valor);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
  await tester.pumpAndSettle();
}

void main() {
  group('a cor do efeito muda', () {
    testWidgets('uma cor pronta entra com um toque', (tester) async {
      final m = await _montar(tester, EffectType.vignette);
      final alvo = EscolhaDeCor.prontas[5];

      await tester.ensureVisible(find.bySemanticsLabel('Cor 30 214 177'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Cor 30 214 177'));
      await tester.pump();

      expect(
        _efeito(m).color.toARGB32(),
        alvo.toARGB32(),
        reason: 'o toque na amostra nao chegou em setEffectColor',
      );
    });

    testWidgets('digitar um canal muda so aquele canal', (tester) async {
      final m = await _montar(tester, EffectType.vignette);
      await _digitar(tester, 'Cor Verde', '128');

      final cor = _efeito(m).color;
      expect((cor.g * 255).round(), 128);
      expect(
        (cor.r * 255).round(),
        0,
        reason: 'a vinheta nasce preta; mexer no verde nao mexe no vermelho',
      );
      expect((cor.b * 255).round(), 0);
    });
  });

  group('as cores extras', () {
    testWidgets('o gradiente de quatro cores mostra as quatro', (
      tester,
    ) async {
      final m = await _montar(tester, EffectType.gradient4);
      for (final rotulo in const ['Cor', 'Cor 2', 'Cor 3', 'Cor 4']) {
        expect(
          find.bySemanticsLabel(rotulo),
          findsOneWidget,
          reason: '$rotulo nao esta na ficha',
        );
      }

      await _digitar(tester, 'Cor 3 Azul', '200');
      expect((_efeito(m).extraColor(1).b * 255).round(), 200);
    });
  });

  group('o ponto', () {
    testWidgets('Centro X e Centro Y sao linhas de verdade', (tester) async {
      final m = await _montar(tester, EffectType.vignette);
      expect(find.text('Centro X'), findsOneWidget);
      expect(find.text('Centro Y'), findsOneWidget);
      expect(
        find.textContaining('proxima entrega'),
        findsNothing,
        reason: 'a ficha avisava que nao desenhava o que ela ja desenha',
      );

      await _digitar(tester, 'Centro X', '0,25');
      expect(
        _efeito(m).params['centroX']!.valueAt(Duration.zero),
        closeTo(.25, .001),
      );
    });

    testWidgets('o ponto tocado passa a mirar o rail', (tester) async {
      final m = await _montar(tester, EffectType.vignette);
      await tester.ensureVisible(find.text('Centro Y'));
      await tester.pump();
      await tester.tap(find.text('Centro Y'));
      await tester.pump();
      expect(m.c.read(parametroAbertoProvider), 'centroY');

      await tester.tap(find.bySemanticsLabel('Marcar keyframe aqui'));
      await tester.pump();
      expect(_efeito(m).params['centroY']!.isAnimated, isTrue);
    });
  });
}
