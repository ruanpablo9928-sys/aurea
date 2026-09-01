import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// FORMA DE ONDA na barra do clipe.
///
/// Desenhada como envelope espelhado no meio da barra: e a forma que
/// deixa a respiracao entre duas falas visivel de relance, que e para
/// isso que ela serve.
///
/// Os picos cobrem o arquivo INTEIRO; a barra mostra so o trecho usado,
/// entao a janela [start, end] recorta a leitura. Assim arrastar a alca
/// de corte revela o audio que estava fora, em vez de esticar o que ja
/// estava dentro.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.start,
    required this.end,
    required this.color,
  });

  final Float32List peaks;
  final Duration start;
  final Duration end;
  final Color color;

  /// Picos por segundo — tem de bater com quem gerou.
  static const perSecond = 100;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.isEmpty || size.width < 2 || size.height < 4) return;

    final from = (start.inMilliseconds / 1000.0 * perSecond).floor();
    final to = (end.inMilliseconds / 1000.0 * perSecond).ceil();
    final span = to - from;
    if (span <= 0) return;

    final mid = size.height / 2;
    final half = size.height / 2 - 1.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Uma coluna por pixel: mais que isso nao aparece, menos que isso
    // esconde transiente.
    final columns = size.width.floor();
    final step = span / columns;
    for (var x = 0; x < columns; x++) {
      final a = from + (x * step).floor();
      final b = from + ((x + 1) * step).ceil();
      var peak = 0.0;
      for (var i = a; i < b; i++) {
        if (i < 0 || i >= peaks.length) continue;
        if (peaks[i] > peak) peak = peaks[i];
      }
      if (peak <= 0) continue;
      // Raiz comprime o alto e abre o baixo: som fraco continua visivel.
      final h = math.sqrt(peak) * half;
      final dx = x + 0.5;
      canvas.drawLine(Offset(dx, mid - h), Offset(dx, mid + h), paint);
    }
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.peaks != peaks ||
      old.start != start ||
      old.end != end ||
      old.color != color;
}

/// TIRA DE MINIATURAS na barra do clipe de video.
///
/// Sem ela, achar o corte e tatear: a barra e um retangulo liso e a
/// unica pista e o playhead. Com ela, da para ver a cena mudar.
class FilmstripPainter extends CustomPainter {
  const FilmstripPainter({
    required this.frames,
    required this.start,
    required this.end,
    required this.sourceDuration,
  });

  final List<ui.Image> frames;

  /// Trecho usado do arquivo.
  final Duration start;
  final Duration end;

  /// Duracao total do arquivo, que e o que as miniaturas cobrem.
  final Duration sourceDuration;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty || size.width < 2 || size.height < 4) return;

    final total = sourceDuration.inMicroseconds;
    final a = total <= 0 ? 0.0 : start.inMicroseconds / total;
    final b = total <= 0 ? 1.0 : end.inMicroseconds / total;
    final span = (b - a).clamp(0.0001, 1.0);

    final paint = Paint()
      ..filterQuality = FilterQuality.low
      ..isAntiAlias = false;

    // Largura de cada miniatura na barra, mantendo a proporcao.
    final first = frames.first;
    final tileW = size.height * first.width / first.height;
    if (tileW <= 0) return;

    final n = (size.width / tileW).ceil() + 1;
    for (var i = 0; i < n; i++) {
      final x = i * tileW;
      // Qual instante do ARQUIVO esta neste ponto da barra.
      final f = a + (x / size.width) * span;
      final idx =
          (f * frames.length).floor().clamp(0, frames.length - 1);
      final img = frames[idx];
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH(x, 0, tileW, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FilmstripPainter old) =>
      old.frames != frames ||
      old.start != start ||
      old.end != end ||
      old.sourceDuration != sourceDuration;
}
