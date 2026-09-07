import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// O GRAO DE FILME NAO DESENHA CELULA A CELULA.
///
/// O pintor antigo fazia um `drawRect` POR CELULA de grao, a cada
/// quadro: num preview de 390x700 com celula de 3 px sao dezenas de
/// milhares de chamadas de desenho por quadro, por camada. Medido em
/// `test/ferramenta_custo_preview_test.dart`, custava 3,6 ms por camada
/// — mais do que compor quarenta camadas sem efeito nenhum.
///
/// A correcao nao mexeu na aparencia: o ruido virou um azulejo montado
/// UMA vez e repetido com deslocamento por quadro. Este teste guarda a
/// propriedade que importa — o custo do grao nao pode crescer com o
/// tamanho da tela.
class _CanvasQueConta implements Canvas {
  int desenhos = 0;

  @override
  void noSuchMethod(Invocation invocation) {
    final nome = invocation.memberName.toString();
    if (nome.contains('drawRect') ||
        nome.contains('drawRRect') ||
        nome.contains('drawCircle') ||
        nome.contains('drawPath') ||
        nome.contains('drawImage') ||
        nome.contains('drawVertices') ||
        nome.contains('drawAtlas')) {
      desenhos++;
    }
  }
}

void main() {
  /// Conta as chamadas de desenho que o pintor do grao emite AGORA.
  int chamadasDoGrao(WidgetTester tester) {
    var total = 0;
    for (final el in find.byType(CustomPaint).evaluate()) {
      final pintor = (el.widget as CustomPaint).painter;
      if (pintor == null) continue;
      if (!pintor.runtimeType.toString().contains('Grain')) continue;
      final caixa = el.renderObject;
      final area = caixa is RenderBox && caixa.hasSize
          ? caixa.size
          : const Size(390, 700);
      final conta = _CanvasQueConta();
      pintor.paint(conta as Canvas, area);
      total += conta.desenhos;
    }
    return total;
  }

  testWidgets('o grao custa o mesmo numa tela pequena e numa grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(editorControllerProvider.notifier);
    c.addShapeLayer(Duration.zero);
    final p = c.state;
    c.openProject(
      p.copyWith(
        layers: [
          for (final l in p.layers)
            l.copyLayer(
              effects: [
                EffectInstance(
                  type: EffectType.filmGrain,
                  params: {
                    'intensidade': AnimatedDouble(.5),
                    'tamanho': AnimatedDouble(1),
                  },
                ),
              ],
            ),
        ],
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _Host(
            builder: (pb) =>
                PreviewStage(playback: pb, videos: VideoLayerManager()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pequena = chamadasDoGrao(tester);

    // A MESMA arvore, so que numa tela dezesseis vezes maior em area.
    tester.view.physicalSize = const Size(1280, 1024);
    await tester.pumpAndSettle();
    final grande = chamadasDoGrao(tester);

    expect(pequena, greaterThan(0), reason: 'o grao nao pintou nada');
    // O numero exato nao importa; o que importa e nao crescer com a
    // area. O pintor antigo emitia uma chamada por celula: numa tela
    // dezesseis vezes maior, dezesseis vezes mais chamadas.
    expect(
      grande,
      lessThanOrEqualTo(pequena * 2),
      reason:
          'o grao voltou a desenhar celula a celula: $pequena chamadas na '
          'tela pequena, $grande na grande',
    );
    // E, em numero absoluto, tem de ser um punhado — nao milhares.
    expect(
      grande,
      lessThan(40),
      reason: '$grande chamadas de desenho para um quadro de grao',
    );
  });
}

class _Host extends StatefulWidget {
  const _Host({required this.builder});

  final Widget Function(PlaybackController) builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  late final PlaybackController playback = PlaybackController(
    vsync: this,
    durationOf: () => const Duration(seconds: 5),
  );

  @override
  void dispose() {
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: widget.builder(playback));
}
