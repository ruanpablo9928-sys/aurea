import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/estresse3d.dart';
import 'package:aurea/src/features/editor/domain/lod3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// O LOD NAO PODE FURAR A MALHA.
///
/// O de antes descartava uma face a cada duas: metade da superficie
/// sumia. O agrupamento por grade reescreve TODAS as faces com vertices
/// agrupados — a superficie continua fechada, so mais grossa. O que se
/// prova aqui e a area conservada, contra o metodo antigo.
void main() {
  Element3DMesh porDescarte(Element3DMesh m, int stride) => Element3DMesh(
    m.verts,
    [for (var i = 0; i < m.faces.length; i += stride) m.faces[i]],
  );

  group('agrupamento por grade', () {
    final esfera = esferaUV(64, 48); // ~6 mil triangulos

    test('reduz os triangulos e conserva a superficie', () {
      final lod = simplificarPorGrade(esfera, celulas: 12);
      expect(lod.faces.length, lessThan(esfera.faces.length ~/ 2));
      final areaOriginal = areaDaMalha(esfera);
      final areaLod = areaDaMalha(lod);
      final areaDescarte = areaDaMalha(porDescarte(esfera, 2));
      expect(areaLod, greaterThan(areaOriginal * 0.8),
          reason: 'a esfera grossa continua uma esfera fechada');
      expect(areaDescarte, closeTo(areaOriginal / 2, areaOriginal * 0.05),
          reason: 'o metodo antigo joga fora metade da superficie');
      expect(areaLod, greaterThan(areaDescarte));
    });

    test('toda face e valida: tres cantos distintos, indices no alcance', () {
      final lod = simplificarPorGrade(esfera, celulas: 10);
      for (final f in lod.faces) {
        expect(f.length, greaterThanOrEqualTo(3));
        expect(f.toSet().length, f.length, reason: 'canto repetido em $f');
        for (final i in f) {
          expect(i, inInclusiveRange(0, lod.verts.length - 1));
        }
      }
      // Nenhum vertice sobra sem uso.
      final usados = {for (final f in lod.faces) ...f};
      expect(usados.length, lod.verts.length);
    });

    test('a caixa da malha nao cresce', () {
      final lod = simplificarPorGrade(esfera, celulas: 8);
      for (final v in lod.verts) {
        for (var i = 0; i < 3; i++) {
          expect(v[i].abs(), lessThanOrEqualTo(1.0 + 1e-9));
        }
      }
    });

    test('malha pequena ou ganho pequeno: devolve a propria malha', () {
      final cubo = element3DMesh(Element3DKind.cube);
      expect(identical(simplificarPorGrade(cubo, celulas: 64), cubo), isTrue);
      final lods = gerarLods(esferaUV(16, 12));
      expect(identical(lods.medio, lods.baixo), isTrue);
    });

    test('os dois LODs de uma malha grande: medio maior que baixo', () {
      final lods = gerarLods(esfera);
      expect(lods.medio.faces.length, lessThan(esfera.faces.length));
      expect(lods.baixo.faces.length, lessThan(lods.medio.faces.length));
      expect(areaDaMalha(lods.baixo), greaterThan(areaDaMalha(esfera) * 0.6));
    });

    test('faces repetidas viram uma', () {
      // Duas faces que apontam para os mesmos tres vertices depois do
      // agrupamento sao uma so.
      final m = Element3DMesh(
        [
          [0, 0, 0],
          [1, 0, 0],
          [0, 1, 0],
          [0.01, 0.01, 0], // cai na celula do primeiro
        ],
        [
          [0, 1, 2],
          [3, 1, 2],
        ],
      );
      final lod = simplificarPorGrade(m, celulas: 4, ganhoMinimo: 0);
      expect(lod.faces, hasLength(1));
    });
  });
}
