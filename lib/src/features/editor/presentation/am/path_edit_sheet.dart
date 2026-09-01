import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/mask.dart';
import '../../domain/path_edit.dart';
import '../widgets/mask_node_editor.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

/// EDITAR OS NOS: os controles ficam aqui embaixo e os nos aparecem em
/// cima da composicao.
///
/// Enquanto esta folha esta aberta, o dedo no preview mexe nos NOS, nao
/// na camada. Fechar devolve o comportamento normal — e por isso o
/// estado de edicao morre junto com a folha.
Future<void> showPathEditSheet(
  BuildContext context,
  WidgetRef ref,
  String layerId,
  String maskId,
  PlaybackController playback,
) async {
  ref.read(pathEditTargetProvider.notifier).state =
      PathEditTarget(layerId, maskId);
  ref.read(pathEditSelectedProvider.notifier).state = null;

  await showParamSheet(
    context,
    heightFactor: 0.34,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final project = ref.read(editorControllerProvider);
        final controller = ref.read(editorControllerProvider.notifier);
        final layer = project.layerById(layerId);
        if (layer == null) return const SizedBox.shrink();

        LayerMask? mascara;
        for (final m in layer.masks) {
          if (m.id == maskId) mascara = m;
        }
        if (mascara == null) return const SizedBox.shrink();

        final t = playback.time.value;
        final caminho = mascara.path.valueAt(layer.localTime(t));
        final sel = ref.watch(pathEditSelectedProvider);
        final temNo =
            sel != null && sel >= 0 && sel < caminho.vertices.length;

        void editar(BezierPath Function(BezierPath) fn) {
          controller.editMaskPath(layerId, maskId, t, fn);
          setSheetState(() {});
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Editar nos',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AmColors.text)),
                    ),
                    Text('${caminho.vertices.length} nos',
                        style: const TextStyle(
                            fontSize: 12, color: AmColors.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  temNo
                      ? 'No ${sel + 1} selecionado. Arraste as bolinhas '
                          'azuis para curvar.'
                      : 'Toque num no para selecionar, ou EM CIMA da '
                          'linha para criar um no ali.',
                  style: const TextStyle(
                      fontSize: 11, height: 1.35, color: AmColors.muted),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _Acao(
                        icone: caminho.vertices.isNotEmpty &&
                                temNo &&
                                caminho.vertices[sel].corner
                            ? CupertinoIcons.circle
                            : CupertinoIcons.square,
                        rotulo: temNo && caminho.vertices[sel].corner
                            ? 'Virar curva'
                            : 'Virar canto',
                        ativo: temNo,
                        onTap: !temNo
                            ? null
                            : () => editar((c) => toggleCorner(c, sel)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Acao(
                        icone: CupertinoIcons.minus_circle,
                        rotulo: 'Apagar no',
                        ativo: temNo && caminho.vertices.length > 3,
                        onTap: !temNo || caminho.vertices.length <= 3
                            ? null
                            : () {
                                editar((c) => removeVertex(c, sel));
                                ref
                                    .read(pathEditSelectedProvider.notifier)
                                    .state = null;
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Acao(
                        icone: mascara.path.hasKeyframeAt(
                                layer.localTime(t))
                            ? CupertinoIcons.circle_filled
                            : CupertinoIcons.circle,
                        rotulo: 'Keyframe',
                        ativo: true,
                        onTap: () {
                          controller.toggleMaskPathKeyframe(
                              layerId, maskId, t);
                          setSheetState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Com o caminho animado, cada ajuste cria keyframe no '
                  'tempo atual — e assim que a mascara acompanha alguem '
                  'andando na cena.',
                  style: TextStyle(
                      fontSize: 11, height: 1.35, color: AmColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  // Fechou: o dedo volta a mover a camada.
  ref.read(pathEditTargetProvider.notifier).state = null;
  ref.read(pathEditSelectedProvider.notifier).state = null;
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.ativo,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? AmColors.text : AmColors.muted;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icone, size: 18, color: cor),
            const SizedBox(height: 5),
            Text(rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cor)),
          ],
        ),
      ),
    );
  }
}
