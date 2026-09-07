import 'dart:math' as math;

import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/projects/domain/flor_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// FLOR · o modelo de dez segundos com a camera na mao.
///
/// Dois riscos guardados aqui. O primeiro e o de sempre numa cena 3D
/// deste app: peso. O segundo e o que o usuario pediu com todas as
/// letras — "camera se mexe como se alguem estivesse gravando" — e
/// isso NAO se verifica olhando o codigo: um `sin` bonito no arquivo
/// vira trilho na tela. O que separa mao de trilho e mensuravel, e e o
/// que os testes abaixo medem.
void main() {
  final projeto = buildFlorTemplate();
  final cena = projeto.layers.whereType<Scene3DLayer>().single;

  Duration t(num s) => Duration(microseconds: (s * 1000000).round());

  /// A posicao da camera [c] no instante [s], em segundos.
  List<double> pos(Camera3D c, double s) => [
    c.posX.valueAt(t(s)),
    c.posY.valueAt(t(s)),
    c.posZ.valueAt(t(s)),
  ];

  List<Camera3D> get3 = [cena.camera, ...cena.extraCameras];

  group('o filme', () {
    test('dez segundos, tres tomadas, uma cena so', () {
      expect(florDuration, const Duration(seconds: 10));
      expect(projeto.layers.whereType<Scene3DLayer>(), hasLength(1));
      expect(get3, hasLength(3));
      expect(cena.shots, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(cena.shots[i].time, t(florTomadas[i]));
        expect(
          cena.shots[i].cameraId,
          get3[i].id,
          reason: 'a tomada ${i + 1} tem de apontar para a camera ${i + 1}',
        );
      }
      // O corte e de CAMERA: se virasse corte de projeto, a flor
      // recomecaria a cada tomada.
      expect(cena.startTime, Duration.zero);
      expect(cena.duration, florDuration);
    });

    test('as tres tomadas cobrem os dez segundos, sem buraco', () {
      expect(florTomadas.first, 0.0);
      for (var i = 1; i < florTomadas.length; i++) {
        expect(florTomadas[i], greaterThan(florTomadas[i - 1]));
      }
      expect(florTomadas.last, lessThan(10.0));
    });

    test('as lentes contam a historia: aberta, macro, aberta de novo', () {
      final lentes = [for (final c in get3) c.focalLength.valueAt(t(0))];
      expect(lentes[1], greaterThan(lentes[0]), reason: 'a 2 e a macro');
      expect(lentes[1], greaterThan(lentes[2]));
      expect(lentes[2], lessThan(lentes[0]), reason: 'a 3 abre para revelar');
    });

    test('toda tomada tem profundidade de campo ligada', () {
      for (final c in get3) {
        expect(c.dof?.enabled, isTrue, reason: '${c.name} sem foco');
        expect(c.dof!.highlightGain.valueAt(t(0)), greaterThan(0),
            reason: 'sem ganho de realce o fundo desfocado vira borrao '
                'cinza em vez de bola de luz');
      }
    });
  });

  group('a mao', () {
    // A camera 1 no seu proprio trecho: e onde a mao dela vale.
    const amostras = 120;

    /// Quantas vezes a ACELERACAO da camera troca de sinal no eixo.
    ///
    /// A posicao nao serve de medida: num empurrao para a frente o eixo
    /// anda sempre para o mesmo lado, com mao ou sem — a base anda mais
    /// depressa que a deriva. O que separa mao de trilho e a segunda
    /// diferenca. Um trilho acelera, mantem e desacelera: a aceleracao
    /// troca de sinal uma ou duas vezes no trecho inteiro. Uma mao
    /// corrige o tempo todo, e a aceleracao vira e revira.
    int viradasDaAceleracao(Camera3D c, double ini, double fim, int eixo) {
      final p = [
        for (var i = 0; i <= amostras; i++)
          pos(c, ini + (fim - ini) * i / amostras)[eixo],
      ];
      var trocas = 0, sinal = 0;
      for (var i = 1; i < p.length - 1; i++) {
        final d2 = p[i + 1] - 2 * p[i] + p[i - 1];
        if (d2.abs() < 1e-7) continue;
        final novo = d2 > 0 ? 1 : -1;
        if (sinal != 0 && novo != sinal) trocas++;
        sinal = novo;
      }
      return trocas;
    }

    test('a camera corrige o tempo todo — nao e trilho', () {
      for (var i = 0; i < 3; i++) {
        final ini = florTomadas[i];
        final fim = i == 2 ? 10.0 : florTomadas[i + 1];
        // Tres eixos: a mao nao escolhe um.
        for (var eixo = 0; eixo < 3; eixo++) {
          expect(
            viradasDaAceleracao(get3[i], ini, fim, eixo),
            greaterThanOrEqualTo(6),
            reason: '${get3[i].name}, eixo $eixo: movimento liso demais '
                'para uma camera na mao',
          );
        }
      }
    });

    test('mas o movimento de base continua legivel', () {
      // O outro extremo: tremor que engole a intencao. O empurrao da
      // tomada 1 tem de continuar sendo um empurrao — a distancia ate
      // a flor cai do comeco ao fim, sem depender de qual instante se
      // mede.
      double distancia(double s) {
        final p = pos(get3[0], s);
        return math.sqrt(p[0] * p[0] + (p[1] - 41) * (p[1] - 41) + p[2] * p[2]);
      }

      expect(distancia(3.3), lessThan(distancia(0.1) - 8),
          reason: 'a camera tinha de ter chegado mais perto');
    });

    test('o horizonte balanca, e balanca pouco', () {
      for (final c in get3) {
        final rolos = [
          for (var i = 0; i <= amostras; i++) c.rotZ.valueAt(t(i / 12)),
        ];
        final lo = rolos.reduce(math.min), hi = rolos.reduce(math.max);
        expect(hi - lo, greaterThan(0.4),
            reason: '${c.name}: sem balanco de horizonte, parece tripe');
        expect(hi - lo, lessThan(9.0),
            reason: '${c.name}: isso nao e mao, e queda');
      }
    });

    test('o tremor e DERIVA, nao solavanco', () {
      // Entre duas amostras vizinhas (1/12 s) a camera nao pode saltar:
      // ruido branco daria passos grandes e aleatorios, e na tela isso
      // le como camera quebrada, nao como camera na mao.
      for (final c in get3) {
        var maiorPasso = 0.0;
        for (var i = 1; i <= 120; i++) {
          final a = pos(c, (i - 1) / 12), b = pos(c, i / 12);
          final d = math.sqrt(
            math.pow(b[0] - a[0], 2) +
                math.pow(b[1] - a[1], 2) +
                math.pow(b[2] - a[2], 2),
          );
          maiorPasso = math.max(maiorPasso, d);
        }
        expect(maiorPasso, lessThan(3.5),
            reason: '${c.name}: passo de ${maiorPasso.toStringAsFixed(2)} '
                'entre quadros vizinhos e solavanco, nao mao');
      }
    });

    test('a mao existe em todo instante, nao so no comeco', () {
      // Um erro facil: aplicar o tremor sobre um t que so anda no
      // trecho da tomada, deixando o resto congelado. Aqui a camera 2 e
      // medida no comeco E no fim do proprio trecho.
      final c = get3[1];
      double faixa(double ini, double fim) {
        final xs = [
          for (var i = 0; i <= 20; i++)
            pos(c, ini + (fim - ini) * i / 20)[0],
        ];
        return xs.reduce(math.max) - xs.reduce(math.min);
      }

      expect(faixa(3.4, 4.5), greaterThan(0.05));
      expect(faixa(5.7, 6.8), greaterThan(0.05));
    });

    test('cada tomada tem a sua mao — nao e o mesmo tremor colado', () {
      // Mesmo instante, cameras diferentes: se as sementes fossem
      // iguais, o tremor seria identico e o corte nao se sentiria.
      final a = get3[0].posX.valueAt(t(5)) - get3[0].posX.valueAt(t(5.25));
      final b = get3[1].posX.valueAt(t(5)) - get3[1].posX.valueAt(t(5.25));
      expect((a - b).abs(), greaterThan(1e-6));
    });
  });

  group('o peso', () {
    test('cabe no orcamento de triangulos', () {
      final tris = florTriangles(projeto);
      // ignore: avoid_print
      print('FLOR: $tris triangulos por quadro '
          '(teto $florTriangleBudget)');
      expect(tris, lessThanOrEqualTo(florTriangleBudget));
      // E nao pode ser leve por estar vazia.
      expect(tris, greaterThan(3000));
    });

    test('a cena tem chao, fundo e a planta', () {
      final nomes = cena.scene.nodes.map((n) => n.name).toList();
      expect(nomes, contains('Mesa'));
      expect(nomes, contains('Rosa'));
      // O fundo NAO e geometria: e o panorama do ambiente, desfocado.
      // Esferas claras atras da flor viravam bolinhas boiando no ar.
      expect(cena.scene.panorama.showBackground, isTrue);
      expect(cena.scene.panorama.backgroundBlur, greaterThan(0));
      expect(cena.scene.background, isNull,
          reason: 'cor de fundo vence do panorama no pintor');
    });

    test('a luz da janela faz sombra, e e a unica que faz', () {
      final comSombra =
          cena.scene.lights.where((l) => l.castsShadow).toList();
      expect(comSombra, hasLength(1),
          reason: 'cada luz com sombra e um mapa de sombra na GPU');
      expect(comSombra.single.id, 'flor_janela');
    });
  });

  test('abrir duas vezes da o mesmo filme', () {
    final outro = buildFlorTemplate();
    final a = outro.layers.whereType<Scene3DLayer>().single;
    for (var i = 0; i < 3; i++) {
      final c1 = [cena.camera, ...cena.extraCameras][i];
      final c2 = [a.camera, ...a.extraCameras][i];
      for (var k = 0; k <= 40; k++) {
        expect(c2.posX.valueAt(t(k / 4)), c1.posX.valueAt(t(k / 4)));
        expect(c2.posY.valueAt(t(k / 4)), c1.posY.valueAt(t(k / 4)));
        expect(c2.rotZ.valueAt(t(k / 4)), c1.rotZ.valueAt(t(k / 4)));
      }
    }
    expect(florTriangles(outro), florTriangles(projeto));
  });
}
