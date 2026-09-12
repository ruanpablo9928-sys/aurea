import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/estudio/estudio_da_cena.dart';

void main() {
  testWidgets('new studio fits small phones, landscape and enlarged text', (
    tester,
  ) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final editor = c.read(editorControllerProvider.notifier);
    editor.addScene3DLayer(Duration.zero);
    final id = c.read(editorControllerProvider).layers.first.id;
    final playback = PlaybackController(
      vsync: const TestVSync(),
      durationOf: () => c.read(editorControllerProvider).duration,
    );
    addTearDown(playback.dispose);
    addTearDown(() => tester.view.resetPhysicalSize());
    addTearDown(() => tester.view.resetDevicePixelRatio());
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 390 ? 1.3 : 1),
              ),
              child: child!,
            ),
            home: EstudioDaCena(
              key: ValueKey(size),
              layerId: id,
              playback: playback,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AutoKey'), findsOneWidget);
      expect(find.text('Dicas'), findsOneWidget);
      expect(find.byKey(const ValueKey('scene-quick-camera')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('scene-edit-panel'))).height,
        greaterThan(170),
      );
      expect(tester.takeException(), isNull, reason: '$size');
      for (var tab = 1; tab <= 4; tab++) {
        final button = find.byKey(ValueKey('scene-tab-$tab'));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size tab $tab');
      }
      await tester.tap(find.text('Dicas'));
      await tester.pumpAndSettle();
      expect(find.text('Dicas • Scene 3D'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.text('Dicas • Scene 3D'))).pop();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
  });
}
