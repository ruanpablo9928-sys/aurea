import 'package:flutter/services.dart';

/// CODIFICADOR DA PLATAFORMA — a ponte para o MediaCodec (Android) e o
/// AVAssetWriter (iOS).
///
/// Por que trocar o x264 do FFmpeg por isto:
///
///   LICENCA   x264 e GPL. Num app comercial isso obrigaria a abrir o
///             codigo inteiro. O codificador do sistema nao contamina, e
///             a exposicao de patente passa a ser do fabricante.
///   VELOCIDADE  e hardware; x264 e software.
///   MANUTENCAO  vem com o sistema, nao e dependencia aposentada.
///
/// O FFmpeg continua no app para DECODIFICAR e para juntar o audio — usos
/// que nao precisam de codec GPL.
class PlatformEncoder {
  PlatformEncoder._();

  static const _channel = MethodChannel('aurea/encoder');

  static bool? _available;

  /// Se o aparelho tem o codificador. Consultado uma vez.
  static Future<bool> get available async {
    if (_available != null) return _available!;
    try {
      _available = await _channel.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      _available = false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Abre o fluxo. [bitrate] em bits por segundo.
  static Future<void> start({
    required String path,
    required int width,
    required int height,
    required int fps,
    required int bitrate,
    bool hevc = false,
  }) async {
    await _channel.invokeMethod<bool>('start', {
      'path': path,
      'width': width,
      'height': height,
      'fps': fps,
      'bitrate': bitrate,
      'hevc': hevc,
    });
  }

  /// Codifica um quadro a partir de um PNG no disco.
  ///
  /// Caminho ANTIGO, mantido so para o modo de reserva. Ver [frameRgba]:
  /// passar por PNG e disco custava mais que codificar.
  static Future<void> frame(String path) async {
    await _channel.invokeMethod<bool>('frame', {'path': path});
  }

  /// CODIFICA UM QUADRO DIRETO DA MEMORIA.
  ///
  /// Este metodo e a correcao central da exportacao. O caminho anterior,
  /// por quadro, era:
  ///
  ///   GPU → CPU  →  codificar PNG (zlib)  →  gravar no disco
  ///                        ... e depois, numa segunda passada ...
  ///   ler do disco  →  decodificar PNG  →  buffer  →  codificador
  ///
  /// O PNG nao existia por nenhum motivo de imagem: era so o jeito de os
  /// pixels irem do Dart ao codificador nativo. Custava de longe a maior
  /// parte do tempo de exportacao (o zlib de um quadro 1080p sozinho e
  /// dezenas a centenas de milissegundos) e obrigava a guardar o filme
  /// inteiro descomprimido em disco — dezenas de gigabytes num filme de
  /// dez minutos, que e por que a exportacao as vezes simplesmente nao
  /// terminava.
  ///
  /// Agora os bytes crus atravessam a ponte uma vez e entram no
  /// codificador. Sem compressao, sem disco, sem segunda passada.
  static Future<void> frameRgba(Uint8List rgba, int width, int height) async {
    await _channel.invokeMethod<bool>('frameRgba', {
      'bytes': rgba,
      'width': width,
      'height': height,
    });
  }

  /// Codifica um LOTE de quadros numa chamada so. Atravessar a ponte por
  /// quadro custa mais que codificar em muitos aparelhos.
  static Future<int> frames(List<String> paths) async {
    final n = await _channel.invokeMethod<int>('frames', {'paths': paths});
    return n ?? 0;
  }

  /// ESPACO LIVRE no disco onde a exportacao vai escrever, em bytes.
  /// Zero quando o sistema nao responde — nesse caso nao se bloqueia
  /// nada: e melhor tentar do que impedir por falta de informacao.
  static Future<int> espacoLivre(String path) async {
    try {
      final v = await _channel.invokeMethod<int>('freeBytes', {'path': path});
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> finish() async =>
      await _channel.invokeMethod<bool>('finish') ?? false;

  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<bool>('cancel');
    } catch (_) {}
  }

  /// REMUX: copia as trilhas sem recodificar. Corte puro deixa de custar
  /// um render inteiro — sai quase instantaneo.
  static Future<bool> remux({
    required String source,
    required String target,
    Duration start = Duration.zero,
    Duration? end,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('remux', {
            'source': source,
            'target': target,
            'startUs': start.inMicroseconds,
            'endUs': end?.inMicroseconds ?? 0,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  // A CONTA DE TAXA DE BITS SAIU DAQUI.
  //
  // Havia duas, iguais menos por um detalhe: esta ignorava o codec, e a
  // de `ExportSettings.bitrateFor` desconta os 35% que o HEVC pede a
  // menos. Duas contas para a mesma pergunta e uma delas ser escolhida
  // por um `if` era o que fazia "alta" ser silenciosamente ignorado.
  // Agora so existe a dos ajustes.
}
