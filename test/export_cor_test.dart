import 'dart:io';
import 'dart:typed_data';

import 'package:aurea/src/features/export/domain/color_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// A COR DA EXPORTACAO.
///
/// A queixa era "o video exportado tem cores diferentes do preview", e a
/// causa era concreta: o Android convertia RGB→YUV com os coeficientes
/// do BT.601 e gravava o arquivo SEM ETIQUETA de cor. Sem etiqueta, todo
/// player assume BT.709 num video de alta definicao — entao o quadro era
/// escrito com uma matriz e lido com outra. Matriz trocada nao escurece:
/// ela GIRA o matiz.
///
/// Estes testes fixam a matriz certa, e fixam tambem a coisa que deixou
/// o bug nascer: o Dart e o Kotlin escreverem numeros diferentes sem que
/// ninguem percebesse.

/// O caminho de volta, BT.709 de faixa limitada. Existe so aqui: e o que
/// permite medir o erro de ida e volta sem aparelho na mao.
({int r, int g, int b}) _ycbcrParaRgb(int y, int cb, int cr) {
  final yy = (y - 16) / 219.0;
  final u = (cb - 128) / 224.0;
  final v = (cr - 128) / 224.0;
  int c(double x) => (x * 255).round().clamp(0, 255);
  return (
    r: c(yy + 1.5748 * v),
    g: c(yy - 0.1873 * u - 0.4681 * v),
    b: c(yy + 1.8556 * u),
  );
}

void main() {
  group('a matriz', () {
    test('preto e branco caem na faixa limitada, exatamente', () {
      final preto = ExportColor.rgbParaYCbCr(0, 0, 0);
      expect(preto.y, 16, reason: 'preto tem de ser 16, nao 0');
      expect(preto.cb, 128);
      expect(preto.cr, 128);

      final branco = ExportColor.rgbParaYCbCr(255, 255, 255);
      expect(branco.y, 235, reason: 'branco tem de ser 235, nao 255');
      expect(branco.cb, 128);
      expect(branco.cr, 128);
    });

    test('cinza continua cinza — os coeficientes de croma somam zero', () {
      // Se nao somassem, TODO cinza ganharia uma dominante, e a imagem
      // inteira sairia com um tom por cima.
      expect(ExportColor.cbR + ExportColor.cbG + ExportColor.cbB, 0);
      expect(ExportColor.crR + ExportColor.crG + ExportColor.crB, 0);
      for (final v in [16, 64, 128, 192, 240]) {
        final c = ExportColor.rgbParaYCbCr(v, v, v);
        expect(c.cb, 128, reason: 'cinza $v vazou para o croma');
        expect(c.cr, 128, reason: 'cinza $v vazou para o croma');
      }
    });

    test('e BT.709, e nao o BT.601 que estava la', () {
      // O verde e onde as duas matrizes mais discordam: 0,7152 (709)
      // contra 0,587 (601). Um verde puro tem de dar o Y do 709.
      final verde = ExportColor.rgbParaYCbCr(0, 255, 0);
      final y709 = ((157 * 255 + 128) >> 8) + 16; // 173
      final y601 = ((129 * 255 + 128) >> 8) + 16; // 145
      expect(verde.y, y709);
      expect(
        verde.y,
        isNot(y601),
        reason: 'voltou para a matriz do BT.601 — o matiz gira',
      );
      // E o azul, onde a diferenca corre para o outro lado.
      final azul = ExportColor.rgbParaYCbCr(0, 0, 255);
      expect(azul.y, ((16 * 255 + 128) >> 8) + 16);
    });

    test('a luminancia respeita a ordem de brilho das primarias', () {
      final r = ExportColor.rgbParaYCbCr(255, 0, 0).y;
      final g = ExportColor.rgbParaYCbCr(0, 255, 0).y;
      final b = ExportColor.rgbParaYCbCr(0, 0, 255).y;
      expect(g, greaterThan(r), reason: 'verde e o mais claro');
      expect(r, greaterThan(b), reason: 'azul e o mais escuro');
    });

    test('nada estoura os limites de 8 bits', () {
      for (final cor in [
        (0, 0, 0),
        (255, 255, 255),
        (255, 0, 0),
        (0, 255, 0),
        (0, 0, 255),
        (255, 255, 0),
        (0, 255, 255),
        (255, 0, 255),
      ]) {
        final c = ExportColor.rgbParaYCbCr(cor.$1, cor.$2, cor.$3);
        for (final v in [c.y, c.cb, c.cr]) {
          expect(v, inInclusiveRange(0, 255));
        }
      }
    });
  });

  group('preview contra exportacao', () {
    /// A CARTELA DE REFERENCIA que o usuario pediu: preto, branco,
    /// cinzas, primarias, tom de pele, e degrades.
    const cartela = <(String, int, int, int)>[
      ('preto', 0, 0, 0),
      ('sombra', 24, 24, 28),
      ('cinza escuro', 64, 64, 64),
      ('cinza medio', 128, 128, 128),
      ('cinza claro', 200, 200, 200),
      ('branco', 255, 255, 255),
      ('vermelho', 220, 40, 40),
      ('verde', 40, 200, 70),
      ('azul', 40, 70, 220),
      ('pele clara', 240, 200, 175),
      ('pele media', 198, 152, 120),
      ('pele escura', 120, 84, 62),
      ('ceu', 150, 190, 235),
      ('realce', 250, 245, 235),
    ];

    test('a ida e volta nao desloca a cor', () {
      // O que se mede aqui e o erro da MATRIZ, nao o do codec. Se a
      // conversao estivesse com a matriz errada, a volta traria uma cor
      // visivelmente diferente — que e exatamente o sintoma relatado.
      var pior = 0;
      String piorNome = '';
      for (final (nome, r, g, b) in cartela) {
        final c = ExportColor.rgbParaYCbCr(r, g, b);
        final volta = _ycbcrParaRgb(c.y, c.cb, c.cr);
        for (final d in [
          (volta.r - r).abs(),
          (volta.g - g).abs(),
          (volta.b - b).abs(),
        ]) {
          if (d > pior) {
            pior = d;
            piorNome = nome;
          }
        }
      }
      // Tres degraus em 255 e o arredondamento do ponto fixo de 8 bits e
      // da faixa limitada — invisivel. Acima disso e matriz errada.
      expect(
        pior,
        lessThanOrEqualTo(3),
        reason: 'desvio de $pior degraus em "$piorNome"',
      );
    });

    test('preto nao afunda e branco nao estoura', () {
      // "Preview normal, exportacao lavada" e "preview normal,
      // exportacao escura" sao os dois sintomas de faixa trocada.
      final preto = ExportColor.rgbParaYCbCr(0, 0, 0);
      final quaseP = ExportColor.rgbParaYCbCr(8, 8, 8);
      expect(quaseP.y, greaterThan(preto.y),
          reason: 'os tons proximos do preto colapsaram num so');

      final branco = ExportColor.rgbParaYCbCr(255, 255, 255);
      final quaseB = ExportColor.rgbParaYCbCr(247, 247, 247);
      expect(quaseB.y, lessThan(branco.y),
          reason: 'os tons proximos do branco colapsaram num so');
    });

    test('a saturacao nao desliza', () {
      // Um vermelho saturado e um dessaturado tem de manter a distancia
      // entre si depois da ida e volta.
      final forte = ExportColor.rgbParaYCbCr(230, 30, 30);
      final fraco = ExportColor.rgbParaYCbCr(180, 120, 120);
      final dForte = (forte.cr - 128).abs();
      final dFraco = (fraco.cr - 128).abs();
      expect(dForte, greaterThan(dFraco * 2));
    });
  });

  group('o quadro inteiro', () {
    test('NV12 tem o tamanho certo e o croma no lugar certo', () {
      const w = 8, h = 4;
      final rgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        rgba[i * 4] = 255; // vermelho puro
        rgba[i * 4 + 3] = 255;
      }
      final nv12 = ExportColor.rgbaParaNv12(rgba, w, h);
      expect(nv12.length, w * h * 3 ~/ 2);
      final vermelho = ExportColor.rgbParaYCbCr(255, 0, 0);
      expect(nv12[0], vermelho.y);
      // O croma comeca depois do plano de luminancia, entrelacado.
      expect(nv12[w * h], vermelho.cb);
      expect(nv12[w * h + 1], vermelho.cr);
      // Um quadro uniforme tem um croma por bloco 2x2.
      expect((nv12.length - w * h), w * h ~/ 2);
    });

    test('um quadro cinza nao ganha dominante nenhuma', () {
      const w = 16, h = 8;
      final rgba = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        rgba[i * 4] = 130;
        rgba[i * 4 + 1] = 130;
        rgba[i * 4 + 2] = 130;
        rgba[i * 4 + 3] = 255;
      }
      final nv12 = ExportColor.rgbaParaNv12(rgba, w, h);
      for (var i = w * h; i < nv12.length; i++) {
        expect(nv12[i], 128, reason: 'croma vazou no indice $i');
      }
    });
  });

  group('os dois lados falam a mesma lingua', () {
    // FOI ASSIM QUE O BUG NASCEU: a conta estava so no Kotlin, ninguem
    // olhava, e ela discordava do que o arquivo anunciava. Agora a
    // politica esta no Dart e o codigo nativo tem de repetir os MESMOS
    // numeros — este teste le o arquivo e cobra.
    String kotlin() =>
        File('android/app/src/main/kotlin/com/aurea/aurea/VideoEncoder.kt')
            .readAsStringSync();

    test('o Kotlin usa os coeficientes de ExportColor', () {
      final src = kotlin();
      expect(
        src,
        contains(
          '(${ExportColor.yR} * r + ${ExportColor.yG} * g + '
          '${ExportColor.yB} * b + 128)',
        ),
        reason: 'a luminancia do Kotlin nao e a da politica de cor',
      );
      expect(
        src,
        contains(
          '(${ExportColor.cbR} * r - ${ExportColor.cbG.abs()} * g + '
          '${ExportColor.cbB} * b + 128)',
        ),
        reason: 'o croma azul do Kotlin nao e o da politica de cor',
      );
      expect(
        src,
        contains(
          '(${ExportColor.crR} * r - ${ExportColor.crG.abs()} * g - '
          '${ExportColor.crB.abs()} * b + 128)',
        ),
        reason: 'o croma vermelho do Kotlin nao e o da politica de cor',
      );
    });

    test('o Kotlin etiqueta o arquivo com o que realmente fez', () {
      final src = kotlin();
      expect(src, contains('COLOR_STANDARD_BT709'));
      expect(src, contains('COLOR_RANGE_LIMITED'));
      expect(src, contains('COLOR_TRANSFER_SDR_VIDEO'));
      expect(
        src,
        isNot(contains('66 * r + 129 * g + 25 * b')),
        reason: 'o BT.601 voltou',
      );
    });

    test('o Swift etiqueta o arquivo e marca o buffer', () {
      final src = File('ios/Runner/VideoEncoderPlugin.swift').readAsStringSync();
      expect(src, contains('AVVideoColorPropertiesKey'));
      expect(src, contains('AVVideoYCbCrMatrix_ITU_R_709_2'));
      expect(src, contains('kCVImageBufferYCbCrMatrixKey'));
      expect(
        src,
        isNot(contains('space: CGColorSpaceCreateDeviceRGB(),')),
        reason: 'voltou ao espaco de cor que depende do aparelho',
      );
    });
  });
}
