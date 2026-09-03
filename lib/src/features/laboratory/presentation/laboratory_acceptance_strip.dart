import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/acceptance_task.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';
import 'laboratory_asset_button.dart';
import 'laboratory_metrics_overlay.dart';

typedef LaboratoryStepDecision = Future<void> Function(
  StepOutcome outcome, {
  String? note,
});

/// Faixa guiada para ser inserida como filha de uma [Column], entre o
/// cabecalho e o preview. Ela nao usa [Stack] nem [Positioned], portanto nao
/// cobre o preview, a regua ou a timeline.
class LaboratoryAcceptanceStrip extends StatefulWidget {
  const LaboratoryAcceptanceStrip({
    super.key,
    required this.levelCode,
    required this.taskTitle,
    required this.step,
    required this.stepNumber,
    required this.stepCount,
    required this.startedAt,
    required this.metrics,
    required this.onDecision,
    required this.onLoadAsset,
    this.assetStates = const {},
    this.onCaptureScreenshot,
    this.onGenerateReport,
    this.onClose,
    this.busy = false,
  });

  final String levelCode;
  final String taskTitle;
  final AcceptanceStepDefinition step;
  final int stepNumber;
  final int stepCount;
  final DateTime startedAt;
  final LaboratoryMetrics metrics;
  final LaboratoryStepDecision onDecision;
  final Future<void> Function(TestAssetRequirement asset) onLoadAsset;
  final Map<LaboratoryAssetId, LaboratoryAssetViewState> assetStates;
  final Future<void> Function()? onCaptureScreenshot;
  final Future<void> Function()? onGenerateReport;
  final VoidCallback? onClose;
  final bool busy;

  @override
  State<LaboratoryAcceptanceStrip> createState() =>
      _LaboratoryAcceptanceStripState();
}

class _LaboratoryAcceptanceStripState
    extends State<LaboratoryAcceptanceStrip> {
  Timer? _timer;
  bool _metricsExpanded = false;

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void didUpdateWidget(covariant LaboratoryAcceptanceStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) _startClock();
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _elapsed {
    final live = DateTime.now().difference(widget.startedAt);
    if (live.isNegative) return widget.metrics.elapsed;
    return live > widget.metrics.elapsed ? live : widget.metrics.elapsed;
  }

  Future<void> _fail() async {
    final note = await _showFailureNote(context);
    if (!mounted) return;
    await widget.onDecision(StepOutcome.failed, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = _formatElapsed(_elapsed);
    final semantics = 'Nivel ${widget.levelCode}, passo '
        '${widget.stepNumber} de ${widget.stepCount}. '
        '${widget.step.instruction}. ${widget.metrics.touchCount} toques, '
        '$elapsed, ${widget.metrics.currentFps.toStringAsFixed(1)} '
        'quadros por segundo.';

    return Semantics(
      container: true,
      liveRegion: true,
      label: semantics,
      child: Material(
        color: AppColors.surface,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.hairline),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 10, 10),
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Header(
                        levelCode: widget.levelCode,
                        taskTitle: widget.taskTitle,
                        stepNumber: widget.stepNumber,
                        stepCount: widget.stepCount,
                        touchCount: widget.metrics.touchCount,
                        elapsed: elapsed,
                        fps: widget.metrics.currentFps,
                        onCaptureScreenshot: widget.onCaptureScreenshot,
                        onGenerateReport: widget.onGenerateReport,
                        onClose: widget.onClose,
                      ),
                      const SizedBox(height: 7),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _Instruction(widget.step)),
                            const SizedBox(width: 12),
                            _DecisionButtons(
                              busy: widget.busy,
                              onPassed: () => widget.onDecision(
                                StepOutcome.passed,
                              ),
                              onFailed: _fail,
                              onSkipped: () => widget.onDecision(
                                StepOutcome.skipped,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _Instruction(widget.step),
                        const SizedBox(height: 9),
                        _DecisionButtons(
                          busy: widget.busy,
                          expand: true,
                          onPassed: () => widget.onDecision(
                            StepOutcome.passed,
                          ),
                          onFailed: _fail,
                          onSkipped: () => widget.onDecision(
                            StepOutcome.skipped,
                          ),
                        ),
                      ],
                      if (widget.step.assets.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final asset in widget.step.assets)
                                SizedBox(
                                  width: wide ? 250 : constraints.maxWidth,
                                  child: LaboratoryAssetButton(
                                    asset: asset,
                                    state: widget.assetStates[asset.id]?.state ??
                                        LaboratoryAssetLoadState.idle,
                                    progress:
                                        widget.assetStates[asset.id]?.progress,
                                    errorMessage: widget
                                        .assetStates[asset.id]
                                        ?.errorMessage,
                                    onPressed: widget.onLoadAsset,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: LaboratoryMetricsOverlay(
                          metrics: widget.metrics,
                          expanded: _metricsExpanded,
                          onToggleExpanded: () => setState(
                            () => _metricsExpanded = !_metricsExpanded,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.levelCode,
    required this.taskTitle,
    required this.stepNumber,
    required this.stepCount,
    required this.touchCount,
    required this.elapsed,
    required this.fps,
    this.onCaptureScreenshot,
    this.onGenerateReport,
    this.onClose,
  });

  final String levelCode;
  final String taskTitle;
  final int stepNumber;
  final int stepCount;
  final int touchCount;
  final String elapsed;
  final double fps;
  final Future<void> Function()? onCaptureScreenshot;
  final Future<void> Function()? onGenerateReport;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: const BoxDecoration(
            color: AppColors.lime,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            CupertinoIcons.play_fill,
            size: 12,
            color: Color(0xFF0B0E12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: 'Nivel $levelCode',
              style: const TextStyle(
                color: AppColors.onDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: ' · passo $stepNumber de $stepCount',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$touchCount toques · $elapsed · ${fps.toStringAsFixed(1)} fps',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (onCaptureScreenshot != null)
          _HeaderButton(
            label: 'Anexar print',
            icon: CupertinoIcons.camera,
            onPressed: onCaptureScreenshot!,
          ),
        if (onGenerateReport != null)
          _HeaderButton(
            label: 'Gerar relatorio',
            icon: CupertinoIcons.doc_plaintext,
            onPressed: onGenerateReport!,
          ),
        if (onClose != null)
          _HeaderButton(
            label: 'Fechar tarefa guiada',
            icon: CupertinoIcons.xmark,
            onPressed: () async => onClose!(),
          ),
      ],
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: 40,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Icon(icon, size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction(this.step);

  final AcceptanceStepDefinition step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            CupertinoIcons.arrow_right,
            size: 16,
            color: AppColors.lime,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            step.instruction,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onDark,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DecisionButtons extends StatelessWidget {
  const _DecisionButtons({
    required this.busy,
    required this.onPassed,
    required this.onFailed,
    required this.onSkipped,
    this.expand = false,
  });

  final bool busy;
  final Future<void> Function() onPassed;
  final Future<void> Function() onFailed;
  final Future<void> Function() onSkipped;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    Widget button({
      required String label,
      required IconData icon,
      required Color color,
      required Future<void> Function() onPressed,
    }) {
      final result = OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        onPressed: busy ? null : onPressed,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
      return expand ? Expanded(child: result) : result;
    }

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        button(
          label: 'Passou',
          icon: CupertinoIcons.check_mark,
          color: AppColors.lime,
          onPressed: onPassed,
        ),
        const SizedBox(width: 7),
        button(
          label: 'Falhou',
          icon: CupertinoIcons.xmark,
          color: Theme.of(context).colorScheme.error,
          onPressed: onFailed,
        ),
        const SizedBox(width: 7),
        button(
          label: 'Pular',
          icon: CupertinoIcons.forward_end,
          color: AppColors.muted,
          onPressed: onSkipped,
        ),
      ],
    );
  }
}

Future<String?> _showFailureNote(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que falhou?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'A nota e opcional. O passo continua registrado mesmo sem texto.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ex.: nao encontrei o seletor de cor',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Registrar e continuar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  controller.dispose();
  final trimmed = result?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatElapsed(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
