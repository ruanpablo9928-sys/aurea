import 'dart:math' as math;
import 'dart:ui';

import 'effect.dart';
import 'fx.dart';

Offset oscillationOffset(
  EffectInstance effect,
  Duration time, {
  double pixelScale = 1,
}) {
  final phase =
      integratedPhase(effect.track('frequency'), time) +
      effect.paramAt('phase', time) / 360;
  final radians = 2 * math.pi * phase;
  final wave = switch (effect.paramAt('wave', time).round()) {
    1 => 2 / math.pi * math.asin(math.sin(radians)),
    2 => math.sin(radians) >= 0 ? 1.0 : -1.0,
    3 => 2 * (phase % 1) - 1,
    _ => math.sin(radians),
  };
  final angle = effect.paramAt('angle', time) * math.pi / 180;
  final amount = effect.paramAt('amplitude', time) * wave * pixelScale;
  return Offset(math.cos(angle) * amount, math.sin(angle) * amount);
}
