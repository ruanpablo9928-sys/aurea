import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/acceptance_task.dart';

enum LaboratoryAssetLoadState { idle, loading, ready, failed }

class LaboratoryAssetViewState {
  const LaboratoryAssetViewState({
    this.state = LaboratoryAssetLoadState.idle,
    this.progress,
    this.errorMessage,
    this.localUri,
  });

  final LaboratoryAssetLoadState state;
  final double? progress;
  final String? errorMessage;
  final String? localUri;
}

/// Botao de ativo de teste com os quatro estados necessarios para um teste
/// reproduzivel. O carregamento em si fica no adaptador da plataforma.
class LaboratoryAssetButton extends StatelessWidget {
  const LaboratoryAssetButton({
    super.key,
    required this.asset,
    required this.onPressed,
    this.state = LaboratoryAssetLoadState.idle,
    this.progress,
    this.errorMessage,
  });

  final TestAssetRequirement asset;
  final Future<void> Function(TestAssetRequirement asset) onPressed;
  final LaboratoryAssetLoadState state;
  final double? progress;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final loading = state == LaboratoryAssetLoadState.loading;
    final ready = state == LaboratoryAssetLoadState.ready;
    final failed = state == LaboratoryAssetLoadState.failed;
    final normalizedProgress = progress?.clamp(0.0, 1.0);
    final size = _formatSize(asset.approximateBytes);
    final subtitle = switch (state) {
      LaboratoryAssetLoadState.loading when normalizedProgress != null =>
        '${(normalizedProgress * 100).round()}%',
      LaboratoryAssetLoadState.loading => 'Preparando…',
      LaboratoryAssetLoadState.ready => 'Pronto',
      LaboratoryAssetLoadState.failed => errorMessage ?? 'Tentar novamente',
      LaboratoryAssetLoadState.idle => [
        if (asset.bundled) 'Incluido no app',
        ?size,
      ].join(' · '),
    };

    return Semantics(
      button: true,
      enabled: !loading,
      label: '${ready ? 'Ativo pronto' : 'Carregar ativo'}: ${asset.label}',
      value: subtitle,
      child: Material(
        color: failed
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.10)
            : ready
            ? AppColors.lime.withValues(alpha: 0.10)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : () => onPressed(asset),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 26,
                        child: Center(
                          child: loading
                              ? const CupertinoActivityIndicator(radius: 9)
                              : Icon(
                                  ready
                                      ? CupertinoIcons.check_mark_circled_solid
                                      : failed
                                      ? CupertinoIcons.exclamationmark_circle
                                      : CupertinoIcons.arrow_down_circle,
                                  size: 21,
                                  color: ready
                                      ? AppColors.lime
                                      : failed
                                      ? Theme.of(context).colorScheme.error
                                      : AppColors.onDark,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.onDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: failed
                                        ? Theme.of(context).colorScheme.error
                                        : AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (!loading && !ready)
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 15,
                          color: AppColors.muted,
                        ),
                    ],
                  ),
                ),
                if (loading && normalizedProgress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: normalizedProgress,
                      minHeight: 2,
                      color: AppColors.lime,
                      backgroundColor: AppColors.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _formatSize(int? bytes) {
    if (bytes == null) return null;
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(megabytes >= 10 ? 0 : 1)} MB';
  }
}
