import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../domain/layer.dart';
import 'preview_stats.dart';
import 'proxy_service.dart';

/// Gerencia um VideoPlayerController por camada de video e mantem todos
/// sincronizados ao clock mestre (play/pause/seek + correcao de drift).
class VideoLayerManager {
  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initializing = {};
  final Map<String, DateTime> _lastSeek = {};

  /// Ultimo volume APLICADO por camada: setVolume e uma chamada de
  /// plataforma — repeti-la a cada tick (30x/s por camada) derruba o
  /// preview. So chama quando o valor realmente muda.
  final Map<String, double> _appliedVolume = {};

  /// Notifica quando um controller termina de inicializar (para o preview
  /// trocar o placeholder pelo video).
  final ValueNotifier<int> revision = ValueNotifier(0);

  /// Ultimo estado visto pelo [sync]: quando um controller termina de
  /// inicializar, o sync roda DE NOVO com ele — sem isso, um clip
  /// CORTADO (sourceOffset != 0) nascia mostrando o frame 0 do arquivo
  /// ate alguem mexer no clock ("nao decupa nada").
  List<Layer> _lastLayers = const [];
  Duration _lastT = Duration.zero;
  bool _lastPlaying = false;

  /// Midias da cena, remontadas so quando a cena muda (zero alocacao por
  /// tick). Audio vem antes de video: o audio e o relogio mestre.
  final List<
      ({
        String id,
        String path,
        double volume,
        Duration offset,
        Layer layer
      })> _media = [];

  /// Ultima posicao JA VISTA por camada: o plugin so publica posicao a
  /// cada ~500 ms, e ancorar o relogio numa amostra repetida empurraria
  /// a composicao para tras.
  final Map<String, Duration?> _lastPos = {};

  /// Vies constante de amostragem por camada (us): a posicao publicada
  /// pelo plugin sempre chega com atraso. Nao e deriva — e medido uma
  /// vez por reproducao e descontado de todas as amostras seguintes.
  final Map<String, int> _biasUs = {};

  VideoPlayerController? controllerFor(String layerId) =>
      _controllers[layerId];

  void _ensure(String id, String path, double volume) {
    if (_controllers.containsKey(id) || _initializing.containsKey(id)) {
      return;
    }
    final controller = VideoPlayerController.file(File(path));
    _initializing[id] = controller.initialize().then((_) {
      _controllers[id] = controller;
      _initializing.remove(id);
      controller.setVolume(volume);
      _appliedVolume[id] = volume;
      revision.value++;
      // Seek inicial no instante atual do clock (decupagem correta).
      sync(_lastLayers, _lastT, _lastPlaying);
    }).catchError((_) {
      _initializing.remove(id);
      controller.dispose();
    });
  }

  /// Chamado a cada mudanca relevante do clock. Camadas de AUDIO usam o
  /// mesmo pipeline (ExoPlayer/AVPlayer tocam audio puro sem textura).
  Duration? sync(List<Layer> layers, Duration t, bool isPlaying) {
    _lastT = t;
    _lastPlaying = isPlaying;

    // Zero alocacao no caminho quente (travada-periodica C6): a lista de
    // midias so e remontada quando a CENA muda, nunca a cada tick.
    if (!identical(layers, _lastLayers)) {
      _lastLayers = layers;
      _media
        ..clear()
        // Audio primeiro: ele e o relogio mestre (nunca "pula" frame).
        ..addAll([
          for (final l in layers)
            if (l is AudioLayer)
              (
                id: l.id,
                path: l.sourcePath,
                volume: l.volume,
                offset: l.sourceOffset,
                layer: l
              ),
          for (final l in layers)
            if (l is VideoLayer)
              (
                id: l.id,
                // PROXY quando ha: quadro-chave a cada 6 quadros faz o
                // scrub ficar continuo. Sem proxy, o original — nunca
                // deixa de tocar por falta de cache.
                path: ProxyService.instance.playbackPath(l.sourcePath),
                volume: l.volume,
                offset: l.sourceOffset,
                layer: l
              ),
        ]);

      // Descarta controllers de camadas removidas.
      final liveIds = {for (final m in _media) m.id};
      final dead =
          _controllers.keys.where((id) => !liveIds.contains(id)).toList();
      for (final id in dead) {
        _controllers.remove(id)?.dispose();
        _lastSeek.remove(id);
        _appliedVolume.remove(id);
        _lastPos.remove(id);
      }
    }
    final mediaLayers = _media;

    // Relogio mestre desta passada: a primeira midia ativa que trouxer
    // amostra nova de posicao (audio primeiro — ver ordenacao acima).
    Duration? master;

    for (final m in mediaLayers) {
      _ensure(m.id, m.path, m.volume);
      final controller = _controllers[m.id];
      if (controller == null) continue;
      final layer = m.layer;
      final isAudio = layer is AudioLayer;

      if (_appliedVolume[m.id] != m.volume) {
        _appliedVolume[m.id] = m.volume;
        controller.setVolume(m.volume);
      }
      final active = layer.activeAt(t);
      final local = t - layer.startTime + m.offset;

      if (active && isPlaying) {
        if (!controller.value.isPlaying) {
          controller.seekTo(local);
          controller.play();
          _lastPos[m.id] = null;
          _biasUs.remove(m.id);
        } else {
          // PR-J1: NENHUM seek durante a reproducao. O antigo "se a
          // deriva passar de X, corrige" corrigia em BLOCO, e o bloco
          // (flush do decoder) era a travada periodica. Agora a midia e
          // o RELOGIO MESTRE: cada amostra NOVA de posicao ancora o
          // clock da composicao continuamente, sem acumular deriva.
          final pos = controller.value.position;
          if (_lastPos[m.id] != pos) {
            _lastPos[m.id] = pos;
            // A posicao do plugin so atualiza a cada ~500 ms: ancorar
            // com amostra repetida empurraria o relogio para tras.
            if (master == null) {
              // A amostra nasce VELHA (idade media ~250 ms). Esse vies e
              // constante e NAO e deriva: ancorar nele puxaria o relogio
              // para tras. Guardamos o vies na primeira amostra e
              // corrigimos so o que DERIVOU a partir dali.
              final errUs = (pos - local).inMicroseconds;
              final bias = _biasUs[m.id] ??= errUs;
              final relUs = errUs - bias;
              master = t + Duration(microseconds: relUs);
              FrameLog.reportDrift(-relUs / 1000.0);
            }
          }
        }
      } else {
        if (controller.value.isPlaying) controller.pause();
        // Scrub pausado: video precisa do seek para MOSTRAR o frame;
        // audio pausado nao tem nada a mostrar — seek so na hora do
        // play. Era o que afogava o preview ao arrastar a timeline.
        if (active && !isAudio) {
          final last = _lastSeek[layer.id];
          if (last == null ||
              DateTime.now().difference(last) >
                  const Duration(milliseconds: 66)) {
            controller.seekTo(local);
            _lastSeek[layer.id] = DateTime.now();
          }
        }
        _lastPos[m.id] = null;
        _biasUs.remove(m.id);
      }
    }
    return master;
  }

  void pauseAll() {
    for (final c in _controllers.values) {
      if (c.value.isPlaying) c.pause();
    }
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    revision.dispose();
  }
}
