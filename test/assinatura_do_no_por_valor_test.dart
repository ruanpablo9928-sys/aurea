// RECONSTRUIR O WIDGET NAO PODE RECONSTRUIR O MODELO NA GPU.
//
// A assinatura de um no decide, em `_sincronizarNos`, se ele e apenas
// atualizado ou se e DESTRUIDO E REFEITO na GPU. Refazer um modelo
// importado quer dizer alocar e subir buffers de dezenas de milhares de
// vertices — no fio da interface, o mesmo que recebe o toque.
//
// A assinatura usava `identityHashCode(motion)`. Como o no e imutavel,
// qualquer reconstrucao traz um `ModelMotion3D` novo com o mesmo
// conteudo: objeto novo, hash de identidade novo, assinatura nova, no
// inteiro refeito a cada edicao.
//
// E o MESMO defeito que ja tinha sido encontrado no cache do `evaluate`
// e corrigido la com igualdade por valor. Aqui ele tinha sobrado, um
// andar acima — e um andar acima custa mais caro.
import 'dart:ui' show Color;

import 'package:aurea/src/features/editor/application/fonte_de_malha.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/model_asset3d.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';

ModelAsset3D _modelo() {
  const triangulos = 60;
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
    'name': 'Importado',
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

String? _assinaturaDe(SceneNode node) => CacheDeMalhas()
    .doNo(
      node,
      Duration.zero,
      lodDaReceita: (n) => n.mesh,
      assinaturaDoMaterial: (m) => '${m.baseColor.toARGB32()}',
    )
    ?.assinatura;

void main() {
  test('o mesmo no reconstruido mantem a assinatura', () {
    final asset = _modelo();
    // Dois nos identicos em conteudo, com objetos de animacao
    // diferentes: e o que uma reconstrucao de widget produz.
    // SEM `const`: o Dart canoniza constantes iguais no mesmo objeto, e
    // com o mesmo objeto o teste passaria mesmo com o defeito de volta.
    SceneNode no() => SceneNode(
      id: 'no',
      name: 'Importado',
      size: 300,
      modelAsset: asset,
      modelMotion: ModelMotion3D(clip: 0, speed: 1, keys: [ModelPoseKey3D(0, const {})]),
    );
    final a = no();
    final b = no();
    expect(
      identical(a.modelMotion, b.modelMotion),
      isFalse,
      reason: 'o teste so vale se os objetos de animacao forem diferentes',
    );
    expect(
      _assinaturaDe(a),
      _assinaturaDe(b),
      reason:
          'a assinatura mudou sem nada ter mudado: no aparelho isso e o '
          'modelo inteiro derrubado e resubido para a GPU a cada edicao',
    );
  });

  test('mudar a animacao MUDA a assinatura', () {
    final asset = _modelo();
    SceneNode com(ModelMotion3D m) => SceneNode(
      id: 'no',
      name: 'Importado',
      size: 300,
      modelAsset: asset,
      modelMotion: m,
    );
    final base = _assinaturaDe(com(const ModelMotion3D()));
    expect(base, isNot(_assinaturaDe(com(const ModelMotion3D(clip: 1)))));
    expect(base, isNot(_assinaturaDe(com(const ModelMotion3D(speed: 2)))));
    expect(base, isNot(_assinaturaDe(com(const ModelMotion3D(offset: 1)))));
  });

  test('mudar o material MUDA a assinatura', () {
    final asset = _modelo();
    // `useModelMaterials` falso: o material do NO passa a valer, e e por
    // isso que ele entra na assinatura. Ligado, quem manda sao os
    // materiais do proprio modelo e o do no nao muda nada — o que a
    // assinatura ja dizia com o sufixo `a`.
    SceneNode com(Material3D m) => SceneNode(
      id: 'no',
      name: 'Importado',
      size: 300,
      modelAsset: asset,
      material: m,
      useModelMaterials: false,
    );
    expect(
      _assinaturaDe(com(const Material3D(baseColor: Color(0xFF112233)))),
      isNot(_assinaturaDe(com(const Material3D(baseColor: Color(0xFF445566))))),
    );
  });

  test('a malha de um no parado e reaproveitada, e nao refeita', () {
    final cache = CacheDeMalhas();
    final node = SceneNode(
      id: 'no',
      name: 'Importado',
      size: 300,
      modelAsset: _modelo(),
    );
    MalhaDoNo? pedir() => cache.doNo(
      node,
      const Duration(milliseconds: 500),
      lodDaReceita: (n) => n.mesh,
      assinaturaDoMaterial: (m) => '${m.baseColor.toARGB32()}',
    );
    final primeira = pedir();
    final segunda = pedir();
    expect(
      identical(primeira, segunda),
      isTrue,
      reason: 'um no parado refez a malha inteira sem motivo',
    );
  });
}
