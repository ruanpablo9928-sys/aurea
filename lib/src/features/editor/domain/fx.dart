import 'dart:math' as math;

import 'keyframe.dart';
import 'text_animator.dart' show valueNoise01;

/// Fundacao dos efeitos avancados (spec AM2-efeitos-avancados, PR-FX0):
/// - ruido PURO compartilhado: funcao de (seed, canal, t), nada acumula
///   estado entre frames (invariante I1 — mesma do seletor Wiggly);
/// - FASE INTEGRADA: fase(t) = integral da frequencia, avaliada numa grade
///   fixa deterministica — animar a frequencia de 2 a 8 vira aceleracao
///   continua, sem o salto do `t * freq`;
/// - "tiques" do glitch: um valor aleatorio num instante aleatorio,
///   funcao pura do tempo — seekavel por construcao.

/// Ruido suave [-1, 1] por (seed, canal, x).
double fxNoiseSigned(int seed, int channel, double x) =>
    valueNoise01(seed * 1000003 + channel * 7919, channel * 13.7, x) * 2 - 1;

/// Hash uniforme [0, 1) por (seed, canal, slot) — para tiques discretos.
double fxHash01(int seed, int channel, int slot) {
  var s = (seed * 0x9E3779B9 ^ (channel + 1) * 0x85EBCA6B ^
          (slot + 1) * 0xC2B2AE35) &
      0xFFFFFFFF;
  s ^= (s << 13) & 0xFFFFFFFF;
  s ^= s >> 17;
  s ^= (s << 5) & 0xFFFFFFFF;
  return (s & 0xFFFFFF) / 0x1000000;
}

/// Fase integrada (PR-FX0 §1.2): integral da frequencia de 0 ate [t],
/// trapezio numa grade FIXA de 240 celulas/s — funcao pura de t, continua
/// e monotonica para frequencias positivas. Frequencia sem keyframe usa o
/// caminho analitico direto.
double integratedPhase(AnimatedDouble frequency, Duration t) {
  final seconds = t.inMicroseconds / 1e6;
  if (seconds <= 0) return 0;
  if (!frequency.isAnimated) return frequency.base * seconds;

  const grid = 1.0 / 240;
  final cells = (seconds / grid).floor();
  var phase = 0.0;
  var prev = frequency.valueAt(Duration.zero);
  for (var i = 1; i <= cells; i++) {
    final f = frequency
        .valueAt(Duration(microseconds: (i * grid * 1e6).round()));
    phase += (prev + f) / 2 * grid;
    prev = f;
  }
  final rem = seconds - cells * grid;
  if (rem > 0) {
    final f = frequency.valueAt(t);
    phase += (prev + f) / 2 * rem;
  }
  return phase;
}

/// ---------------------------------------------------------------- Tremor

/// Amostra do Tremor (PR-FX3): translacao + zoom + inclinacao, aleatorio
/// mas REPETIVEL — mesma semente, mesmo resultado, sempre.
class TremorSample {
  const TremorSample(this.dx, this.dy, this.scale, this.rotationDeg);

  final double dx;
  final double dy;
  final double scale;
  final double rotationDeg;

  static const none = TremorSample(0, 0, 1, 0);

  bool get isNeutral =>
      dx == 0 && dy == 0 && scale == 1 && rotationDeg == 0;
}

/// Estilos: 0 = Normal (constante), 1 = Nervoso (rajadas entre pausas),
/// 2 = Aos saltos (saltos secos com deriva lenta).
TremorSample tremorSample({
  required double amplitudePx,
  required double phase,
  required int style,
  required int seed,
  double zoom = 0,
  double tiltDeg = 0,
}) {
  if (amplitudePx <= 0 && zoom <= 0 && tiltDeg <= 0) {
    return TremorSample.none;
  }

  var gate = 1.0;
  var px = phase;
  switch (style) {
    case 1: // Nervoso: imobilidade ~0,7 com rajadas.
      final burst = valueNoise01(seed * 7 + 99, 5.5, phase * 0.35);
      gate = burst > 0.62 ? 1.0 : 0.05;
    case 2: // Aos saltos: quantiza a fase; deriva pequena entre saltos.
      const jumpRate = 0.9;
      final slot = (phase * jumpRate).floorToDouble();
      final frac = phase * jumpRate - slot;
      px = slot / jumpRate + frac * 0.12;
  }

  double n(int ch) => fxNoiseSigned(seed, ch, px);

  return TremorSample(
    n(1) * amplitudePx * gate,
    n(2) * amplitudePx * 0.6 * gate,
    1 + n(3) * zoom.clamp(0, 1) * 0.22 * gate,
    n(4) * tiltDeg * gate,
  );
}

/// -------------------------------------------------------- Glitch Modular

/// Estado do glitch num instante: cada operador sorteia tiques no seu
/// intervalo; um tique = valor aleatorio num instante aleatorio (funcao
/// pura de (seed, slot) — deterministico e seekavel, PR-FX4).
class GlitchState {
  const GlitchState({
    this.dx = 0,
    this.dy = 0,
    this.scale = 1,
    this.blurSigma = 0,
    this.hueDeg = 0,
    this.brightness = 0,
    this.rgbSep = 0,
  });

  final double dx;
  final double dy;
  final double scale;
  final double blurSigma;
  final double hueDeg;
  final double brightness;
  final double rgbSep;

  static const none = GlitchState();

  bool get isNeutral =>
      dx == 0 &&
      dy == 0 &&
      scale == 1 &&
      blurSigma == 0 &&
      hueDeg == 0 &&
      brightness == 0 &&
      rgbSep == 0;
}

/// [tau] e a fase integrada da velocidade mestre (modulador §1.3): o
/// mestre multiplica a quantidade de TODOS os operadores.
GlitchState glitchState({
  required double master,
  required double tau,
  required double intervalSec,
  required int seed,
  double slide = 0,
  double scaleAmt = 0,
  double colorAmt = 0,
  double lightAmt = 0,
  double blurAmt = 0,
  double rgbAmt = 0,
}) {
  if (master <= 0 || intervalSec <= 0) return GlitchState.none;

  (bool, double) op(int channel, double amount, double intervalMul) {
    if (amount <= 0) return (false, 0);
    final slot = (tau / (intervalSec * intervalMul)).floor();
    final p = (amount * master).clamp(0.0, 1.0) * 0.55;
    if (fxHash01(seed, channel, slot) >= p) return (false, 0);
    return (true, fxHash01(seed, channel + 31, slot) * 2 - 1);
  }

  var dx = 0.0, dy = 0.0, scale = 1.0;
  var blurSigma = 0.0, hueDeg = 0.0, brightness = 0.0, rgbSep = 0.0;

  final (slideOn, slideV) = op(1, slide, 1.0);
  if (slideOn) {
    dx = slideV * 200 * master;
    dy = (fxHash01(seed, 71, (tau / intervalSec).floor()) * 2 - 1) *
        46 *
        master;
    rgbSep = rgbAmt.clamp(0, 1) * 26 * master;
  }
  final (scOn, scV) = op(2, scaleAmt, 1.35);
  if (scOn) scale = 1 + scV * 0.35 * master;

  final (huOn, huV) = op(3, colorAmt, 0.8);
  if (huOn) hueDeg = huV * 180 * master;

  final (liOn, liV) = op(4, lightAmt, 1.1);
  if (liOn) brightness = liV.abs() * 0.85 * master;

  final (blOn, blV) = op(5, blurAmt, 1.6);
  if (blOn) blurSigma = blV.abs() * 14 * master;

  return GlitchState(
    dx: dx,
    dy: dy,
    scale: scale,
    blurSigma: blurSigma,
    hueDeg: hueDeg,
    brightness: brightness,
    rgbSep: rgbSep,
  );
}

/// Matriz de rotacao de matiz (para o operador Cor do glitch).
List<double> hueRotateMatrix(double degrees) {
  final rad = degrees * math.pi / 180;
  final c = math.cos(rad);
  final s = math.sin(rad);
  // Combinacao classica luminancia-preservada.
  return <double>[
    0.213 + c * 0.787 - s * 0.213,
    0.715 - c * 0.715 - s * 0.715,
    0.072 - c * 0.072 + s * 0.928,
    0, 0,
    0.213 - c * 0.213 + s * 0.143,
    0.715 + c * 0.285 + s * 0.140,
    0.072 - c * 0.072 - s * 0.283,
    0, 0,
    0.213 - c * 0.213 - s * 0.787,
    0.715 - c * 0.715 + s * 0.715,
    0.072 + c * 0.928 + s * 0.072,
    0, 0,
    0, 0, 0, 1, 0,
  ];
}
