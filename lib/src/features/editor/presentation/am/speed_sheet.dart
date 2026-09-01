import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

/// VELOCIDADE DO CLIPE.
///
/// A barra na linha do tempo e o tempo FINAL: acelerar encurta a barra e
/// puxa o que vinha depois. Sem isso, acelerar deixaria um buraco — ou
/// pior, cortaria o fim do clipe sem avisar, porque a fonte acabaria
/// antes da barra.
Future<void> showSpeedSheet(
    BuildContext context, WidgetRef ref, String layerId) async {
  await showParamSheet(
    context,
    heightFactor: 0.42,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final project = ref.read(editorControllerProvider);
        final controller = ref.read(editorControllerProvider.notifier);
        final layer = project.layerById(layerId);
        if (layer == null) return const SizedBox.shrink();

        final v = controller.clipSpeedOf(layerId);
        final temSom = layer is AudioLayer ||
            (layer is VideoLayer && layer.volume > 0.001);

        void muda(double nova) {
          controller.setClipSpeed(layerId, nova);
          setSheetState(() {});
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Velocidade',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                const SizedBox(height: 4),
                Text(
                  '${v.toStringAsFixed(2)}x — a barra fica '
                  '${formatTime(layer.duration)}',
                  style: const TextStyle(
                      fontSize: 12, color: AmColors.accent),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in const [0.25, 0.5, 1.0, 1.5, 2.0, 4.0])
                      GestureDetector(
                        onTap: () => muda(p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 8),
                          decoration: BoxDecoration(
                            color: (v - p).abs() < 0.01
                                ? AmColors.accentDim
                                : AmColors.chip,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            p == 1.0
                                ? 'Normal'
                                : '${p.toStringAsFixed(p < 1 ? 2 : 1)}x',
                            style: TextStyle(
                              fontSize: 12,
                              color: (v - p).abs() < 0.01
                                  ? AmColors.accent
                                  : AmColors.text,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const SizedBox(
                      width: 62,
                      child: Text('Ajuste',
                          style: TextStyle(
                              fontSize: 12, color: AmColors.muted)),
                    ),
                    Expanded(
                      child: AmTickRuler(
                        value: v,
                        min: 0.1,
                        max: 8,
                        unitsPerPixel: 0.02,
                        height: 42,
                        onChanged: muda,
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text('${v.toStringAsFixed(2)}x',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12, color: AmColors.text)),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  temSom
                      ? 'Acelerar o som tambem sobe o tom — e o mesmo que '
                          'acontece num toca-discos.\n'
                          'Para RAMPA de velocidade (acelerar aos poucos), '
                          'precomponha o clipe e use "Tempo da precomp".'
                      : 'Para RAMPA de velocidade (acelerar aos poucos), '
                          'precomponha o clipe e use "Tempo da precomp".',
                  style: const TextStyle(
                      fontSize: 11, height: 1.4, color: AmColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
