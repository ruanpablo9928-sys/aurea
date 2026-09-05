import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/shape.dart';
import 'am_colors.dart';
import 'am_widgets.dart';
import 'color_picker_sheet.dart';

Future<void> showGradientFillSheet(BuildContext context, String layerId) =>
    showParamSheet(
      context,
      title: 'Gradiente vetorial',
      heightFactor: .60,
      builder: (_) => _GradientPanel(layerId: layerId),
    );

class _GradientPanel extends ConsumerWidget {
  const _GradientPanel({required this.layerId});
  final String layerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = ref.watch(editorControllerProvider).layerById(layerId);
    if (layer is! ShapeLayer) return const SizedBox.shrink();
    final controller = ref.read(editorControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Cores e distribuicao',
          style: TextStyle(color: AmColors.text, fontSize: 18),
        ),
        for (final g in layer.contents.whereType<ShapeGradientFill>()) ...[
          const SizedBox(height: 12),
          Container(
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: g.paradas,
                stops: g.resolvedStops,
              ),
            ),
          ),
          SwitchListTile.adaptive(
            title: const Text('Radial'),
            value: g.radial,
            onChanged: (v) => controller.updateShapeGradient(
              layerId,
              g.id,
              (old) => old.copyWith(radial: v),
            ),
          ),
          for (var i = 0; i < g.paradas.length; i++)
            Row(
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  onPressed: () async {
                    final index = i;
                    final color = await showColorPicker(
                      context,
                      initial: g.paradas[index],
                    );
                    if (color == null || !context.mounted) return;
                    controller.updateShapeGradient(layerId, g.id, (old) {
                      final colors = [...old.paradas];
                      if (index >= colors.length) return old;
                      colors[index] = color;
                      return old.copyWith(
                        colorA: colors.first,
                        colorB: colors.last,
                        extras: colors.sublist(1, colors.length - 1),
                      );
                    });
                  },
                  child: Container(width: 28, height: 28, color: g.paradas[i]),
                ),
                Text(
                  '${(g.resolvedStops[i] * 100).round()}%',
                  style: const TextStyle(color: AmColors.text),
                ),
                Expanded(
                  child: AmTickRuler(
                    value: g.resolvedStops[i],
                    min: 0,
                    max: 1,
                    height: 48,
                    unitsPerPixel: .003,
                    onChanged: (v) =>
                        controller.updateShapeGradient(layerId, g.id, (old) {
                          final stops = [...old.resolvedStops];
                          stops[i] = v.clamp(
                            i == 0 ? 0 : stops[i - 1],
                            i == stops.length - 1 ? 1 : stops[i + 1],
                          );
                          return old.copyWith(stops: stops);
                        }),
                  ),
                ),
              ],
            ),
          _slider(
            'Angulo',
            g.angleDeg,
            -180,
            180,
            (v) => controller.updateShapeGradient(
              layerId,
              g.id,
              (old) => old.copyWith(angleDeg: v),
            ),
          ),
          _slider(
            'Centro X',
            g.center.dx,
            -1,
            1,
            (v) => controller.updateShapeGradient(
              layerId,
              g.id,
              (old) => old.copyWith(center: Offset(v, old.center.dy)),
            ),
          ),
          _slider(
            'Centro Y',
            g.center.dy,
            -1,
            1,
            (v) => controller.updateShapeGradient(
              layerId,
              g.id,
              (old) => old.copyWith(center: Offset(old.center.dx, v)),
            ),
          ),
          _slider(
            'Alcance',
            g.radiusScale,
            .05,
            3,
            (v) => controller.updateShapeGradient(
              layerId,
              g.id,
              (old) => old.copyWith(radiusScale: v),
            ),
          ),
        ],
      ],
    );
  }

  Widget _slider(
    String name,
    double v,
    double min,
    double max,
    ValueChanged<double> update,
  ) => Row(
    children: [
      SizedBox(
        width: 82,
        child: Text(name, style: const TextStyle(color: AmColors.text)),
      ),
      Expanded(
        child: AmTickRuler(
          min: min,
          max: max,
          height: 56,
          unitsPerPixel: (max - min) / 240,
          value: v.isFinite ? v.clamp(min, max) : min,
          onChanged: update,
        ),
      ),
      SizedBox(
        width: 44,
        child: Text(
          v.toStringAsFixed(2),
          style: const TextStyle(color: AmColors.muted),
        ),
      ),
    ],
  );
}
