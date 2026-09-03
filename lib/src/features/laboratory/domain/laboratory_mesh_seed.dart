import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

/// OS DOIS MODELOS 3D DO LABORATORIO, FEITOS NA HORA.
///
/// A especificacao pede um produto de ~3 MB e um de ~40 MB. Empacotar 43 MB
/// de .glb no APK penalizaria todo mundo por causa de um teste — e o
/// aparelho de teste ja e o gargalo. Entao a esfera e gerada aqui: mesma
/// malha toda vez, mesmo numero de triangulos, e nada disso viaja na loja.
///
/// A saida e um .glb valido de verdade (cabecalho, pedaco JSON, pedaco
/// binario), lido pelo mesmo importador que le um modelo baixado.
Uint8List gerarEsferaGlb({required int bytesAlvo, String nome = 'Esfera'}) {
  // Cada anel custa aproximadamente 72 bytes por unidade ao quadrado
  // (posicoes + indices); resolver para o alvo poupa tentativa e erro.
  final aneis = math.max(8, math.sqrt(bytesAlvo / 72).round());
  final setores = aneis * 2;
  return _esfera(aneis: aneis, setores: setores, nome: nome);
}

/// Ponto de entrada de isolate: compute() so aceita um argumento, e a
/// esfera grande nao pode ser montada na thread da interface.
Uint8List esferaGlbNoIsolate(int bytesAlvo) =>
    gerarEsferaGlb(bytesAlvo: bytesAlvo);

/// Quantos triangulos a esfera desse tamanho vai ter — o relatorio mostra
/// esse numero junto do fps para "travou" virar conta.
int trianguloDaEsfera(int bytesAlvo) {
  final aneis = math.max(8, math.sqrt(bytesAlvo / 72).round());
  return 2 * aneis * (aneis * 2);
}

Uint8List _esfera({
  required int aneis,
  required int setores,
  required String nome,
}) {
  final vertices = (setores + 1) * (aneis + 1);
  final posicoes = Float32List(vertices * 3);
  var p = 0;
  for (var anel = 0; anel <= aneis; anel++) {
    final phi = math.pi * anel / aneis;
    final sinPhi = math.sin(phi);
    final cosPhi = math.cos(phi);
    for (var setor = 0; setor <= setores; setor++) {
      final theta = 2 * math.pi * setor / setores;
      posicoes[p++] = sinPhi * math.cos(theta);
      posicoes[p++] = cosPhi;
      posicoes[p++] = sinPhi * math.sin(theta);
    }
  }

  // Dois triangulos por quadrado; os polos entram degenerados de proposito,
  // como sai de qualquer exportador, para o teste bater com o mundo real.
  final indices = Uint32List(aneis * setores * 6);
  var i = 0;
  for (var anel = 0; anel < aneis; anel++) {
    for (var setor = 0; setor < setores; setor++) {
      final a = anel * (setores + 1) + setor;
      final b = a + setores + 1;
      indices[i++] = a;
      indices[i++] = b;
      indices[i++] = a + 1;
      indices[i++] = a + 1;
      indices[i++] = b;
      indices[i++] = b + 1;
    }
  }

  final bytesPos = posicoes.lengthInBytes;
  final bytesIdx = indices.lengthInBytes;
  final json = jsonEncode({
    'asset': {'version': '2.0', 'generator': 'Aurea Laboratorio'},
    'scene': 0,
    'scenes': [
      {
        'nodes': [0],
      },
    ],
    'nodes': [
      {'mesh': 0, 'name': nome},
    ],
    'meshes': [
      {
        'name': nome,
        'primitives': [
          {
            'attributes': {'POSITION': 0},
            'indices': 1,
            'mode': 4,
          },
        ],
      },
    ],
    'accessors': [
      {
        'bufferView': 0,
        'componentType': 5126,
        'count': vertices,
        'type': 'VEC3',
        'min': [-1.0, -1.0, -1.0],
        'max': [1.0, 1.0, 1.0],
      },
      {
        'bufferView': 1,
        'componentType': 5125,
        'count': indices.length,
        'type': 'SCALAR',
      },
    ],
    'bufferViews': [
      {
        'buffer': 0,
        'byteOffset': 0,
        'byteLength': bytesPos,
        'target': 34962,
      },
      {
        'buffer': 0,
        'byteOffset': bytesPos,
        'byteLength': bytesIdx,
        'target': 34963,
      },
    ],
    'buffers': [
      {'byteLength': bytesPos + bytesIdx},
    ],
  });

  // Os dois pedacos vao alinhados em 4 bytes: espaco no JSON, zero no
  // binario, como manda o formato.
  final jsonBytes = utf8.encode(json);
  final jsonPad = (4 - jsonBytes.length % 4) % 4;
  final binLen = bytesPos + bytesIdx;
  final binPad = (4 - binLen % 4) % 4;
  final total = 12 + 8 + jsonBytes.length + jsonPad + 8 + binLen + binPad;

  final saida = Uint8List(total);
  final vista = ByteData.view(saida.buffer);
  var o = 0;
  vista.setUint32(o, 0x46546C67, Endian.little); // "glTF"
  vista.setUint32(o + 4, 2, Endian.little);
  vista.setUint32(o + 8, total, Endian.little);
  o += 12;
  vista.setUint32(o, jsonBytes.length + jsonPad, Endian.little);
  vista.setUint32(o + 4, 0x4E4F534A, Endian.little); // "JSON"
  o += 8;
  saida.setRange(o, o + jsonBytes.length, jsonBytes);
  for (var k = 0; k < jsonPad; k++) {
    saida[o + jsonBytes.length + k] = 0x20;
  }
  o += jsonBytes.length + jsonPad;
  vista.setUint32(o, binLen + binPad, Endian.little);
  vista.setUint32(o + 4, 0x004E4942, Endian.little); // "BIN"
  o += 8;
  saida.setRange(o, o + bytesPos, posicoes.buffer.asUint8List());
  saida.setRange(o + bytesPos, o + bytesPos + bytesIdx,
      indices.buffer.asUint8List());
  return saida;
}
