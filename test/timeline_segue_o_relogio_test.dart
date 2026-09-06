import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/am/am_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A TIMELINE SEGUE O RELOGIO — inclusive depois de um arrasto que
/// terminou de um jeito torto.
///
/// O cabecote e desenhado FIXO no centro: quem se move e o conteudo.
/// Enquanto se arrasta uma barra a timeline para de seguir o relogio, de
/// proposito, para nao brigar com o dedo. So que os tratadores de FIM do
/// arrasto so existiam enquanto a camada estava selecionada e a timeline
/// nao estava compacta — desselecionar no meio do arrasto (ou o painel
/// trocar) fazia o fim nunca chegar, e a timeline ficava presa.
///
/// Presa assim, o keyframe nasce no tempo certo e APARECE longe do
/// cabecote. Foi o primeiro bug que os testadores acharam: "olha onde eu
/// coloquei keyframe e olha onde ele aparece".
void main() {
  Future<(ProviderContainer, PlaybackController)> montar(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(editorControllerProvider.notifier);
    editor.addShapeLayer(Duration.zero, name: 'Circulo 1');
    final id = container.read(editorControllerProvider).layers.first.id;
    container.read(selectedLayerProvider.notifier).state = id;

    late PlaybackController playback;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: _Host(
            builder: (p) {
              playback = p;
              return AmTimeline(playback: p, height: 280);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (container, playback);
  }

  double offset(WidgetTester tester) {
    for (final s in tester.stateList<ScrollableState>(
      find.byType(Scrollable),
    )) {
      if (s.position.axis == Axis.horizontal) return s.position.pixels;
    }
    return -1;
  }

  testWidgets('o conteudo anda quando o relogio anda', (tester) async {
    final (_, playback) = await montar(tester);
    final antes = offset(tester);
    playback.seek(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      offset(tester),
      greaterThan(antes),
      reason: 'o cabecote e fixo: quem anda e o conteudo',
    );
  });

  testWidgets(
    'desselecionar no meio do arrasto nao trava a timeline no tempo',
    (tester) async {
      final (container, playback) = await montar(tester);
      // Comeca a arrastar a BARRA da camada selecionada (o nome dela
      // mora dentro da barra).
      final barra = find.textContaining('Circulo');
      expect(barra, findsWidgets, reason: 'a barra da camada nao apareceu');
      final gesto = await tester.startGesture(tester.getCenter(barra.first));
      await tester.pump(const Duration(milliseconds: 40));
      for (var i = 0; i < 6; i++) {
        await gesto.moveBy(const Offset(8, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Sem um arrasto RECONHECIDO este teste nao prova nada: com a
      // barra na mao a timeline para de seguir o relogio de proposito.
      final presa = offset(tester);
      playback.seek(const Duration(seconds: 2));
      await tester.pump();
      expect(
        offset(tester),
        presa,
        reason: 'o gesto nao pegou a barra da camada',
      );

      // O painel troca / a selecao cai NO MEIO do arrasto: os tratadores
      // de fim deixam de existir.
      container.read(selectedLayerProvider.notifier).state = null;
      await tester.pump();
      await gesto.up();
      await tester.pumpAndSettle();

      // A prova: a timeline voltou a seguir o relogio.
      final antes = offset(tester);
      playback.seek(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(
        offset(tester),
        greaterThan(antes),
        reason: 'a timeline ficou presa em "editando barra"',
      );
    },
  );
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
    durationOf: () => const Duration(seconds: 20),
  );

  @override
  void dispose() {
    playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Column(children: [widget.builder(playback)])); 
}
