import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../../domain/layer.dart';

/// Pinta o sistema de particulas em ESPACO 3D de verdade (estilo CC
/// Particle World): cada particula vive em (x, y, z) no mundo, com
/// velocidade 3D; a rotacao do sistema (da camada ou herdada do nulo 3D)
/// gira a NUVEM inteira no espaco — nao inclina o canvas como um cartao.
/// Cada particula e projetada em perspectiva individualmente (posicao E
/// tamanho convergem pro ponto de fuga) e desenhada em ordem de
/// profundidade (longe primeiro).
///
/// Simulacao PURA: cada particula e funcao de (seed, indice, tempo) —
/// scrub para frente/tras da o mesmo frame, nada acumula estado (mesmo
/// invariante I1 do motor de texto).
class ParticlesPainter extends CustomPainter {
  const ParticlesPainter({
    required this.layer,
    required this.time,
    this.rotXDeg = 0,
    this.rotYDeg = 0,
    this.rotZDeg = 0,
  });

  final ParticlesLayer layer;
  final Duration time;

  /// Rotacao do SISTEMA (camada + delta herdado do pai 3D), em graus.
  final double rotXDeg;
  final double rotYDeg;
  final double rotZDeg;

  static const double _focal = 1200;

  /// xorshift32 de (seed, i, canal) -> [0,1).
  double _rand(int i, int channel) {
    var s = (layer.seed * 0x9E3779B9 ^ (i + 1) * 0x85EBCA6B ^
            (channel + 1) * 0xC2B2AE35) &
        0xFFFFFFFF;
    s ^= (s << 13) & 0xFFFFFFFF;
    s ^= s >> 17;
    s ^= (s << 5) & 0xFFFFFFFF;
    return (s & 0xFFFFFF) / 0x1000000;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final life = math.max(0.2, layer.lifetimeMs / 1000.0);
    final tSec = time.inMicroseconds / 1e6;

    final rx = rotXDeg * math.pi / 180;
    final ry = rotYDeg * math.pi / 180;
    final rz = rotZDeg * math.pi / 180;
    final cxr = math.cos(rx), sxr = math.sin(rx);
    final cyr = math.cos(ry), syr = math.sin(ry);
    final czr = math.cos(rz), szr = math.sin(rz);

    // 1a passada: simula + projeta; 2a: desenha do fundo pra frente.
    final drawList = <_Proj>[];

    for (var i = 0; i < layer.count; i++) {
      // Emissor em REGIME CONTINUO (pre-roll): o campo ja nasce cheio no
      // frame 0, como se o sistema rodasse desde sempre; cada particula
      // "renasce" ao fim da vida, com fase propria.
      final phase = _rand(i, 0) * life;
      var age = (tSec - phase) % life;
      if (age < 0) age += life;
      final u = age / life; // 0..1 da vida

      // Posicao de nascimento: caixa 3D do emissor (area X/Y + fundo Z).
      final bx = (_rand(i, 6) - 0.5) * layer.emitW;
      final by = (_rand(i, 7) - 0.5) * layer.emitH;
      final bz = (_rand(i, 3) - 0.5) * layer.depth;

      // Velocidade 3D: cone no plano XY + componente em Z (a particula
      // tambem viaja em profundidade, como no CC Particle World).
      final dir = (layer.directionDeg +
              (_rand(i, 1) - 0.5) * layer.spreadDeg) *
          math.pi /
          180;
      final v0 = layer.speed * (0.5 + _rand(i, 2));
      final vz = (_rand(i, 10) - 0.5) * layer.speed;

      // Posicao no MUNDO (relativa ao emissor).
      var wx = bx + math.cos(dir) * v0 * age;
      var wy =
          by + math.sin(dir) * v0 * age + 0.5 * layer.gravity * age * age;
      var wz = bz + vz * age;

      // Rotacao do sistema: v' = Rz * Ry * Rx * v (nuvem gira no espaco).
      final y1 = wy * cxr - wz * sxr;
      final z1 = wy * sxr + wz * cxr;
      final x1 = wx * cyr + z1 * syr;
      final z2 = -wx * syr + z1 * cyr;
      wx = x1 * czr - y1 * szr;
      wy = x1 * szr + y1 * czr;
      wz = z2;

      // Projecao em perspectiva POR PARTICULA: posicao e tamanho
      // convergem pro ponto de fuga; atras da camera nao desenha.
      final denom = _focal + wz;
      if (denom < 60) continue;
      final proj = (_focal / denom).clamp(0.02, 6.0);
      final p = center + Offset(wx, wy) * proj;

      // Fade: entra rapido, sai suave.
      final fadeIn = (u / 0.08).clamp(0.0, 1.0);
      final fadeOut = ((1 - u) / 0.35).clamp(0.0, 1.0);
      var alpha = fadeIn * fadeOut;

      // Cintilar: oscila com frequencia e fase proprias (deterministico).
      if (layer.twinkle) {
        final tw = 0.5 +
            0.5 *
                math.sin((tSec * (0.7 + _rand(i, 8) * 1.5) + _rand(i, 9)) *
                    2 *
                    math.pi);
        alpha *= 0.30 + 0.70 * tw;
      }
      if (alpha <= 0.01) continue;

      final r = layer.size * (0.45 + 0.9 * _rand(i, 4)) * proj * 0.5;
      if (r < 0.3) continue;

      drawList.add(_Proj(
        z: wz,
        pos: p,
        radius: r,
        alpha: alpha,
        variant: _rand(i, 5),
      ));
    }

    // Longe primeiro: perto cobre longe (ordem 3D correta).
    drawList.sort((a, b) => b.z.compareTo(a.z));

    final paintDot = Paint()..style = PaintingStyle.fill;
    final halo = Paint()..style = PaintingStyle.fill;
    for (final d in drawList) {
      final color =
          layer.color.withValues(alpha: layer.color.a * d.alpha);
      paintDot.color = color;

      // Halo suave atras da o "brilho" do sparkle sem blur caro.
      halo.color = color.withValues(alpha: color.a * 0.22);
      canvas.drawCircle(d.pos, d.radius * 1.8, halo);

      if (layer.star) {
        _drawSparkle(canvas, d.pos, d.radius, paintDot, d.variant);
      } else {
        canvas.drawCircle(d.pos, d.radius, paintDot);
      }
    }
  }

  /// Cruz de 4 pontas alongada (sparkle de lente): dois losangos finos +
  /// nucleo claro, como nas referencias de edicao.
  void _drawSparkle(
      Canvas canvas, Offset c, double r, Paint paint, double variant) {
    final len = r * (2.4 + variant * 1.6);
    final lenH = len * 0.72;
    final w = r * 0.40;
    final path = Path()
      ..moveTo(c.dx, c.dy - len)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + len)
      ..lineTo(c.dx - w, c.dy)
      ..close()
      ..moveTo(c.dx - lenH, c.dy)
      ..lineTo(c.dx, c.dy - w)
      ..lineTo(c.dx + lenH, c.dy)
      ..lineTo(c.dx, c.dy + w)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      c,
      w * 0.95,
      Paint()
        ..color = const Color(0xFFFFFFFF)
            .withValues(alpha: paint.color.a * 0.85),
    );
  }

  @override
  bool shouldRepaint(ParticlesPainter old) =>
      old.layer != layer ||
      old.time != time ||
      old.rotXDeg != rotXDeg ||
      old.rotYDeg != rotYDeg ||
      old.rotZDeg != rotZDeg;
}

class _Proj {
  const _Proj({
    required this.z,
    required this.pos,
    required this.radius,
    required this.alpha,
    required this.variant,
  });

  final double z;
  final Offset pos;
  final double radius;
  final double alpha;
  final double variant;
}

/// Gizmo do objeto nulo: quadrado tracejado com X — visivel so no editor.
class NullGizmoPainter extends CustomPainter {
  const NullGizmoPainter({this.color = const Color(0xFF9F8CFF)});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.9);

    void dashedLine(Offset a, Offset b) {
      const dash = 14.0, gap = 9.0;
      final delta = b - a;
      final len = delta.distance;
      final dir = delta / len;
      var d = 0.0;
      while (d < len) {
        final e = math.min(d + dash, len);
        canvas.drawLine(a + dir * d, a + dir * e, stroke);
        d = e + gap;
      }
    }

    dashedLine(rect.topLeft, rect.topRight);
    dashedLine(rect.topRight, rect.bottomRight);
    dashedLine(rect.bottomRight, rect.bottomLeft);
    dashedLine(rect.bottomLeft, rect.topLeft);

    final cross = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = color.withValues(alpha: 0.65);
    final c = rect.center;
    canvas.drawLine(c - const Offset(26, 0), c + const Offset(26, 0), cross);
    canvas.drawLine(c - const Offset(0, 26), c + const Offset(0, 26), cross);
  }

  @override
  bool shouldRepaint(NullGizmoPainter old) => old.color != color;
}
