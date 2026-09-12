import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../application/ui/editor_session.dart';
import '../am/am_colors.dart';
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
    this.onAdd,
  });

  /// O "+" unico do editor (adicionar camada). Mora aqui, no fim do
  /// transporte, para nunca cobrir uma linha da timeline.
  final VoidCallback? onAdd;

  final PlaybackController playback;

  /// Crava ou tira o keyframe da propriedade ativa no instante atual.
  final VoidCallback onKeyframe;
  final bool keyframeHere;
  final bool keyframeEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AureaTokens.of(context);
    final duration = ref.watch(
      editorControllerProvider.select((p) => p.duration),
    );
    final fps = ref.watch(editorControllerProvider.select((p) => p.fps));
    final controller = ref.read(editorControllerProvider.notifier);
    final selected = ref.watch(selectedLayerProvider);
    ref.watch(editorControllerProvider);
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
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap();
              },
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress();
              },
        child: SizedBox(
          width: AureaTokens.minTap,
          height: AureaTokens.minTap,
          child: Icon(
            icon,
            size: size,
            color:
                cor ?? (onTap == null ? t.muted.withValues(alpha: .5) : t.text),
          ),
        ),
      ),
    );

    // OITO BOTOES NUM CELULAR DE 320 PX. Cada um mede 44 (o alvo minimo),
    // e oito vezes 44 sao 352: a tesoura nova estourava a fileira em 32
    // pixels no aparelho mais estreito. Aqui cada botao recebe uma fatia
    // igual da largura que existe — 44 quando cabe, e nunca menos de 36,
    // que ainda e um alvo que o dedo acerta.
    return Container(
      height: AureaTokens.transport,
      color: t.surface,
      child: LayoutBuilder(
        builder: (context, c) {
          final filhos = <Widget>[
            botao(
              key: const ValueKey('editor-undo'),
              icon: CupertinoIcons.arrow_uturn_left,
              tooltip: 'Desfazer',
              onTap: controller.canUndo ? controller.undo : null,
            ),
            botao(
              key: const ValueKey('editor-redo'),
              icon: CupertinoIcons.arrow_uturn_right,
              tooltip: 'Refazer',
              onTap: controller.canRedo ? controller.redo : null,
            ),
            botao(
              key: const ValueKey('transport-start'),
              icon: CupertinoIcons.backward_end,
              tooltip: 'Início · segure para marcas',
              onTap: () => playback.seek(Duration.zero),
              onLongPress: () => menuDasMarcas(context, ref, playback),
            ),
            ListenableBuilder(
              listenable: Listenable.merge([playback.playing, playback.loop]),
              builder: (context, _) => botao(
                key: const ValueKey('transport-play'),
                icon: playback.playing.value
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                tooltip: playback.loop.value
                    ? 'Repetição ligada · segure para desligar'
                    : (playback.playing.value ? 'Pausar' : 'Reproduzir'),
                cor: playback.loop.value ? t.accent : t.text,
                size: 24,
                onTap: playback.toggle,
                onLongPress: () => playback.loop.value = !playback.loop.value,
              ),
            ),
            botao(
              key: const ValueKey('transport-end'),
              icon: CupertinoIcons.forward_end,
              tooltip: 'Fim · segure para ir ao tempo',
              onTap: () => playback.seek(duration),
              onLongPress: () =>
                  _digitarTempo(context, playback, duration, fps),
            ),
            botao(
              key: const ValueKey('transport-keyframe'),
              icon: keyframeHere
                  ? CupertinoIcons.rhombus_fill
                  : CupertinoIcons.rhombus,
              tooltip: keyframeHere
                  ? 'Remover keyframe no cabeçote'
                  : 'Adicionar keyframe no cabeçote',
              cor: !keyframeEnabled
                  ? t.muted.withValues(alpha: .35)
                  : (keyframeHere ? AmColors.accent : t.text),
              size: 24,
              onTap: keyframeEnabled ? onKeyframe : null,
            ),
            botao(
              key: const ValueKey('camada-duplicar'),
              icon: CupertinoIcons.plus_square_on_square,
              tooltip: 'Duplicar camada',
              onTap: selected == null
                  ? null
                  : () => controller.duplicateLayer(selected),
            ),
            // DIVIDIR SEMPRE A VISTA. Estava numa fila de acoes que a
            // largura da tela escondia atras de "Mais" — e cortar no
            // cabecote e o gesto mais comum de um editor. Aqui, no
            // transporte, ele nunca sai da tela.
            botao(
              key: const ValueKey('camada-dividir'),
              icon: CupertinoIcons.scissors,
              tooltip: 'Dividir a camada no cabeçote',
              onTap: selected == null
                  ? null
                  : () => controller.splitLayer(selected, playback.time.value),
            ),
            botao(
              key: const ValueKey('transport-expand'),
              icon: CupertinoIcons.viewfinder,
              tooltip: 'Expandir prévia',
              onTap: () => ref
                  .read(editorSessionProvider.notifier)
                  .togglePreviewExpanded(),
            ),
          ];
          final fatia = c.maxWidth.isFinite && filhos.isNotEmpty
              ? (c.maxWidth / filhos.length).clamp(0.0, AureaTokens.minTap)
              : AureaTokens.minTap;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final f in filhos)
                SizedBox(
                  width: fatia,
                  child: Center(child: f),
                ),
            ],
          );
        },
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
