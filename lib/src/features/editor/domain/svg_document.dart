import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../../core/utils/mini_xml.dart';
import 'mask.dart';
import 'shape.dart';
import 'keyframe.dart';
import 'svg_path.dart';

/// LEITOR DE ARQUIVO SVG -> FORMAS EDITAVEIS.
///
/// O app ja sabia ler PATH DATA (o `d=` de um caminho, usado nos icones);
/// o que faltava era o ARQUIVO: viewBox, varios desenhos, cada um com a
/// sua cor, contorno, e os `<g transform>` por cima. Sem isso, um SVG so
/// entrava como imagem — e imagem nao se edita ponto a ponto.
///
/// Cada desenho vira uma forma com caminho de Bezier, que e o que o
/// editor de pontos sabe pegar com o dedo. Um SVG com cinco desenhos de
/// cores diferentes vira um grupo com cinco camadas — pintura por forma,
/// como no arquivo.
class SvgForma {
  const SvgForma({
    required this.path,
    required this.nome,
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
  });

  /// Caminho com NOS: e o que o editor de pontos sabe pegar com o dedo.
  final BezierPath path;
  final String nome;
  final Color? fill;
  final Color? stroke;
  final double strokeWidth;
}

class SvgImportado {
  const SvgImportado({
    required this.formas,
    required this.tamanho,
    required this.ignorados,
  });

  final List<SvgForma> formas;

  /// A caixa que os desenhos ocupam depois de ajustados.
  final Size tamanho;
  final List<String> ignorados;
}

class SvgException implements Exception {
  const SvgException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Le o SVG e devolve os desenhos ja centrados na origem, com o lado
/// maior valendo [alvo] px (o tamanho que uma forma nova tem aqui).
SvgImportado lerSvg(String fonte, {double alvo = 420}) {
  final root = parseXml(fonte);
  XmlNode? svg;
  for (final e in [...root.children, ...root.descendants()]) {
    if (e.tag == 'svg') {
      svg = e;
      break;
    }
  }
  if (svg == null) throw const SvgException('Isso nao parece um SVG.');

  final ignorados = <String>[];
  final formas = <SvgForma>[];
  _percorre(svg, _Estado.raiz(svg), formas, ignorados);
  if (formas.isEmpty) {
    throw const SvgException(
      'O SVG nao tem desenho nenhum que eu saiba ler (path, rect, circle, '
      'ellipse, line, polygon, polyline).',
    );
  }

  // Uma transformacao para todos: mantem a posicao relativa entre os
  // desenhos e poe o conjunto centrado na origem.
  var uniao = _caixa(formas.first.path);
  for (final f in formas.skip(1)) {
    uniao = uniao.expandToInclude(_caixa(f.path));
  }
  final lado = math.max(uniao.width, uniao.height);
  final k = lado <= 0 ? 1.0 : alvo / lado;
  Offset ajusta(Offset o) => Offset(
    (o.dx - uniao.center.dx) * k,
    (o.dy - uniao.center.dy) * k,
  );
  final ajustadas = [
    for (final f in formas)
      SvgForma(
        path: BezierPath(
          closed: f.path.closed,
          vertices: [
            for (final v in f.path.vertices)
              PathVertex(
                p: ajusta(v.p),
                inT: v.inT * k,
                outT: v.outT * k,
                corner: v.corner,
              ),
          ],
        ),
        nome: f.nome,
        fill: f.fill,
        stroke: f.stroke,
        strokeWidth: f.strokeWidth * k,
      ),
  ];
  return SvgImportado(
    formas: ajustadas,
    tamanho: Size(uniao.width * k, uniao.height * k),
    ignorados: ignorados,
  );
}

/// As formas do SVG como itens de UMA camada (quando ha um desenho so)
/// ou como uma camada por desenho (quando ha varios, para cada um ficar
/// com a sua cor e o seu ponto de edicao).
List<List<ShapeItem>> itensDoSvg(SvgImportado svg) => [
  for (final f in svg.formas)
    [
      ShapeBezier(path: AnimatedPath(f.path)),
      if (f.fill != null) ShapeFill(color: f.fill!),
      if (f.stroke != null && f.strokeWidth > 0)
        ShapeStroke(
          color: f.stroke!,
          width: AnimatedDouble(f.strokeWidth),
        ),
      // Desenho sem pintura nenhuma no arquivo: entra com um traco fino,
      // senao ele existe e nao aparece.
      if (f.fill == null && (f.stroke == null || f.strokeWidth <= 0))
        ShapeStroke(
          color: const Color(0xFFFFFFFF),
          width: AnimatedDouble(4),
        ),
    ],
];

// ------------------------------------------------------------ leitura

class _Estado {
  const _Estado({
    required this.matriz,
    this.fill,
    this.stroke,
    this.strokeWidth,
    this.fillOpacity = 1,
    this.opacity = 1,
  });

  factory _Estado.raiz(XmlNode svg) {
    // viewBox nao muda a forma: os desenhos sao ajustados no fim pela
    // uniao das caixas. Serve so para nao herdar transformacao nenhuma.
    return const _Estado(matriz: null, fill: null);
  }

  final Float64List? matriz;
  final Color? fill;
  final Color? stroke;
  final double? strokeWidth;
  final double fillOpacity;
  final double opacity;

  _Estado herda(XmlNode e) {
    final t = _transform(e.attr(['transform']));
    final estilo = _estilo(e);
    return _Estado(
      matriz: t == null ? matriz : (matriz == null ? t : _multiplica(matriz!, t)),
      fill: estilo.containsKey('fill')
          ? _cor(estilo['fill'])
          : (e.attr(['fill']) != null ? _cor(e.attr(['fill'])) : fill),
      stroke: estilo.containsKey('stroke')
          ? _cor(estilo['stroke'])
          : (e.attr(['stroke']) != null ? _cor(e.attr(['stroke'])) : stroke),
      strokeWidth:
          _numero(estilo['stroke-width'] ?? e.attr(['stroke-width'])) ??
          strokeWidth,
      fillOpacity:
          _numero(estilo['fill-opacity'] ?? e.attr(['fill-opacity'])) ??
          fillOpacity,
      opacity:
          (_numero(estilo['opacity'] ?? e.attr(['opacity'])) ?? 1) * opacity,
    );
  }
}

const _desenhos = {
  'path',
  'rect',
  'circle',
  'ellipse',
  'line',
  'polygon',
  'polyline',
};

void _percorre(
  XmlNode no,
  _Estado herdado,
  List<SvgForma> out,
  List<String> ignorados,
) {
  for (final e in no.children) {
    // Nao desenham: definicoes, mascaras, degrades, texto.
    if (e.tag == 'defs' || e.tag == 'clippath' || e.tag == 'mask') continue;
    if (e.tag == 'text' || e.tag == 'tspan') {
      if (!ignorados.contains('texto do SVG')) ignorados.add('texto do SVG');
      continue;
    }
    if (e.tag == 'image') {
      if (!ignorados.contains('imagem embutida no SVG')) {
        ignorados.add('imagem embutida no SVG');
      }
      continue;
    }
    final estado = herdado.herda(e);
    if (e.tag == 'g' || e.tag == 'svg' || e.tag == 'a') {
      _percorre(e, estado, out, ignorados);
      continue;
    }
    if (!_desenhos.contains(e.tag)) continue;
    final p = _caminho(e, ignorados);
    if (p == null || p.vertices.isEmpty) continue;
    final path = _aplica(p, estado.matriz);

    // Sem `fill` declarado, o SVG pinta de preto. `none` nao pinta.
    final temFill = estado.fill != null;
    final corFill = temFill
        ? estado.fill!.withValues(
            alpha: estado.fill!.a * estado.fillOpacity * estado.opacity,
          )
        : (_declarado(e, 'fill') == 'none' ? null : const Color(0xFF000000));
    out.add(
      SvgForma(
        path: path,
        nome: _texto(e.attr(['id'])) ?? _nomeDoDesenho(e.tag),
        fill: corFill,
        stroke: estado.stroke,
        strokeWidth: estado.strokeWidth ?? (estado.stroke != null ? 2 : 0),
      ),
    );
  }
}

String? _declarado(XmlNode e, String nome) {
  final estilo = _estilo(e);
  return estilo[nome] ?? e.attr([nome]);
}

String _nomeDoDesenho(String tag) => switch (tag) {
  'rect' => 'Retangulo',
  'circle' => 'Circulo',
  'ellipse' => 'Elipse',
  'line' => 'Linha',
  'polygon' => 'Poligono',
  'polyline' => 'Linha',
  _ => 'Caminho',
};

BezierPath? _caminho(XmlNode e, List<String> ignorados) {
  double n(String nome, [double padrao = 0]) =>
      _numero(e.attr([nome])) ?? padrao;
  BezierPath deCantos(List<Offset> pts, {bool fechado = true}) => BezierPath(
    closed: fechado,
    vertices: [for (final q in pts) PathVertex(p: q)],
  );
  switch (e.tag) {
    case 'path':
      final d = e.attr(['d']);
      if (d == null || d.trim().isEmpty) return null;
      try {
        return svgPathToBezier(d);
      } catch (_) {
        ignorados.add('um caminho com "d" que nao consegui ler');
        return null;
      }
    case 'rect':
      final w = n('width');
      final h = n('height');
      if (w <= 0 || h <= 0) return null;
      final rx = _numero(e.attr(['rx'])) ?? _numero(e.attr(['ry'])) ?? 0;
      final centro = Offset(n('x') + w / 2, n('y') + h / 2);
      return rx > 0
          ? BezierPath.roundedRect(w, h, rx, center: centro)
          : BezierPath.rect(w, h, center: centro);
    case 'circle':
      final raio = n('r');
      if (raio <= 0) return null;
      return BezierPath.ellipse(
        raio * 2,
        raio * 2,
        center: Offset(n('cx'), n('cy')),
      );
    case 'ellipse':
      final rx = n('rx');
      final ry = n('ry');
      if (rx <= 0 || ry <= 0) return null;
      return BezierPath.ellipse(
        rx * 2,
        ry * 2,
        center: Offset(n('cx'), n('cy')),
      );
    case 'line':
      return deCantos([
        Offset(n('x1'), n('y1')),
        Offset(n('x2'), n('y2')),
      ], fechado: false);
    case 'polygon':
    case 'polyline':
      final pts = _pontos(e.attr(['points']));
      if (pts.length < 2) return null;
      return deCantos(pts, fechado: e.tag == 'polygon');
  }
  return null;
}

/// A caixa que os nos ocupam (basta a ancora: as tangentes ficam dentro
/// da margem que o ajuste ja deixa).
Rect _caixa(BezierPath p) {
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final v in p.vertices) {
    minX = math.min(minX, v.p.dx);
    minY = math.min(minY, v.p.dy);
    maxX = math.max(maxX, v.p.dx);
    maxY = math.max(maxY, v.p.dy);
  }
  if (minX > maxX) return Rect.zero;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}

/// Aplica a transformacao do SVG (`transform=`) nos nos.
BezierPath _aplica(BezierPath p, Float64List? m) {
  if (m == null) return p;
  Offset ponto(Offset o) =>
      Offset(m[0] * o.dx + m[4] * o.dy + m[12], m[1] * o.dx + m[5] * o.dy + m[13]);
  Offset vetor(Offset o) =>
      Offset(m[0] * o.dx + m[4] * o.dy, m[1] * o.dx + m[5] * o.dy);
  return BezierPath(
    closed: p.closed,
    vertices: [
      for (final v in p.vertices)
        PathVertex(
          p: ponto(v.p),
          inT: vetor(v.inT),
          outT: vetor(v.outT),
          corner: v.corner,
        ),
    ],
  );
}

List<Offset> _pontos(String? s) {
  if (s == null) return const [];
  final n = <double>[];
  for (final m in RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?')
      .allMatches(s)) {
    n.add(double.parse(m.group(0)!));
  }
  return [
    for (var i = 0; i + 1 < n.length; i += 2) Offset(n[i], n[i + 1]),
  ];
}

Map<String, String> _estilo(XmlNode e) {
  final s = e.attr(['style']);
  if (s == null || s.isEmpty) return const {};
  final out = <String, String>{};
  for (final parte in s.split(';')) {
    final i = parte.indexOf(':');
    if (i <= 0) continue;
    out[parte.substring(0, i).trim().toLowerCase()] = parte
        .substring(i + 1)
        .trim();
  }
  return out;
}

/// `translate(..)`, `scale(..)`, `rotate(..)`, `matrix(..)`, encadeados.
Float64List? _transform(String? t) {
  if (t == null || t.trim().isEmpty) return null;
  Float64List? acc;
  for (final m in RegExp(r'(\w+)\s*\(([^)]*)\)').allMatches(t)) {
    final nome = m.group(1)!.toLowerCase();
    final v = [
      for (final x in RegExp(r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?')
          .allMatches(m.group(2)!))
        double.parse(x.group(0)!),
    ];
    double at(int i, [double p = 0]) => i < v.length ? v[i] : p;
    final Float64List passo;
    switch (nome) {
      case 'translate':
        passo = _matriz(1, 0, 0, 1, at(0), at(1));
      case 'scale':
        passo = _matriz(at(0, 1), 0, 0, at(1, at(0, 1)), 0, 0);
      case 'matrix':
        passo = _matriz(at(0, 1), at(1), at(2), at(3, 1), at(4), at(5));
      case 'rotate':
        final r = at(0) * math.pi / 180;
        final cx = at(1);
        final cy = at(2);
        final rot = _matriz(
          math.cos(r),
          math.sin(r),
          -math.sin(r),
          math.cos(r),
          0,
          0,
        );
        passo = cx == 0 && cy == 0
            ? rot
            : _multiplica(
                _multiplica(_matriz(1, 0, 0, 1, cx, cy), rot),
                _matriz(1, 0, 0, 1, -cx, -cy),
              );
      case 'skewx':
        passo = _matriz(1, 0, math.tan(at(0) * math.pi / 180), 1, 0, 0);
      case 'skewy':
        passo = _matriz(1, math.tan(at(0) * math.pi / 180), 0, 1, 0, 0);
      default:
        continue;
    }
    acc = acc == null ? passo : _multiplica(acc, passo);
  }
  return acc;
}

/// Matriz 4x4 (coluna a coluna, como o Flutter espera) a partir dos seis
/// numeros do SVG.
Float64List _matriz(
  double a,
  double b,
  double c,
  double d,
  double e,
  double f,
) {
  final m = Float64List(16);
  m[0] = a;
  m[1] = b;
  m[4] = c;
  m[5] = d;
  m[12] = e;
  m[13] = f;
  m[10] = 1;
  m[15] = 1;
  return m;
}

Float64List _multiplica(Float64List x, Float64List y) {
  // So a parte afim 2D importa.
  final a = x[0] * y[0] + x[4] * y[1];
  final b = x[1] * y[0] + x[5] * y[1];
  final c = x[0] * y[4] + x[4] * y[5];
  final d = x[1] * y[4] + x[5] * y[5];
  final e = x[0] * y[12] + x[4] * y[13] + x[12];
  final f = x[1] * y[12] + x[5] * y[13] + x[13];
  return _matriz(a, b, c, d, e, f);
}

/// `#rgb`, `#rrggbb`, `rgb(r,g,b)`, `none`, e os nomes mais comuns.
Color? _cor(String? s) {
  if (s == null) return null;
  final t = s.trim().toLowerCase();
  if (t.isEmpty || t == 'none' || t == 'transparent') return null;
  if (t.startsWith('url(')) return null; // degrade: fica para depois
  if (t == 'currentcolor') return const Color(0xFF000000);
  if (t.startsWith('#')) {
    var h = t.substring(1);
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}';
    }
    if (h.length == 6) h = 'ff$h';
    if (h.length == 8) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(v);
    }
    return null;
  }
  final rgb = RegExp(r'rgba?\(([^)]*)\)').firstMatch(t);
  if (rgb != null) {
    final p = rgb
        .group(1)!
        .split(',')
        .map((x) => double.tryParse(x.trim()) ?? 0)
        .toList();
    if (p.length >= 3) {
      return Color.fromARGB(
        p.length > 3 ? (p[3] * 255).round().clamp(0, 255) : 255,
        p[0].round().clamp(0, 255),
        p[1].round().clamp(0, 255),
        p[2].round().clamp(0, 255),
      );
    }
  }
  return _nomeadas[t];
}

const _nomeadas = <String, Color>{
  'black': Color(0xFF000000),
  'white': Color(0xFFFFFFFF),
  'red': Color(0xFFFF0000),
  'green': Color(0xFF008000),
  'blue': Color(0xFF0000FF),
  'yellow': Color(0xFFFFFF00),
  'orange': Color(0xFFFFA500),
  'purple': Color(0xFF800080),
  'gray': Color(0xFF808080),
  'grey': Color(0xFF808080),
  'silver': Color(0xFFC0C0C0),
  'pink': Color(0xFFFFC0CB),
  'brown': Color(0xFFA52A2A),
  'cyan': Color(0xFF00FFFF),
  'magenta': Color(0xFFFF00FF),
  'lime': Color(0xFF00FF00),
  'navy': Color(0xFF000080),
  'teal': Color(0xFF008080),
  'olive': Color(0xFF808000),
  'maroon': Color(0xFF800000),
};

double? _numero(String? s) {
  if (s == null) return null;
  final m = RegExp(
    r'[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?',
  ).firstMatch(s.trim());
  return m == null ? null : double.tryParse(m.group(0)!);
}

String? _texto(String? s) {
  final t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

