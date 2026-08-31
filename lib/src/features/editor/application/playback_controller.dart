import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'preview_stats.dart';

/// Clock mestre da composicao.
///
/// Um unico [Ticker] alimenta [time] (ValueNotifier); quem depende do tempo
/// escuta o notifier direto, sem setState por frame. Toda a UI (preview,
/// playhead, contador) deriva deste valor.
class PlaybackController {
  PlaybackController({
    required TickerProvider vsync,
    required this.durationOf,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final Duration Function() durationOf;
  late final Ticker _ticker;

  final ValueNotifier<Duration> time = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> playing = ValueNotifier(false);

  /// Taxa da COMPOSICAO (fps do projeto). O ticker roda a cada vsync
  /// (60-120 Hz), mas o clock so notifica quando o FRAME da composicao
  /// muda — num painel de 90 Hz com projeto de 30 fps, isso corta 2/3
  /// das recomposicoes (spec motor-de-preview, C1: compor na taxa da
  /// composicao, nunca na da tela).
  int compositionFps = 30;

  Duration _base = Duration.zero;

  void _onTick(Duration elapsed) {
    final t = _base + elapsed;
    final end = durationOf();
    if (t >= end) {
      time.value = end;
      pause();
      return;
    }
    final fps = compositionFps < 1 ? 30 : compositionFps;
    final frameUs = 1000000 ~/ fps;
    final quantized = Duration(
        microseconds: (t.inMicroseconds ~/ frameUs) * frameUs);
    if (quantized != time.value) {
      // Cadencia (marchas §6): a metrica de suavidade e a VARIANCIA do
      // intervalo entre ticks, nao a media de fps. FrameLog mede no
      // ponto de APRESENTACAO (travada-periodica, PR-J0).
      PreviewStats.clockTick();
      FrameLog.present();
      time.value = quantized;
    }
  }

  /// ANCORAGEM CONTINUA na midia (PR-J1, fim da deriva por construcao).
  ///
  /// O padrao "se a diferenca passar de X, corrige" corrige em BLOCO — e
  /// o bloco E a travada periodica. Aqui o erro medido contra a posicao
  /// real do player e absorvido em fracoes, a cada amostra: a deriva
  /// nunca acumula, entao nunca existe correcao em bloco. Como a imagem
  /// do video vem da textura da plataforma, deslocar o relogio em alguns
  /// ms nao mexe um pixel — ao contrario do seek, que esvazia o decoder.
  void anchorToMedia(Duration mediaTime) {
    if (!playing.value) return;
    final errUs = mediaTime.inMicroseconds - time.value.inMicroseconds;
    if (errUs.abs() > 1000000) {
      // Dessincronia REAL (app em background, midia reiniciada): nao e
      // deriva — realinha de uma vez.
      _base += Duration(microseconds: errUs);
      debugBaseShiftUs = errUs;
      return;
    }
    // Slew proporcional, teto de 20 ms por amostra (~2 amostras/s).
    final step = (errUs * 0.25).round().clamp(-20000, 20000);
    debugBaseShiftUs = step;
    if (step != 0) _base += Duration(microseconds: step);
  }

  /// Ultimo deslocamento aplicado pela ancoragem (us) — so para teste e
  /// diagnostico: mostra que a correcao e fracionada, nunca em bloco.
  int debugBaseShiftUs = 0;

  void play() {
    if (playing.value) return;
    final end = durationOf();
    if (end == Duration.zero) return;
    if (time.value >= end) time.value = Duration.zero;
    _base = time.value;
    _ticker.start();
    playing.value = true;
    FrameLog.reset();
  }

  void pause() {
    if (_ticker.isActive) _ticker.stop();
    playing.value = false;
    // Intervalo atravessando a pausa nao e jitter.
    PreviewStats.clockReset();
  }

  void toggle() => playing.value ? pause() : play();

  void seek(Duration t) {
    final end = durationOf();
    var v = t;
    if (v < Duration.zero) v = Duration.zero;
    if (v > end) v = end;
    if (playing.value) {
      _ticker.stop();
      _base = v;
      time.value = v;
      _ticker.start();
    } else {
      time.value = v;
    }
  }

  void dispose() {
    _ticker.dispose();
    time.dispose();
    playing.dispose();
  }
}
