/// A MALHA DO DOMINIO VIRANDO BUFFERS DE GPU — em memoria tipada.
///
/// O que existia montava cada grupo em `List<double>` crescendo por
/// `addAll([x, y, z])`: cada numero era um objeto no heap (16 bytes),
/// cada canto de triangulo criava tres listas, e no fim tudo era copiado
/// para `Float32List`. Um modelo de um milhao de triangulos passava de
/// 400 MB de heap transitorio so para abrir — no iPhone 13, e o jetsam
/// matando o app antes do primeiro quadro.
///
/// Aqui os grupos crescem em `Float32List`/`Uint32List` (32 bytes por
/// vertice, 4 por indice), sem lista intermediaria, e os vertices lisos
/// sao reaproveitados por um mapa em `Int32List`. O ALGORITMO e o mesmo:
/// normal de Newell por face, ordem dos vertices corrigida pela normal,
/// UV do modelo quando existe e projecao planar pelo eixo dominante
/// quando nao — o teste de equivalencia prova que os arrays saem iguais.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'element3d.dart';
import 'scene3d.dart';

/// Um grupo de faces de um mesmo material: uma primitiva, uma chamada.
class GrupoGpu {
  GrupoGpu(this.material, {int capacidadeInicial = 256})
    : _pos = Float32List(capacidadeInicial * 3),
      _nor = Float32List(capacidadeInicial * 3),
      _uv = Float32List(capacidadeInicial * 2),
      _idx = Uint32List(capacidadeInicial * 3);

  final Material3D material;
  Float32List _pos, _nor, _uv;
  Uint32List _idx;
  int _vertices = 0;
  int _indices = 0;

  /// Vertice de origem -> indice neste grupo (so nas malhas lisas).
  Int32List? _mapa;

  int get vertices => _vertices;
  int get indices => _indices;
  int get triangulos => _indices ~/ 3;

  Float32List get positions => Float32List.sublistView(_pos, 0, _vertices * 3);
  Float32List get normals => Float32List.sublistView(_nor, 0, _vertices * 3);
  Float32List get texCoords => Float32List.sublistView(_uv, 0, _vertices * 2);
  Uint32List get indexList => Uint32List.sublistView(_idx, 0, _indices);

  int _adicionar(
    double px,
    double py,
    double pz,
    double nx,
    double ny,
    double nz,
    double u,
    double v,
  ) {
    if (_vertices * 3 + 3 > _pos.length) {
      final novoCap = _vertices * 2 + 64;
      _pos = _crescer(_pos, novoCap * 3);
      _nor = _crescer(_nor, novoCap * 3);
      _uv = _crescer(_uv, novoCap * 2);
    }
    final p = _vertices * 3;
    _pos[p] = px;
    _pos[p + 1] = py;
    _pos[p + 2] = pz;
    _nor[p] = nx;
    _nor[p + 1] = ny;
    _nor[p + 2] = nz;
    final t = _vertices * 2;
    _uv[t] = u;
    _uv[t + 1] = v;
    return _vertices++;
  }

  void _indice(int i) {
    if (_indices + 1 > _idx.length) {
      final novo = Uint32List(_idx.length * 2 + 64);
      novo.setRange(0, _indices, _idx);
      _idx = novo;
    }
    _idx[_indices++] = i;
  }

  static Float32List _crescer(Float32List antigo, int tamanho) {
    final novo = Float32List(tamanho);
    novo.setRange(0, antigo.length, antigo);
    return novo;
  }
}

/// A caixa da malha, para a projecao planar de UV.
class CaixaDaMalha {
  CaixaDaMalha(this.lo, this.hi);

  final List<double> lo;
  final List<double> hi;

  static CaixaDaMalha de(Element3DMesh m) {
    final lo = [double.infinity, double.infinity, double.infinity];
    final hi = [-double.infinity, -double.infinity, -double.infinity];
    for (final v in m.verts) {
      for (var i = 0; i < 3; i++) {
        if (v[i] < lo[i]) lo[i] = v[i];
        if (v[i] > hi[i]) hi[i] = v[i];
      }
    }
    return CaixaDaMalha(lo, hi);
  }

  double faixa(double v, int eixo) {
    final d = hi[eixo] - lo[eixo];
    return d <= 1e-9 ? 0.5 : (v - lo[eixo]) / d;
  }
}

/// Monta os grupos por material de [malha].
///
/// [materiais] tem um material por face. [normais] e [uvs] sao por
/// vertice (modelos importados); quando todos os vertices tem normal, a
/// malha e LISA e os vertices sao compartilhados entre faces vizinhas.
Map<Material3D, GrupoGpu> montarGruposGpu({
  required Element3DMesh malha,
  required List<Material3D> materiais,
  List<Vec3?>? normais,
  List<Offset?>? uvs,
}) {
  final grupos = <Material3D, GrupoGpu>{};
  final verts = malha.verts;
  final lisa =
      normais != null &&
      normais.length == verts.length &&
      normais.every((n) => n != null);
  final caixa = CaixaDaMalha.de(malha);

  // UV de um vertice: a do modelo, ou a projecao planar pelo eixo
  // dominante da normal da face, normalizada pela caixa.
  double u = 0, v = 0;
  void uvDe(int vi, List<double> p, double nx, double ny, double nz) {
    if (uvs != null && vi < uvs.length && uvs[vi] != null) {
      u = uvs[vi]!.dx;
      v = uvs[vi]!.dy;
      return;
    }
    final ax = nx.abs(), ay = ny.abs(), az = nz.abs();
    if (ax >= ay && ax >= az) {
      u = caixa.faixa(p[2], 2);
      v = caixa.faixa(p[1], 1);
    } else if (ay >= ax && ay >= az) {
      u = caixa.faixa(p[0], 0);
      v = caixa.faixa(p[2], 2);
    } else {
      u = caixa.faixa(p[0], 0);
      v = caixa.faixa(p[1], 1);
    }
  }

  for (var f = 0; f < malha.faces.length; f++) {
    final face = malha.faces[f];
    if (face.length < 3) continue;
    final material = materiais[f];
    final grupo = grupos[material] ??= GrupoGpu(
      material,
      capacidadeInicial: math.max(256, math.min(1 << 16, malha.faces.length)),
    );

    // Normal da face (Newell): decide o lado e serve as faces planas.
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (var i = 0; i < face.length; i++) {
      final a = verts[face[i]], b = verts[face[(i + 1) % face.length]];
      nx += (a[1] - b[1]) * (a[2] + b[2]);
      ny += (a[2] - b[2]) * (a[0] + b[0]);
      nz += (a[0] - b[0]) * (a[1] + b[1]);
    }
    final len = math.sqrt(nx * nx + ny * ny + nz * nz);
    if (len < 1e-12) continue;
    nx /= len;
    ny /= len;
    nz /= len;

    for (var i = 1; i < face.length - 1; i++) {
      var ia = face[0], ib = face[i], ic = face[i + 1];
      // O motor descarta a face de costas pela ordem dos vertices; a
      // normal manda: se a ordem discorda dela, inverte.
      final a = verts[ia], b = verts[ib], c = verts[ic];
      final ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
      final vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
      final wx = uy * vz - uz * vy, wy = uz * vx - ux * vz, wz = ux * vy - uy * vx;
      if (wx * nx + wy * ny + wz * nz < 0) {
        final tmp = ib;
        ib = ic;
        ic = tmp;
      }
      for (final vi in [ia, ib, ic]) {
        final p = verts[vi];
        if (lisa) {
          final mapa = grupo._mapa ??= Int32List(verts.length)..fillRange(0, verts.length, -1);
          var idx = mapa[vi];
          if (idx < 0) {
            final n = normais[vi]!;
            uvDe(vi, p, nx, ny, nz);
            idx = grupo._adicionar(p[0], p[1], p[2], n.x, n.y, n.z, u, v);
            mapa[vi] = idx;
          }
          grupo._indice(idx);
        } else {
          uvDe(vi, p, nx, ny, nz);
          grupo._indice(grupo._adicionar(p[0], p[1], p[2], nx, ny, nz, u, v));
        }
      }
    }
  }
  return grupos;
}
