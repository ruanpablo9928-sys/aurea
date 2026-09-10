// A CATEGORIA MASCARA, do cartao ao keyframe.
//
// O motor sabia fazer mascara desde sempre: criar, apagar, reordenar,
// trocar o modo, inverter, animar feather/expansao/opacidade e sete
// revelacoes prontas — tudo desenhado no palco e salvo no arquivo. Nada
// disso tinha porta na interface. Estes testes cobram a PORTA, e nao o
// motor: se um dia alguem tirar o cartao ou desligar um botao da ficha,
// e aqui que quebra.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/mask.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_mascaras.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

Future<_Bancada> _montar(WidgetTester tester) async {
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
                categoriaId: 'mascara',
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

List<LayerMask> _mascaras(ProviderContainer c, String id) =>
    _camada(c, id).masks;

void main() {
  group('o cartao da mascara aparece onde a mascara faz alguma coisa', () {
    test('camada de texto tem o cartao', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      expect(
        categoriasDaCamada(camada).map((x) => x.id),
        contains('mascara'),
        reason: 'sem o cartao, o recurso inteiro continua sem porta',
      );
    });

    test('camada de audio NAO tem, porque nao desenha nada', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addAudioLayer(
        Duration.zero,
        'som.m4a',
        'Som',
        const Duration(seconds: 4),
      );
      final camada = container.read(editorControllerProvider).layers.single;
      expect(categoriasDaCamada(camada).map((x) => x.id), isNot(contains('mascara')));
    });
  });

  group('criar', () {
    testWidgets('o retangulo entra e ja abre a ficha', (tester) async {
      final m = await _montar(tester);
      expect(_mascaras(m.c, m.id), isEmpty);

      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();

      expect(_mascaras(m.c, m.id), hasLength(1));
      expect(
        m.c.read(mascaraAbertaProvider),
        _mascaras(m.c, m.id).single.id,
        reason: 'quem acabou de criar quer ajustar, e nao procurar de novo',
      );
      expect(find.text('Suavidade'), findsOneWidget);
    });

    testWidgets('a mascara nasce do tamanho da camada', (tester) async {
      final m = await _montar(tester);
      final c = m.c.read(editorControllerProvider.notifier);
      final caixa = c.maskBox(m.id, Duration.zero);

      await tester.tap(find.bySemanticsLabel('Elipse'));
      await tester.pump();

      final pontos = _mascaras(m.c, m.id).single.path.base.vertices;
      final largura =
          pontos.map((v) => v.p.dx).reduce((a, b) => a > b ? a : b) -
          pontos.map((v) => v.p.dx).reduce((a, b) => a < b ? a : b);
      expect(
        largura,
        closeTo(caixa.width, 1),
        reason: 'uma mascara de tamanho fixo nasceria fora da camada',
      );
    });

    testWidgets('uma revelacao ja vem animada', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Esquerda'));
      await tester.pump();

      final mascara = _mascaras(m.c, m.id).single;
      expect(
        mascara.path.isAnimated,
        isTrue,
        reason: 'o preset existe justamente para ja trazer os keyframes',
      );
      expect(mascara.path.keyframes, hasLength(greaterThanOrEqualTo(2)));
    });

    testWidgets('as sete revelacoes estao todas na tela', (tester) async {
      await _montar(tester);
      for (final p in MaskRevealPreset.values) {
        expect(
          find.bySemanticsLabel(p.label),
          findsOneWidget,
          reason: '${p.label} existe no motor e precisa existir na tela',
        );
      }
    });
  });

  group('a ficha', () {
    testWidgets('o modo cicla e o chip mostra qual e', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).single.mode, MaskMode.add);
      expect(find.text('Somar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Modo da mascara: Somar'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).single.mode, MaskMode.subtract);
      expect(find.text('Subtrair'), findsOneWidget);
    });

    testWidgets('inverter inverte', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Inverter Retangulo'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).single.inverted, isTrue);
    });

    testWidgets('soltar os eixos abre a segunda suavidade', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      expect(find.text('Suavidade Y'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Soltar suavidade X e Y'));
      await tester.pump();

      expect(_mascaras(m.c, m.id).single.featherLinked, isFalse);
      expect(find.text('Suavidade X'), findsOneWidget);
      expect(find.text('Suavidade Y'), findsOneWidget);
    });

    testWidgets('a fita da opacidade muda o valor', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).single.opacity.valueAt(Duration.zero), 1);

      final fita = find.bySemanticsLabel('Ajustar Opacidade');
      final gesto = await tester.startGesture(tester.getCenter(fita));
      // OS PRIMEIROS PIXELS SOMEM no reconhecimento do gesto, e o
      // `onHorizontalDragStart` chega ja com a posicao de depois do
      // limiar. Sem este primeiro passo, o teste mediria menos do que o
      // dedo andou e o numero nao fecharia.
      await gesto.moveBy(const Offset(20, 0));
      await gesto.moveBy(const Offset(-60, 0));
      await gesto.up();
      await tester.pump();

      expect(
        _mascaras(m.c, m.id).single.opacity.valueAt(Duration.zero),
        lessThan(1),
      );
    });
  });

  group('o losango do rail chega na mascara', () {
    testWidgets('marcar e tirar keyframe da suavidade', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      // Criar ja mira a suavidade; sem isso o rail nao teria alvo.
      expect(m.c.read(parametroDaMascaraProvider), 'feather');

      m.p.seek(const Duration(milliseconds: 500));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Marcar keyframe aqui'));
      await tester.pump();
      expect(
        _mascaras(m.c, m.id).single.feather.isAnimated,
        isTrue,
        reason: 'sem isto da para arrastar o valor e nunca cravar o instante',
      );

      await tester.tap(find.bySemanticsLabel('Tirar o keyframe daqui'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).single.feather.isAnimated, isFalse);
    });

    testWidgets('o parametro tocado passa a ser o alvo', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();

      await tester.tap(find.text('Expansao'));
      await tester.pump();
      expect(m.c.read(parametroDaMascaraProvider), 'expansion');

      m.p.seek(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Marcar keyframe aqui'));
      await tester.pump();

      final mascara = _mascaras(m.c, m.id).single;
      expect(mascara.expansion.isAnimated, isTrue);
      expect(mascara.feather.isAnimated, isFalse);
    });
  });

  group('ordem e remocao', () {
    testWidgets('a segunda mascara sobe e desce', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Elipse'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).map((x) => x.name), ['Retangulo', 'Elipse']);

      // A ORDEM DECIDE O DESENHO: subtrair depois de somar tira o que a
      // de cima poe. Sem estas setas, criar na ordem errada obrigaria a
      // apagar e refazer.
      await tester.tap(find.bySemanticsLabel('Subir Elipse'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).map((x) => x.name), ['Elipse', 'Retangulo']);

      await tester.tap(find.bySemanticsLabel('Descer Elipse'));
      await tester.pump();
      expect(_mascaras(m.c, m.id).map((x) => x.name), ['Retangulo', 'Elipse']);
    });

    testWidgets('a primeira nao tem seta para cima', (tester) async {
      await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();
      expect(find.bySemanticsLabel('Subir Retangulo'), findsNothing);
      expect(find.bySemanticsLabel('Descer Retangulo'), findsNothing);
    });

    testWidgets('tirar tira, e fecha a ficha junto', (tester) async {
      final m = await _montar(tester);
      await tester.tap(find.bySemanticsLabel('Retangulo'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Tirar Retangulo'));
      await tester.pump();

      expect(_mascaras(m.c, m.id), isEmpty);
      expect(m.c.read(mascaraAbertaProvider), isNull);
      expect(find.text('Suavidade'), findsNothing);
    });
  });
}
