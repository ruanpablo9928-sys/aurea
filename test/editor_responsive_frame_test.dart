import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/ui/editor_session.dart';
import 'package:aurea/src/features/editor/presentation/widgets/composition_frame.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:aurea/src/features/editor/presentation/widgets/motion_keyframe_track.dart';

import 'editor_hierarchy_test.dart' show openEditor;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in [
      'Aurea Motion Sans',
      '.SF Pro Text',
      '.SF Pro Display',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
  });
  test('output bounds fit phone, landscape and tablet without cropping', () {
    for (final viewport in [
      const Size(320, 230),
      const Size(430, 400),
      const Size(280, 160),
      const Size(720, 600),
    ]) {
      for (final output in [
        const Size(1080, 1920),
        const Size(1920, 1080),
        const Size(1080, 1080),
        const Size(4096, 1716),
      ]) {
        final r = compositionRect(viewport, output);
        expect(r.width / r.height, closeTo(output.aspectRatio, 1e-9));
        expect(r.left, greaterThanOrEqualTo(7.99));
        expect(r.top, greaterThanOrEqualTo(7.99));
        expect(r.right, lessThanOrEqualTo(viewport.width - 7.99));
        expect(r.bottom, lessThanOrEqualTo(viewport.height - 7.99));
      }
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(667, 375),
    const Size(844, 390),
    const Size(1024, 768),
  ]) {
    testWidgets('fixed preview while switching tools at $size', (tester) async {
      final c = await openEditor(tester, size: size);
      final controller = c.read(editorControllerProvider.notifier);
      controller.setComposition(aspectRatio: 9 / 16);
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(PreviewStage));
      final frame = tester.getRect(
        find.byKey(const ValueKey('composition-frame')),
      );
      expect(frame.width / frame.height, closeTo(9 / 16, .001));
      c.read(selectedLayerProvider.notifier).state = c
          .read(editorControllerProvider)
          .layers
          .first
          .id;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(PreviewStage)), before);
      for (final panel in [
        EditorPanel.transform,
        EditorPanel.effects,
        EditorPanel.blending,
        EditorPanel.colorFill,
      ]) {
        c.read(editorSessionProvider.notifier).openPanel(panel);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(PreviewStage)), before);
        expect(tester.takeException(), isNull, reason: '$size / $panel');
      }
    });
  }
  testWidgets('motion diamonds seek and scrub exact times', (tester) async {
    Duration? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 324,
              child: MotionKeyframeTrack(
                keysUs: const [0, 1000000, 4000000],
                duration: const Duration(seconds: 5),
                time: Duration.zero,
                label: 'Camera',
                onSeek: (t) => chosen = t,
              ),
            ),
          ),
        ),
      ),
    );
    final track = tester.getRect(find.byType(MotionKeyframeTrack));
    await tester.tapAt(track.topLeft + const Offset(12 + 60 + 6, 18));
    expect(chosen, const Duration(seconds: 1));
    await tester.tapAt(track.topLeft + const Offset(12 + 240, 18));
    expect(chosen, const Duration(seconds: 4));
  });
}
