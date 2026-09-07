import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/freehand_session.dart';
import '../../application/preview_stats.dart';
import '../am/scene3d_studio_ux.dart'
    show LinhaDoEstudio, SecaoDoEstudio, folhaDoEstudio;
import 'layer_actions.dart';

/// ⚙ PROJETO — o lugar das configuracoes (os tres apps de referencia).
///
/// Fase 1: nome, o que o projeto e (proporcao, resolucao, fps), a casca
/// de cebola do preview e o diagnostico. Proporcao/resolucao/fps
/// editaveis, fundo, guias, motion blur e template chegam na Fase 6.
Future<void> showProjectSettingsSheet(BuildContext context, WidgetRef ref) {
  return folhaDoEstudio<void>(
    context,
    titulo: 'Projeto',
    alturaFator: 0.7,
    builder: (ctx, setSheet) {
      final p = ref.read(editorControllerProvider);
      final onion = ref.read(onionSkinProvider);
      final diag = ref.read(debugOverlayProvider);
      return ListView(
        shrinkWrap: true,
        children: [
          LinhaDoEstudio(
            key: const ValueKey('projeto-nome'),
            icone: CupertinoIcons.pencil,
            titulo: p.name,
            subtitulo: 'Toque para renomear',
            chevron: true,
            onTap: () async {
              await renomearProjeto(context, ref);
              if (ctx.mounted) setSheet(() {});
            },
          ),
          const SecaoDoEstudio('Composicao'),
          LinhaDoEstudio(
            icone: CupertinoIcons.rectangle,
            titulo: 'Tamanho',
            subtitulo:
                '${p.outputWidth} × ${p.outputHeight} · ${p.fps} fps · '
                '${(p.duration.inMilliseconds / 1000).toStringAsFixed(1)} s',
          ),
          const SecaoDoEstudio('Preview'),
          LinhaDoEstudio(
            key: const ValueKey('projeto-cebola'),
            icone: CupertinoIcons.square_stack_3d_down_dottedline,
            titulo: 'Casca de cebola',
            subtitulo: onion == 0
                ? 'Desligada'
                : '$onion quadro${onion == 1 ? '' : 's'} vizinho${onion == 1 ? '' : 's'} em transparencia',
            trailing: Text(
              onion == 0 ? 'Desligada' : '$onion',
              style: const TextStyle(fontSize: 13),
            ),
            onTap: () {
              ref.read(onionSkinProvider.notifier).state = (onion + 1) % 3;
              setSheet(() {});
            },
          ),
          LinhaDoEstudio(
            key: const ValueKey('projeto-diagnostico'),
            icone: CupertinoIcons.waveform_path_ecg,
            titulo: 'Diagnostico na tela',
            subtitulo: 'Marcha, composicoes por segundo, memoria e o motor 3D.',
            ligado: diag,
            onTap: () {
              ref.read(debugOverlayProvider.notifier).state = !diag;
              setSheet(() {});
            },
          ),
          const SizedBox(height: 12),
        ],
      );
    },
  );
}
