import 'dart:math' as math;

import 'package:aurea/src/features/editor/domain/camera_cuts.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/projects/domain/mao_enterrada_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// A MAO ENTERRADA — o que tem de continuar verdade.
///
/// Um modelo cinematografico nao se testa por pixels: o que importa e
/// que a cena continue montada do jeito que foi montada. Cada teste aqui
/// existe porque a coisa ja esteve errada uma vez.
void main() {
  test('quinze segundos, trinta quadros, quatro planos', () {
    final p = buildMaoEnterradaTemplate();
    expect(p.fps, 30);
    expect(p.markers.length, 4);
    final cena = p.layers.whereType<Scene3DLayer>().single;
    expect(cena.duration, maoDuracao);
    expect(cena.shots.length, 4);
    expect(1 + cena.extraCameras.length, 4);
    // Cada tomada aponta para uma camera que existe.
    final ids = {cena.camera.id, ...cena.extraCameras.map((c) => c.id)};
    for (final s in cena.shots) {
      expect(ids, contains(s.cameraId));
    }
    // E os cortes sao secos: quatro planos, nao um voo de quinze
    // segundos.
    for (final s in cena.shots) {
      expect(s.isCut, isTrue);
    }
  });

  test('as quatro cameras cortam nos instantes certos', () {
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    final todas = [cena.camera, ...cena.extraCameras];
    for (var i = 0; i < 4; i++) {
      // Meio segundo depois do corte, quem manda e a camera daquele
      // plano.
      final t = Duration(
        microseconds: ((maoCortes[i] + 0.5) * 1000000).round(),
      );
      final ativa = resolveCamera(todas, cena.shots, t, cena.camera);
      final esperada = todas[i].renderAt(t);
      expect(ativa.position.x, closeTo(esperada.position.x, 1e-6));
      expect(ativa.position.z, closeTo(esperada.position.z, 1e-6));
    }
  });

  test('nenhuma camera fica enterrada na areia', () {
    // Camera dentro do terreno mostra o preto do avesso das faces. Foi o
    // caso do plano de contraluz, que comecava em y = -40 com a areia em
    // torno de +30.
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    for (final cam in [cena.camera, ...cena.extraCameras]) {
      for (var s = 0.0; s <= 15; s += 0.5) {
        final t = Duration(microseconds: (s * 1000000).round());
        final pos = cam.positionAt(t);
        expect(
          pos.y,
          greaterThan(alturaDaAreia(pos.x, pos.z) + 8),
          reason: '${cam.name} em ${s}s esta dentro da duna',
        );
      }
    }
  });

  test('a mao sai da areia, com cova em volta e monte no punho', () {
    // A mao vive na origem: o punho vai de y=-230 a -60 e a ponta do
    // dedo medio chega perto de +250. A areia no centro tem de cobrir o
    // punho sem engolir a palma.
    final noCentro = alturaDaAreia(0, 0);
    expect(noCentro, inInclusiveRange(-160, 20));

    // A cova e o monte se conferem por MEDIA em volta do circulo, e nao
    // num ponto so: num ponto o ruido da duna decide sozinho, e o teste
    // vira sorteio.
    double anel(double raio) {
      var soma = 0.0;
      for (var i = 0; i < 24; i++) {
        final a = 2 * math.pi * i / 24;
        soma += alturaDaAreia(raio * math.cos(a), raio * math.sin(a));
      }
      return soma / 24;
    }

    expect(anel(260), lessThan(noCentro), reason: 'o monte levanta o centro');
    expect(anel(260), lessThan(anel(820)), reason: 'a areia cedeu em volta');
  });

  test('a cena cabe no orcamento de triangulos do motor', () {
    // Acima de ~10 mil triangulos so a GPU da conta. Este modelo existe
    // para exercitar o motor 3D, entao pode encostar no teto — mas nao
    // pode passar sem que alguem tenha decidido isso.
    final mao = maoMalha().triangulos;
    final dunas = dunasMalha().triangulos;
    final ceu = ceuMalha().triangulos;
    expect(mao, lessThan(4000));
    expect(dunas, lessThan(11000));
    expect(ceu, lessThan(1500));
    expect(mao + dunas + ceu, lessThan(15000));
  });

  test('a mao e uma peca so: nenhuma juncao de superficies', () {
    // A versao de pecas encaixadas deixava lascas escuras em cada junta,
    // porque um desenhador que ordena por profundidade nao resolve
    // intersecao. A malha de agora e varrida, e o teste que segura isso
    // e o numero de primitivas: um material, uma peca.
    final asset = maoMalha().asset('Mao');
    final primitivas = asset.data['primitives'] as List;
    expect(primitivas.length, 1);
  });

  test('o ceu tem degrade de verdade, e o sol onde a luz diz', () {
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    final ceu = cena.scene.nodes.firstWhere((n) => n.id == 'mao_ceu_cupula');
    final materiais =
        ceu.modelAsset!.data['materials'] as List<Map<String, dynamic>>;
    // Sem luz e com as duas faces: a cupula e vista por dentro.
    expect(materiais.single['unlit'], isTrue);
    expect(materiais.single['doubleSided'], isTrue);
    // E texturizada — e e a textura que salva o degrade da neblina.
    expect(materiais.single['image'], startsWith('data:image/png'));
  });

  test('a luz do entardecer: sol rasante, ceu frio e contraluz', () {
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    expect(cena.scene.lights.length, 3);
    final sol = cena.scene.lights.firstWhere((l) => l.id == 'mao_sol');
    // Rasante: a luz viaja quase na horizontal.
    expect(sol.direction.y.abs(), lessThan(0.3));
    expect(sol.castsShadow, isTrue);
    // O contraluz vem do lado oposto ao da camera principal, senao nao
    // desenha silhueta nenhuma.
    final recorte = cena.scene.lights.firstWhere(
      (l) => l.id == 'mao_recorte',
    );
    expect(recorte.direction.z, greaterThan(0.5));
    expect(cena.scene.fogDensity, greaterThan(0));
  });

  test('abre e fecha no preto', () {
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    expect(cena.opacity.valueAt(Duration.zero), closeTo(0, 1e-9));
    expect(
      cena.opacity.valueAt(const Duration(seconds: 7)),
      closeTo(1, 1e-6),
    );
    expect(
      cena.opacity.valueAt(const Duration(seconds: 15)),
      closeTo(0, 1e-9),
    );
  });

  test('as cameras se movem: nenhum plano parado', () {
    final p = buildMaoEnterradaTemplate();
    final cena = p.layers.whereType<Scene3DLayer>().single;
    for (var i = 0; i < 4; i++) {
      final cam = [cena.camera, ...cena.extraCameras][i];
      final inicio = Duration(
        microseconds: (maoCortes[i] * 1000000).round(),
      );
      final fim = Duration(
        microseconds: ((i == 3 ? 15.0 : maoCortes[i + 1]) * 1000000).round(),
      );
      final a = cam.positionAt(inicio), b = cam.positionAt(fim);
      final andou = math.sqrt(
        math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2) + math.pow(a.z - b.z, 2),
      );
      expect(andou, greaterThan(80), reason: '${cam.name} nao anda');
    }
  });
}
