// O MODELO IMPORTADO NAO PODE SER REAVALIADO A TOA.
//
// `ModelAsset3D.evaluate` refaz a pose sobre TODOS os vertices, em Dart,
// no mesmo fio que recebe o toque. Num modelo importado isso e perto de
// dois segundos de tela parada — foi o que o registro de travadas do
// iPhone 13 mostrou: 1.800 ms em "constroi" com "desenha" em zero.
//
// Por isso existe um cache do ultimo quadro avaliado. Ele so servia
// quando o objeto de animacao era o MESMO objeto (`identical`). Como o
// no e imutavel, qualquer reconstrucao trazia um objeto novo com as
// MESMAS configuracoes, o cache errava, e o modelo inteiro era refeito.
//
// Agora a comparacao e por VALOR. Este teste cobra isso onde importa:
// mesma animacao com objeto diferente tem de reaproveitar; animacao
// realmente diferente tem de reavaliar.
import 'package:aurea/src/features/editor/domain/model_asset3d.dart';
import 'package:flutter_test/flutter_test.dart';

ModelAsset3D _modelo() {
  const triangulos = 40;
  // Cada posicao e um vetor [x, y, z] — e assim que o importador guarda.
  final positions = <List<double>>[];
  final indices = <int>[];
  for (var i = 0; i < triangulos * 3; i++) {
    final f = i / (triangulos * 3);
    positions.add([f, f * 2, f * 3]);
    indices.add(i);
  }
  return ModelAsset3D({
    'version': 1,
    'format': 'gltf2',
    'name': 'Modelo',
    'nodes': [
      {'name': 'raiz'},
    ],
    'primitives': [
      {'node': 0, 'positions': positions, 'indices': indices, 'material': 0},
    ],
    'skins': <dynamic>[],
    'clips': <dynamic>[],
    'materials': <dynamic>[],
    'warnings': <dynamic>[],
  });
}

void main() {
  test('a MESMA animacao noutro objeto reaproveita o quadro', () {
    final asset = _modelo();
    const t = Duration(milliseconds: 500);
    final primeiro = asset.evaluate(t, const ModelMotion3D());
    // Um objeto NOVO, com exatamente as mesmas configuracoes: e o que
    // um no reconstruido produz a cada edicao.
    final segundo = asset.evaluate(t, const ModelMotion3D());
    expect(
      identical(primeiro, segundo),
      isTrue,
      reason:
          'o modelo foi reavaliado por causa de um objeto de animacao '
          'novo com o mesmo conteudo: e isso que trava o aparelho',
    );
  });

  test('animacao DIFERENTE reavalia', () {
    final asset = _modelo();
    const t = Duration(milliseconds: 500);
    final primeiro = asset.evaluate(t, const ModelMotion3D());
    final segundo = asset.evaluate(t, const ModelMotion3D(offset: 2, speed: 3));
    expect(
      identical(primeiro, segundo),
      isFalse,
      reason: 'mudar a animacao TEM de refazer a pose',
    );
  });

  group('a igualdade por valor, campo a campo', () {
    test('iguais quando tudo bate', () {
      expect(const ModelMotion3D(), const ModelMotion3D());
      expect(
        const ModelMotion3D(clip: 2, speed: 1.5, offset: .25, loop: false),
        const ModelMotion3D(clip: 2, speed: 1.5, offset: .25, loop: false),
      );
    });

    test('diferentes quando qualquer campo muda', () {
      const base = ModelMotion3D();
      expect(base == const ModelMotion3D(clip: 1), isFalse);
      expect(base == const ModelMotion3D(speed: 2), isFalse);
      expect(base == const ModelMotion3D(offset: 1), isFalse);
      expect(base == const ModelMotion3D(loop: false), isFalse);
    });

    test('as chaves de pose entram na conta', () {
      final comChave = ModelMotion3D(
        keys: [
          ModelPoseKey3D(0.5, {
            1: const ModelPose3D(translation: [1, 2, 3]),
          }),
        ],
      );
      final igual = ModelMotion3D(
        keys: [
          ModelPoseKey3D(0.5, {
            1: const ModelPose3D(translation: [1, 2, 3]),
          }),
        ],
      );
      final diferente = ModelMotion3D(
        keys: [
          ModelPoseKey3D(0.5, {
            1: const ModelPose3D(translation: [1, 2, 9]),
          }),
        ],
      );
      expect(comChave, igual);
      expect(comChave == diferente, isFalse);
      expect(comChave == const ModelMotion3D(), isFalse);
    });
  });
}
