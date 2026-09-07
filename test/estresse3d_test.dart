import 'package:aurea/src/features/editor/domain/estresse3d.dart';
import 'package:aurea/src/features/editor/domain/orcamento_render.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

/// AS NOVE CENAS DO ESTRESSE PEDEM O QUE O PEDIDO PEDIU.
///
/// O teste de verdade roda no aparelho (Ajustes > Cena 3D > Teste de
/// estresse). O que se fixa aqui e que cada cena mira o recurso certo —
/// cem objetos sao cem chamadas, o milhao e um milhao, sete sombras sao
/// sete — e que o orcamento as reconhece como o que sao.
void main() {
  test('sao nove, na ordem do pedido, com o que cada uma promete', () {
    final r = receitasDeEstresse(texturas: ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(r, hasLength(9));
    expect([for (final x in r) x.id], TesteDeEstresse.values);
    expect([for (final x in r) x.numero], [1, 2, 3, 4, 5, 6, 7, 8, 9]);
    expect(r[5].video, isTrue);
    expect(r[6].motionGraph, isTrue);
    expect(r[7].video && r[7].texto && r[7].efeitos, isTrue);
    expect(r[8].video && r[8].texto && r[8].efeitos && r[8].motionGraph, isTrue);
  });

  test('TESTE 1: cem objetos, cem chamadas', () {
    final cena = cenaObjetos100();
    expect(cena.nodes, hasLength(100));
    final p = PerfilDaCena.de(cena);
    expect(p.chamadas, 100);
    expect(p.direcionalComSombra, isTrue);
  });

  test('TESTE 2: um milhao de poligonos numa malha so', () {
    final cena = cenaPoligonos1M();
    expect(cena.nodes, hasLength(1));
    final tri = triangulosDe(cena.nodes.single.mesh!);
    expect(tri, greaterThanOrEqualTo(1000000));
    final p = PerfilDaCena.de(cena, lod: MeshLod3D.high);
    expect(p.triangulos, tri);
    // A conta reconhece o peso: a geometria sozinha passa de 100 MB.
    final e = estimarGpu(
      perfil: p,
      receita: ReceitaDeQualidade.alta,
      larguraPx: 1080,
      alturaPx: 1920,
    );
    expect(e.geometria, greaterThan(100 * 1024 * 1024));
  });

  test('TESTE 3: seis texturas, uma por objeto', () {
    final caminhos = [for (var i = 0; i < 6; i++) '/tmp/tex_$i.png'];
    final cena = cenaTexturasGrandes(caminhos);
    expect(PerfilDaCena.de(cena).texturas, 6);
    // Sem arquivos, o teste vale como seis objetos.
    expect(PerfilDaCena.de(cenaTexturasGrandes(const [])).texturas, 0);
  });

  test('TESTE 4: uma direcional, seis spots e oito pontuais; sete sombras', () {
    final cena = cenaLuzesESombras();
    expect(cena.lights.where((l) => l.kind == Light3DKind.directional), hasLength(1));
    expect(cena.lights.where((l) => l.kind == Light3DKind.spot), hasLength(6));
    expect(cena.lights.where((l) => l.kind == Light3DKind.point), hasLength(8));
    expect(cena.lights.where((l) => l.castsShadow), hasLength(7));
    final p = PerfilDaCena.de(cena);
    expect(p.spotsComSombra, 6);
    // Em "alta" so dois spots ganham sombra; em "ultra", quatro.
    expect(
      estimarGpu(perfil: p, receita: ReceitaDeQualidade.alta, larguraPx: 10, alturaPx: 10)
          .spotsComSombra,
      2,
    );
    expect(
      estimarGpu(perfil: p, receita: ReceitaDeQualidade.ultra, larguraPx: 10, alturaPx: 10)
          .spotsComSombra,
      4,
    );
  });

  test('TESTE 5: sessenta objetos animados, com emissivo', () {
    final cena = cenaPbrAnimada();
    expect(cena.nodes, hasLength(60));
    expect(cena.nodes.every((n) => n.y.isAnimated && n.rotX.isAnimated), isTrue);
    expect(PerfilDaCena.de(cena).emissiva, isTrue);
  });

  test('TESTE 9: a soma de tudo, e a mais cara de todas', () {
    final texturas = [for (var i = 0; i < 6; i++) '/tmp/tex_$i.png'];
    final extrema = PerfilDaCena.de(cenaExtrema(texturas), lod: MeshLod3D.high);
    expect(extrema.triangulos, greaterThanOrEqualTo(1000000));
    expect(extrema.spotsComSombra, 6);
    expect(extrema.texturas, 6);
    expect(extrema.emissiva, isTrue);
    int custo(PerfilDaCena p) => estimarGpu(
      perfil: p,
      receita: ReceitaDeQualidade.alta,
      larguraPx: 1080,
      alturaPx: 1920,
    ).total;
    for (final outra in [
      cenaObjetos100(),
      cenaLuzesESombras(),
      cenaPbrAnimada(),
      cenaTexturasGrandes(texturas),
    ]) {
      expect(custo(extrema), greaterThan(custo(PerfilDaCena.de(outra))));
    }
  });

  test('a esfera UV tem a contagem prometida', () {
    final m = esferaUV(16, 12);
    expect(triangulosDe(m), 16 * (12 - 2) * 2 + 2 * 16);
    expect(m.verts, hasLength(16 * 11 + 2));
  });
}
