import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import 'layer_actions.dart';

/// ZONA C — O TRANSPORTE (48 pt).
///
/// `|◀ ▶ ▶|` · timecode atual / total (toque = digitar) · loop · ◆
/// keyframe · marca. So reproducao e tempo: desfazer mora na barra de
/// cima e duplicar mora nas acoes da camada (secao 4C do prompt).
class EditorTransportBar extends ConsumerWidget {
  const EditorTransportBar({
    super.key,
    required this.playback,
    required this.onKeyframe,
    required this.keyframeHere,
    required this.keyframeEnabled,
  });

  final PlaybackController playback;

  /// Crava ou tira o keyframe da propriedade ativa no instante atual.
  final VoidCallback onKeyframe;
  final bool keyframeHere;
  final bool keyframeEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AureaTokens.of(context);
    final duration = ref.watch(editorControllerProvider.select((p) => p.duration));
    final fps = ref.watch(editorControllerProvider.select((p) => p.fps));
    final markers = ref.watch(editorControllerProvider.select((p) => p.markers));
    final controller = ref.read(editorControllerProvider.notifier);

    Widget botao({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
      Color? cor,
      double size = 22,
      VoidCallback? onLongPress,
    }) => Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: AureaTokens.minTap,
          height: AureaTokens.minTap,
          child: Icon(
            icon,
            size: size,
            color: cor ?? (onTap == null ? t.muted.withValues(alpha: .5) : t.text),
          ),
        ),
      ),
    );

    return Container(
      height: AureaTokens.transport,
      color: t.surface,
      child: Row(
        children: [
          const SizedBox(width: 4),
          botao(
            key: const ValueKey('transport-start'),
            icon: CupertinoIcons.backward_end,
            tooltip: markers.isEmpty ? 'Inicio' : 'Marca anterior',
            onTap: () {
              final now = playback.time.value;
              playback.seek(
                markers.isEmpty
                    ? Duration.zero
                    : (controller.markerBefore(now) ?? Duration.zero),
              );
            },
          ),
          ValueListenableBuilder<bool>(
            valueListenable: playback.playing,
            builder: (context, playing, _) => botao(
              key: const ValueKey('transport-play'),
              icon: playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              tooltip: playing ? 'Pausar' : 'Reproduzir',
              size: 26,
              cor: t.text,
              onTap: playback.toggle,
            ),
          ),
          botao(
            key: const ValueKey('transport-end'),
            icon: CupertinoIcons.forward_end,
            tooltip: markers.isEmpty ? 'Fim' : 'Proxima marca',
            onTap: () {
              final now = playback.time.value;
              playback.seek(
                markers.isEmpty
                    ? duration
                    : (controller.markerAfter(now) ?? duration),
              );
            },
          ),
          // TIMECODE atual / total. Toque = digitar o tempo.
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: playback.time,
              builder: (context, now, _) => GestureDetector(
                key: const ValueKey('transport-timecode'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _digitarTempo(context, playback, duration, fps),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: t.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        children: [
                          TextSpan(
                            text: formatTimecode(now, fps),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' / ${formatTimecode(duration, fps)}',
                            style: TextStyle(color: t.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: playback.loop,
            builder: (context, loop, _) => botao(
              key: const ValueKey('transport-loop'),
              icon: CupertinoIcons.repeat,
              tooltip: loop ? 'Loop ligado' : 'Loop',
              cor: loop ? t.accent : t.text,
              onTap: () => playback.loop.value = !loop,
            ),
          ),
          // ◆ KEYFRAME: o losango unico (principio 7).
          botao(
            key: const ValueKey('transport-keyframe'),
            icon: keyframeHere ? CupertinoIcons.rhombus_fill : CupertinoIcons.rhombus,
            tooltip: keyframeHere
                ? 'Keyframe: remover aqui'
                : 'Keyframe: adicionar aqui',
            cor: !keyframeEnabled
                ? t.muted.withValues(alpha: .5)
                : t.keyframe,
            onTap: keyframeEnabled ? onKeyframe : null,
          ),
          // MARCA: toque poe/tira (no ritmo, com o play andando); toque
          // longo abre o que as marcas destravam.
          ValueListenableBuilder<Duration>(
            valueListenable: playback.time,
            builder: (context, now, _) {
              final tem =
                  ref
                      .read(editorControllerProvider)
                      .markerNear(now, const Duration(milliseconds: 120)) !=
                  null;
              return botao(
                key: const ValueKey('transport-marker'),
                icon: tem ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark,
                tooltip: 'Marca (toque longo: menu das marcas)',
                cor: tem ? t.accent : t.text,
                onTap: () => controller.toggleMarker(playback.time.value),
                onLongPress: () => menuDasMarcas(context, ref, playback),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Future<void> _digitarTempo(
    BuildContext context,
    PlaybackController playback,
    Duration total,
    int fps,
  ) async {
    playback.pause();
    final ctrl = TextEditingController(
      text: (playback.time.value.inMilliseconds / 1000).toStringAsFixed(2),
    );
    final r = await showCupertinoDialog<String>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Ir para o tempo'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            key: const ValueKey('transport-timecode-campo'),
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: 'segundos, ou mm:ss.ms',
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Ir'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    final t = parseTimecodeInput(r ?? '', fps);
    if (t == null) return;
    playback.seek(t < Duration.zero ? Duration.zero : (t > total ? total : t));
  }
}

/// Le "12.5", "1:02.5", "00:01:02:15" (o ultimo campo em quadros quando
/// ha tres separadores).
Duration? parseTimecodeInput(String texto, int fps) {
  final s = texto.trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  final partes = s.split(':');
  try {
    if (partes.length == 1) {
      return Duration(microseconds: (double.parse(partes[0]) * 1e6).round());
    }
    if (partes.length == 2) {
      final m = int.parse(partes[0]);
      final seg = double.parse(partes[1]);
      return Duration(microseconds: ((m * 60 + seg) * 1e6).round());
    }
    if (partes.length == 3) {
      final h = int.parse(partes[0]);
      final m = int.parse(partes[1]);
      final seg = double.parse(partes[2]);
      return Duration(microseconds: ((h * 3600 + m * 60 + seg) * 1e6).round());
    }
    if (partes.length == 4) {
      final h = int.parse(partes[0]);
      final m = int.parse(partes[1]);
      final seg = int.parse(partes[2]);
      final q = int.parse(partes[3]);
      return Duration(
        microseconds:
            ((h * 3600 + m * 60 + seg) * 1e6).round() +
            (q * 1e6 / (fps <= 0 ? 30 : fps)).round(),
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}
