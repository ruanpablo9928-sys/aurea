import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// EFEITOS DO LOTE 2.
///
/// Vários deles precisam da camada COMO IMAGEM para funcionar de
/// verdade — deslocar turbulento, entortar, ordenar pixels e semear nao
/// sao filtros de cor, sao redistribuicao de pixels. O [SnapshotWidget]
/// rasteriza a subarvore uma vez por quadro e entrega uma `ui.Image`, e
/// dai para frente e malha e `drawVertices`, que a GPU faz de graca.

// ------------------------------------------------------------ ruido

/// Ruido de valor deterministico: funcao pura de (x, y, semente).
double fxNoise(double x, double y, int seed) {
  int h = seed * 374761393;
  h += x.floor() * 668265263;
  h ^= y.floor() * 2246822519;
  h = (h ^ (h >> 13)) * 1274126177;
  return ((h ^ (h >> 16)) & 0x7fffffff) / 0x7fffffff;
}

double _smooth(double t) => t * t * (3 - 2 * t);

/// Ruido interpolado (continuo no espaco).
double fxValueNoise(double x, double y, int seed) {
  final xi = x.floorToDouble(), yi = y.floorToDouble();
  final xf = x - xi, yf = y - yi;
  final a = fxNoise(xi, yi, seed);
  final b = fxNoise(xi + 1, yi, seed);
  final c = fxNoise(xi, yi + 1, seed);
  final d = fxNoise(xi + 1, yi + 1, seed);
  final u = _smooth(xf), v = _smooth(yf);
  return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
}

/// Ruido fractal (varias oitavas) — a base do deslocar turbulento.
double fxFractal(double x, double y, int seed, int octaves) {
  var amp = 1.0, freq = 1.0, sum = 0.0, norm = 0.0;
  for (var i = 0; i < octaves; i++) {
    sum += fxValueNoise(x * freq, y * freq, seed + i * 101) * amp;
    norm += amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return norm <= 0 ? 0 : sum / norm;
}

// ------------------------------------------------- base de snapshot

/// Envelope que rasteriza o filho e deixa um pintor trabalhar em cima
/// da imagem.
class FxSnapshot extends StatefulWidget {
  const FxSnapshot({
    super.key,
    required this.painter,
    required this.child,
    this.mode = SnapshotMode.permissive,
  });

  final SnapshotPainter painter;
  final Widget child;

  /// PERMISSIVO, e nao FORCADO.
  ///
  /// O modo forcado tira a foto mesmo quando ha uma TEXTURA de plataforma
  /// embaixo — e a textura simplesmente nao aparece na foto. O video sai
  /// PRETO. Era o que apagava o video do preview inteiro, porque o passe
  /// de dithering embrulha a composicao toda.
  ///
  /// No modo permissivo, havendo textura, o Flutter desenha o filho
  /// direto e o efeito daquele quadro nao acontece. Perder o dithering e
  /// pequeno; perder o video e o aplicativo nao funcionar.
  final SnapshotMode mode;

  @override
  State<FxSnapshot> createState() => _FxSnapshotState();
}

class _FxSnapshotState extends State<FxSnapshot> {
  // Ligado o tempo todo: o efeito PRECISA da imagem para existir.
  final SnapshotController _controller =
      SnapshotController(allowSnapshotting: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SnapshotWidget(
        controller: _controller,
        mode: widget.mode,
        painter: widget.painter,
        child: widget.child,
      );
}

/// Base comum: quando o snapshot nao esta disponivel, pinta o filho
/// normalmente em vez de sumir com ele.
abstract class _FxPainter extends SnapshotPainter {
  @override
  void paint(PaintingContext context, Offset offset, Size size,
      PaintingContextCallback painter) {
    painter(context, offset);
  }
}

Rect _dst(Offset offset, Size size) => offset & size;

/// Shader que mapeia a imagem no retangulo de destino.
ui.ImageShader _imageShader(ui.Image image, Offset offset, Size size) {
  final m = Matrix4.identity()
    ..translateByDouble(offset.dx, offset.dy, 0, 1)
    ..scaleByDouble(
        size.width / image.width, size.height / image.height, 1, 1);
  return ui.ImageShader(
      image, TileMode.clamp, TileMode.clamp, m.storage);
}

/// Desenha uma malha deformada: para cada no da grade, [displace]
/// devolve o deslocamento em pixels.
void _drawMesh(
  Canvas canvas,
  ui.Image image,
  Offset offset,
  Size size, {
  required int cols,
  required int rows,
  required Offset Function(double u, double v) displace,
  bool antiAlias = true,
}) {
  final nx = cols + 1, ny = rows + 1;
  final positions = <double>[];
  final texcoords = <double>[];
  final indices = <int>[];

  for (var j = 0; j < ny; j++) {
    for (var i = 0; i < nx; i++) {
      final u = i / cols, v = j / rows;
      final tx = u * size.width, ty = v * size.height;
      final d = displace(u, v);
      positions.add(offset.dx + tx + d.dx);
      positions.add(offset.dy + ty + d.dy);
      texcoords.add(offset.dx + tx);
      texcoords.add(offset.dy + ty);
    }
  }
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      final a = j * nx + i, b = a + 1, c = a + nx, d = c + 1;
      indices..addAll([a, b, c])..addAll([b, d, c]);
    }
  }

  canvas.drawVertices(
    ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(positions),
      textureCoordinates: Float32List.fromList(texcoords),
      indices: Uint16List.fromList(indices),
    ),
    BlendMode.srcOver,
    Paint()
      ..isAntiAlias = antiAlias
      ..shader = _imageShader(image, offset, size)
      ..filterQuality = FilterQuality.low,
  );
}

// --------------------------------------------- deslocar turbulento

/// DESLOCAR TURBULENTO: cada ponto da malha anda conforme um ruido
/// fractal. Evoluir o ruido no tempo e o que faz o liquido "viver".
class TurbulentDisplacePainter extends _FxPainter {
  TurbulentDisplacePainter({
    required this.amount,
    required this.scale,
    required this.complexity,
    required this.evolution,
    required this.seed,
  });

  final double amount;
  final double scale;
  final double complexity;
  final double evolution;
  final int seed;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    if (amount.abs() < 0.5 || size.isEmpty) {
      context.canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(),
              image.height.toDouble()),
          _dst(offset, size),
          Paint()..filterQuality = FilterQuality.low);
      return;
    }
    final oct = complexity.round().clamp(1, 5);
    final s = math.max(4.0, scale);
    final ev = evolution / 60.0;
    final cols = (size.width / 18).clamp(8, 40).round();
    final rows = (size.height / 18).clamp(8, 40).round();

    _drawMesh(
      context.canvas,
      image,
      offset,
      size,
      cols: cols,
      rows: rows,
      displace: (u, v) {
        final x = u * size.width / s + ev;
        final y = v * size.height / s + ev;
        final dx = (fxFractal(x, y, seed, oct) - 0.5) * 2;
        final dy = (fxFractal(x + 37.7, y - 11.3, seed + 5, oct) - 0.5) * 2;
        return Offset(dx * amount, dy * amount);
      },
    );
  }

  @override
  bool shouldRepaint(covariant TurbulentDisplacePainter old) =>
      old.amount != amount ||
      old.scale != scale ||
      old.complexity != complexity ||
      old.evolution != evolution ||
      old.seed != seed;
}

// ------------------------------------------------------- entortar

/// ENTORTAR: a malha ganha um arco. Curvatura muda o quanto o arco e
/// concentrado no meio.
class BendPainter extends _FxPainter {
  BendPainter({
    required this.amount,
    required this.vertical,
    required this.curvature,
    required this.anchor,
  });

  final double amount;
  final bool vertical;
  final double curvature;
  final double anchor;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    if (amount.abs() < 0.5 || size.isEmpty) {
      context.canvas.drawImageRect(
          image,
          Rect.fromLTWH(
              0, 0, image.width.toDouble(), image.height.toDouble()),
          _dst(offset, size),
          Paint()..filterQuality = FilterQuality.low);
      return;
    }
    final k = curvature.clamp(0.2, 4.0);
    _drawMesh(
      context.canvas,
      image,
      offset,
      size,
      cols: vertical ? 12 : 28,
      rows: vertical ? 28 : 12,
      displace: (u, v) {
        // Perfil de arco: 0 nas pontas, 1 na ancora.
        final t = vertical ? v : u;
        final d = (t - anchor).abs() / math.max(1e-6, math.max(anchor, 1 - anchor));
        final w = math.pow(1 - d.clamp(0.0, 1.0), k).toDouble();
        return vertical
            ? Offset(amount * w, 0)
            : Offset(0, amount * w);
      },
    );
  }

  @override
  bool shouldRepaint(covariant BendPainter old) =>
      old.amount != amount ||
      old.vertical != vertical ||
      old.curvature != curvature ||
      old.anchor != anchor;
}

// -------------------------------------------------- ordenar pixels

/// ORDENAR PIXELS: as faixas mais claras que o limiar sao esticadas na
/// direcao escolhida, que e o rastro que o pixel sorting produz.
class PixelSortPainter extends _FxPainter {
  PixelSortPainter({
    required this.threshold,
    required this.length,
    required this.direction,
    required this.density,
    required this.seed,
  });

  /// 0 baixo, 1 cima, 2 direita, 3 esquerda.
  final int direction;
  final double threshold;
  final double length;
  final double density;
  final int seed;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, src, _dst(offset, size),
        Paint()..filterQuality = FilterQuality.low);
    if (length < 1 || size.isEmpty) return;

    final vertical = direction <= 1;
    final negative = direction == 1 || direction == 3;
    final span = vertical ? size.height : size.width;
    final across = vertical ? size.width : size.height;

    // Uma faixa a cada N pixels: densidade alta = mais faixas.
    final step = (10 - density.clamp(0.05, 1.0) * 8).clamp(2.0, 10.0);
    final n = (across / step).floor().clamp(1, 400);
    final sx = image.width / size.width;
    final sy = image.height / size.height;

    canvas.save();
    canvas.clipRect(_dst(offset, size));
    for (var i = 0; i < n; i++) {
      final r = fxNoise(i.toDouble(), 0, seed);
      if (r < threshold) continue;
      final r2 = fxNoise(i.toDouble(), 1, seed + 31);
      final start = r2 * span * 0.8;
      final len = length * (0.35 + r * 0.65);

      if (vertical) {
        final x = i * step;
        // Uma fatia fina da imagem, esticada ao longo do eixo.
        final srcSlice = Rect.fromLTWH(
            x * sx, start * sy, math.max(1, step * sx), math.max(1, sy));
        final dstSlice = Rect.fromLTWH(
          offset.dx + x,
          offset.dy + (negative ? start - len : start),
          step,
          len,
        );
        canvas.drawImageRect(image, srcSlice, dstSlice,
            Paint()..filterQuality = FilterQuality.none);
      } else {
        final y = i * step;
        final srcSlice = Rect.fromLTWH(
            start * sx, y * sy, math.max(1, sx), math.max(1, step * sy));
        final dstSlice = Rect.fromLTWH(
          offset.dx + (negative ? start - len : start),
          offset.dy + y,
          len,
          step,
        );
        canvas.drawImageRect(image, srcSlice, dstSlice,
            Paint()..filterQuality = FilterQuality.none);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PixelSortPainter old) =>
      old.threshold != threshold ||
      old.length != length ||
      old.direction != direction ||
      old.density != density ||
      old.seed != seed;
}

// -------------------------------------------------------- CC Semear

/// CC SEMEAR: a imagem vira graos e os graos se espalham. Transferencia
/// controla quanto do original ainda aparece por baixo.
class ScatterizePainter extends _FxPainter {
  ScatterizePainter({
    required this.spread,
    required this.grain,
    required this.rotation,
    required this.transfer,
    required this.gravity,
    required this.seed,
  });

  final double spread;
  final double grain;
  final double rotation;
  final double transfer;
  final double gravity;
  final int seed;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    if (transfer < 0.999) {
      canvas.drawImageRect(
        image,
        src,
        _dst(offset, size),
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Colors.white
              .withValues(alpha: (1 - transfer).clamp(0.0, 1.0)),
      );
    }
    if (spread < 0.5 || size.isEmpty) {
      if (transfer >= 0.999) {
        canvas.drawImageRect(image, src, _dst(offset, size),
            Paint()..filterQuality = FilterQuality.low);
      }
      return;
    }

    final g = grain.clamp(4.0, 200.0);
    final cols = (size.width / g).ceil().clamp(1, 90);
    final rows = (size.height / g).ceil().clamp(1, 90);
    final sx = image.width / size.width;
    final sy = image.height / size.height;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..color = Colors.white.withValues(alpha: transfer.clamp(0.0, 1.0));

    canvas.save();
    canvas.clipRect(_dst(offset, size));
    for (var j = 0; j < rows; j++) {
      for (var i = 0; i < cols; i++) {
        final n1 = fxNoise(i.toDouble(), j.toDouble(), seed);
        final n2 = fxNoise(i.toDouble(), j.toDouble(), seed + 77);
        final dx = (n1 - 0.5) * 2 * spread;
        final dy = (n2 - 0.5) * 2 * spread + gravity * spread * n1;
        final rot = (n1 - 0.5) * 2 * rotation * math.pi / 180;

        final cellW = size.width / cols;
        final cellH = size.height / rows;
        final s = Rect.fromLTWH(
            i * cellW * sx, j * cellH * sy, cellW * sx, cellH * sy);
        final cx = offset.dx + i * cellW + cellW / 2 + dx;
        final cy = offset.dy + j * cellH + cellH / 2 + dy;

        canvas.save();
        canvas.translate(cx, cy);
        if (rot != 0) canvas.rotate(rot);
        canvas.drawImageRect(
          image,
          s,
          Rect.fromCenter(
              center: Offset.zero, width: cellW, height: cellH),
          paint,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScatterizePainter old) =>
      old.spread != spread ||
      old.grain != grain ||
      old.rotation != rotation ||
      old.transfer != transfer ||
      old.gravity != gravity ||
      old.seed != seed;
}

// ----------------------------------------------------- motion tile

/// MOSAICO DE MOVIMENTO: repete a camada num tabuleiro, com espelho
/// opcional nas bordas — o jeito de encher a tela com um elemento so.
class MotionTilePainter extends _FxPainter {
  MotionTilePainter({
    required this.tileW,
    required this.tileH,
    required this.outW,
    required this.outH,
    required this.offsetX,
    required this.offsetY,
    required this.mirror,
    required this.fade,
  });

  final double tileW;
  final double tileH;
  final double outW;
  final double outH;
  final double offsetX;
  final double offsetY;
  final bool mirror;
  final double fade;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    if (size.isEmpty) return;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());

    final tw = size.width * (tileW / 100).clamp(0.05, 3.0);
    final th = size.height * (tileH / 100).clamp(0.05, 3.0);
    final ow = size.width * (outW / 100).clamp(1.0, 6.0);
    final oh = size.height * (outH / 100).clamp(1.0, 6.0);

    final cx = offset.dx + size.width / 2;
    final cy = offset.dy + size.height / 2;
    final area = Rect.fromCenter(
        center: Offset(cx, cy), width: ow, height: oh);

    final nx = (ow / tw).ceil() + 2;
    final ny = (oh / th).ceil() + 2;
    final ox = offsetX / 100 * tw;
    final oy = offsetY / 100 * th;

    canvas.save();
    canvas.clipRect(_dst(offset, size));
    for (var j = -ny ~/ 2; j <= ny ~/ 2; j++) {
      for (var i = -nx ~/ 2; i <= nx ~/ 2; i++) {
        final x = cx - tw / 2 + i * tw + ox;
        final y = cy - th / 2 + j * th + oy;
        final flipX = mirror && i.isOdd;
        final flipY = mirror && j.isOdd;

        // Desvanecer pelas bordas do tabuleiro.
        var alpha = 1.0;
        if (fade > 0.001) {
          final d = math.max(
            (x + tw / 2 - cx).abs() / (area.width / 2),
            (y + th / 2 - cy).abs() / (area.height / 2),
          );
          alpha = (1 - d.clamp(0.0, 1.0) * fade).clamp(0.0, 1.0);
        }
        if (alpha <= 0.004) continue;

        canvas.save();
        canvas.translate(x + tw / 2, y + th / 2);
        canvas.scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0);
        canvas.drawImageRect(
          image,
          src,
          Rect.fromCenter(center: Offset.zero, width: tw, height: th),
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = Colors.white.withValues(alpha: alpha),
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MotionTilePainter old) =>
      old.tileW != tileW ||
      old.tileH != tileH ||
      old.outW != outW ||
      old.outH != outH ||
      old.offsetX != offsetX ||
      old.offsetY != offsetY ||
      old.mirror != mirror ||
      old.fade != fade;
}

// -------------------------------------------------------- CC Split

/// CC SPLIT: a imagem se rasga em duas metades que se afastam.
class SplitPainter extends _FxPainter {
  SplitPainter({
    required this.split,
    required this.angleDeg,
    required this.center,
    required this.softness,
  });

  final double split;
  final double angleDeg;
  final double center;
  final double softness;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    if (split.abs() < 0.5 || size.isEmpty) {
      canvas.drawImageRect(image, src, _dst(offset, size),
          Paint()..filterQuality = FilterQuality.low);
      return;
    }

    final rad = angleDeg * math.pi / 180;
    final dir = Offset(math.cos(rad), math.sin(rad));
    // Normal da linha de corte: e por ela que as metades se afastam.
    final nrm = Offset(-dir.dy, dir.dx);
    final cx = offset.dx + size.width / 2;
    final cy = offset.dy + size.height / 2;
    final cut = Offset(
      cx + nrm.dx * (center - 0.5) * size.height,
      cy + nrm.dy * (center - 0.5) * size.height,
    );

    final big = size.longestSide * 2;
    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = true;

    for (final side in [1.0, -1.0]) {
      canvas.save();
      // Meio plano: retangulo enorme girado sobre a linha de corte.
      final path = Path()
        ..moveTo(cut.dx - dir.dx * big, cut.dy - dir.dy * big)
        ..lineTo(cut.dx + dir.dx * big, cut.dy + dir.dy * big)
        ..lineTo(cut.dx + dir.dx * big + nrm.dx * big * side,
            cut.dy + dir.dy * big + nrm.dy * big * side)
        ..lineTo(cut.dx - dir.dx * big + nrm.dx * big * side,
            cut.dy - dir.dy * big + nrm.dy * big * side)
        ..close();
      canvas.clipPath(path);
      canvas.translate(nrm.dx * split * side, nrm.dy * split * side);
      if (softness > 0.01) {
        paint.imageFilter = ui.ImageFilter.blur(
            sigmaX: softness * 8, sigmaY: softness * 8,
            tileMode: TileMode.decal);
      }
      canvas.drawImageRect(image, src, _dst(offset, size), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant SplitPainter old) =>
      old.split != split ||
      old.angleDeg != angleDeg ||
      old.center != center ||
      old.softness != softness;
}

// -------------------------------------------------- nitidez (USM)

/// MASCARA DE NITIDEZ: resultado = (1+q)*original − q*borrado. E a
/// definicao classica, feita com duas passadas na mesma imagem.
class UnsharpMaskPainter extends _FxPainter {
  UnsharpMaskPainter({
    required this.amount,
    required this.radius,
    required this.threshold,
  });

  final double amount;
  final double radius;
  final double threshold;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = _dst(offset, size);
    final a = amount.clamp(0.0, 3.0);
    if (a < 0.01) {
      canvas.drawImageRect(image, src, dst,
          Paint()..filterQuality = FilterQuality.low);
      return;
    }

    canvas.saveLayer(dst, Paint());
    // (1+q) * original
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.low
        ..colorFilter = ColorFilter.matrix(_gain(1 + a)),
    );
    // menos q * borrado
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()
        ..filterQuality = FilterQuality.low
        ..imageFilter = ui.ImageFilter.blur(
            sigmaX: radius, sigmaY: radius, tileMode: TileMode.decal)
        ..colorFilter = ColorFilter.matrix(_gain(a * (1 - threshold)))
        ..blendMode = BlendMode.difference,
    );
    canvas.restore();
  }

  static List<double> _gain(double g) => <double>[
        g, 0, 0, 0, 0, //
        0, g, 0, 0, 0, //
        0, 0, g, 0, 0, //
        0, 0, 0, 1, 0,
      ];

  @override
  bool shouldRepaint(covariant UnsharpMaskPainter old) =>
      old.amount != amount ||
      old.radius != radius ||
      old.threshold != threshold;
}

// ----------------------------------------------------- sobreposicoes

/// VHS: linhas de varredura, sangramento de cor, tremor horizontal e
/// ruido de fita.
class VhsPainter extends CustomPainter {
  const VhsPainter({
    required this.intensity,
    required this.lines,
    required this.noise,
    required this.time,
    required this.seed,
  });

  final double intensity;
  final double lines;
  final double noise;
  final Duration time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.inMilliseconds / 1000.0;

    // Linhas de varredura.
    if (lines > 0.01) {
      final paint = Paint()
        ..color = Colors.black.withValues(alpha: 0.10 * lines * intensity);
      for (var y = 0.0; y < size.height; y += 3) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.4), paint);
      }
    }

    // Faixa de cabecote descendo: a marca registrada da fita.
    final bandY =
        ((t * 0.22) % 1.0) * (size.height + 160) - 80;
    canvas.drawRect(
      Rect.fromLTWH(0, bandY, size.width, 46),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, bandY),
          Offset(0, bandY + 46),
          [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.16 * intensity),
            Colors.white.withValues(alpha: 0),
          ],
          [0, 0.5, 1],
        ),
    );

    // Ruido de fita em riscos curtos.
    if (noise > 0.01) {
      final n = (noise * 90).round();
      final frame = (t * 24).floor();
      final paint = Paint();
      for (var i = 0; i < n; i++) {
        final r1 = fxNoise(i.toDouble(), frame.toDouble(), seed);
        final r2 = fxNoise(i.toDouble(), frame.toDouble() + 1, seed + 9);
        final r3 = fxNoise(i.toDouble(), frame.toDouble() + 2, seed + 19);
        paint.color =
            Colors.white.withValues(alpha: 0.05 + r3 * 0.30 * noise);
        canvas.drawRect(
          Rect.fromLTWH(r1 * size.width, r2 * size.height,
              4 + r3 * 60, 1 + r3 * 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(VhsPainter old) =>
      old.intensity != intensity ||
      old.lines != lines ||
      old.noise != noise ||
      old.time != time ||
      old.seed != seed;
}

/// FILME DANIFICADO: poeira, riscos verticais, queimado nas bordas.
class FilmDamagePainter extends CustomPainter {
  const FilmDamagePainter({
    required this.dust,
    required this.scratches,
    required this.burn,
    required this.time,
    required this.seed,
  });

  final double dust;
  final double scratches;
  final double burn;
  final Duration time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // O quadro do filme troca a 16 fps: e o que da o ar de projetor.
    final frame = (time.inMilliseconds / 1000.0 * 16).floor();

    if (dust > 0.01) {
      final n = (dust * 60).round();
      final paint = Paint();
      for (var i = 0; i < n; i++) {
        final r1 = fxNoise(i.toDouble(), frame.toDouble(), seed);
        final r2 = fxNoise(i.toDouble(), frame.toDouble(), seed + 41);
        final r3 = fxNoise(i.toDouble(), frame.toDouble(), seed + 83);
        paint.color = (r3 > 0.5 ? Colors.black : Colors.white)
            .withValues(alpha: 0.20 + r3 * 0.45);
        canvas.drawCircle(
            Offset(r1 * size.width, r2 * size.height), 0.6 + r3 * 2.2,
            paint);
      }
    }

    if (scratches > 0.01) {
      final n = (scratches * 6).round() + 1;
      for (var i = 0; i < n; i++) {
        final r1 = fxNoise(i.toDouble(), (frame ~/ 3).toDouble(), seed + 7);
        final r2 = fxNoise(i.toDouble(), (frame ~/ 3).toDouble(), seed + 17);
        if (r2 < 0.45) continue;
        final x = r1 * size.width;
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 0.8 + r2 * 1.6, size.height),
          Paint()
            ..color = Colors.white
                .withValues(alpha: 0.10 + r2 * 0.22 * scratches),
        );
      }
    }

    if (burn > 0.01) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(size.width / 2, size.height / 2),
            size.longestSide * 0.62,
            [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55 * burn),
            ],
            [0.55, 1.0],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(FilmDamagePainter old) =>
      old.dust != dust ||
      old.scratches != scratches ||
      old.burn != burn ||
      old.time != time ||
      old.seed != seed;
}

/// GLITCHIFY: blocos deslocados na horizontal, com linhas de erro.
class GlitchifyPainter extends _FxPainter {
  GlitchifyPainter({
    required this.intensity,
    required this.blocks,
    required this.shift,
    required this.colorSplit,
    required this.lineNoise,
    required this.speed,
    required this.time,
    required this.seed,
  });

  final double intensity;
  final double blocks;
  final double shift;
  final double colorSplit;
  final double lineNoise;
  final double speed;
  final Duration time;
  final int seed;

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    final canvas = context.canvas;
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = _dst(offset, size);
    canvas.drawImageRect(image, src, dst,
        Paint()..filterQuality = FilterQuality.low);
    if (intensity < 0.01 || size.isEmpty) return;

    // O tique: o glitch nao e continuo, ele ACONTECE em instantes.
    final tick = (time.inMilliseconds / 1000.0 * speed).floor();
    final n = blocks.round().clamp(1, 40);
    final sy = image.height / size.height;

    canvas.save();
    canvas.clipRect(dst);
    for (var i = 0; i < n; i++) {
      final r = fxNoise(i.toDouble(), tick.toDouble(), seed);
      if (r > intensity) continue;
      final r2 = fxNoise(i.toDouble(), tick.toDouble(), seed + 53);
      final r3 = fxNoise(i.toDouble(), tick.toDouble(), seed + 97);

      final y = r2 * size.height;
      final h = (2 + r3 * size.height * 0.12).clamp(2.0, size.height);
      final dx = (r3 - 0.5) * 2 * shift;

      final sRect = Rect.fromLTWH(0, y * sy, image.width.toDouble(), h * sy);
      final dRect =
          Rect.fromLTWH(offset.dx + dx, offset.dy + y, size.width, h);

      if (colorSplit > 0.02) {
        // Cada bloco puxa um canal para um lado: o corte de cor.
        for (final ch in [0, 2]) {
          canvas.drawImageRect(
            image,
            sRect,
            dRect.translate(ch == 0 ? -colorSplit * 12 : colorSplit * 12, 0),
            Paint()
              ..filterQuality = FilterQuality.none
              ..blendMode = BlendMode.plus
              ..colorFilter = ColorFilter.matrix(_channel(ch)),
          );
        }
      }
      canvas.drawImageRect(image, sRect, dRect,
          Paint()..filterQuality = FilterQuality.none);
    }

    if (lineNoise > 0.01) {
      final paint = Paint();
      final lines = (lineNoise * 40).round();
      for (var i = 0; i < lines; i++) {
        final r = fxNoise(i.toDouble(), tick.toDouble(), seed + 211);
        paint.color = Colors.white.withValues(alpha: 0.06 + r * 0.22);
        canvas.drawRect(
          Rect.fromLTWH(offset.dx, offset.dy + r * size.height,
              size.width, 1 + r * 2),
          paint,
        );
      }
    }
    canvas.restore();
  }

  static List<double> _channel(int ch) => <double>[
        ch == 0 ? 1 : 0, 0, 0, 0, 0, //
        0, ch == 1 ? 1 : 0, 0, 0, 0, //
        0, 0, ch == 2 ? 1 : 0, 0, 0, //
        0, 0, 0, 1, 0,
      ];

  @override
  bool shouldRepaint(covariant GlitchifyPainter old) =>
      old.intensity != intensity ||
      old.blocks != blocks ||
      old.shift != shift ||
      old.colorSplit != colorSplit ||
      old.lineNoise != lineNoise ||
      old.speed != speed ||
      old.time != time ||
      old.seed != seed;
}

/// RASTREADOR DE BLOBS: os alvos de rastreio como elemento grafico —
/// caixas com cantos, mira e rotulo, andando devagar pelo quadro.
class BlobTrackerPainter extends CustomPainter {
  const BlobTrackerPainter({
    required this.count,
    required this.boxSize,
    required this.spread,
    required this.speed,
    required this.stroke,
    required this.cornersOnly,
    required this.color,
    required this.time,
    required this.seed,
  });

  final int count;
  final double boxSize;
  final double spread;
  final double speed;
  final double stroke;
  final bool cornersOnly;
  final Color color;
  final Duration time;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = time.inMilliseconds / 1000.0 * speed;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = color
      ..isAntiAlias = true;

    for (var i = 0; i < count; i++) {
      final fx = fxValueNoise(t + i * 13.7, i * 3.1, seed);
      final fy = fxValueNoise(t + i * 7.3 + 50, i * 5.9, seed + 31);
      final fs = fxNoise(i.toDouble(), 0, seed + 61);

      final cx = size.width * (0.5 + (fx - 0.5) * spread);
      final cy = size.height * (0.5 + (fy - 0.5) * spread);
      final w = boxSize * (0.6 + fs * 0.8);
      final h = w * (0.7 + fs * 0.6);
      final rect = Rect.fromCenter(
          center: Offset(cx, cy), width: w, height: h);

      if (cornersOnly) {
        final c = math.min(w, h) * 0.28;
        for (final corner in [
          [rect.topLeft, Offset(c, 0), Offset(0, c)],
          [rect.topRight, Offset(-c, 0), Offset(0, c)],
          [rect.bottomLeft, Offset(c, 0), Offset(0, -c)],
          [rect.bottomRight, Offset(-c, 0), Offset(0, -c)],
        ]) {
          final p = corner[0];
          canvas.drawLine(p, p + corner[1], paint);
          canvas.drawLine(p, p + corner[2], paint);
        }
      } else {
        canvas.drawRect(rect, paint);
      }

      // Mira no centro.
      final m = math.min(w, h) * 0.12;
      canvas.drawLine(Offset(cx - m, cy), Offset(cx + m, cy), paint);
      canvas.drawLine(Offset(cx, cy - m), Offset(cx, cy + m), paint);

      // Rotulo com a "confianca" — deterministico, nao inventado a cada
      // quadro.
      final conf = (60 + fs * 39).toStringAsFixed(0);
      final tp = TextPainter(
        text: TextSpan(
          text: 'ID ${i + 1}  $conf%',
          style: TextStyle(
            fontSize: math.max(8, w * 0.11),
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, rect.top - tp.height - 3));
    }
  }

  @override
  bool shouldRepaint(BlobTrackerPainter old) =>
      old.count != count ||
      old.boxSize != boxSize ||
      old.spread != spread ||
      old.speed != speed ||
      old.stroke != stroke ||
      old.cornersOnly != cornersOnly ||
      old.color != color ||
      old.time != time ||
      old.seed != seed;
}
