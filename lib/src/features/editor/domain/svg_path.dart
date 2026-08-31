import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Parser de path data SVG -> [Path] (spec AUREA-atualizacao §6.4):
/// o icone entra como CAMINHO vetorial editavel, nunca como imagem.
/// Suporta M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z.
Path parseSvgPathData(String data) {
  final path = Path();
  final tokens = _tokenize(data);
  var i = 0;

  var cx = 0.0, cy = 0.0; // ponto atual
  var sx = 0.0, sy = 0.0; // inicio do subcaminho
  var lastCx = 0.0, lastCy = 0.0; // controle anterior (S/T)
  var lastCmd = '';

  double num_() => tokens[i++] as double;

  while (i < tokens.length) {
    var cmd = tokens[i] is String ? tokens[i++] as String : lastCmd;
    // Comando implicito: apos M vem L; apos m vem l.
    if (lastCmd == 'M' && cmd == 'M' && tokens[i - 1] is! String) cmd = 'L';
    if (lastCmd == 'm' && cmd == 'm' && tokens[i - 1] is! String) cmd = 'l';

    switch (cmd) {
      case 'M':
        cx = num_();
        cy = num_();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        lastCmd = 'M';
      case 'm':
        cx += num_();
        cy += num_();
        path.moveTo(cx, cy);
        sx = cx;
        sy = cy;
        lastCmd = 'm';
      case 'L':
        cx = num_();
        cy = num_();
        path.lineTo(cx, cy);
        lastCmd = 'L';
      case 'l':
        cx += num_();
        cy += num_();
        path.lineTo(cx, cy);
        lastCmd = 'l';
      case 'H':
        cx = num_();
        path.lineTo(cx, cy);
        lastCmd = 'H';
      case 'h':
        cx += num_();
        path.lineTo(cx, cy);
        lastCmd = 'h';
      case 'V':
        cy = num_();
        path.lineTo(cx, cy);
        lastCmd = 'V';
      case 'v':
        cy += num_();
        path.lineTo(cx, cy);
        lastCmd = 'v';
      case 'C':
      case 'c':
        final rel = cmd == 'c';
        final x1 = (rel ? cx : 0) + num_();
        final y1 = (rel ? cy : 0) + num_();
        final x2 = (rel ? cx : 0) + num_();
        final y2 = (rel ? cy : 0) + num_();
        final x = (rel ? cx : 0) + num_();
        final y = (rel ? cy : 0) + num_();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastCx = x2;
        lastCy = y2;
        cx = x;
        cy = y;
        lastCmd = 'C';
      case 'S':
      case 's':
        final rel = cmd == 's';
        final x1 = lastCmd == 'C' || lastCmd == 'S'
            ? 2 * cx - lastCx
            : cx;
        final y1 = lastCmd == 'C' || lastCmd == 'S'
            ? 2 * cy - lastCy
            : cy;
        final x2 = (rel ? cx : 0) + num_();
        final y2 = (rel ? cy : 0) + num_();
        final x = (rel ? cx : 0) + num_();
        final y = (rel ? cy : 0) + num_();
        path.cubicTo(x1, y1, x2, y2, x, y);
        lastCx = x2;
        lastCy = y2;
        cx = x;
        cy = y;
        lastCmd = 'S';
      case 'Q':
      case 'q':
        final rel = cmd == 'q';
        final x1 = (rel ? cx : 0) + num_();
        final y1 = (rel ? cy : 0) + num_();
        final x = (rel ? cx : 0) + num_();
        final y = (rel ? cy : 0) + num_();
        path.quadraticBezierTo(x1, y1, x, y);
        lastCx = x1;
        lastCy = y1;
        cx = x;
        cy = y;
        lastCmd = 'Q';
      case 'T':
      case 't':
        final rel = cmd == 't';
        final x1 = lastCmd == 'Q' || lastCmd == 'T'
            ? 2 * cx - lastCx
            : cx;
        final y1 = lastCmd == 'Q' || lastCmd == 'T'
            ? 2 * cy - lastCy
            : cy;
        final x = (rel ? cx : 0) + num_();
        final y = (rel ? cy : 0) + num_();
        path.quadraticBezierTo(x1, y1, x, y);
        lastCx = x1;
        lastCy = y1;
        cx = x;
        cy = y;
        lastCmd = 'T';
      case 'A':
      case 'a':
        final rel = cmd == 'a';
        final rx = num_();
        final ry = num_();
        final rot = num_();
        final largeArc = num_() != 0;
        final sweep = num_() != 0;
        final x = (rel ? cx : 0) + num_();
        final y = (rel ? cy : 0) + num_();
        _arcTo(path, cx, cy, x, y, rx, ry, rot, largeArc, sweep);
        cx = x;
        cy = y;
        lastCmd = 'A';
      case 'Z':
      case 'z':
        path.close();
        cx = sx;
        cy = sy;
        lastCmd = 'Z';
      default:
        // Token desconhecido: aborta com o que deu para ler.
        return path;
    }
  }
  return path;
}

/// Arco eliptico SVG -> arcToPoint do Flutter (mesma semantica).
void _arcTo(Path path, double x0, double y0, double x, double y, double rx,
    double ry, double rotDeg, bool largeArc, bool sweep) {
  if (rx <= 0 || ry <= 0) {
    path.lineTo(x, y);
    return;
  }
  path.arcToPoint(
    Offset(x, y),
    radius: Radius.elliptical(rx, ry),
    rotation: rotDeg,
    largeArc: largeArc,
    clockwise: sweep,
  );
}

/// Divide o path data em comandos (String) e numeros (double).
List<Object> _tokenize(String d) {
  final out = <Object>[];
  final re = RegExp(r'([MmLlHhVvCcSsQqTtAaZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)');
  for (final m in re.allMatches(d)) {
    if (m.group(1) != null) {
      out.add(m.group(1)!);
    } else {
      out.add(double.parse(m.group(2)!));
    }
  }
  return out;
}

/// Normaliza um path para caber centrado num box de [size] logicos
/// (usado ao inserir icones: viewBox varia por conjunto).
Path fitPathToBox(Path source, double size) {
  final b = source.getBounds();
  if (b.isEmpty) return source;
  final s = size / math.max(b.width, b.height);
  return source.transform(Float64List.fromList([
    s, 0, 0, 0, //
    0, s, 0, 0, //
    0, 0, 1, 0, //
    -b.center.dx * s, -b.center.dy * s, 0, 1,
  ]));
}
