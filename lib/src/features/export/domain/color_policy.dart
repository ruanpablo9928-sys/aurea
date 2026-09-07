import 'dart:typed_data';

/// A POLITICA DE COR DA EXPORTACAO — um lugar so, e este e o lugar.
///
/// O sintoma que trouxe este arquivo: o video exportado saia com cores
/// diferentes do preview. Nao era impressao. Eram duas coisas, cada uma
/// num canto do app, e nenhuma delas escrita em lugar nenhum.
///
/// NO ANDROID a conversao RGB→YUV usava os coeficientes do BT.601
/// (66/129/25), e o arquivo saia SEM ETIQUETA de cor. Player nenhum
/// adivinha: diante de um H.264 de alta definicao sem etiqueta, todos
/// assumem BT.709. Entao o quadro era escrito com uma matriz e lido com
/// outra — e uma matriz trocada nao "escurece um pouco", ela GIRA o
/// matiz: o verde puxa para amarelo, a pele avermelha. Era esse o
/// "cores diferentes".
///
/// NO IOS o escritor nao recebia `AVVideoColorProperties`, entao a
/// etiqueta do arquivo dependia do que o AVFoundation decidisse, e o
/// desenho ia para um contexto `DeviceRGB` — um espaco que depende do
/// aparelho, em vez do sRGB explicito em que o Flutter pinta.
///
/// A CADEIA, agora declarada de ponta a ponta:
///
///   ENTRADA      o Flutter pinta em sRGB (8 bits por canal, cheio)
///   TRABALHO     sRGB — a composicao inteira acontece aqui
///   SAIDA        BT.709 primarias + transferencia
///   MATRIZ       BT.709
///   FAIXA        LIMITADA (16..235 em Y, 16..240 em croma)
///
/// Duas escolhas merecem justificativa:
///
/// FAIXA LIMITADA e nao cheia. Faixa cheia guarda mais degraus, mas
/// depende de o arquivo ser etiquetado como cheia E de o player
/// respeitar a etiqueta. Faixa limitada e o que todo player espera de um
/// MP4; escolher a que funciona em todo lugar vale mais que os degraus
/// extras que quase ninguem ve.
///
/// sRGB TRATADO COMO 709 na transferencia. As duas curvas nao sao
/// identicas — divergem no pe da escala, nos tons mais escuros — mas
/// H.264 nao tem etiqueta para "sRGB", e converter de uma para a outra
/// custaria uma passada a mais por quadro para corrigir algo que so
/// aparece em medicao. E a mesma aproximacao que todo editor de video
/// faz. O que NAO se pode fazer e o que estava sendo feito: converter
/// com uma matriz e etiquetar com outra.
class ExportColor {
  ExportColor._();

  /// O que vai na etiqueta do arquivo. Os tres tem de ser iguais nos
  /// dois sistemas, e iguais ao que a conversao realmente fez.
  static const primarias = 'bt709';
  static const transferencia = 'bt709';
  static const matriz = 'bt709';
  static const faixaLimitada = true;

  // ---------------------------------------------------------- BT.709
  //
  // Y  =  0,2126 R + 0,7152 G + 0,0722 B   (luminancia 709)
  // Cb = (B - Y) / 1,8556
  // Cr = (R - Y) / 1,5748
  //
  // com a escala da faixa limitada: Y ocupa 16..235 (219 degraus) e o
  // croma 16..240, centrado em 128.
  //
  // Em ponto fixo de 8 bits (x256), com uma condicao que nao pode ser
  // arredondada por descuido: a SOMA dos tres coeficientes de croma tem
  // de dar exatamente zero. Se nao der, cinza deixa de ser cinza — um
  // desvio constante entra no croma e a imagem inteira ganha uma
  // dominante.

  /// Coeficientes de Y, em ponto fixo x256. Somam 220: e o que faz o
  /// branco cair exatamente em 235.
  static const yR = 47, yG = 157, yB = 16;

  /// Coeficientes de Cb, x256. Somam ZERO.
  static const cbR = -26, cbG = -87, cbB = 113;

  /// Coeficientes de Cr, x256. Somam ZERO.
  static const crR = 113, crG = -102, crB = -11;

  static int _corta(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

  /// A conversao de referencia, em Dart.
  ///
  /// Os codificadores nativos fazem esta mesma conta — o Android em
  /// Kotlin, o iOS por dentro do AVFoundation. Esta versao existe para
  /// o teste poder cobrar o resultado: e ela que diz o que preto,
  /// branco, cinza e as primarias TEM de virar.
  static ({int y, int cb, int cr}) rgbParaYCbCr(int r, int g, int b) => (
    y: _corta(((yR * r + yG * g + yB * b + 128) >> 8) + 16),
    cb: _corta(((cbR * r + cbG * g + cbB * b + 128) >> 8) + 128),
    cr: _corta(((crR * r + crG * g + crB * b + 128) >> 8) + 128),
  );

  /// Converte um quadro RGBA em NV12 (Y inteiro, depois CbCr entrelacado
  /// em 2x2) — o formato que o MediaCodec do Android aceita.
  ///
  /// Mora aqui, e nao so no Kotlin, porque assim o teste consegue
  /// comparar quadro a quadro sem aparelho na mao.
  static Uint8List rgbaParaNv12(Uint8List rgba, int largura, int altura) {
    final out = Uint8List(largura * altura * 3 ~/ 2);
    var yi = 0;
    var uvi = largura * altura;
    for (var linha = 0; linha < altura; linha++) {
      for (var col = 0; col < largura; col++) {
        final p = (linha * largura + col) * 4;
        final r = rgba[p], g = rgba[p + 1], b = rgba[p + 2];
        final c = rgbParaYCbCr(r, g, b);
        out[yi++] = c.y;
        if (linha.isEven && col.isEven) {
          out[uvi++] = c.cb;
          out[uvi++] = c.cr;
        }
      }
    }
    return out;
  }
}
