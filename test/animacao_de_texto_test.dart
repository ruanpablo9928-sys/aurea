// A ANIMACAO DE TEXTO: 35 animacoes que nao tinham porta.
//
// O catalogo existe, o compilador transforma cada animacao num ANIMADOR
// de verdade (nada de caixa-preta: o resultado continua editavel), o
// pintor por glifo desenha e o arquivo salva. Nenhum widget chamava
// `setTextAnim`, `updateTextAnim`, `setTextAnimParam`,
// `textAnimUnitCount` ou `applyTextPreset` — os unicos chamadores vivos
// eram dois testes. Sem isso, "tipografia cinetica" era mover a caixa
// de texto inteira, que e animacao de camada e nao de letra.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/text_anim.dart';
import 'package:aurea/src/features/editor/domain/text_animator.dart';
import 'package:aurea/src/features/editor/domain/text_presets.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_animacao_de_texto.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, String id});

Future<_Bancada> _montar(
  WidgetTester tester, {
  String texto = 'Ola mundo',
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.addTextLayer(Duration.zero, text: texto);
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
                categoriaId: 'animacao',
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
  return (c: container, id: camada.id);
}

TextLayer _texto(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id)
        as TextLayer;

Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

void main() {
  group('o cartao', () {
    test('so texto tem animacao de texto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      c.addShapeLayer(Duration.zero);
      final camadas = container.read(editorControllerProvider).layers;
      expect(
        categoriasDaCamada(camadas.whereType<TextLayer>().single)
            .map((x) => x.id),
        contains('animacao'),
      );
      expect(
        categoriasDaCamada(camadas.whereType<ShapeLayer>().single)
            .map((x) => x.id),
        isNot(contains('animacao')),
      );
    });
  });

  group('o caso de 90%: dois toques', () {
    testWidgets('um chip do catalogo ja anima o texto', (tester) async {
      final m = await _montar(tester);
      expect(_texto(m.c, m.id).hasTextAnimation, isFalse);

      final entrada = textAnimsForSlot(TextAnimSlot.entrada).first;
      await _tocar(tester, 'Animacao ${entrada.label}');

      final l = _texto(m.c, m.id);
      expect(l.anims, hasLength(1));
      expect(l.anims.single.specId, entrada.id);
      expect(
        l.hasTextAnimation,
        isTrue,
        reason: 'e isto que troca o Text simples pelo pintor por glifo',
      );
      // O spec traz duracao, atraso, unidade e curva prontos: nada mais
      // precisa ser tocado para a animacao existir.
      expect(l.anims.single.duration, entrada.duration);
      expect(l.anims.single.unit, entrada.unit);
    });

    testWidgets('as tres posicoes estao la, e a bolinha diz onde ha coisa', (
      tester,
    ) async {
      final m = await _montar(tester);
      for (final s in TextAnimSlot.values) {
        expect(
          find.bySemanticsLabel('Posicao ${textAnimSlotLabel(s)}'),
          findsOneWidget,
        );
      }

      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');
      await _tocar(tester, 'Posicao ${textAnimSlotLabel(TextAnimSlot.saida)}');
      // Trocar de posicao nao apaga a que ja existe: cada uma guarda a
      // sua.
      expect(_texto(m.c, m.id).anims, hasLength(1));
      expect(find.textContaining('Escolha uma animacao'), findsOneWidget);
    });

    testWidgets('o catalogo inteiro da posicao aparece', (tester) async {
      await _montar(tester);
      final entrada = textAnimsForSlot(TextAnimSlot.entrada);
      expect(entrada.length, greaterThan(10));
      for (final spec in entrada) {
        expect(
          find.bySemanticsLabel('Animacao ${spec.label}'),
          findsOneWidget,
          reason: '${spec.label} existe no catalogo e nao na tela',
        );
      }
    });

    testWidgets('tocar no chip vigente DESLIGA, e nao reaplica', (
      tester,
    ) async {
      final m = await _montar(tester);
      final spec = textAnimsForSlot(TextAnimSlot.entrada).first;
      await _tocar(tester, 'Animacao ${spec.label}');
      // `setTextAnim` RECRIA a instancia com os padroes do spec:
      // reaplicar apagaria o que a pessoa acabou de ajustar.
      final id = _texto(m.c, m.id).anims.single.id;
      m.c
          .read(editorControllerProvider.notifier)
          .updateTextAnim(m.id, id, (a) => a.copyWith(
                duration: const Duration(milliseconds: 1234),
              ));
      await tester.pump();

      await _tocar(tester, 'Animacao ${spec.label}');
      expect(
        _texto(m.c, m.id).anims,
        isEmpty,
        reason: 'o segundo toque no mesmo chip desliga',
      );
    });
  });

  group('os ajustes', () {
    testWidgets('nada aparece antes de haver animacao', (tester) async {
      await _montar(tester);
      expect(find.bySemanticsLabel('Duracao'), findsNothing);
      expect(find.bySemanticsLabel('Unidade Letras'), findsNothing);
      expect(find.textContaining('Escolha uma animacao'), findsOneWidget);
    });

    testWidgets('duracao, atraso e unidade escrevem no projeto', (
      tester,
    ) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');

      final campo = find.bySemanticsLabel('Valor de Duracao');
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      await tester.tap(campo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '900');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
      await tester.pumpAndSettle();
      expect(
        _texto(m.c, m.id).anims.single.duration,
        const Duration(milliseconds: 900),
      );

      await _tocar(
        tester,
        'Unidade ${textAnimUnitLabel(TextAnimUnit.word)}',
      );
      expect(_texto(m.c, m.id).anims.single.unit, TextAnimUnit.word);
    });

    testWidgets('o atraso some com "Tudo junto"', (tester) async {
      await _montar(tester);
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');
      expect(find.bySemanticsLabel('Atraso entre unidades'), findsOneWidget);

      // O compilador zera o atraso nessa unidade: a linha seria inerte,
      // e linha inerte e pior que linha ausente.
      await _tocar(tester, 'Unidade ${textAnimUnitLabel(TextAnimUnit.all)}');
      expect(find.bySemanticsLabel('Atraso entre unidades'), findsNothing);
    });

    testWidgets('a curva some nas animacoes de loop', (tester) async {
      final m = await _montar(tester);
      final loop = textAnimsForSlot(
        TextAnimSlot.enfase,
      ).firstWhere((s) => s.loop);
      await _tocar(tester, 'Posicao ${textAnimSlotLabel(TextAnimSlot.enfase)}');
      await _tocar(tester, 'Animacao ${loop.label}');

      expect(_texto(m.c, m.id).anims.single.specId, loop.id);
      // O compilador sai pelo ramo do loop antes de aplicar a curva: um
      // chip ali gravaria no projeto e nao moveria um pixel.
      expect(
        find.bySemanticsLabel('Curva ${textAnimEaseLabel(TextAnimEase.mola)}'),
        findsNothing,
      );
    });

    testWidgets('a contagem viva conta na unidade escolhida', (tester) async {
      await _montar(tester, texto: 'Ola mundo');
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');

      // 'Ola mundo' tem nove caracteres e duas palavras.
      expect(find.textContaining('9 letras'), findsOneWidget);
      await _tocar(
        tester,
        'Unidade ${textAnimUnitLabel(TextAnimUnit.word)}',
      );
      expect(find.textContaining('2 palavras'), findsOneWidget);
    });

    testWidgets('ligar e desligar mantem o ajuste', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');
      expect(_texto(m.c, m.id).anims.single.enabled, isTrue);

      await _tocar(tester, 'Desligar a animacao');
      final a = _texto(m.c, m.id).anims.single;
      expect(a.enabled, isFalse);
      expect(
        a.specId,
        isNotEmpty,
        reason: 'desligar compara com e sem, e nao joga fora',
      );
    });
  });

  group('os prontos antigos', () {
    testWidgets('os sete estao la', (tester) async {
      await _montar(tester);
      expect(textPresets, hasLength(greaterThan(4)));
      for (final p in textPresets) {
        expect(find.bySemanticsLabel('Pronto ${p.name}'), findsOneWidget);
      }
    });

    testWidgets('um pronto SUBSTITUI o catalogo, e nao empilha', (
      tester,
    ) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');
      expect(_texto(m.c, m.id).anims, hasLength(1));

      await _tocar(tester, 'Pronto ${textPresets.first.name}');

      final l = _texto(m.c, m.id);
      // O motor SOMA anims e animators: sem limpar, o pronto
      // empilharia em cima da animacao do catalogo sem nenhum sinal de
      // que ha dois.
      expect(l.anims, isEmpty);
      expect(l.animators, isNotEmpty);
      expect(l.hasTextAnimation, isTrue);
    });

    testWidgets('trocar e desfazer custa UM desfazer', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Animacao ${textAnimsForSlot(TextAnimSlot.entrada).first.label}');
      await _tocar(tester, 'Pronto ${textPresets.first.name}');

      m.c.read(editorControllerProvider.notifier).undo();
      final l = _texto(m.c, m.id);
      expect(l.animators, isEmpty);
      expect(
        l.anims,
        hasLength(1),
        reason: 'limpar e aplicar sao uma acao so',
      );
    });

    testWidgets('da para tirar o pronto', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Pronto ${textPresets.first.name}');
      expect(_texto(m.c, m.id).animators, isNotEmpty);

      final tirar = find.bySemanticsLabel(RegExp('^Tirar o pronto'));
      await tester.ensureVisible(tirar);
      await tester.pump();
      await tester.tap(tirar);
      await tester.pump();
      expect(_texto(m.c, m.id).animators, isEmpty);
    });
  });

  group('a saida contava as unidades erradas', () {
    test('por palavra, o recuo do fim usa PALAVRAS e nao caracteres', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      // 'Ola mundo': nove caracteres, duas palavras.
      c.addTextLayer(Duration.zero, text: 'Ola mundo');
      final id = container.read(editorControllerProvider).layers.single.id;
      final saida = textAnimsForSlot(TextAnimSlot.saida).first;
      c.setTextAnim(id, TextAnimSlot.saida, saida.id);
      c.updateTextAnim(
        id,
        (container.read(editorControllerProvider).layers.single as TextLayer)
            .anims
            .single
            .id,
        (a) => a.copyWith(unit: TextAnimUnit.word),
      );

      final l =
          container.read(editorControllerProvider).layers.single as TextLayer;
      final unidades = TextUnits.of(l.text);

      // O pintor mandava o total de CARACTERES para todas as animacoes:
      // a saida por palavra reservava tempo para nove unidades e o texto
      // sumia quase um segundo antes do fim da camada.
      Duration comecoDe(List<TextAnimator> a) =>
          (a.single.selectors.single as StaggerSelector).start;

      final porCaractere = comecoDe(l.effectiveAnimators(unidades.length));
      final porUnidade = comecoDe(
        l.effectiveAnimators(unidades.length, units: unidades),
      );

      expect(unidades.charCount, 9);
      expect(unidades.wordCount, 2);
      // A saida recua do FIM da camada, e o recuo e duracao + atraso
      // vezes (unidades - 1). Contando nove em vez de duas, ela
      // comecava quase um segundo mais cedo — e o texto ficava sumido.
      expect(
        porUnidade,
        greaterThan(porCaractere),
        reason: 'a saida por palavra comecava cedo demais',
      );
    });
  });
}
