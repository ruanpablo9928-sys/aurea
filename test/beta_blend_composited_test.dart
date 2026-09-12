import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/presentation/widgets/blend_mask.dart';

void main() {
  testWidgets('blend sees a separately composited backdrop', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const RepaintBoundary(
                    child: ColoredBox(color: Color(0xFFFF0000)),
                  ),
                  const BlendMask(
                    blendMode: BlendMode.multiply,
                    child: ColoredBox(color: Color(0xFF00FF00)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final img =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(
        [bytes.getUint8(0), bytes.getUint8(1), bytes.getUint8(2)],
        [0, 0, 0],
      );
      img.dispose();
    });
  });
}
