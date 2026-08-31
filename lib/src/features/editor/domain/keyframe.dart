import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';

/// Tipo de easing do segmento (taxonomia oficial do Alight Motion).
enum EasingType {
  cubicBezier,
  bounce,
  elastic,
  cyclic,
  random,
  steps,
  elasticSteps,
}

/// Easing do SEGMENTO que sai de um keyframe (modelo Alight: N keyframes =
/// N-1 curvas; a curva remapeia tempo->tempo dentro do trecho).
class Easing {
  const Easing({
    this.type = EasingType.cubicBezier,
    this.x1 = 0,
    this.y1 = 0,
    this.x2 = 1,
    this.y2 = 1,
    this.count = 4,
    this.smooth = 1.0,
    this.intensity = 0.5,
  });

  // Presets bezier (coluna de presets do graph editor).
  static const linear = Easing();
  static const easeIn = Easing(x1: 0.42, y1: 0, x2: 1, y2: 1);
  static const easeOut = Easing(x1: 0, y1: 0, x2: 0.58, y2: 1);
  static const easeInOut = Easing(x1: 0.42, y1: 0, x2: 0.58, y2: 1);
  static const overshoot = Easing(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1);
  static const bounce = Easing(type: EasingType.bounce);
  static const elastic = Easing(type: EasingType.elastic);

  static const bezierPresets = [linear, easeIn, easeOut, easeInOut, overshoot];

  final EasingType type;

  /// Alcas cubic-bezier: x em [0,1]; y pode passar de [0,1] com overshoot.
  final double x1, y1, x2, y2;

  /// Steps/elasticSteps: degraus; cyclic: ciclos.
  final int count;

  /// Cyclic: 1 = senoide suave, 0 = linear (dente de serra).
  final double smooth;

  /// Random: forca do ruido.
  final double intensity;

  bool get isLinear =>
      type == EasingType.cubicBezier &&
      x1 == 0 &&
      y1 == 0 &&
      x2 == 1 &&
      y2 == 1;

  /// Remapeia o progresso t (0..1) do segmento.
  double transform(double t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    switch (type) {
      case EasingType.cubicBezier:
        if (isLinear) return t;
        return Cubic(x1.clamp(0.0, 1.0), y1, x2.clamp(0.0, 1.0), y2)
            .transform(t);
      case EasingType.bounce:
        return Curves.bounceOut.transform(t);
      case EasingType.elastic:
        return Curves.elasticOut.transform(t);
      case EasingType.steps:
        final n = count < 2 ? 2 : count;
        return ((t * n).floor() / (n - 1)).clamp(0.0, 1.0);
      case EasingType.elasticSteps:
        final n = count < 2 ? 2 : count;
        final s = (t * n).floor();
        final frac = t * n - s;
        return ((s + Curves.elasticOut.transform(frac)) / n).clamp(0.0, 1.5);
      case EasingType.cyclic:
        final c = count < 1 ? 1 : count;
        final u = t * c;
        final f = u - u.floorToDouble();
        final smoothed = 0.5 - 0.5 * math.cos(math.pi * f);
        return smooth * smoothed + (1 - smooth) * f;
      case EasingType.random:
        // Ruido deterministico (scrub-estavel): garante f(0)=0 e f(1)=1.
        final envelope = 4 * t * (1 - t);
        final noise = math.sin(t * 27.4) * 0.62 + math.sin(t * 61.7) * 0.38;
        return (t + intensity * 0.3 * envelope * noise).clamp(0.0, 1.0);
    }
  }

  Easing copyWith({
    EasingType? type,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    int? count,
    double? smooth,
    double? intensity,
  }) {
    return Easing(
      type: type ?? this.type,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
      count: count ?? this.count,
      smooth: smooth ?? this.smooth,
      intensity: intensity ?? this.intensity,
    );
  }

  String get label => switch (type) {
        EasingType.cubicBezier => isLinear ? 'Linear' : 'Bezier',
        EasingType.bounce => 'Quicar',
        EasingType.elastic => 'Elastico',
        EasingType.cyclic => 'Ciclico',
        EasingType.random => 'Aleatorio',
        EasingType.steps => 'Degraus',
        EasingType.elasticSteps => 'Deg. elastico',
      };
}

class Keyframe<T> {
  const Keyframe({
    required this.time,
    required this.value,
    this.ease = Easing.linear,
  });

  /// Tempo local a camada (0 = inicio da camada).
  final Duration time;
  final T value;
  final Easing ease;

  Keyframe<T> copyWith({Duration? time, T? value, Easing? ease}) => Keyframe(
        time: time ?? this.time,
        value: value ?? this.value,
        ease: ease ?? this.ease,
      );
}

/// Mesmo frame se a diferenca for menor que isto.
const _epsilon = Duration(milliseconds: 8);

/// Nucleo compartilhado da avaliacao: busca binaria + segmento com easing.
/// As listas sao sempre mantidas ordenadas por tempo.
(T, T, double)? _segmentAt<T>(List<Keyframe<T>> kfs, Duration t) {
  if (t <= kfs.first.time) return null; // antes do primeiro
  if (t >= kfs.last.time) return null; // depois do ultimo
  var lo = 0;
  var hi = kfs.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (kfs[mid].time <= t) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  final a = kfs[lo];
  final b = kfs[hi];
  final span = (b.time - a.time).inMicroseconds;
  var f = span == 0 ? 1.0 : (t - a.time).inMicroseconds / span;
  f = a.ease.transform(f.clamp(0.0, 1.0));
  return (a.value, b.value, f);
}

List<Keyframe<T>> _insertSorted<T>(List<Keyframe<T>> kfs, Keyframe<T> kf) {
  final out = [
    for (final k in kfs)
      if ((k.time - kf.time).abs() >= _epsilon) k,
    kf,
  ]..sort((a, b) => a.time.compareTo(b.time));
  return List.unmodifiable(out);
}

List<Keyframe<T>> _removeAt<T>(List<Keyframe<T>> kfs, Duration t) {
  return List.unmodifiable([
    for (final k in kfs)
      if ((k.time - t).abs() >= _epsilon) k,
  ]);
}

/// Segmento de keyframe em que um tempo cai (PR-G0 do Modulo Grid):
/// valor anterior, valor seguinte e fracao JA com easing aplicado.
/// E o que permite o "caminho mais curto": animar um alvo de 1 a 4 vai
/// direto, sem passar por 2 e 3.
class KeyframeSegment {
  const KeyframeSegment(this.from, this.to, this.fraction);

  final double from;
  final double to;
  final double fraction;
}

/// Propriedade double animavel (escala, rotacao, opacidade...).
class AnimatedDouble {
  AnimatedDouble(this.base, [List<Keyframe<double>>? keyframes])
      : keyframes = List.unmodifiable(keyframes ?? const <Keyframe<double>>[]);

  final double base;
  final List<Keyframe<double>> keyframes;

  bool get isAnimated => keyframes.isNotEmpty;

  bool hasKeyframeAt(Duration t) =>
      keyframes.any((k) => (k.time - t).abs() < _epsilon);

  double valueAt(Duration t) {
    if (keyframes.isEmpty) return base;
    if (t <= keyframes.first.time) return keyframes.first.value;
    if (t >= keyframes.last.time) return keyframes.last.value;
    final (a, b, f) = _segmentAt(keyframes, t)!;
    return lerpDouble(a, b, f)!;
  }

  /// Entre quais keyframes [t] esta (null fora de um segmento) — PR-G0.
  KeyframeSegment? segmentAt(Duration t) {
    if (keyframes.length < 2) return null;
    if (t <= keyframes.first.time || t >= keyframes.last.time) return null;
    final (a, b, f) = _segmentAt(keyframes, t)!;
    return KeyframeSegment(a, b, f);
  }

  AnimatedDouble withBase(double v) => AnimatedDouble(v, keyframes);

  AnimatedDouble withKeyframe(Duration t, double v,
          [Easing ease = Easing.linear]) =>
      AnimatedDouble(base, _insertSorted(keyframes, Keyframe(time: t, value: v, ease: ease)));

  AnimatedDouble withoutKeyframe(Duration t) {
    final rest = _removeAt(keyframes, t);
    // Removeu o ultimo keyframe: volta a ser estatico no valor atual.
    if (rest.isEmpty) return AnimatedDouble(valueAt(t));
    return AnimatedDouble(base, rest);
  }

  /// Editar = keyframe automatico se a propriedade ja anima (comportamento AE).
  AnimatedDouble edited(Duration t, double v) =>
      isAnimated ? withKeyframe(t, v, easeAt(t)) : withBase(v);

  /// Easing do keyframe em [t] (ou o padrao, se nao houver).
  Easing easeAt(Duration t) {
    for (final k in keyframes) {
      if ((k.time - t).abs() < _epsilon) return k.ease;
    }
    return Easing.linear;
  }

  /// Troca o easing do keyframe em [t], se existir.
  AnimatedDouble withEase(Duration t, Easing ease) => AnimatedDouble(base, [
        for (final k in keyframes)
          if ((k.time - t).abs() < _epsilon) k.copyWith(ease: ease) else k,
      ]);

  /// Aplica a curva a TODOS os segmentos ("Paste Curve to All Keyframes").
  AnimatedDouble withEaseAll(Easing ease) => AnimatedDouble(base, [
        for (final k in keyframes) k.copyWith(ease: ease),
      ]);
}

/// Propriedade Offset animavel (posicao, ancora...).
class AnimatedOffset {
  AnimatedOffset(this.base, [List<Keyframe<Offset>>? keyframes])
      : keyframes = List.unmodifiable(keyframes ?? const <Keyframe<Offset>>[]);

  final Offset base;
  final List<Keyframe<Offset>> keyframes;

  bool get isAnimated => keyframes.isNotEmpty;

  bool hasKeyframeAt(Duration t) =>
      keyframes.any((k) => (k.time - t).abs() < _epsilon);

  Offset valueAt(Duration t) {
    if (keyframes.isEmpty) return base;
    if (t <= keyframes.first.time) return keyframes.first.value;
    if (t >= keyframes.last.time) return keyframes.last.value;
    final (a, b, f) = _segmentAt(keyframes, t)!;
    return Offset.lerp(a, b, f)!;
  }

  AnimatedOffset withBase(Offset v) => AnimatedOffset(v, keyframes);

  AnimatedOffset withKeyframe(Duration t, Offset v,
          [Easing ease = Easing.linear]) =>
      AnimatedOffset(base, _insertSorted(keyframes, Keyframe(time: t, value: v, ease: ease)));

  AnimatedOffset withoutKeyframe(Duration t) {
    final rest = _removeAt(keyframes, t);
    if (rest.isEmpty) return AnimatedOffset(valueAt(t));
    return AnimatedOffset(base, rest);
  }

  AnimatedOffset edited(Duration t, Offset v) =>
      isAnimated ? withKeyframe(t, v, easeAt(t)) : withBase(v);

  Easing easeAt(Duration t) {
    for (final k in keyframes) {
      if ((k.time - t).abs() < _epsilon) return k.ease;
    }
    return Easing.linear;
  }

  AnimatedOffset withEase(Duration t, Easing ease) => AnimatedOffset(base, [
        for (final k in keyframes)
          if ((k.time - t).abs() < _epsilon) k.copyWith(ease: ease) else k,
      ]);

  AnimatedOffset withEaseAll(Easing ease) => AnimatedOffset(base, [
        for (final k in keyframes) k.copyWith(ease: ease),
      ]);
}
