import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/element3d.dart';
import '../../domain/layer.dart';

/// Pintor de Elemento 3D: rotaciona os VERTICES no espaco (X depois Y —
/// a mesma ordem da matematica de orbita do app), projeta com a focal
/// padrao (1200) e desenha as faces do fundo para a frente (algoritmo do
/// pintor) com sombreamento lambertiano. O Rz e aplicado pelo canvas,
/// como nas particulas — girar em torno do eixo de visao equivale a
/// girar a imagem projetada.
class Element3DPainter extends CustomPainter {
  Element3DPainter({
    required this.layer,
    this.rotXDeg = 0,
    this.rotYDeg = 0,
  });

  final Element3DLayer layer;
  final double rotXDeg;
  final double rotYDeg;

  static const double _focal = 1200;

  @override
  void paint(Canvas canvas, Size size) {
    final mesh = element3DMesh(layer.kind);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final s = layer.size;
    final rx = rotXDeg * math.pi / 180;
    final ry = rotYDeg * math.pi / 180;
    final cxr = math.cos(rx), sxr = math.sin(rx);
    final cyr = math.cos(ry), syr = math.sin(ry);

    // Rotaciona e escala todos os vertices uma vez.
    final n = mesh.verts.length;
    final wx = List<double>.filled(n, 0);
    final wy = List<double>.filled(n, 0);
    final wz = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final v = mesh.verts[i];
      final vx = v[0] * s;
      var vy = v[1] * s;
      var vz = v[2] * s;
      final y1 = vy * cxr - vz * sxr;
      final z1 = vy * sxr + vz * cxr;
      final x1 = vx * cyr + z1 * syr;
      final z2 = -vx * syr + z1 * cyr;
      wx[i] = x1;
      wy[i] = y1;
      wz[i] = z2;
    }

    // Luz fixa vinda de cima/esquerda/frente (normalizada).
    const lx = -0.37, ly = -0.55, lz = -0.75;

    final order = <(double, int)>[];
    for (var f = 0; f < mesh.faces.length; f++) {
      var depth = 0.0;
      for (final i in mesh.faces[f]) {
        depth += wz[i];
      }
      order.add((depth / mesh.faces[f].length, f));
    }
    // Fundo primeiro: z maior = mais longe (persp = f/(f+z)).
    order.sort((a, b) => b.$1.compareTo(a.$1));

    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    final base = layer.color;
    final edgeColor = Color.lerp(base, Colors.black, 0.55)!;

    for (final (_, f) in order) {
      final face = mesh.faces[f];
      // Normal por Newell (robusto para poligonos de qualquer lado).
      var nx = 0.0, ny = 0.0, nz = 0.0;
      for (var i = 0; i < face.length; i++) {
        final a = face[i];
        final b = face[(i + 1) % face.length];
        nx += (wy[a] - wy[b]) * (wz[a] + wz[b]);
        ny += (wz[a] - wz[b]) * (wx[a] + wx[b]);
        nz += (wx[a] - wx[b]) * (wy[a] + wy[b]);
      }
      final len = math.sqrt(nx * nx + ny * ny + nz * nz);
      double shade = 0.65;
      if (len > 1e-9) {
        final dot = (nx * lx + ny * ly + nz * lz) / len;
        shade = 0.34 + 0.66 * dot.abs();
      }

      final path = Path();
      for (var i = 0; i < face.length; i++) {
        final v = face[i];
        final persp = _focal / (_focal + wz[v]).clamp(60.0, double.infinity);
        final px = cx + wx[v] * persp;
        final py = cy + wy[v] * persp;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();

      fill.color = Color.lerp(Colors.black, base, shade)!;
      canvas.drawPath(path, fill);
      if (layer.edges) {
        stroke.color = edgeColor;
        canvas.drawPath(path, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(Element3DPainter old) =>
      old.layer != layer ||
      old.rotXDeg != rotXDeg ||
      old.rotYDeg != rotYDeg;
}
