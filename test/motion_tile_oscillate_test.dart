import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/oscillate.dart';
import 'package:aurea/src/features/editor/presentation/widgets/motion_tile_pass.dart';

void main() {
  test('oscillation has deterministic frequency, direction and amplitude', () {
    final fx = EffectInstance(
      type: EffectType.oscillate,
      params: {'angle': AnimatedDouble(90)},
    );
    final position = oscillationOffset(fx, const Duration(milliseconds: 250));
    expect(position.dx, closeTo(0, 0.001));
    expect(position.dy, closeTo(50, 0.001));
    expect(
      oscillationOffset(fx, const Duration(seconds: 1)).distance,
      closeTo(0, 0.001),
    );
    expect(effectTypeFromId('s_shake'), EffectType.tremor);
  });
  testWidgets(
    'Motion Tile 200 percent covers preview after scaling layer to 50 percent',
    (tester) async {
      final fx = EffectInstance(
        type: EffectType.motionTile,
        params: {
          'output_width': AnimatedDouble(200),
          'output_height': AnimatedDouble(200),
          'mirror_edges': AnimatedDouble(1),
        },
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 200,
                height: 200,
                child: ClipRect(
                  child: Center(
                    child: Transform.scale(
                      scale: 0.5,
                      child: MotionTilePass(
                        effect: fx,
                        time: Duration.zero,
                        child: const SizedBox(
                          width: 200,
                          height: 200,
                          child: ColoredBox(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      final image = (await tester.runAsync(
        () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(),
      ))!;
      final data = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      for (final point in [
        const Offset(2, 2),
        const Offset(197, 2),
        const Offset(2, 197),
        const Offset(197, 197),
      ]) {
        final i = (point.dy.toInt() * 200 + point.dx.toInt()) * 4;
        expect(data!.getUint8(i), greaterThan(200));
        expect(
          data.getUint8(i + 1),
          lessThan(100),
          reason: 'tile must cover the white backdrop',
        );
      }
      image.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
