import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/domain/am_sections.dart';
import 'package:aurea/src/features/editor/domain/glb_import.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape_library.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_acceptance_catalog.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_level.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_mesh_seed.dart';

const _d = Duration(seconds: 4);

/// Uma de cada tipo — a grade precisa se comportar para todas.
List<Layer> _todasAsCamadas() => [
      VideoLayer(name: 'v', startTime: Duration.zero, duration: _d,
          sourcePath: '/tmp/v.mp4'),
      ImageLayer(name: 'i', startTime: Duration.zero, duration: _d,
          sourcePath: '/tmp/i.png'),
      TextLayer(name: 't', startTime: Duration.zero, duration: _d, text: 'oi'),
      ShapeLayer(name: 's', startTime: Duration.zero, duration: _d,
          contents: ShapeLibrary.roundedSquare()),
      GroupLayer(name: 'g', startTime: Duration.zero, duration: _d),
      CaptionLayer(name: 'l', startTime: Duration.zero, duration: _d),
      AudioLayer(name: 'a', startTime: Duration.zero, duration: _d,
          sourcePath: '/tmp/a.wav'),
      NullLayer(name: 'n', startTime: Duration.zero, duration: _d),
      ParticlesLayer(name: 'p', startTime: Duration.zero, duration: _d),
      Element3DLayer(name: 'e', startTime: Duration.zero, duration: _d),
      Scene3DLayer(name: 'c', startTime: Duration.zero, duration: _d),
      AdjustmentLayer(name: 'j', startTime: Duration.zero, duration: _d),
    ];

void main() {
  group('Nivel 10.1 - a grade nao cresce', () {
    test('nenhum tipo de camada ve mais de sete secoes', () {
      // O teto e por TIPO, nao no total de nomes: uma secao que so existe
      // para um tipo de camada e a saida que a propria regra preve.
      for (final camada in _todasAsCamadas()) {
        expect(AmNiveis.tudo.visiveisPara(camada).length,
            lessThanOrEqualTo(kAmMaximoSecoes),
            reason: '${camada.runtimeType}');
      }
    });

    test('com os dez niveis ligados nenhum tipo passa de sete', () {
      for (final camada in _todasAsCamadas()) {
        final secoes = AmNiveis.tudo.visiveisPara(camada);
        expect(secoes.length, lessThanOrEqualTo(kAmMaximoSecoes),
            reason: '${camada.runtimeType} estourou a grade');
      }
    });

    test('no Nucleo puro a grade e movimentacao e opacidade', () {
      for (final camada in _todasAsCamadas()) {
        final secoes = AmNiveis.nucleo.visiveisPara(camada);
        expect(secoes, contains(AmSecao.moverTransformar));
        expect(secoes.length, lessThanOrEqualTo(2));
        expect(secoes.any((s) =>
            s != AmSecao.moverTransformar && s != AmSecao.mesclarOpacidade),
            isFalse);
      }
    });

    test('nenhuma camada fica sem secao nenhuma', () {
      for (final niveis in [AmNiveis.nucleo, AmNiveis.tudo]) {
        for (final camada in _todasAsCamadas()) {
          expect(niveis.visiveisPara(camada), isNotEmpty,
              reason: '${camada.runtimeType} abriria um menu vazio');
        }
      }
    });

    test('a ordem da grade nao muda quando o tipo muda', () {
      for (final camada in _todasAsCamadas()) {
        final secoes = AmNiveis.tudo.visiveisPara(camada).toList();
        final indices = [for (final s in secoes) AmSecao.values.indexOf(s)];
        final ordenado = [...indices]..sort();
        expect(indices, ordenado,
            reason: '${camada.runtimeType} reordenou a grade');
      }
    });
  });

  group('Nivel 10.1 - nada inerte', () {
    test('Editar forma so aparece na forma, e so com o nivel 1 ligado', () {
      for (final camada in _todasAsCamadas()) {
        expect(AmNiveis.tudo.visiveisPara(camada).contains(AmSecao.editarForma),
            camada is ShapeLayer);
      }
      final forma = ShapeLayer(name: 's', startTime: Duration.zero,
          duration: _d, contents: ShapeLibrary.roundedSquare());
      const semShapes = AmNiveis(text: true, effects: true);
      expect(semShapes.visiveisPara(forma), isNot(contains(AmSecao.editarForma)));
    });

    test('o Nulo nao mostra cor, efeito, borda nem opacidade', () {
      final nulo = NullLayer(name: 'n', startTime: Duration.zero, duration: _d);
      expect(AmNiveis.tudo.visiveisPara(nulo), {AmSecao.moverTransformar});
    });

    test('cor e preenchimento nao aparece em video nem em audio', () {
      for (final camada in _todasAsCamadas()) {
        if (camada is VideoLayer || camada is AudioLayer) {
          expect(AmNiveis.tudo.visiveisPara(camada),
              isNot(contains(AmSecao.corPreenchimento)));
        }
      }
    });

    test('desligar o nivel 3 tira a secao de efeitos de todo mundo', () {
      const semEfeitos = AmNiveis(shapes: true, text: true, masks: true);
      for (final camada in _todasAsCamadas()) {
        expect(semEfeitos.visiveisPara(camada),
            isNot(contains(AmSecao.efeitos)));
      }
    });
  });

  group('Nivel 10.1 no Laboratorio', () {
    test('ligar a UI final liga os dez niveis', () {
      final selecao = LaboratoryLevelSelection().enable(
        LaboratoryLevelId.uiFinal,
      );
      // Os dez sao do 0 ao 9; o 11 vem depois e nao entra por tabela.
      for (final nivel in LaboratoryLevelId.values) {
        if (nivel == LaboratoryLevelId.audio) continue;
        expect(selecao.isEnabled(nivel), isTrue, reason: nivel.name);
      }
      expect(selecao.isEnabled(LaboratoryLevelId.audio), isFalse);
    });

    test('a tarefa cobre os seis parametros medidos em toques', () {
      final tarefa = LaboratoryAcceptanceCatalog.forLevel(
        LaboratoryLevelId.uiFinal,
      );
      final texto = tarefa.steps.map((s) => s.instruction).join(' ');
      for (final alvo in [
        'raio',
        'limiar',
        'feather',
        'duracao',
        'contagem',
        'rugosidade',
      ]) {
        expect(texto, contains(alvo), reason: 'falta medir $alvo');
      }
      expect(texto, contains('cinco'));
      expect(texto, contains('sete'));
    });

    test('todo nivel do catalogo tem tarefa de aceite', () {
      for (final nivel in LaboratoryLevelId.values) {
        expect(() => LaboratoryAcceptanceCatalog.forLevel(nivel),
            returnsNormally, reason: nivel.name);
      }
    });
  });

  group('Ativos 3D gerados', () {
    test('a esfera pequena e um .glb valido de aproximadamente 3 MB', () {
      final bytes = gerarEsferaGlb(bytesAlvo: 3000000);
      expect(bytes.length, greaterThan(2500000));
      expect(bytes.length, lessThan(3500000));
      final r = parseGlb(Uint8List.fromList(bytes));
      expect(r.triangles, trianguloDaEsfera(3000000));
      expect(r.mesh.verts, isNotEmpty);
      expect(r.mesh.faces, isNotEmpty);
    });

    test('a esfera grande chega perto dos 40 MB sem passar', () {
      final bytes = gerarEsferaGlb(bytesAlvo: 40000000);
      expect(bytes.length, greaterThan(35000000));
      expect(bytes.length, lessThan(45000000));
      // Cabecalho glTF: "glTF" e versao 2.
      final v = ByteData.view(Uint8List.fromList(bytes.sublist(0, 12)).buffer);
      expect(v.getUint32(0, Endian.little), 0x46546C67);
      expect(v.getUint32(4, Endian.little), 2);
      expect(v.getUint32(8, Endian.little), bytes.length);
    });
  });
}
