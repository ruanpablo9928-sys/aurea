import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/cut.dart';
import 'package:aurea/src/features/editor/domain/cut_ops.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/widgets/essential_warp_pass.dart';

void main() {
  testWidgets(
    'dissolve draws both shapes after arbitrary timeline layer reorder',
    (tester) async {
      tester.view.physicalSize = const Size(100, 100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      ShapeLayer shape(
        String id,
        Color color,
        Duration start, {
        ClipTransition? transition,
      }) => ShapeLayer(
        id: id,
        name: id,
        startTime: start,
        duration: const Duration(seconds: 2),
        transitionIn: transition,
        position: AnimatedOffset(const Offset(50, 50)),
        contents: [
          ShapePath(
            primitive: ShapePrimitive.rectangle,
            width: 100,
            height: 100,
          ),
          ShapeFill(color: color),
        ],
      );
      final a = shape('a', const Color(0xffff0000), Duration.zero);
      final b = shape(
        'b',
        const Color(0xff0000ff),
        const Duration(seconds: 2),
        transition: ClipTransition(outgoingLayerId: 'a'),
      );
      final project = VideoProject(
        name: 'Order',
        createdAt: DateTime(2026),
        aspectRatio: 1,
        resolutionHeight: 100,
        layers: [a, b],
      );
      c.read(editorControllerProvider.notifier).openProject(project);
      final contexts = transitionContextsAt(
        project.layers,
        const Duration(seconds: 2),
      );
      expect(transitionPaintOrder([b, a], contexts).map((l) => l.id), [
        'a',
        'b',
      ]);
      final time = ValueNotifier(const Duration(seconds: 2));
      addTearDown(time.dispose);
      final videos = VideoLayerManager();
      addTearDown(videos.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: CompositionView(
                time: time,
                videos: videos,
                selectedId: null,
                exporting: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = (await tester.runAsync(
        () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(),
      ))!;
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final i = (50 * 100 + 50) * 4;
      expect(data.getUint8(i), closeTo(127, 2));
      expect(data.getUint8(i + 2), closeTo(128, 2));
      image.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  test('optional image/shape junction persists, keeps binding through edit, undo and remove', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final e = c.read(editorControllerProvider.notifier);
    final image = ImageLayer(
      id: 'a',
      name: 'Photo',
      sourcePath: 'photo.jpg',
      startTime: Duration.zero,
      duration: const Duration(seconds: 2),
    );
    final shape = ShapeLayer(
      id: 'b',
      name: 'Shape',
      startTime: const Duration(seconds: 2),
      duration: const Duration(seconds: 2),
    );
    e.openProject(
      VideoProject(
        createdAt: DateTime(2026),
        name: 'Cut',
        layers: [image, shape],
      ),
    );
    expect(e.transitionAfter('a'), isNull);
    expect(
      e.applyTransition(
        'a',
        ClipTransitionType.effect,
        effectType: EffectType.twirl,
      ),
      isTrue,
    );
    final saved = projectFromJson(
      jsonDecode(jsonEncode(projectToJson(c.read(editorControllerProvider)))),
    );
    final b = saved.layers.last;
    expect(b.transitionIn!.effect!.type, EffectType.twirl);
    expect(b.copyLayer(name: 'Renamed').transitionIn!.outgoingLayerId, 'a');
    expect(
      b.duplicated().transitionIn,
      isNull,
      reason: 'duplicate must not steal existing junction',
    );
    final contexts = transitionContextsAt(
      saved.layers,
      const Duration(seconds: 2),
    );
    expect(contexts, hasLength(1));
    expect(contexts.single.outgoing, isA<ImageLayer>());
    expect(contexts.single.incoming, isA<ShapeLayer>());
    e.removeTransition('a');
    expect(e.transitionAfter('a'), isNull);
    e.undo();
    expect(e.transitionAfter('a'), isNotNull);
  });
  test(
    'all visual subclasses retain junction in generic and specialized edits',
    () {
      final transition = ClipTransition(outgoingLayerId: 'a');
      final layers = <Layer>[
        TextLayer(
          name: 'Text',
          text: 'X',
          startTime: Duration.zero,
          duration: const Duration(seconds: 2),
        ),
        ParticlesLayer(
          name: 'Particles',
          startTime: Duration.zero,
          duration: const Duration(seconds: 2),
        ),
        Scene3DLayer(
          name: 'Scene',
          startTime: Duration.zero,
          duration: const Duration(seconds: 2),
        ),
        Element3DLayer(
          name: 'Solid',
          startTime: Duration.zero,
          duration: const Duration(seconds: 2),
        ),
      ];
      for (final l in layers) {
        final next = l
            .copyLayer(transitionIn: transition)
            .copyLayer(name: 'edited');
        expect(next.transitionIn, transition);
        final project = VideoProject(
          createdAt: DateTime(2026),
          name: 'Roundtrip',
          layers: [next],
        );
        expect(
          projectFromJson(projectToJson(project))
              .layers
              .single
              .transitionIn!
              .outgoingLayerId,
          'a',
        );
        if (next is Scene3DLayer) {
          expect(next.copyScene().transitionIn, transition);
        }
        expect(next.copyLayer(clearTransitionIn: true).transitionIn, isNull);
      }
    },
  );
  for (final type in essentialWarpTypes) {
    testWidgets(
      '${type.name} renders identity and changes pixels with controls',
      (tester) async {
        final boundary = GlobalKey();
        Future<List<int>> render(Map<String, double> values) async {
          final fx = EffectInstance(
            type: type,
            params: {
              for (final e in values.entries) e.key: AnimatedDouble(e.value),
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: EssentialWarpPass(
                      effect: fx,
                      time: Duration.zero,
                      child: CustomPaint(painter: _Pattern()),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pumpAndSettle();
          final image = (await tester.runAsync(
            () =>
                (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(),
          ))!;
          final data = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          final result = data.buffer
              .asUint8List(data.offsetInBytes, data.lengthInBytes)
              .toList();
          image.dispose();
          return result;
        }

        final identity = await render({
          'amount': 0,
          'center_x': .5,
          'center_y': .5,
        });
        final altered = await render(
          type == EffectType.offset ? {'center_x': .7, 'center_y': .6} : {},
        );
        expect(altered, hasLength(identity.length));
        final changed = [
          for (var i = 0; i < identity.length; i++)
            if ((identity[i] - altered[i]).abs() > 8) i,
        ].length;
        expect(
          changed,
          greaterThan(100),
          reason: 'visible effect must actually alter samples',
        );
        if (type == EffectType.invert) {
          for (var channel = 0; channel < 3; channel++) {
            expect(altered[channel], closeTo(255 - identity[channel], 1));
          }
        }
        final repeated = await render(
          type == EffectType.offset ? {'center_x': .7, 'center_y': .6} : {},
        );
        expect(repeated, altered, reason: 'deterministic direct seek');
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _Pattern extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.red);
    c.drawRect(Rect.fromLTWH(40, 0, 40, 80), Paint()..color = Colors.green);
    c.drawCircle(const Offset(32, 50), 19, Paint()..color = Colors.blue);
    c.drawRect(
      const Rect.fromLTWH(6, 11, 12, 7),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Pattern old) => false;
}
