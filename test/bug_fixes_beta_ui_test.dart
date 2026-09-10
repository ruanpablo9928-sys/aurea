import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/presentation/widgets/editor_de_curva.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/pilula_de_navegacao.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';

class _FakeVsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Regressao UI Beta e Estabilidade', () {
    testWidgets('1. O FAB + fica oculto quando uma camada esta selecionada', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final playback = PlaybackController(
        vsync: _FakeVsync(),
        durationOf: () => const Duration(seconds: 10),
      );

      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Camada 1');
      final camadaId = container.read(editorControllerProvider).layers.first.id;

      // Sem selecao: FAB + visivel
      container.read(selectedLayerProvider.notifier).state = null;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: LinhaDoTempo(playback: playback),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Adicionar conteudo'), findsOneWidget);

      // Com selecao: FAB + deve ficar totalmente oculto (SizedBox.shrink)
      container.read(selectedLayerProvider.notifier).state = camadaId;
      await tester.pump();
      expect(find.bySemanticsLabel('Adicionar conteudo'), findsNothing);
    });

    testWidgets('2. O EditorDeCurva contem ClipRect para nao vazar alcas de controle', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Curva com overshoot (y1 = 1.56) que causava vazamento
      container.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
        titulo: 'Opacidade',
        atual: Easing.overshoot,
        aoAplicar: (_) {},
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 200,
                child: EditorDeCurva(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verifica que o quadro da curva esta envolto por um ClipRect
      final quadroFinder = find.byKey(const ValueKey('quadro-da-curva'));
      expect(quadroFinder, findsOneWidget);

      final clipRectFinder = find.ancestor(
        of: quadroFinder,
        matching: find.byType(ClipRect),
      );
      expect(clipRectFinder, findsAtLeastNWidgets(1));
    });

    testWidgets('3. Navegacao de camada na linha do tempo esta alinhada a trilha', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final playback = PlaybackController(
        vsync: _FakeVsync(),
        durationOf: () => const Duration(seconds: 10),
      );

      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Camada 1');
      c.addTextLayer(Duration.zero, text: 'Camada 2');
      final layers = container.read(editorControllerProvider).layers;

      container.read(selectedLayerProvider.notifier).state = layers.first.id;
      container.read(modoDaLinhaDoTempoProvider.notifier).state = ModoDaLinhaDoTempo.detalhado;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: LinhaDoTempo(playback: playback),
            ),
          ),
        ),
      );
      await tester.pump();

      // A PilulaDeNavegacao nao exibe nome duplicado sobre a trilha
      final pilula = tester.widget<PilulaDeNavegacao>(find.byType(PilulaDeNavegacao));
      expect(pilula.mostrarNome, isFalse);

      // As setas de navegacao existem e funcionam
      expect(find.bySemanticsLabel('Proxima camada'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Proxima camada'));
      await tester.pump();
      expect(container.read(selectedLayerProvider), layers[1].id);
    });
  });
}
