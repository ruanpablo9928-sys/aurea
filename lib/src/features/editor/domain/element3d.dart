import 'dart:math' as math;

/// Elementos 3D nativos: solidos gerados por codigo (nenhum asset
/// externo), girados de verdade no espaco — vertices rotacionados e
/// projetados por face, nunca um "cartao" inclinado. A malha e funcao
/// pura do tipo: mesmo kind -> mesma malha (cache estatico).
enum Element3DKind {
  cube,
  pyramid,
  cone,
  sphere,
  cylinder,
  prism,
  diamond,
  torus,
  star,
}

/// Malha em coordenadas unitarias (meia-extensao ~1). O pintor escala
/// pelo tamanho da camada e projeta com a focal padrao do app (1200).
class Element3DMesh {
  Element3DMesh(this.verts, this.faces);

  /// Cada vertice e [x, y, z]; y positivo desce (convencao de tela).
  final List<List<double>> verts;

  /// Cada face e uma lista de indices (poligono plano).
  final List<List<int>> faces;
}

final Map<Element3DKind, Element3DMesh> _meshCache = {};

Element3DMesh element3DMesh(Element3DKind kind) =>
    _meshCache[kind] ??= _build(kind);

Element3DMesh _build(Element3DKind kind) {
  switch (kind) {
    case Element3DKind.cube:
      return _cuboChanfrado();

    case Element3DKind.pyramid:
      return Element3DMesh(
        [
          [0, -1.1, 0],
          [-1, 1, -1], [1, 1, -1], [1, 1, 1], [-1, 1, 1],
        ],
        [
          [1, 2, 3, 4],
          [0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
        ],
      );

    case Element3DKind.cone:
      return _lathe(
        segments: 24,
        apex: const [0.0, -1.1, 0.0],
        ringY: 1,
        ringR: 1,
        withCap: true,
      );

    case Element3DKind.sphere:
      return _sphere(stacks: 10, slices: 16);

    case Element3DKind.cylinder:
      return _cylinder(segments: 20);

    case Element3DKind.prism:
      return _extrude(
        outline: const [
          [0.0, -1.0], [1.0, 1.0], [-1.0, 1.0],
        ],
        halfDepth: 0.8,
      );

    case Element3DKind.diamond:
      return _diamond();

    case Element3DKind.torus:
      return _torus(major: 0.72, minor: 0.3, around: 18, tube: 10);

    case Element3DKind.star:
      final pts = <List<double>>[];
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 1.0 : 0.45;
        final a = -math.pi / 2 + i * math.pi / 5;
        pts.add([r * math.cos(a), r * math.sin(a)]);
      }
      return _extrude(outline: pts, halfDepth: 0.28);
  }
}

/// Cone/funil: aro no plano Y + apex; cap opcional no aro.
Element3DMesh _lathe({
  required int segments,
  required List<double> apex,
  required double ringY,
  required double ringR,
  required bool withCap,
}) {
  final verts = <List<double>>[apex];
  for (var i = 0; i < segments; i++) {
    final a = 2 * math.pi * i / segments;
    verts.add([ringR * math.cos(a), ringY, ringR * math.sin(a)]);
  }
  final faces = <List<int>>[];
  for (var i = 0; i < segments; i++) {
    faces.add([0, 1 + i, 1 + (i + 1) % segments]);
  }
  if (withCap) {
    faces.add([for (var i = 0; i < segments; i++) 1 + i]);
  }
  return Element3DMesh(verts, faces);
}

Element3DMesh _sphere({required int stacks, required int slices}) {
  final verts = <List<double>>[];
  for (var st = 0; st <= stacks; st++) {
    final phi = math.pi * st / stacks;
    final y = -math.cos(phi);
    final r = math.sin(phi);
    for (var sl = 0; sl < slices; sl++) {
      final th = 2 * math.pi * sl / slices;
      verts.add([r * math.cos(th), y, r * math.sin(th)]);
    }
  }
  final faces = <List<int>>[];
  int at(int st, int sl) => st * slices + sl % slices;
  for (var st = 0; st < stacks; st++) {
    for (var sl = 0; sl < slices; sl++) {
      faces.add([
        at(st, sl), at(st, sl + 1), at(st + 1, sl + 1), at(st + 1, sl),
      ]);
    }
  }
  return Element3DMesh(verts, faces);
}

Element3DMesh _cylinder({required int segments}) {
  final verts = <List<double>>[];
  for (final y in const [-1.0, 1.0]) {
    for (var i = 0; i < segments; i++) {
      final a = 2 * math.pi * i / segments;
      verts.add([math.cos(a), y, math.sin(a)]);
    }
  }
  final faces = <List<int>>[];
  for (var i = 0; i < segments; i++) {
    final j = (i + 1) % segments;
    faces.add([i, j, segments + j, segments + i]);
  }
  faces.add([for (var i = 0; i < segments; i++) i]);
  faces.add([for (var i = 0; i < segments; i++) segments + i]);
  return Element3DMesh(verts, faces);
}

/// Extrusao de um contorno 2D (x, y) ao longo de Z: frente + tras + lados.
Element3DMesh _extrude({
  required List<List<double>> outline,
  required double halfDepth,
}) {
  final n = outline.length;
  final verts = <List<double>>[
    for (final p in outline) [p[0], p[1], -halfDepth],
    for (final p in outline) [p[0], p[1], halfDepth],
  ];
  final faces = <List<int>>[
    [for (var i = 0; i < n; i++) i],
    [for (var i = 0; i < n; i++) n + i],
    for (var i = 0; i < n; i++)
      [i, (i + 1) % n, n + (i + 1) % n, n + i],
  ];
  return Element3DMesh(verts, faces);
}

/// Gema lapidada: mesa hexagonal em cima, cinta hexagonal maior no meio
/// e pavilhao em ponta — 1 mesa + 6 facetas de coroa + 6 de pavilhao.
Element3DMesh _diamond() {
  final verts = <List<double>>[];
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 6 + 2 * math.pi * i / 6;
    verts.add([0.55 * math.cos(a), -0.72, 0.55 * math.sin(a)]);
  }
  for (var i = 0; i < 6; i++) {
    final a = math.pi / 6 + 2 * math.pi * i / 6;
    verts.add([1.0 * math.cos(a), -0.18, 1.0 * math.sin(a)]);
  }
  verts.add([0, 1.05, 0]);
  final faces = <List<int>>[
    [0, 1, 2, 3, 4, 5],
    for (var i = 0; i < 6; i++)
      [i, (i + 1) % 6, 6 + (i + 1) % 6, 6 + i],
    for (var i = 0; i < 6; i++) [6 + i, 6 + (i + 1) % 6, 12],
  ];
  return Element3DMesh(verts, faces);
}

Element3DMesh _torus({
  required double major,
  required double minor,
  required int around,
  required int tube,
}) {
  final verts = <List<double>>[];
  for (var i = 0; i < around; i++) {
    final u = 2 * math.pi * i / around;
    for (var j = 0; j < tube; j++) {
      final v = 2 * math.pi * j / tube;
      final r = major + minor * math.cos(v);
      verts.add([r * math.cos(u), minor * math.sin(v), r * math.sin(u)]);
    }
  }
  final faces = <List<int>>[];
  int at(int i, int j) => (i % around) * tube + j % tube;
  for (var i = 0; i < around; i++) {
    for (var j = 0; j < tube; j++) {
      faces.add([at(i, j), at(i + 1, j), at(i + 1, j + 1), at(i, j + 1)]);
    }
  }
  return Element3DMesh(verts, faces);
}

String element3DLabel(Element3DKind kind) => switch (kind) {
      Element3DKind.cube => 'Cubo',
      Element3DKind.pyramid => 'Piramide',
      Element3DKind.cone => 'Cone',
      Element3DKind.sphere => 'Esfera',
      Element3DKind.cylinder => 'Cilindro',
      Element3DKind.prism => 'Prisma',
      Element3DKind.diamond => 'Diamante',
      Element3DKind.torus => 'Anel 3D',
      Element3DKind.star => 'Estrela 3D',
    };


/// CUBO COM CHANFRO nas arestas.
///
/// Objeto real nao tem canto infinitamente afiado: sempre ha uma faixa
/// estreita na aresta, e e a luz batendo NELA que a gente le como
/// volume. Um cubo de canto perfeito perde essa faixa, e o resultado
/// parece um desenho de cubo, nao um cubo.
///
/// Custa doze faces de aresta e oito de canto — nada perto do que
/// entrega. O chanfro e pequeno de proposito: grande demais vira
/// almofada.
Element3DMesh _cuboChanfrado({double chanfro = 0.075}) {
  const a = 1.0;
  final c = 1 - chanfro.clamp(0.01, 0.4);

  // Para cada um dos oito cantos, tres vertices: o canto recuado em X,
  // em Y e em Z. E o que abre espaco para a faixa da aresta.
  final verts = <List<double>>[];
  final idx = <String, int>{};
  for (final sx in const [-1.0, 1.0]) {
    for (final sy in const [-1.0, 1.0]) {
      for (final sz in const [-1.0, 1.0]) {
        for (var eixo = 0; eixo < 3; eixo++) {
          final v = [sx * a, sy * a, sz * a];
          v[eixo] = v[eixo] / a * c;
          idx['$sx|$sy|$sz|$eixo'] = verts.length;
          verts.add(v);
        }
      }
    }
  }
  int em(double sx, double sy, double sz, int eixo) =>
      idx['$sx|$sy|$sz|$eixo']!;

  final faces = <List<int>>[];

  // AS SEIS FACES viraram octogonos: os cantos foram cortados.
  for (var eixo = 0; eixo < 3; eixo++) {
    final u = (eixo + 1) % 3;
    final w = (eixo + 2) % 3;
    for (final sinal in const [-1.0, 1.0]) {
      final pontos = <(double, int)>[];
      for (final su in const [-1.0, 1.0]) {
        for (final sw in const [-1.0, 1.0]) {
          final sig = List<double>.filled(3, 0);
          sig[eixo] = sinal;
          sig[u] = su;
          sig[w] = sw;
          // Os dois vertices deste canto que ficam NESTA face sao os
          // recuados nos outros dois eixos.
          for (final recuo in [u, w]) {
            final i = em(sig[0], sig[1], sig[2], recuo);
            final v = verts[i];
            pontos.add((math.atan2(v[w], v[u]), i));
          }
        }
      }
      // Ordenar pelo angulo garante poligono convexo sem depender de
      // acertar a volta na mao.
      pontos.sort((p1, p2) => p1.$1.compareTo(p2.$1));
      faces.add([for (final ponto in pontos) ponto.$2]);
    }
  }

  // AS DOZE FAIXAS DE ARESTA: onde duas faces se encontram.
  for (var i = 0; i < 3; i++) {
    for (var j = i + 1; j < 3; j++) {
      final k = 3 - i - j;
      for (final si in const [-1.0, 1.0]) {
        for (final sj in const [-1.0, 1.0]) {
          final s0 = List<double>.filled(3, 0);
          s0[i] = si;
          s0[j] = sj;
          s0[k] = -1;
          final s1 = List<double>.from(s0);
          s1[k] = 1;
          faces.add([
            em(s0[0], s0[1], s0[2], i),
            em(s0[0], s0[1], s0[2], j),
            em(s1[0], s1[1], s1[2], j),
            em(s1[0], s1[1], s1[2], i),
          ]);
        }
      }
    }
  }

  // OS OITO CANTOS: o triangulinho que sobra.
  for (final sx in const [-1.0, 1.0]) {
    for (final sy in const [-1.0, 1.0]) {
      for (final sz in const [-1.0, 1.0]) {
        faces.add([
          em(sx, sy, sz, 0),
          em(sx, sy, sz, 1),
          em(sx, sy, sz, 2),
        ]);
      }
    }
  }

  return Element3DMesh(verts, faces);
}
