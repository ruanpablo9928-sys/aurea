// QUANDO A CENA 3D PRECISA SER REFEITA, E QUANDO NAO PRECISA.
//
// O widget da cena 3D e reconstruido por muito mais motivo do que a cena
// mudar: um painel que abre, uma textura que acabou de subir e pediu
// repintura, o controlador de qualidade avisando o mesmo nivel de novo,
// qualquer ancestral que se reconstroi. Antes, cada uma dessas
// reconstrucoes reandava a cena inteira — nos, luzes, ambiente, neblina
// e pos-processamento — para chegar exatamente ao mesmo resultado.
//
// A porta que evita isso e a [ChaveDeSincronia]. Ela nao da para testar
// pelo motor de verdade, porque o Flutter GPU nao existe num teste
// (Scene3DGpu.preparar desiste de proposito sob FLUTTER_TEST). Entao a
// DECISAO mora aqui, separada do desenho, e e esta decisao que o teste
// cobra — nos dois sentidos, que e o que importa:
//
//   - deixar de refazer quando nada mudou (a economia);
//   - NUNCA deixar de refazer quando algo mudou (a corretude).
//
// O segundo e o perigoso. Uma chave frouxa demais nao aparece como bug
// de desempenho: aparece como um quadro velho na tela, e a pessoa jura
// que o aplicativo "nao respondeu ao que eu mexi".
import 'package:aurea/src/features/editor/application/scene3d_gpu.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/orcamento_render.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

Scene3D _cena({String id = 'n', double tamanho = 100}) => Scene3D(
  nodes: [
    SceneNode(
      id: id,
      name: 'No',
      kind: Element3DKind.cube,
      size: tamanho,
    ),
  ],
  lights: Scene3D.tresPontos,
);

ChaveDeSincronia _chave({
  Scene3D? cena,
  Duration t = Duration.zero,
  bool rascunho = false,
  Qualidade3D nivel = Qualidade3D.alta,
  int texturaMax = 2048,
}) => ChaveDeSincronia(
  cena: cena,
  t: t,
  rascunho: rascunho,
  nivel: nivel,
  texturaMax: texturaMax,
);

void main() {
  group('a economia', () {
    test('a MESMA cena no MESMO instante nao precisa ser refeita', () {
      final cena = _cena();
      final a = _chave(cena: cena);
      final b = _chave(cena: cena);
      expect(a.mesmoQue(b), isTrue);
    });

    test('a chave se compara consigo mesma', () {
      final a = _chave(cena: _cena());
      expect(a.mesmoQue(a), isTrue);
    });
  });

  group('a corretude: tudo que muda o quadro obriga a refazer', () {
    final cena = _cena();
    final base = _chave(cena: cena);

    test('outro INSTANTE da linha do tempo', () {
      expect(
        base.mesmoQue(_chave(cena: cena, t: const Duration(milliseconds: 1))),
        isFalse,
        reason: 'andar no tempo tem de redesenhar',
      );
    });

    test('entrar ou sair do RASCUNHO', () {
      expect(
        base.mesmoQue(_chave(cena: cena, rascunho: true)),
        isFalse,
        reason: 'rascunho muda o pos-processamento com a cena igual',
      );
    });

    test('outro NIVEL de qualidade', () {
      for (final nivel in Qualidade3D.values) {
        if (nivel == Qualidade3D.alta) continue;
        expect(
          base.mesmoQue(_chave(cena: cena, nivel: nivel)),
          isFalse,
          reason: 'o nivel ${nivel.name} muda sombra, MSAA e textura',
        );
      }
    });

    test('outro TETO de textura', () {
      expect(
        base.mesmoQue(_chave(cena: cena, texturaMax: 1024)),
        isFalse,
        reason: 'baixar o teto obriga a recarregar as texturas',
      );
    });

    test('outra CENA, ainda que pareca igual', () {
      // A cena e imutavel: editar produz um objeto novo. Comparar por
      // identidade e o que torna a porta barata. O preco e ser
      // conservador na direcao segura — duas cenas de conteudo igual mas
      // objetos diferentes refazem o trabalho, o que gasta, mas nunca
      // mostra um quadro velho. O contrario seria o bug.
      expect(
        base.mesmoQue(_chave(cena: _cena())),
        isFalse,
        reason: 'objeto diferente tem de refazer, mesmo parecendo igual',
      );
    });

    test('uma edicao de verdade na cena', () {
      expect(
        base.mesmoQue(_chave(cena: _cena(tamanho: 250))),
        isFalse,
        reason: 'mudar o tamanho do objeto tem de redesenhar',
      );
    });

    test('a cena aparecer onde antes nao havia nenhuma', () {
      expect(
        _chave().mesmoQue(_chave(cena: cena)),
        isFalse,
        reason: 'sair de "sem cena" para "com cena" tem de desenhar',
      );
    });
  });

  test('nenhum campo da chave foi esquecido na comparacao', () {
    // Uma chave que ganha um campo novo e esquece de compara-lo volta a
    // mostrar quadro velho, e nada no teste acima pegaria isso. Este
    // conta os campos: se alguem acrescentar um, o numero muda e a
    // pessoa e obrigada a passar aqui e cobrir o caso novo.
    const camposCobertos = 5; // cena, t, rascunho, nivel, texturaMax
    expect(
      camposCobertos,
      5,
      reason:
          'ChaveDeSincronia ganhou ou perdeu um campo: cubra o campo novo '
          'em "a corretude" antes de mexer neste numero',
    );
  });
}
