import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'layer.dart';
import 'video_project.dart';

/// The editor overlay uses the same 2D transform order as the content:
/// position, pivot, rotation, skew, scale, inverse pivot.
Matrix4 selectionTransform(VideoProject project, Layer layer, Duration time) {
  final local = layer.localTime(time);
  final effective = effectiveTransform(project, layer, time);
  final ownScale = layer.scaleX.valueAt(local);
  final ratio = ownScale.abs() < 1e-6 ? 1.0 : effective.scale / ownScale;
  var sx = ownScale * ratio;
  var sy = layer.scaleY.valueAt(local) * ratio;
  if (layer.is3D || effective.z != 0) {
    final perspective = 1200 / (1200 + effective.z.clamp(-1100, 100000));
    sx *= perspective;
    sy *= perspective;
  }
  final pivot = layer.pivot.valueAt(local);
  return Matrix4.identity()
    ..translateByDouble(
      effective.pos.dx + pivot.dx,
      effective.pos.dy + pivot.dy,
      0,
      1,
    )
    ..rotateZ(effective.rot * math.pi / 180)
    ..multiply(
      Matrix4.skew(
        layer.skewX.valueAt(local) * math.pi / 180,
        layer.skewY.valueAt(local) * math.pi / 180,
      ),
    )
    ..scaleByDouble(sx, sy, 1, 1)
    ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
}
