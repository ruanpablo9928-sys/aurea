import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/ui/editor_session.dart';
import 'package:aurea/src/features/editor/application/ui/preview_resolution.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/cut_ops.dart';
import 'package:aurea/src/features/editor/presentation/context/context_sheet.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:aurea/src/features/editor/presentation/widgets/campo_de_valor.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/media/application/gallery_service.dart';

import 'editor_hierarchy_test.dart' show openEditor;

void main() {
  test('image Z enables depth and undo restores 2D', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final e = c.read(editorControllerProvider.notifier);
    e.addImageLayer(Duration.zero, 'image.png', 'Photo');
    final id = c.read(editorControllerProvider).layers.first.id;
    e.editPositionZ(id, Duration.zero, 160);
    final l = c.read(editorControllerProvider).layerById(id)!;
    expect(l.is3D, isTrue);
    expect(l.positionZ.valueAt(Duration.zero), 160);
    e.undo();
    expect(c.read(editorControllerProvider).layerById(id)!.is3D, isFalse);
  });
  test('long video reverses source time without waiting for a proxy', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final e = c.read(editorControllerProvider.notifier);
    final id = e.addVideoLayer(
      Duration.zero,
      'clip.mp4',
      'Clip',
      const Duration(seconds: 20),
    );
    expect(e.setClipReverse(id, true), isTrue);
    final l = c.read(editorControllerProvider).layerById(id)! as VideoLayer;
    expect(
      videoAbsoluteSourceTimeAt(l, const Duration(seconds: 2)),
      greaterThan(videoAbsoluteSourceTimeAt(l, const Duration(seconds: 3))),
    );
    expect(e.setClipReverse(id, false), isTrue);
  });
  test(
    'expired gallery thumbnail metadata returns no image instead of throwing',
    () async {
      expect(
        await GalleryService().thumbnail(
          const GalleryAsset('expired', video: false),
        ),
        isNull,
      );
    },
  );
  for (final size in [const Size(375, 667), const Size(390, 844)]) {
    testWidgets('editing panel and preview stay usable on $size', (
      tester,
    ) async {
      final c = await openEditor(tester, size: size);
      final before = tester.getRect(find.byType(PreviewStage));
      final fullRatio = MediaQuery.devicePixelRatioOf(
        tester.element(find.byType(CompositionView).first),
      );
      final outputHeight = c.read(editorControllerProvider).resolutionHeight;
      c.read(selectedLayerProvider.notifier).state = c
          .read(editorControllerProvider)
          .layers
          .first
          .id;
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ContextSheet)).height,
        greaterThanOrEqualTo(215),
      );
      expect(tester.getRect(find.byType(PreviewStage)), before);
      for (final key in [
        'timeline-ima',
        'timeline-buscar',
        'timeline-entrada',
        'timeline-saida',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('preview-resolution')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1/8'));
      await tester.pumpAndSettle();
      expect(c.read(previewResolutionProvider), PreviewResolution.eighth);
      expect(
        MediaQuery.devicePixelRatioOf(
          tester.element(find.byType(CompositionView).first),
        ),
        closeTo(fullRatio / 8, .0001),
      );
      expect(c.read(editorControllerProvider).resolutionHeight, outputHeight);
      expect(tester.getRect(find.byType(PreviewStage)), before);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('corner value opens keypad and updates only that corner', (
    tester,
  ) async {
    final c = await openEditor(tester, size: const Size(375, 667));
    final e = c.read(editorControllerProvider.notifier);
    e.addShapeLayer(
      Duration.zero,
      name: 'Rounded',
      contents: [
        ShapeParametric(roundness: AnimatedDouble(25)),
        ShapeFill(),
      ],
    );
    final id = c.read(selectedLayerProvider)!;
    await tester.pumpAndSettle();
    c.read(editorSessionProvider.notifier).openPanel(EditorPanel.editShape);
    c.read(editorSessionProvider.notifier).setShapeTool(ShapeTool.corners);
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is CampoDeValor && w.rotulo == 'Superior dir.',
    );
    expect(field, findsOneWidget);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), '40');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final l = c.read(editorControllerProvider).layerById(id)! as ShapeLayer;
    final shape = l.contents.whereType<ShapeParametric>().single;
    expect(
      shapeParamTrackOf(shape, 'cornerTopRight')!.valueAt(Duration.zero),
      40,
    );
    expect(
      shapeParamTrackOf(shape, 'cornerTopLeft')!.valueAt(Duration.zero),
      25,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'transform pad keeps straight movement and clears its red guide on release',
    (tester) async {
      final c = await openEditor(tester);
      final id = c.read(editorControllerProvider).layers.first.id;
      c.read(selectedLayerProvider.notifier).state = id;
      await tester.pumpAndSettle();
      c.read(editorSessionProvider.notifier).openTransform();
      await tester.pumpAndSettle();
      final before = c
          .read(editorControllerProvider)
          .layerById(id)!
          .position
          .valueAt(Duration.zero);
      final pad = find.byKey(const ValueKey('position-drag-pad'));
      final gesture = await tester.startGesture(tester.getCenter(pad));
      await gesture.moveBy(const Offset(30, 1));
      await tester.pump();
      await gesture.moveBy(const Offset(40, 1));
      await tester.pump();
      final after = c
          .read(editorControllerProvider)
          .layerById(id)!
          .position
          .valueAt(Duration.zero);
      expect(after.dx, greaterThan(before.dx));
      expect(after.dy, before.dy);
      expect(c.read(transformGuidesProvider).y, before.dy);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(c.read(transformGuidesProvider), (x: null, y: null));
    },
  );
}
