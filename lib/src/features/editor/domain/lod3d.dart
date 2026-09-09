/// NIVEIS DE DETALHE que NAO furam a malha.
///
/// O LOD que existia descartava uma face a cada duas (ou quatro): metade
/// da superficie sumia, e o modelo de longe virava uma peneira. Aqui a
/// simplificacao e por AGRUPAMENTO DE VERTICES numa grade: vertices que
/// caem na mesma celula viram um so (a media deles), e cada face original
/// e reescrita com os vertices agrupados. Uma face cujos tres cantos
/// cairam na mesma celula desaparece — mas a superficie em volta fecha
/// sobre ela, porque as vizinhas foram puxadas para o mesmo ponto. Nao ha
/// buraco: toda face ou continua, ou colapsa num ponto coberto.
///
/// E O(n), sem estruturas de vizinhanca, e roda num isolate se a malha
/// for grande. Nao e um simplificador de aresta (quadric): onde a grade
/// e grossa, detalhes finos somem inteiros, o que para um LOD de longe e
/// exatamente o que se quer.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'element3d.dart';

/// Simplifica [mesh] numa grade de [celulas] por lado (no eixo maior).
///
/// Devolve a propria malha quando nao ha o que ganhar: malha pequena, ou
/// resultado que nao ficou pelo menos [ganhoMinimo] menor.
Element3DMesh simplificarPorGrade(
  Element3DMesh mesh, {
  required int celulas,
  double ganhoMinimo = 0.25,
}) {
  final verts = mesh.verts;
  final faces = mesh.faces;
  if (verts.isEmpty || faces.isEmpty || celulas < 2) return mesh;

  // A caixa da malha; a celula e cubica, do tamanho do eixo maior.
  var lox = double.infinity, loy = double.infinity, loz = double.infinity;
  var hix = -double.infinity, hiy = -double.infinity, hiz = -double.infinity;
  for (final v in verts) {
    if (v[0] < lox) lox = v[0];
    if (v[1] < loy) loy = v[1];
    if (v[2] < loz) loz = v[2];
    if (v[0] > hix) hix = v[0];
    if (v[1] > hiy) hiy = v[1];
    if (v[2] > hiz) hiz = v[2];
  }
  final maior = math.max(hix - lox, math.max(hiy - loy, hiz - loz));
  if (!(maior > 0) || !maior.isFinite) return mesh;
  final lado = maior / celulas;

  // Cada vertice -> celula -> representante (media dos que cairam nela).
  final grupoDe = Int32List(verts.length);
  final chaves = <int, int>{};
  final somaX = <double>[], somaY = <double>[], somaZ = <double>[];
  final contagem = <int>[];
  for (var i = 0; i < verts.length; i++) {
    final v = verts[i];
    final cx = ((v[0] - lox) / lado).floor().clamp(0, celulas);
    final cy = ((v[1] - loy) / lado).floor().clamp(0, celulas);
    final cz = ((v[2] - loz) / lado).floor().clamp(0, celulas);
    final chave = (cx * (celulas + 1) + cy) * (celulas + 1) + cz;
    var g = chaves[chave];
    if (g == null) {
      g = contagem.length;
      chaves[chave] = g;
      somaX.add(0);
      somaY.add(0);
      somaZ.add(0);
      contagem.add(0);
    }
    grupoDe[i] = g;
    somaX[g] += v[0];
    somaY[g] += v[1];
    somaZ[g] += v[2];
    contagem[g]++;
  }

  final novosVerts = <List<double>>[
    for (var g = 0; g < contagem.length; g++)
      [somaX[g] / contagem[g], somaY[g] / contagem[g], somaZ[g] / contagem[g]],
  ];

  // Faces reescritas; as que colapsaram (menos de tres cantos distintos)
  // somem, e as repetidas (duas faces que viraram a mesma) ficam uma.
  final vistas = <Object>{};
  final novasFaces = <List<int>>[];
  final n = contagem.length;
  final cabeEmInt = n < (1 << 20);
  for (final face in faces) {
    final nova = <int>[];
    for (final vi in face) {
      if (vi < 0 || vi >= verts.length) continue;
      final g = grupoDe[vi];
      if (nova.isEmpty || nova.last != g) nova.add(g);
    }
    while (nova.length > 1 && nova.first == nova.last) {
      nova.removeLast();
    }
    if (nova.length < 3) continue;
    if (nova.toSet().length < 3) continue;
    final Object chave;
    if (nova.length == 3 && cabeEmInt) {
      var a = nova[0], b = nova[1], c = nova[2];
      if (a > b) {
        final t = a;
        a = b;
        b = t;
      }
      if (b > c) {
        final t = b;
        b = c;
        c = t;
      }
      if (a > b) {
        final t = a;
        a = b;
        b = t;
      }
      chave = (a * n + b) * n + c;
    } else {
      chave = ([...nova]..sort()).join(',');
    }
    if (!vistas.add(chave)) continue;
    novasFaces.add(nova);
  }

  if (novasFaces.isEmpty) return mesh;
  if (novasFaces.length > faces.length * (1 - ganhoMinimo)) return mesh;
  return Element3DMesh(novosVerts, novasFaces);
}

/// Os dois LODs de uma malha importada: medio e baixo.
///
/// A grade e escolhida pelo tamanho da malha: quanto mais triangulos,
/// mais celulas — o objetivo e o medio ficar perto de metade e o baixo
/// perto de um quarto, sem cair abaixo do que ainda parece o objeto.
({Element3DMesh medio, Element3DMesh baixo}) gerarLods(Element3DMesh mesh) {
  final faces = mesh.faces.length;
  if (faces < 2000) return (medio: mesh, baixo: mesh);
  // Superficie ~ celulas^2 * 6 * 2 triangulos: para metade das faces,
  // celulas ~ sqrt(faces / 24); para um quarto, sqrt(faces / 48).
  final medioCelulas = math.sqrt(faces / 24).round().clamp(12, 256);
  final baixoCelulas = math.sqrt(faces / 96).round().clamp(8, 128);
  final medio = simplificarPorGrade(mesh, celulas: medioCelulas);
  final baixo = simplificarPorGrade(mesh, celulas: baixoCelulas);
  return (medio: medio, baixo: baixo);
}

/// Area total das faces (triangulando em leque) — a medida de quanto da
/// superficie um LOD conservou.
double areaDaMalha(Element3DMesh mesh) {
  var area = 0.0;
  for (final f in mesh.faces) {
    for (var i = 1; i + 1 < f.length; i++) {
      final a = mesh.verts[f[0]],
          b = mesh.verts[f[i]],
          c = mesh.verts[f[i + 1]];
      final ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      final vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      final wx = uy * vz - uz * vy,
          wy = uz * vx - ux * vz,
          wz = ux * vy - uy * vx;
      area += math.sqrt(wx * wx + wy * wy + wz * wz) / 2;
    }
  }
  return area;
}
