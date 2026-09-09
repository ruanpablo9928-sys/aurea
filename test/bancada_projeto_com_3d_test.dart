// QUANTO CUSTA SALVAR E ABRIR UM PROJETO QUE TEM CENA 3D.
//
// O relato do beta e preciso: "o scene 3d nao ta mais lagando, mas se
// tiver projeto com ele a timeline da gargalo, ate o projeto demora
// abrir, clicar em algo so clica depois de uns 2 seg, mover trava
// tudo".
//
// Repare no que essa frase separa: o DESENHO da cena esta bom, e mesmo
// assim tudo em volta trava — e so quando o projeto tem cena 3D. Isso
// aponta para algo que roda a cada mudanca do projeto e cresce com o
// tamanho da cena, nao para o motor 3D.
//
// A suspeita e o ARQUIVO. A geometria do modelo importado e gravada
// DENTRO do projeto (`meshData`), em base64, para o projeto reabrir sem
// depender do arquivo original. Se essa gravacao for refeita a cada
// salvamento, cada salvamento percorre a malha inteira, monta megabytes
// de bytes e os converte para texto — no mesmo fio que responde ao
// toque.
//
// Esta bancada mede, com malhas de tamanho realista:
//   - quanto tempo leva montar o JSON do projeto;
//   - quanto tempo leva transformar isso em texto;
//   - o tamanho do arquivo;
//   - quanto tempo leva reabrir.
//
// Rodar:  flutter test test/bancada_projeto_com_3d_test.dart
import 'dart:convert';

import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/model_asset3d.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma esfera de [aneis] x [setores]: contagem de faces conhecida, sem
/// depender de arquivo em disco.
Element3DMesh _malha({required int aneis, required int setores}) {
  final verts = <List<double>>[];
  final faces = <List<int>>[];
  for (var a = 0; a <= aneis; a++) {
    final v = a / aneis;
    for (var s = 0; s <= setores; s++) {
      final u = s / setores;
      verts.add([u - 0.5, v - 0.5, (u * v) - 0.25]);
    }
  }
  final porLinha = setores + 1;
  for (var a = 0; a < aneis; a++) {
    for (var s = 0; s < setores; s++) {
      final i = a * porLinha + s;
      faces
        ..add([i, i + 1, i + porLinha])
        ..add([i + 1, i + porLinha + 1, i + porLinha]);
    }
  }
  return Element3DMesh(verts, faces);
}

VideoProject _projetoCom(Element3DMesh? malha, {int camadas = 12}) {
  final layers = <Layer>[
    for (var i = 0; i < camadas; i++)
      ShapeLayer(
        id: 'c$i',
        name: 'Camada $i',
        startTime: Duration(milliseconds: 250 * i),
        duration: const Duration(seconds: 3),
        position: AnimatedOffset(const Offset(200, 200)),
        contents: [
          ShapePath(primitive: ShapePrimitive.rectangle),
          ShapeFill(color: const Color(0xFF3DDC97)),
        ],
      ),
  ];
  if (malha != null) {
    layers.add(
      Scene3DLayer(
        id: 'cena',
        name: 'Cena 3D',
        startTime: Duration.zero,
        duration: const Duration(seconds: 8),
        scene: Scene3D(
          nodes: [
            SceneNode(
              id: 'modelo',
              name: 'Modelo',
              size: 200,
              mesh: malha,
              modelSource: ModelSource3D(
                path: '/tmp/modelo.obj',
                triangles: malha.faces.length,
              ),
            ),
          ],
          lights: Scene3D.tresPontos,
        ),
      ),
    );
  }
  return VideoProject(
    name: 'bancada',
    createdAt: DateTime(2026, 9, 9),
    layers: layers,
  );
}

/// O MODELO IMPORTADO como ele fica guardado: o glTF ja lido, com as
/// posicoes, normais, UVs e indices em listas de numeros. E isto que
/// `modelAsset` carrega dentro do projeto.
ModelAsset3D _modeloImportado({required int triangulos}) {
  final vertices = triangulos * 3;
  final positions = <double>[];
  final normals = <double>[];
  final uv = <double>[];
  final indices = <int>[];
  for (var i = 0; i < vertices; i++) {
    final f = i / vertices;
    positions.addAll([f, f * 2, f * 3]);
    normals.addAll([0, 1, 0]);
    uv.addAll([f, 1 - f]);
    indices.add(i);
  }
  return ModelAsset3D({
    'version': 1,
    'format': 'gltf2',
    'name': 'Modelo',
    'nodes': [
      {
        'name': 'raiz',
        'matrix': [for (var i = 0; i < 16; i++) i.toDouble()],
      },
    ],
    'primitives': [
      {
        'node': 0,
        'positions': positions,
        'indices': indices,
        'material': 0,
        'normals': normals,
        'uv': uv,
      },
    ],
    'skins': <dynamic>[],
    'clips': <dynamic>[],
    'materials': <dynamic>[],
    'warnings': <dynamic>[],
  });
}

VideoProject _projetoComModelo(ModelAsset3D modelo) => VideoProject(
  name: 'bancada',
  createdAt: DateTime(2026, 9, 9),
  layers: [
    Scene3DLayer(
      id: 'cena',
      name: 'Cena 3D',
      startTime: Duration.zero,
      duration: const Duration(seconds: 8),
      scene: Scene3D(
        nodes: [
          SceneNode(
            id: 'modelo',
            name: 'Modelo',
            size: 200,
            modelAsset: modelo,
          ),
        ],
        lights: Scene3D.tresPontos,
      ),
    ),
  ],
);

double _ms(void Function() corpo, {int vezes = 3}) {
  final r = Stopwatch()..start();
  for (var i = 0; i < vezes; i++) {
    corpo();
  }
  r.stop();
  return r.elapsedMicroseconds / 1000 / vezes;
}

void main() {
  test('bancada: salvar e abrir um projeto com cena 3D', () {
    final linhas = <String>[
      '',
      'BANCADA DO ARQUIVO — projeto com e sem cena 3D',
      '',
      'A malha do modelo importado e gravada DENTRO do projeto.',
      '',
      'cena                triangulos    montar    texto   abrir   tamanho',
      '------------------------------------------------------------------',
    ];

    final casos = <(String, Element3DMesh?)>[
      ('sem cena 3D', null),
      ('modelo leve', _malha(aneis: 20, setores: 20)),
      ('modelo medio', _malha(aneis: 90, setores: 90)),
      ('modelo pesado', _malha(aneis: 200, setores: 200)),
    ];

    for (final (nome, malha) in casos) {
      final p = _projetoCom(malha);
      final tris = malha == null ? 0 : malha.faces.length;
      late Map<String, dynamic> json;
      final montar = _ms(() => json = projectToJson(p));
      late String texto;
      final emTexto = _ms(() => texto = jsonEncode(json));
      final abrir = _ms(() => projectFromJson(jsonDecode(texto)));
      final kb = texto.length / 1024;
      linhas.add(
        '${nome.padRight(20)}'
        '${tris.toString().padLeft(9)}  '
        '${montar.toStringAsFixed(1).padLeft(8)} ms'
        '${emTexto.toStringAsFixed(1).padLeft(8)} ms'
        '${abrir.toStringAsFixed(1).padLeft(7)} ms'
        '${kb.toStringAsFixed(0).padLeft(8)} KB',
      );
    }

    linhas
      ..add('')
      ..add('MODELO IMPORTADO (glTF/GLB lido e guardado no projeto)')
      ..add('')
      ..add(
        'modelo              triangulos    montar    texto   abrir   tamanho',
      )
      ..add(
        '------------------------------------------------------------------',
      );

    for (final (nome, tris) in <(String, int)>[
      ('importado leve', 2000),
      ('importado medio', 20000),
      ('importado pesado', 60000),
    ]) {
      final p = _projetoComModelo(_modeloImportado(triangulos: tris));
      late Map<String, dynamic> json;
      final montar = _ms(() => json = projectToJson(p), vezes: 2);
      late String texto;
      final emTexto = _ms(() => texto = jsonEncode(json), vezes: 2);
      final abrir = _ms(() => projectFromJson(jsonDecode(texto)), vezes: 2);
      linhas.add(
        '${nome.padRight(20)}'
        '${tris.toString().padLeft(9)}  '
        '${montar.toStringAsFixed(1).padLeft(8)} ms'
        '${emTexto.toStringAsFixed(1).padLeft(8)} ms'
        '${abrir.toStringAsFixed(1).padLeft(7)} ms'
        '${(texto.length / 1024).toStringAsFixed(0).padLeft(8)} KB',
      );
    }

    linhas
      ..add('')
      ..add('O salvamento automatico dispara 900 ms depois da ultima')
      ..add('mudanca, no fio da interface. "montar + texto" e o tempo em')
      ..add('que o aplicativo fica surdo ao toque a cada salvamento.');
    // ignore: avoid_print
    print(linhas.join(String.fromCharCode(10)));
  });
}
