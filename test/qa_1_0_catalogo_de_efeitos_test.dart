// QA 1.0 — CAMPANHA 4: TODO EFEITO, EM TODO EXTREMO.
//
// A ficha de um efeito promete tres coisas: um valor inicial, um minimo
// e um maximo. Quem arrasta o controle ate a ponta espera que o
// aplicativo continue de pe la — e e justamente na ponta que ninguem
// testa a mao.
//
// Esta campanha varre o CATALOGO INTEIRO (nao uma lista escrita a mao) e
// cobra tres coisas de cada parametro de cada efeito:
//
//   1. A FICHA e coerente: minimo < maximo, inicial dentro da faixa,
//      nenhum numero impossivel. Uma ficha torta e um controle que nasce
//      fora do proprio limite.
//   2. O EXTREMO SOBREVIVE ao arquivo: no minimo e no maximo, o valor
//      volta igual da gravacao.
//   3. O EXTREMO DESENHA: com todos os parametros no maximo — e depois
//      todos no minimo — o quadro sai, sem excecao e sem quadro em
//      branco por causa de um numero que virou NaN.
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma forma solida, do tamanho da tela, para o efeito ter o que comer.
ShapeLayer _alvo({List<EffectInstance> efeitos = const []}) => ShapeLayer(
  id: 'alvo',
  name: 'Alvo',
  startTime: Duration.zero,
  duration: const Duration(seconds: 10),
  position: AnimatedOffset(const Offset(64, 64)),
  contents: [
    ShapePath(primitive: ShapePrimitive.rectangle),
    ShapeFill(color: const Color(0xFF3DDC97)),
  ],
  effects: efeitos,
);

VideoProject _projeto(List<Layer> camadas) => VideoProject(
  name: 'qa-efeitos',
  createdAt: DateTime(2026, 9, 8),
  aspectRatio: 1,
  resolutionHeight: 128,
  backgroundColor: const Color(0xFF101014),
  layers: camadas,
);

/// O efeito [tipo] com TODOS os parametros no extremo pedido.
EffectInstance _noExtremo(EffectType tipo, {required bool maximo}) {
  final spec = effectSpecs[tipo]!;
  return EffectInstance(
    type: tipo,
    params: {
      for (final e in spec.params.entries)
        e.key: AnimatedDouble(maximo ? e.value.max : e.value.min),
    },
  );
}

void main() {
  group('a ficha de cada efeito', () {
    test('minimo, maximo e inicial fazem sentido', () {
      final falhas = <String>[];
      for (final entrada in effectSpecs.entries) {
        final spec = entrada.value;
        for (final p in spec.params.entries) {
          final param = p.value;
          final onde = '${spec.id}.${p.key}';
          if (!param.min.isFinite ||
              !param.max.isFinite ||
              !param.initial.isFinite) {
            falhas.add('$onde: numero impossivel na ficha');
            continue;
          }
          if (param.min >= param.max) {
            falhas.add('$onde: minimo ${param.min} >= maximo ${param.max}');
          }
          if (param.initial < param.min || param.initial > param.max) {
            falhas.add(
              '$onde: nasce em ${param.initial}, fora de '
              '[${param.min}, ${param.max}]',
            );
          }
          if (param.kind == ParamKind.choice && param.options.isEmpty) {
            falhas.add('$onde: e escolha e nao tem opcao nenhuma');
          }
          if (param.kind == ParamKind.choice &&
              param.max >= param.options.length) {
            falhas.add(
              '$onde: escolha vai ate ${param.max} e so ha '
              '${param.options.length} opcoes',
            );
          }
        }
        if (spec.id.trim().isEmpty) falhas.add('${entrada.key.name}: sem id');
        if (spec.name.trim().isEmpty) falhas.add('${spec.id}: sem nome');
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('nenhum id de efeito se repete no catalogo', () {
      // Dois efeitos com o mesmo id no arquivo: um vira o outro ao
      // reabrir o projeto.
      final vistos = <String, EffectType>{};
      final falhas = <String>[];
      for (final e in effectSpecs.entries) {
        final antigo = vistos[e.value.id];
        if (antigo != null) {
          falhas.add('id "${e.value.id}": ${antigo.name} e ${e.key.name}');
        }
        vistos[e.value.id] = e.key;
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
      expect(vistos.length, effectSpecs.length);
    });
  });

  group('os extremos sobrevivem ao arquivo', () {
    test('cada parametro no minimo e no maximo volta igual', () {
      final falhas = <String>[];
      for (final tipo in EffectType.values) {
        for (final maximo in const [false, true]) {
          final efeito = _noExtremo(tipo, maximo: maximo);
          try {
            final volta = projectFromJson(
              projectToJson(
                _projeto([
                  _alvo(efeitos: [efeito]),
                ]),
              ),
            );
            final lido = volta.layers.single.effects.single;
            for (final chave in efeito.params.keys) {
              final antes = efeito.params[chave]!.valueAt(Duration.zero);
              final depois = lido.params[chave]?.valueAt(Duration.zero);
              if (depois == null) {
                falhas.add('${effectIdOf(tipo)}.$chave: sumiu no extremo');
              } else if ((antes - depois).abs() > 1e-6) {
                falhas.add('${effectIdOf(tipo)}.$chave: $antes -> $depois');
              }
            }
          } catch (erro) {
            falhas.add('${effectIdOf(tipo)} (max=$maximo): EXPLODIU ($erro)');
          }
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('um valor ALEM do limite nao quebra a gravacao', () {
      // O limite e da interface; o arquivo pode chegar com qualquer
      // coisa (expressao, preset antigo, edicao a mao). Nada disso pode
      // impedir de salvar nem de reabrir.
      final falhas = <String>[];
      for (final tipo in EffectType.values) {
        final spec = effectSpecs[tipo]!;
        final efeito = EffectInstance(
          type: tipo,
          params: {
            for (final e in spec.params.entries)
              e.key: AnimatedDouble(e.value.max * 1000 + 12345),
          },
        );
        try {
          final volta = projectFromJson(
            projectToJson(
              _projeto([
                _alvo(efeitos: [efeito]),
              ]),
            ),
          );
          if (volta.layers.single.effects.length != 1) {
            falhas.add('${spec.id}: perdeu o efeito com valor exagerado');
          }
        } catch (erro) {
          falhas.add('${spec.id}: EXPLODIU no exagero ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('os extremos desenham', () {
    /// Desenha o projeto e devolve os pixels — ou lanca.
    Future<ui.Image> quadro(WidgetTester tester, VideoProject p) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).openProject(p);
      final tempo = ValueNotifier(const Duration(milliseconds: 500));
      addTearDown(tempo.dispose);
      final videos = VideoLayerManager();
      addTearDown(videos.dispose);
      final chave = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: chave,
                child: SizedBox(
                  width: 128,
                  height: 128,
                  child: CompositionView(
                    time: tempo,
                    videos: videos,
                    selectedId: null,
                    exporting: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final boundary =
          chave.currentContext!.findRenderObject() as RenderRepaintBoundary;
      return boundary.toImageSync(pixelRatio: 1);
    }

    for (final maximo in const [false, true]) {
      testWidgets(
        'todo efeito no ${maximo ? "MAXIMO" : "MINIMO"} produz um quadro',
        (tester) async {
          tester.view.physicalSize = const Size(256, 256);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final falhas = <String>[];
          for (final tipo in EffectType.values) {
            try {
              final imagem = await quadro(
                tester,
                _projeto([
                  _alvo(efeitos: [_noExtremo(tipo, maximo: maximo)]),
                ]),
              );
              if (imagem.width != 128 || imagem.height != 128) {
                falhas.add(
                  '${effectIdOf(tipo)}: quadro ${imagem.width}x'
                  '${imagem.height}',
                );
              }
              imagem.dispose();
            } catch (erro) {
              final linha = '$erro'.split('\n').first;
              falhas.add('${effectIdOf(tipo)}: EXPLODIU ($linha)');
            }
            // Uma excecao levantada DENTRO do desenho nao volta pelo
            // try: ela cai no coletor do teste. Colhe-se aqui, efeito a
            // efeito, para saber qual foi.
            final erroDoQuadro = tester.takeException();
            if (erroDoQuadro != null) {
              final linha = '$erroDoQuadro'.split('\n').first;
              falhas.add('${effectIdOf(tipo)}: QUEBROU AO PINTAR ($linha)');
            }
          }
          expect(falhas, isEmpty, reason: falhas.join('\n'));
        },
      );
    }

    testWidgets('cinco efeitos empilhados no maximo ainda desenham', (
      tester,
    ) async {
      // O caso do usuario entusiasmado: glow por cima de blur por cima
      // de distorcao. Se a pilha estoura, estoura para todo mundo.
      tester.view.physicalSize = const Size(256, 256);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tipos = EffectType.values;
      final falhas = <String>[];
      for (var i = 0; i + 4 < tipos.length; i += 5) {
        final pilha = [
          for (var k = 0; k < 5; k++) _noExtremo(tipos[i + k], maximo: true),
        ];
        try {
          final imagem = await quadro(
            tester,
            _projeto([_alvo(efeitos: pilha)]),
          );
          imagem.dispose();
        } catch (erro) {
          falhas.add(
            'pilha ${pilha.map((e) => effectIdOf(e.type)).join("+")}: '
            '${'$erro'.split('\n').first}',
          );
        }
        final erroDoQuadro = tester.takeException();
        if (erroDoQuadro != null) {
          falhas.add(
            'pilha ${pilha.map((e) => effectIdOf(e.type)).join("+")}: '
            'AO PINTAR ${'$erroDoQuadro'.split('\n').first}',
          );
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });
}
