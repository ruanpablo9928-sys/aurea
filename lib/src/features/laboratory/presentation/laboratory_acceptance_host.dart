import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/laboratory_report_generator.dart';
import '../domain/laboratory_level.dart';
import '../domain/laboratory_session.dart';
import 'laboratory_acceptance_strip.dart';
import 'laboratory_report_sheet.dart';
import 'laboratory_runtime_bridge.dart';
import 'laboratory_session_controller.dart';

/// Liga a faixa de aceite ao provider da sessao.
///
/// Insira este widget como uma linha da coluna principal do editor, antes do
/// preview. Quando nao ha tarefa ativa ele ocupa zero pixels.
class LaboratoryAcceptanceHost extends ConsumerWidget {
  const LaboratoryAcceptanceHost({super.key});

  Future<void> _showReport(
    BuildContext context,
    WidgetRef ref, [
    LaboratoryReport? existing,
  ]) async {
    final controller = ref.read(laboratorySessionControllerProvider.notifier);
    final report = existing ?? await controller.generateReport();
    if (report == null || !context.mounted) return;
    await showLaboratoryReportSheet(
      context,
      reportText: report.text,
      attachments: report.attachments,
      onShare: (_, _) => controller.shareReport(report),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(laboratorySessionControllerProvider);
    final run = value.activeRun;
    final task = value.activeTask;
    final step = value.activeStep;
    if (run == null || task == null || step == null) {
      return const SizedBox.shrink();
    }
    final runtime = ref.watch(laboratoryRuntimeBridgeProvider);
    final controller = ref.read(laboratorySessionControllerProvider.notifier);

    return LaboratoryAcceptanceStrip(
      levelCode: run.level.code,
      taskTitle: task.title,
      step: step,
      stepNumber: run.stepNumber,
      stepCount: task.steps.length,
      startedAt: run.startedAt,
      metrics: run.metrics,
      busy: value.busy,
      assetStates: value.assetStates,
      onLoadAsset: controller.loadAsset,
      onCaptureScreenshot:
          runtime.canCaptureScreenshot ? controller.captureScreenshot : null,
      onGenerateReport: () => _showReport(context, ref),
      onClose: controller.cancelSession,
      onDecision: (outcome, {note}) async {
        await controller.finishStep(outcome, note: note);
        if (!context.mounted) return;
        final report = ref.read(laboratorySessionControllerProvider).report;
        if (report != null &&
            ref.read(laboratorySessionControllerProvider).session?.status !=
                LaboratorySessionStatus.running) {
          await _showReport(context, ref, report);
        }
      },
    );
  }
}
