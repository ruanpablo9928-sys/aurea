// A ESTIMATIVA DE TRIANGULOS ERA CEGA PARA O MODELO IMPORTADO.
//
// `trianglesEstimados` so olhava `node.mesh`. Um no de modelo importado
// tem `mesh` NULO — a geometria mora em `modelAsset` e so vira malha na
// hora de desenhar. A conta caia no valor de primitiva e devolvia 32.
//
// Trinta e dois, para um modelo de sessenta mil faces. Duas coisas
// quebravam por causa disso, e as duas custaram caro:
//
//   1. O teto do pintor de CPU (3.000 faces), entregue no build 66
//      exatamente para proteger contra modelo importado, nunca disparava
//      para modelo importado. A protecao existia e nao protegia nada.
//
//   2. O registro do aparelho vinha com `PINTOU-EM-CPU=32tri` com o
//      modelo inteiro na cena, e eu li isso como "o pintor de CPU esta
//      fora disto".
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/model_asset3d.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:flutter_test/flutter_test.dart';

ModelAsset3D _modeloCom(int triangulos) {
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

Scene3D _cenaCom(ModelAsset3D modelo, {bool rascunho = false}) => Scene3D(
  nodes: [
    SceneNode(id: 'no', name: 'Importado', size: 300, modelAsset: modelo),
  ],
  lights: Scene3D.tresPontos,
  draftMode: rascunho,
);

void main() {
  test('a estimativa conta as faces do modelo importado', () {
    final cena = _cenaCom(_modeloCom(9000));
    expect(
      trianglesEstimados(cena),
      9000,
      reason:
          'com mesh nulo a conta caia na primitiva e devolvia 32 — mil '
          'vezes menos que a cena de verdade',
    );
  });

  test('um modelo pesado estoura o teto do pintor de CPU', () {
    final cena = _cenaCom(_modeloCom(60000));
    expect(
      trianglesEstimados(cena),
      greaterThan(Scene3DPainter.orcamentoDeCpu),
      reason:
          'e este o caso que o teto existe para pegar: se ele nao dispara '
          'aqui, ele nao serve para nada',
    );
  });

  test('a conta respeita o teto de faces que o pintor aplica', () {
    // O pintor corta o modelo em `tetoDeFacesCpu` antes de desenhar. A
    // estimativa tem de contar o que sera desenhado, e nao o arquivo.
    expect(trianglesEstimados(_cenaCom(_modeloCom(90000))), tetoDeFacesCpu);
    expect(
      trianglesEstimados(_cenaCom(_modeloCom(90000), rascunho: true)),
      tetoDeFacesCpuRascunho,
    );
  });

  test('sem modelo importado nada muda', () {
    final malha = Element3DMesh(
      [
        [0.0, 0.0, 0.0],
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
      ],
      [
        [0, 1, 2],
      ],
    );
    final cena = Scene3D(
      nodes: [SceneNode(id: 'n', name: 'N', size: 100, mesh: malha)],
      lights: Scene3D.tresPontos,
    );
    expect(trianglesEstimados(cena), 1);
    final primitiva = Scene3D(
      nodes: [
        SceneNode(
          id: 'p',
          name: 'P',
          size: 100,
          kind: Element3DKind.sphere,
        ),
      ],
      lights: Scene3D.tresPontos,
    );
    expect(
      trianglesEstimados(primitiva),
      facesDaPrimitiva(Element3DKind.sphere),
    );
  });

  test('com o orcamento como teto, UM modelo pesado cabe e e desenhado', () {
    // A DECISAO: decimar ate caber, em vez de recusar a desenhar.
    //
    // O teto do pintor (40 mil) e o orcamento (3 mil) eram dois numeros
    // que nao se falavam. Corrigida a estimativa, TODO modelo importado
    // cairia no substituto — inclusive na tela que existe para mostrar o
    // modelo. Agora o teto e o orcamento, e um modelo de 73 mil faces
    // vira um de 3 mil e aparece.
    const orcamento = Scene3DPainter.orcamentoDeCpu;
    final um = _cenaCom(_modeloCom(73187));
    expect(
      trianglesEstimados(um, teto: orcamento),
      lessThanOrEqualTo(orcamento),
      reason: 'um modelo sozinho sempre cabe: ele e decimado ate caber',
    );
  });

  test('o substituto fica para o que a decimacao NAO resolve', () {
    // Muitos objetos e muitas copias: decimar cada um nao salva a cena,
    // e e para este caso que o substituto foi escrito.
    const orcamento = Scene3DPainter.orcamentoDeCpu;
    final muitos = Scene3D(
      nodes: [
        for (var i = 0; i < 6; i++)
          SceneNode(
            id: 'no$i',
            name: 'Importado $i',
            size: 300,
            modelAsset: _modeloCom(9000),
          ),
      ],
      lights: Scene3D.tresPontos,
    );
    expect(
      trianglesEstimados(muitos, teto: orcamento),
      greaterThan(orcamento),
      reason: 'seis modelos pesados nao cabem no processador nem decimados',
    );
  });

  test('no invisivel continua nao custando nada', () {
    final cena = Scene3D(
      nodes: [
        SceneNode(
          id: 'no',
          name: 'Importado',
          size: 300,
          modelAsset: _modeloCom(9000),
          visible: false,
        ),
      ],
      lights: Scene3D.tresPontos,
    );
    expect(trianglesEstimados(cena), 0);
  });
}
