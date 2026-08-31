import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../domain/layer.dart';

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
      revision.value++;
    }).catchError((_) {
      _initializing.remove(id);
      controller.dispose();
    });
  }

  /// Chamado a cada mudanca relevante do clock. Camadas de AUDIO usam o
  /// mesmo pipeline (ExoPlayer/AVPlayer tocam audio puro sem textura).
  void sync(List<Layer> layers, Duration t, bool isPlaying) {
    final mediaLayers = <
        ({String id, String path, double volume, Duration offset, Layer layer})>[
      for (final l in layers)
        if (l is VideoLayer)
          (
            id: l.id,
            path: l.sourcePath,
            volume: l.volume,
            offset: l.sourceOffset,
            layer: l
          )
        else if (l is AudioLayer)
          (
            id: l.id,
            path: l.sourcePath,
            volume: l.volume,
            offset: Duration.zero,
            layer: l
          ),
    ];

    // Descarta controllers de camadas removidas.
    final liveIds = mediaLayers.map((m) => m.id).toSet();
    final dead = _controllers.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in dead) {
      _controllers.remove(id)?.dispose();
      _lastSeek.remove(id);
      _appliedVolume.remove(id);
    }

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
        } else {
          // Correcao de drift a cada ~800ms. O relato de posicao do
          // audio e mais grosso (polling do plugin): limiar maior, senao
          // vira uma tempestade de seeks que engasga tudo.
          final last = _lastSeek[layer.id];
          if (last == null ||
              DateTime.now().difference(last) >
                  const Duration(milliseconds: 800)) {
            final drift = (controller.value.position - local).abs();
            final threshold = isAudio
                ? const Duration(milliseconds: 400)
                : const Duration(milliseconds: 140);
            if (drift > threshold) {
              controller.seekTo(local);
            }
            _lastSeek[layer.id] = DateTime.now();
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
      }
    }
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
