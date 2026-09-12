import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

vm.Matrix4 rotationMatrix(double x, double y, double z) => vm.Matrix4.identity()
  ..rotateZ(z * math.pi / 180)
  ..rotateY(y * math.pi / 180)
  ..rotateX(x * math.pi / 180);

(double, double, double) rotationAngles(vm.Matrix4 m) {
  final y = math.asin((-m.entry(2, 0)).clamp(-1.0, 1.0));
  final singular = math.cos(y).abs() < 1e-7;
  final x = singular
      ? math.atan2(-m.entry(1, 2), m.entry(1, 1))
      : math.atan2(m.entry(2, 1), m.entry(2, 2));
  final z = singular ? 0.0 : math.atan2(m.entry(1, 0), m.entry(0, 0));
  return (x * 180 / math.pi, y * 180 / math.pi, z * 180 / math.pi);
}

double nearestRotationTurn(double angle, double reference) =>
    angle + ((reference - angle) / 360).round() * 360;
