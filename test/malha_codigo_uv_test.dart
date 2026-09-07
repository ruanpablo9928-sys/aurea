import 'dart:ui';

import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/projects/domain/malha_codigo.dart';
import 'package:flutter_test/flutter_test.dart';

/// UV E TUDO OU NADA DENTRO DE UMA PRIMITIVA.
///
/// Quem desenha le `uv[i]` para cada posicao. Uma lista de uv mais curta
/// que a de posicoes nao falha na montagem: falha DEPOIS, dentro do
/// motor, com um RangeError que nao diz de onde veio. Isso aconteceu de
/// verdade — o caule da FLOR nao passava uv e as sepalas passavam, e as
/// duas partes dividiam o mesmo material.
void main() {
  const p = Vec3(1, 2, 3);
  const n = Vec3(0, 1, 0);

  List<dynamic> primitivas(MalhaCodigo m) =>
      m.asset('teste').data['primitives'] as List;

  test('ninguem passou uv: a chave nem aparece', () {
    final m = MalhaCodigo([materialCodigo('A', 0xffffffff)]);
    m.vertice(0, p, n);
    m.vertice(0, p, n);
    expect(primitivas(m).single.containsKey('uv'), isFalse);
  });

  test('todos passaram uv: uma por vertice', () {
    final m = MalhaCodigo([materialCodigo('A', 0xffffffff)]);
    m.vertice(0, p, n, uv: const Offset(.1, .2));
    m.vertice(0, p, n, uv: const Offset(.3, .4));
    final prim = primitivas(m).single;
    expect((prim['uv'] as List), hasLength(2));
    expect((prim['positions'] as List), hasLength(2));
  });

  test('sem uv e depois com uv: o que ficou para tras e preenchido', () {
    final m = MalhaCodigo([materialCodigo('A', 0xffffffff)]);
    m.vertice(0, p, n);
    m.vertice(0, p, n);
    m.vertice(0, p, n, uv: const Offset(.5, .6));
    final prim = primitivas(m).single;
    expect((prim['uv'] as List), hasLength(3));
    expect((prim['uv'] as List)[2], [.5, .6]);
  });

  test('com uv e depois sem uv: o que chega depois ganha (0,0)', () {
    final m = MalhaCodigo([materialCodigo('A', 0xffffffff)]);
    m.vertice(0, p, n, uv: const Offset(.5, .6));
    m.vertice(0, p, n);
    final prim = primitivas(m).single;
    expect((prim['uv'] as List), hasLength(2));
    expect((prim['uv'] as List)[1], [0.0, 0.0]);
  });

  test('cada material tem a sua conta, sem contaminar o vizinho', () {
    final m = MalhaCodigo([
      materialCodigo('Com uv', 0xffffffff),
      materialCodigo('Sem uv', 0xffffffff),
    ]);
    m.vertice(0, p, n, uv: const Offset(.1, .1));
    m.vertice(1, p, n);
    m.vertice(1, p, n);
    final prims = primitivas(m);
    final comUv = prims.firstWhere((x) => x['material'] == 0);
    final semUv = prims.firstWhere((x) => x['material'] == 1);
    expect((comUv['uv'] as List), hasLength(1));
    expect(semUv.containsKey('uv'), isFalse);
  });

  test('a invariante que importa: uv, quando existe, cobre tudo', () {
    final m = MalhaCodigo([materialCodigo('A', 0xffffffff)]);
    for (var i = 0; i < 7; i++) {
      m.vertice(0, p, n, uv: i.isEven ? Offset(i * .1, 0) : null);
    }
    final prim = primitivas(m).single;
    expect(
      (prim['uv'] as List).length,
      (prim['positions'] as List).length,
      reason: 'lista de uv mais curta que a de posicoes vira RangeError '
          'na hora de desenhar, longe daqui',
    );
  });
}
