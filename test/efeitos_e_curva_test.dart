// EFEITOS, CURVA E NAVEGACAO ENTRE MARCAS.
//
// Sao as tres coisas que faltavam para o sistema de animacao fechar o
// circulo: aplicar um efeito, dizer COMO uma propriedade chega no valor,
// e andar de marca em marca sem cacar o cabecote no olho.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/editor_de_curva.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

Future<({ProviderContainer c, PlaybackController p, String id})> _montar(
  WidgetTester tester,
  String categoria,
) async {
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
          body: Stack(
            children: [
              // A TELA INTEIRA como base da pilha. Sem ela o Stack se
              // ajusta ao unico filho — os controles, que sao baixos —
              // e o painel do meio, que e `Positioned.fill`, ficaria do
              // tamanho deles. Na tela de verdade quem preenche e a
              // coluna do editor.
              const SizedBox.expand(),
              Consumer(
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
                  );
                },
              ),
              const EditorDeCurva(),
            ],
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback, id: camada.id);
}

Layer _camada(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id);

/// Anima a opacidade entre dois instantes, para haver trecho e curva.
///
/// Pelo caminho de verdade: keyframe automatico ligado e duas edicoes.
/// Cravar marca a mao tambem funciona, mas testar pelo caminho que a
/// pessoa usa e o que pega o defeito onde ele mora.
void _animar(ProviderContainer container, String id) {
  final c = container.read(editorControllerProvider.notifier);
  container.read(autoKeyframeProvider.notifier).state = true;
  c.editOpacity(id, Duration.zero, 1);
  c.editOpacity(id, const Duration(seconds: 2), 0);
  container.read(autoKeyframeProvider.notifier).state = false;
}

void main() {
  group('efeitos', () {
    testWidgets('a camada comeca sem efeito, e ha caminho para adicionar', (
      tester,
    ) async {
      final m = await _montar(tester, 'efeitos');
      expect(_camada(m.c, m.id).effects, isEmpty);
      expect(find.bySemanticsLabel('Adicionar efeito'), findsOneWidget);
    });

    testWidgets('o catalogo aplica, e a ficha do efeito abre sozinha', (
      tester,
    ) async {
      final m = await _montar(tester, 'efeitos');
      await tester.tap(find.bySemanticsLabel('Adicionar efeito'));
      await tester.pump();

      final nome = effectSpecs[EffectType.gaussianBlur]!.name;
      await tester.tap(find.bySemanticsLabel(nome));
      await tester.pump();

      final efeitos = _camada(m.c, m.id).effects;
      expect(efeitos.length, 1);
      expect(efeitos.single.type, EffectType.gaussianBlur);
      expect(
        m.c.read(efeitoAbertoProvider),
        efeitos.single.id,
        reason: 'quem acabou de escolher quer ajustar, e nao procurar',
      );
    });

    testWidgets('os parametros saem da tabela, e chegam no efeito', (
      tester,
    ) async {
      final m = await _montar(tester, 'efeitos');
      m.c.read(editorControllerProvider.notifier).addEffect(
        m.id,
        EffectType.gaussianBlur,
      );
      final efeito = _camada(m.c, m.id).effects.single;
      m.c.read(efeitoAbertoProvider.notifier).state = efeito.id;
      await tester.pump();

      final spec = effectSpecs[EffectType.gaussianBlur]!;
      final primeira = spec.params.keys.first;
      expect(find.text(spec.params[primeira]!.label), findsOneWidget);

      final antes = _camada(
        m.c,
        m.id,
      ).effects.single.params[primeira]!.valueAt(Duration.zero);
      await tester.drag(find.byType(Slider).first, const Offset(80, 0));
      await tester.pump();
      expect(
        _camada(
          m.c,
          m.id,
        ).effects.single.params[primeira]!.valueAt(Duration.zero),
        isNot(antes),
        reason: 'o deslizante gerado da tabela nao chegou no efeito',
      );
    });

    testWidgets('o olho desliga sem tirar, e o x tira', (tester) async {
      final m = await _montar(tester, 'efeitos');
      m.c.read(editorControllerProvider.notifier).addEffect(
        m.id,
        EffectType.gaussianBlur,
      );
      await tester.pump();
      final nome = effectSpecs[EffectType.gaussianBlur]!.name;

      await tester.tap(find.bySemanticsLabel('Desligar $nome'));
      await tester.pump();
      expect(
        _camada(m.c, m.id).effects.single.enabled,
        isFalse,
        reason: 'desligar guarda o ajuste; tirar joga fora',
      );

      await tester.tap(find.bySemanticsLabel('Tirar $nome'));
      await tester.pump();
      expect(_camada(m.c, m.id).effects, isEmpty);
    });
  });

  group('navegar entre marcas', () {
    testWidgets('sem marca nenhuma, nao ha para onde ir', (tester) async {
      await _montar(tester, 'opacidade');
      expect(find.bySemanticsLabel('Marca anterior de Opacidade'), findsNothing);
      expect(find.bySemanticsLabel('Curva de Opacidade'), findsNothing);
    });

    testWidgets('as setas pulam o cabecote de marca em marca', (tester) async {
      final m = await _montar(tester, 'opacidade');
      _animar(m.c, m.id);
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Proxima marca de Opacidade'));
      await tester.pump();
      expect(m.p.time.value, const Duration(seconds: 2));

      await tester.tap(find.bySemanticsLabel('Marca anterior de Opacidade'));
      await tester.pump();
      expect(m.p.time.value, Duration.zero);
    });
  });

  group('o editor de curva', () {
    testWidgets('abre so quando o cabecote esta DENTRO de um trecho', (
      tester,
    ) async {
      final m = await _montar(tester, 'opacidade');
      _animar(m.c, m.id);
      // Depois da ultima marca nao ha trecho: nao ha para onde a
      // propriedade estar indo.
      m.p.seek(const Duration(seconds: 3));
      await tester.pump();
      expect(m.c.read(curvaEmEdicaoProvider), isNull);
      await tester.tap(find.bySemanticsLabel('Curva de Opacidade'));
      await tester.pump();
      expect(
        m.c.read(curvaEmEdicaoProvider),
        isNull,
        reason: 'o botao estava apagado, e apagado nao age',
      );

      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Curva de Opacidade'));
      await tester.pump();
      expect(m.c.read(curvaEmEdicaoProvider), isNotNull);
    });

    testWidgets('escolher um preset grava a curva NAQUELE trecho', (
      tester,
    ) async {
      final m = await _montar(tester, 'opacidade');
      _animar(m.c, m.id);
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Curva de Opacidade'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Suave'));
      await tester.pump();

      expect(
        _camada(m.c, m.id).opacity.easeAt(Duration.zero),
        Easing.easeInOut,
        reason: 'o preset tem de chegar no trecho que estava aberto',
      );
    });

    testWidgets('arrastar a alca muda os pontos de controle', (tester) async {
      final m = await _montar(tester, 'opacidade');
      _animar(m.c, m.id);
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Curva de Opacidade'));
      await tester.pump();

      final antes = _camada(m.c, m.id).opacity.easeAt(Duration.zero);
      final quadro = tester.getRect(
        find.byKey(const ValueKey('quadro-da-curva')),
      );
      await tester.dragFrom(
        quadro.bottomLeft + const Offset(10, -10),
        const Offset(60, -40),
      );
      await tester.pump();

      expect(
        _camada(m.c, m.id).opacity.easeAt(Duration.zero),
        isNot(antes),
        reason: 'a alca move os MESMOS numeros que o motor usa',
      );
    });

    testWidgets('fechar nao desfaz o que ja foi aplicado', (tester) async {
      final m = await _montar(tester, 'opacidade');
      _animar(m.c, m.id);
      m.p.seek(const Duration(seconds: 1));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Curva de Opacidade'));
      await tester.pump();
      // Os primeiros presets, que cabem na largura sem rolar — a lista
      // e horizontal e nao adianta mirar num chip que esta fora dela.
      await tester.tap(find.bySemanticsLabel('Suave'));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Fechar a curva'));
      await tester.pump();
      expect(m.c.read(curvaEmEdicaoProvider), isNull);
      expect(
        _camada(m.c, m.id).opacity.easeAt(Duration.zero),
        Easing.easeInOut,
      );
    });
  });

  group('transformar por inteiro', () {
    testWidgets('ancoragem e inclinacao entraram', (tester) async {
      await _montar(tester, 'transformar');
      for (final rotulo in [
        'Ancoragem X',
        'Ancoragem Y',
        'Inclinacao X',
        'Inclinacao Y',
      ]) {
        expect(find.text(rotulo), findsOneWidget, reason: 'falta "$rotulo"');
      }
    });

    testWidgets('destravar a escala abre X e Y separados', (tester) async {
      final m = await _montar(tester, 'transformar');
      expect(find.text('Escala'), findsOneWidget);
      expect(find.text('Escala X'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Escala travada em X e Y'));
      await tester.pump();
      expect(m.c.read(escalaUniformeProvider), isFalse);
      expect(find.text('Escala X'), findsOneWidget);
      expect(find.text('Escala Y'), findsOneWidget);
    });
  });
}
