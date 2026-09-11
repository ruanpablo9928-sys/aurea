import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../am/am_colors.dart';

/// A painted track rather than one widget per key: dense motions remain
/// inexpensive, and a tap snaps to the nearest visible diamond.
class MotionKeyframeTrack extends StatelessWidget {
  const MotionKeyframeTrack({
    super.key,
    required this.keysUs,
    required this.duration,
    required this.time,
    required this.onSeek,
    required this.label,
  });
  final List<int> keysUs;
  final Duration duration, time;
  final ValueChanged<Duration> onSeek;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label, ${keysUs.length} keyframes',
    value: '${(time.inMicroseconds / 1e6).toStringAsFixed(2)} segundos',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final span = math.max(1, duration.inMicroseconds);
        final width = math.max(1.0, constraints.maxWidth - 24);
        void seek(double x, {bool snap = false}) {
          var us = (((x - 12) / width).clamp(0.0, 1.0) * span).round();
          if (snap && keysUs.isNotEmpty) {
            final nearest = keysUs.reduce(
              (a, b) => (a - us).abs() <= (b - us).abs() ? a : b,
            );
            if ((nearest - us).abs() * width / span <= 16) us = nearest;
          }
          onSeek(Duration(microseconds: us.clamp(0, span)));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seek(d.localPosition.dx, snap: true),
          onHorizontalDragStart: (d) => seek(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seek(d.localPosition.dx),
          child: CustomPaint(
            painter: MotionKeyframePainter(keysUs, span, time.inMicroseconds),
            child: const SizedBox(height: 36, width: double.infinity),
          ),
        );
      },
    ),
  );
}

class MotionKeyframePainter extends CustomPainter {
  const MotionKeyframePainter(this.keysUs, this.durationUs, this.timeUs);
  final List<int> keysUs;
  final int durationUs, timeUs;
  @override
  void paint(Canvas canvas, Size size) {
    double x(int t) =>
        12 + (size.width - 24) * (t / durationUs).clamp(0.0, 1.0);
    final paint = Paint()..color = AmColors.chip;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 7, math.max(0, size.width - 16), 22),
        const Radius.circular(3),
      ),
      paint,
    );
    var lastPixel = -100.0;
    for (final key in keysUs) {
      if (key < 0 || key > durationUs) continue;
      final dx = x(key);
      // Several keys at the same physical pixel need only one diamond.
      if ((dx - lastPixel).abs() < 1) continue;
      lastPixel = dx;
      final here = (key - timeUs).abs() <= 8000;
      paint.color = here ? AmColors.accent : AmColors.text;
      canvas.drawPath(
        Path()
          ..moveTo(dx, 11)
          ..lineTo(dx + 5, 18)
          ..lineTo(dx, 25)
          ..lineTo(dx - 5, 18)
          ..close(),
        paint,
      );
    }
    paint
      ..color = AmColors.accent
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(x(timeUs), 1),
      Offset(x(timeUs), size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(MotionKeyframePainter old) =>
      old.timeUs != timeUs ||
      old.durationUs != durationUs ||
      old.keysUs != keysUs;
}
