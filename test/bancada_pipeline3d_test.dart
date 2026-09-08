// A BANCADA DO PIPELINE 3D: mede antes de otimizar.
//
// A missao P0 pediu, nesta ordem: PRIMEIRO medir, depois achar o
// gargalo, depois otimizar, depois medir de novo. Este arquivo e a
// primeira e a ultima parte — ele monta cenas de verdade (uma malha, e
// depois cinco, vinte e cinquenta objetos, de simples a pesado), roda o
// caminho de CPU que alimenta a GPU quadro a quadro e imprime uma tabela
// com o tempo de cada fase e quantas coisas caras aconteceram por
// quadro.
//
// O QUE ELE MEDE, E POR QUE NAO PRECISA DE GPU: o que trava um aparelho
// nao e so a GPU desenhar. Antes de qualquer pixel, o app percorre a
// cena, resolve a transformacao de cada no (subindo a cadeia de pais),
// escolhe a malha, avalia o modelo animado, monta a lista de material
// por face e decide o que mudou. Tudo isso e Dart puro, roda no
// processador do aparelho, e cabe num teste — e e exatamente onde as
// travadas relatadas costumam nascer.
//
// Rodar:  flutter test test/bancada_pipeline3d_test.dart
// Com detalhe:  AUREA_BANCADA=1 flutter test test/bancada_pipeline3d_test.dart
import 'dart:io';
import 'dart:math' as math;

import 'dart:typed_data';

import 'package:aurea/src/features/editor/application/perfil3d.dart';
import 'package:aurea/src/features/editor/application/fonte_de_malha.dart';
import 'package:aurea/src/features/editor/domain/geometria_gpu.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma esfera de [aneis] x [setores]: o jeito de ter contagem de faces
/// conhecida sem depender de arquivo.
Element3DMesh _malhaPesada({required int aneis, required int setores}) {
  final verts = <List<double>>[];
  final faces = <List<int>>[];
  for (var i = 0; i <= aneis; i++) {
    final v = i / aneis;
    final phi = v * math.pi;
    for (var j = 0; j <= setores; j++) {
      final u = j / setores;
      final theta = u * 2 * math.pi;
      verts.add([
        math.sin(phi) * math.cos(theta),
        math.cos(phi),
        math.sin(phi) * math.sin(theta),
      ]);
    }
  }
  final porAnel = setores + 1;
  for (var i = 0; i < aneis; i++) {
    for (var j = 0; j < setores; j++) {
      final a = i * porAnel + j;
      faces.add([a, a + 1, a + porAnel + 1]);
      faces.add([a, a + porAnel + 1, a + porAnel]);
    }
  }
  return Element3DMesh(
    verts,
    faces,
    normals: [for (final v in verts) v],
  );
}

/// Uma cena com [quantos] objetos, cada um com [faces] faces, metade
/// deles pendurados num pai (a cadeia de transformacao que o app tem de
/// resolver) e uma parte animada.
Scene3D _cena({
  required int quantos,
  required int aneis,
  required int setores,
  bool animada = true,
  bool comPai = true,
}) {
  final malha = _malhaPesada(aneis: aneis, setores: setores);
  final nos = <SceneNode>[
    if (comPai)
      SceneNode(
        id: 'pai',
        name: 'Pai',
        isNull: true,
        rotY: animada
            ? AnimatedDouble(0)
                  .withKeyframe(Duration.zero, 0)
                  .withKeyframe(const Duration(seconds: 4), 360)
            : AnimatedDouble(0),
      ),
  ];
  for (var i = 0; i < quantos; i++) {
    final angulo = i / math.max(1, quantos) * 2 * math.pi;
    nos.add(
      SceneNode(
        id: 'n$i',
        name: 'Objeto $i',
        kind: Element3DKind.cube,
        mesh: malha,
        parentId: comPai && i.isEven ? 'pai' : null,
        x: AnimatedDouble(math.cos(angulo) * 200),
        z: AnimatedDouble(math.sin(angulo) * 200),
        rotY: animada && i % 3 == 0
            ? AnimatedDouble(0)
                  .withKeyframe(Duration.zero, 0)
                  .withKeyframe(const Duration(seconds: 3), 180)
            : AnimatedDouble(0),
        material: Material3D(baseColor: Color(0xFF808080 + i * 7)),
      ),
    );
  }
  return Scene3D(nodes: nos, lights: Scene3D.tresPontos);
}

/// O QUE O APP FAZ POR QUADRO ANTES DE MANDAR PARA A GPU, medido aqui
/// exatamente como o `Scene3DGpu._sincronizarNos` faz: transformacao de
/// cada no (com a cadeia de pais), escolha da malha, lista de material
/// por face e a assinatura que decide se o no precisa ser reconstruido.
({double msPorQuadro, int nos, int faces}) _medirSincronia(
  Scene3D cena, {
  required int quadros,
}) {
  var faces = 0;
  final relogio = Stopwatch()..start();
  for (var q = 0; q < quadros; q++) {
    final t = Duration(milliseconds: (q * 16.6).round());
    for (final node in cena.nodes) {
      if (!node.visible || node.isNull) continue;
      resolveNodeTransform(cena, node, t);
      final mesh = node.mesh ?? element3DMesh(node.kind);
      // As duas alocacoes que o caminho da GPU faz por no, por quadro.
      final normais = mesh.normals
          ?.map((n) => Vec3(n[0], n[1], n[2]))
          .toList(growable: false);
      final materiais = List<Material3D>.filled(
        mesh.faces.length,
        node.material,
      );
      final assinatura =
          'p${node.kind.index}:${identityHashCode(mesh)}:'
          '${node.instances.isNotEmpty}:${node.material.baseColor.toARGB32()}';
      if (assinatura.isEmpty || materiais.isEmpty || normais == null) {
        throw StateError('impossivel');
      }
      if (q == 0) faces += mesh.faces.length;
    }
  }
  relogio.stop();
  return (
    msPorQuadro: relogio.elapsedMicroseconds / 1000.0 / quadros,
    nos: cena.nodes.where((n) => !n.isNull).length,
    faces: faces,
  );
}

/// O caminho de CPU inteiro (o pintor de reserva), para comparar: ele
/// projeta vertice a vertice e ordena as faces.
double _medirRenderCpu(Scene3D cena, {required int quadros}) {
  const camera = RenderCamera(position: Vec3(0, -120, 520));
  const area = Size(390, 700);
  final relogio = Stopwatch()..start();
  for (var q = 0; q < quadros; q++) {
    renderScene(cena, camera, area, Duration(milliseconds: (q * 16.6).round()));
  }
  relogio.stop();
  return relogio.elapsedMicroseconds / 1000.0 / quadros;
}

void main() {
  final detalhe = Platform.environment['AUREA_BANCADA'] == '1';

  test('bancada: o custo de CPU por quadro, cena a cena', () {
    final casos = <(String, Scene3D)>[
      ('1 objeto simples', _cena(quantos: 1, aneis: 8, setores: 12)),
      ('5 objetos medios', _cena(quantos: 5, aneis: 16, setores: 24)),
      ('20 objetos medios', _cena(quantos: 20, aneis: 16, setores: 24)),
      ('50 objetos medios', _cena(quantos: 50, aneis: 16, setores: 24)),
      ('1 objeto pesado', _cena(quantos: 1, aneis: 64, setores: 96)),
      ('5 objetos pesados', _cena(quantos: 5, aneis: 48, setores: 72)),
    ];
    final linhas = <String>[
      '',
      'BANCADA DO PIPELINE 3D — custo de CPU por quadro',
      '(o que roda ANTES da GPU: transformacao, malha, material, assinatura)',
      '',
      'cena                        nos    faces   sincronia   render CPU',
      '------------------------------------------------------------------',
    ];
    for (final (nome, cena) in casos) {
      final s = _medirSincronia(cena, quadros: 40);
      final cpu = _medirRenderCpu(cena, quadros: 6);
      linhas.add(
        '${nome.padRight(26)} ${s.nos.toString().padLeft(4)} '
        '${s.faces.toString().padLeft(8)} '
        '${s.msPorQuadro.toStringAsFixed(2).padLeft(8)} ms '
        '${cpu.toStringAsFixed(1).padLeft(9)} ms',
      );
    }
    linhas
      ..add('')
      ..add('16.6 ms = 60 fps | 33.3 ms = 30 fps');
    // ignore: avoid_print
    print(linhas.join('\n'));

    // A TRAVA DA BANCADA: uma cena media (20 objetos, ~1500 faces cada)
    // nao pode gastar um quadro inteiro so decidindo o que desenhar.
    final media = _medirSincronia(
      _cena(quantos: 20, aneis: 16, setores: 24),
      quadros: 40,
    );
    expect(
      media.msPorQuadro,
      lessThan(16.6),
      reason: 'so a sincronia ja come o quadro de 60 fps',
    );
  });

  test('bancada: o quadro de um modelo ANIMADO (o caminho que reconstroi)', () {
    // O no animado nao so move: a cada quadro a malha e avaliada de novo,
    // os buffers da GPU sao remontados face a face e a lista de indices e
    // COMPARADA INTEIRA para decidir se a topologia mudou. Este e o
    // caminho que a missao descreve — "modelo complexo + animacao".
    final linhas = <String>[
      '',
      'QUADRO DE UM MODELO ANIMADO — o que se refaz a cada quadro',
      '',
      'malha            faces   montar buffers   comparar indices   total',
      '----------------------------------------------------------------',
    ];
    for (final (nome, aneis, setores) in const [
      ('media', 16, 24),
      ('grande', 32, 48),
      ('pesada', 64, 96),
    ]) {
      final malha = _malhaPesada(aneis: aneis, setores: setores);
      final materiais = List<Material3D>.filled(
        malha.faces.length,
        const Material3D(),
      );
      final normais = [for (final v in malha.verts) Vec3(v[0], v[1], v[2])];

      // 1. montar os buffers tipados (positions/normals/uvs/indices).
      var relogio = Stopwatch()..start();
      var grupos = montarGruposGpu(
        malha: malha,
        materiais: materiais,
        normais: normais,
      );
      const repeticoes = 10;
      for (var i = 1; i < repeticoes; i++) {
        grupos = montarGruposGpu(
          malha: malha,
          materiais: materiais,
          normais: normais,
        );
      }
      relogio.stop();
      final montar = relogio.elapsedMicroseconds / 1000.0 / repeticoes;

      // 2. a comparacao da lista de indices, que o codigo faz por grupo.
      final indices = grupos.values.first.indexList;
      final copia = Uint16List.fromList(indices);
      relogio = Stopwatch()..start();
      for (var i = 0; i < repeticoes; i++) {
        listEquals(indices, copia);
      }
      relogio.stop();
      final comparar = relogio.elapsedMicroseconds / 1000.0 / repeticoes;

      linhas.add(
        '${nome.padRight(14)} ${malha.faces.length.toString().padLeft(7)} '
        '${montar.toStringAsFixed(2).padLeft(12)} ms '
        '${comparar.toStringAsFixed(2).padLeft(15)} ms '
        '${(montar + comparar).toStringAsFixed(2).padLeft(8)} ms',
      );
    }
    linhas
      ..add('')
      ..add('16.6 ms = 60 fps — e isto e SO a preparacao, sem desenhar.');
    // ignore: avoid_print
    print(linhas.join(String.fromCharCode(10)));

    final malha = _malhaPesada(aneis: 32, setores: 48);
    final materiais = List<Material3D>.filled(
      malha.faces.length,
      const Material3D(),
    );
    final relogio = Stopwatch()..start();
    montarGruposGpu(malha: malha, materiais: materiais);
    relogio.stop();
    // A trava: remontar os buffers de uma malha grande nao pode, sozinho,
    // estourar o quadro de 30 fps.
    expect(
      relogio.elapsedMicroseconds / 1000.0,
      lessThan(33.3),
      reason: 'so remontar os buffers ja perde o quadro de 30 fps',
    );
  });

  test('DEPOIS: com memoria, o no parado nao aloca mais nada', () {
    Perfil3D.zerar();
    Perfil3D.ligado = true;
    addTearDown(() {
      Perfil3D.ligado = false;
      Perfil3D.zerar();
    });
    final cena = _cena(quantos: 20, aneis: 16, setores: 24);
    final cache = CacheDeMalhas();
    String assinatura(Material3D m) => '${m.baseColor.toARGB32()}';

    final relogio = Stopwatch()..start();
    const quadros = 40;
    for (var q = 0; q < quadros; q++) {
      final t = Duration(milliseconds: (q * 16.6).round());
      final vivos = <String>{};
      for (final node in cena.nodes) {
        if (!node.visible || node.isNull) continue;
        vivos.add(node.id);
        cache.doNo(
          node,
          t,
          lodDaReceita: (n) => n.mesh,
          assinaturaDoMaterial: assinatura,
        );
      }
      cache.manterApenas(vivos);
      Perfil3D.quadro();
    }
    relogio.stop();
    final r = Perfil3D.relatorio();
    final msPorQuadro = relogio.elapsedMicroseconds / 1000.0 / quadros;

    // ignore: avoid_print
    print(
      [
        '',
        'DEPOIS — a malha de cada no, com memoria (20 objetos, 40 quadros)',
        '  ${msPorQuadro.toStringAsFixed(3)} ms/quadro',
        '  malhas refeitas:      ${r.porQuadroDe('malha.refeita').toStringAsFixed(1)} /quadro',
        '  malhas reaproveitadas:${r.porQuadroDe('malha.reaproveitada').toStringAsFixed(1)} /quadro',
        '  materiais alocados:   ${r.porQuadroDe('alocacao.materiais').toStringAsFixed(0)} /quadro',
        '  normais alocadas:     ${r.porQuadroDe('alocacao.normais').toStringAsFixed(0)} /quadro',
        '',
        '(ANTES, medido no mesmo caso: 15360 materiais e 8500 normais por quadro)',
      ].join(String.fromCharCode(10)),
    );

    // O QUE A OTIMIZACAO PROMETE: o primeiro quadro monta as vinte
    // malhas; os outros trinta e nove reaproveitam todas.
    expect(r.contas['malha.refeita'], 20, reason: 'so o primeiro quadro monta');
    expect(r.contas['malha.reaproveitada'], 20 * (quadros - 1));
    // E a alocacao por quadro cai a praticamente zero.
    expect(r.porQuadroDe('alocacao.materiais'), lessThan(400));
    expect(r.porQuadroDe('alocacao.normais'), lessThan(250));
    expect(msPorQuadro, lessThan(1.0));
  });

  test('a memoria das malhas solta o que saiu da cena', () {
    final cena = _cena(quantos: 3, aneis: 8, setores: 12);
    final cache = CacheDeMalhas();
    String assinatura(Material3D m) => '${m.baseColor.toARGB32()}';
    for (final node in cena.nodes) {
      if (node.isNull) continue;
      cache.doNo(
        node,
        Duration.zero,
        lodDaReceita: (n) => n.mesh,
        assinaturaDoMaterial: assinatura,
      );
    }
    expect(cache.tamanho, 3);
    cache.manterApenas({'n0'});
    expect(cache.tamanho, 1, reason: 'no que saiu nao fica ocupando memoria');
    cache.limpar();
    expect(cache.tamanho, 0);
  });

  test('bancada: onde o tempo vai, por fase (com o perfilador ligado)', () {
    Perfil3D.zerar();
    Perfil3D.ligado = true;
    addTearDown(() {
      Perfil3D.ligado = false;
      Perfil3D.zerar();
    });
    final cena = _cena(quantos: 20, aneis: 16, setores: 24);
    for (var q = 0; q < 20; q++) {
      final t = Duration(milliseconds: (q * 16.6).round());
      for (final node in cena.nodes) {
        if (!node.visible || node.isNull) continue;
        Perfil3D.contar('nos.vistos');
        Perfil3D.fase(
          'sincronia.transform',
          () => resolveNodeTransform(cena, node, t),
        );
        Perfil3D.fase('sincronia.malha', () {
          final mesh = node.mesh ?? element3DMesh(node.kind);
          Perfil3D.contar('alocacao.normais', mesh.normals?.length ?? 0);
          Perfil3D.contar('alocacao.materiais', mesh.faces.length);
          mesh.normals?.map((n) => Vec3(n[0], n[1], n[2])).toList();
          List<Material3D>.filled(mesh.faces.length, node.material);
        });
      }
      Perfil3D.quadro();
    }
    final r = Perfil3D.relatorio();
    if (detalhe) {
      // ignore: avoid_print
      print('\nPOR FASE, cena de 20 objetos:\n${r.emTexto()}');
    }
    expect(r.quadros, 20);
    expect(r.porQuadroDe('nos.vistos'), 20);
    // O perfilador tem de ver as duas fases, senao a medicao nao vale.
    expect(r.fases.containsKey('sincronia.transform'), isTrue);
    expect(r.fases.containsKey('sincronia.malha'), isTrue);
    // E a conta que interessa: quantas alocacoes por quadro so para
    // dizer "nada mudou".
    expect(r.porQuadroDe('alocacao.materiais'), greaterThan(0));
  });

  test('o perfilador desligado nao cobra nada', () {
    Perfil3D.zerar();
    Perfil3D.ligado = false;
    var contou = 0;
    for (var i = 0; i < 100000; i++) {
      contou += Perfil3D.fase('x', () => 1);
      Perfil3D.contar('y');
    }
    expect(contou, 100000);
    expect(Perfil3D.relatorio().fases, isEmpty);
    expect(Perfil3D.relatorio().contas, isEmpty);
  });
}
