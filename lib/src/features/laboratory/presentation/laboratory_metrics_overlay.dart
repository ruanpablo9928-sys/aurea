import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/laboratory_metrics.dart';

/// Leitura compacta das metricas coletadas durante uma tarefa de aceite.
///
/// O widget nao se posiciona por cima do editor: quem o hospeda escolhe uma
/// faixa livre. Assim ele pode viver tanto no cabecalho do checklist quanto
/// em um painel persistente sem cobrir preview ou timeline.
class LaboratoryMetricsOverlay extends StatelessWidget {
  const LaboratoryMetricsOverlay({
    super.key,
    required this.metrics,
    this.expanded = false,
    this.onToggleExpanded,
  });

  final LaboratoryMetrics metrics;
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final fpsColor = metrics.currentFps > 0 && metrics.currentFps < 30
        ? Theme.of(context).colorScheme.error
        : AppColors.lime;
    final temperature = metrics.temperatureCelsius == null
        ? metrics.thermalState.reportLabel
        : '${metrics.temperatureCelsius!.toStringAsFixed(0)} °C';

    return Semantics(
      container: true,
      label: _semanticsLabel(temperature),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.94),
          border: Border.all(color: AppColors.hairline),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MetricText(value: metrics.gear ?? '—', label: 'marcha'),
                  const _Dot(),
                  _MetricText(
                    value: metrics.currentFps.toStringAsFixed(1),
                    label: 'fps',
                    color: fpsColor,
                  ),
                  const _Dot(),
                  _MetricText(
                    value: '${metrics.renderPasses}',
                    label: 'passes',
                  ),
                  if (onToggleExpanded != null) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onToggleExpanded,
                        child: Icon(
                          expanded
                              ? CupertinoIcons.chevron_up
                              : CupertinoIcons.chevron_down,
                          size: 15,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 6),
                Divider(color: AppColors.hairline),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 7,
                  children: [
                    _MetricText(
                      value: '${metrics.drawCalls}',
                      label: 'draw calls',
                    ),
                    _MetricText(
                      value: '${metrics.liveDecoders}',
                      label: 'decoders',
                    ),
                    _MetricText(
                      value: '${metrics.audioUnderruns}',
                      label: 'underruns',
                      color: metrics.audioUnderruns == 0
                          ? AppColors.onDark
                          : Theme.of(context).colorScheme.error,
                    ),
                    _MetricText(
                      value: '${metrics.allocationsPerFrame}',
                      label: 'aloc./frame',
                    ),
                    _MetricText(
                      value: temperature,
                      label: 'temperatura',
                      color: _thermalColor(context, metrics.thermalState),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _semanticsLabel(String temperature) {
    return 'Desempenho: ${metrics.gear ?? 'marcha indisponivel'}, '
        '${metrics.currentFps.toStringAsFixed(1)} quadros por segundo, '
        '${metrics.renderPasses} passes de renderizacao, '
        '${metrics.drawCalls} chamadas de desenho, '
        '${metrics.liveDecoders} decodificadores, '
        '${metrics.audioUnderruns} interrupcoes de audio, '
        '${metrics.allocationsPerFrame} alocacoes por quadro, '
        'temperatura $temperature.';
  }

  Color _thermalColor(BuildContext context, ThermalState state) {
    return switch (state) {
      ThermalState.serious ||
      ThermalState.critical => Theme.of(context).colorScheme.error,
      ThermalState.fair => const Color(0xFFFFC857),
      ThermalState.unknown || ThermalState.nominal => AppColors.onDark,
    };
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({
    required this.value,
    required this.label,
    this.color = AppColors.onDark,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: ' $label',
            style: const TextStyle(color: AppColors.muted),
          ),
        ],
      ),
      maxLines: 1,
      style: const TextStyle(fontSize: 11, height: 1.2),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text('·', style: TextStyle(color: AppColors.muted)),
    );
  }
}
