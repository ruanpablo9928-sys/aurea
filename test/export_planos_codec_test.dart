import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// O CODIFICADOR ANDROID ESCREVE NO LAYOUT QUE O CODEC PEDIU.
///
/// YUV420Flexible quer dizer: o codec escolhe entre NV12, NV21 e I420, e
/// os strides. Despejar NV12 fixo acerta nos Snapdragon e erra nos
/// MediaTek (o Moto G05): planos de croma trocados ou desalinhados viram
/// tinta verde/roxa no video exportado. O contrato aqui e que o Kotlin
/// pergunte o layout (getInputImage) e honre rowStride/pixelStride — e
/// que o arquivo saia etiquetado (caixa colr) mesmo quando o codificador
/// nao repete as etiquetas.
///
/// Kotlin nao roda no `flutter test`; o que da para provar daqui e o
/// codigo-fonte, que e o que se compila no APK.
void main() {
  final kt = File('android/app/src/main/kotlin/com/aurea/aurea/VideoEncoder.kt')
      .readAsStringSync();

  test('o quadro entra pelos planos da Image, com stride', () {
    expect(kt, contains('getInputImage('));
    expect(kt, contains('rowStride'));
    expect(kt, contains('pixelStride'));
    // A capacidade e lida antes da Image: pedir a Image invalida o buffer.
    final capacidade = kt.indexOf('getInputBuffer(inIndex)?.capacity()');
    final image = kt.indexOf('getInputImage(inIndex)');
    expect(capacidade, greaterThan(-1));
    expect(capacidade, lessThan(image));
  });

  test('sem Image o caminho antigo continua la', () {
    expect(kt, contains('buf.put(yuv!!)'));
  });

  test('a caixa colr sai do formato que vai ao muxer, sempre 709 limitado', () {
    final mudou = kt.indexOf('INFO_OUTPUT_FORMAT_CHANGED ->');
    final addTrack = kt.indexOf('addTrack(', mudou);
    expect(mudou, greaterThan(-1));
    expect(addTrack, greaterThan(mudou));
    final trecho = kt.substring(mudou, addTrack);
    expect(trecho, contains('KEY_COLOR_STANDARD'));
    expect(trecho, contains('COLOR_STANDARD_BT709'));
    expect(trecho, contains('COLOR_RANGE_LIMITED'));
    expect(trecho, contains('COLOR_TRANSFER_SDR_VIDEO'));
    expect(kt, contains('addTrack(fmt)'));
  });
}
