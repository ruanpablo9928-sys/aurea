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
      return Element3DMesh(
        [
          [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1],
          [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1],
        ],
        [
          [0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
          [2, 3, 7, 6], [0, 3, 7, 4], [1, 2, 6, 5],
        ],
      );

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
