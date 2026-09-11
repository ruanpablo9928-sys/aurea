import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/presentation/am/scene3d_studio.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/editor/presentation/widgets/motion_keyframe_track.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in [
      'Roboto',
      'CupertinoSystemText',
      'CupertinoSystemDisplay',
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
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(667, 375),
  ]) {
    testWidgets(
      'studio scrubs, records object rotation and preserves first pose at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final editor = container.read(editorControllerProvider.notifier);
        editor.openProject(
          container
              .read(editorControllerProvider)
              .copyWith(
                layers: [
                  Scene3DLayer(
                    id: 'scene',
                    name: 'Motion',
                    startTime: Duration.zero,
                    duration: const Duration(seconds: 5),
                    scene: Scene3D(
                      nodes: [SceneNode(id: 'cube', name: 'Cubo manual')],
                    ),
                  ),
                ],
              ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: RepaintBoundary(
                key: ValueKey('studio-capture'),
                child: Scene3DStudio(layerId: 'scene'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ruler = tester.widget<AmTickRuler>(
          find.byKey(const ValueKey('scene-motion-time')),
        );
        ruler.onChanged(2);
        await tester.pumpAndSettle();
        final viewport = find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is Scene3DPainter &&
              (w.painter as Scene3DPainter).view == SceneView.camera,
        );
        expect(
          (tester.widget<CustomPaint>(viewport).painter as Scene3DPainter).time,
          const Duration(seconds: 2),
        );
        await tester.tap(viewport);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(find.text('Cubo manual'), findsOneWidget);
        await tester.tap(find.text('Girar'));
        await tester.pumpAndSettle();
        await tester.drag(viewport, const Offset(45, 0));
        await tester.pumpAndSettle();
        final layer =
            container.read(editorControllerProvider).layerById('scene')
                as Scene3DLayer;
        final node = layer.scene.nodeById('cube')!;
        expect(node.rotY.valueAt(Duration.zero), 0);
        expect(node.rotY.valueAt(const Duration(seconds: 2)), isNot(0));
        expect(node.rotY.hasKeyframeAt(const Duration(seconds: 2)), isTrue);
        final track = tester.widget<MotionKeyframeTrack>(
          find.byKey(const ValueKey('scene-motion-keyframes')),
        );
        expect(track.keysUs, containsAll([0, 2000000]));
        final rect = tester.getRect(find.byType(MotionKeyframeTrack));
        await tester.tapAt(rect.topLeft + const Offset(12, 18));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MotionKeyframeTrack>(find.byType(MotionKeyframeTrack))
              .time,
          Duration.zero,
        );
        expect(
          tester
                  .getRect(
                    find.byKey(const ValueKey('studio-composition-frame')),
                  )
                  .width /
              tester
                  .getRect(
                    find.byKey(const ValueKey('studio-composition-frame')),
                  )
                  .height,
          closeTo(container.read(editorControllerProvider).aspectRatio, .001),
        );
        expect(tester.takeException(), isNull);
        ruler.onChanged(2);
        await tester.pumpAndSettle();
        final beforeEdit = tester.getRect(
          find.byKey(const ValueKey('studio-composition-frame')),
        );
        await tester.tap(find.byKey(const ValueKey('scene-transform-1')));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(
            find.byKey(const ValueKey('studio-composition-frame')),
          ),
          beforeEdit,
        );
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byKey(const ValueKey('valor-campo')), '45');
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        final edited =
            (container.read(editorControllerProvider).layerById('scene')
                    as Scene3DLayer)
                .scene
                .nodeById('cube')!;
        expect(edited.rotY.valueAt(const Duration(seconds: 2)), 45);
        expect(edited.rotY.valueAt(Duration.zero), 0);
        expect(
          tester.getRect(
            find.byKey(const ValueKey('studio-composition-frame')),
          ),
          beforeEdit,
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('AUREA_CAPTURE') && size.width == 390) {
          for (final family in [
            'Roboto',
            'CupertinoSystemText',
            'CupertinoSystemDisplay',
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
          await tester.pumpAndSettle();
          void repaint(RenderObject node) {
            node.markNeedsPaint();
            node.visitChildren(repaint);
          }

          repaint(
            tester.renderObject(find.byKey(const ValueKey('studio-capture'))),
          );
          await tester.pump();
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('studio-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('tmp/scene3d-studio-motion.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
