import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/snack.dart';
import '../application/laboratory_app_bridge.dart';
import '../application/laboratory_controller.dart';
import '../domain/laboratory_level.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';
import 'laboratory_metrics_overlay.dart';
import 'laboratory_report_sheet.dart';
import 'laboratory_runtime_bridge.dart';
import 'laboratory_session_controller.dart';

/// Nivel 10: liga funcionalidades e inicia tarefas de aceite sem editar codigo.
class LaboratoryScreen extends ConsumerStatefulWidget {
  const LaboratoryScreen({super.key});

  @override
  ConsumerState<LaboratoryScreen> createState() => _LaboratoryScreenState();
}

class _LaboratoryScreenState extends ConsumerState<LaboratoryScreen> {
  bool _includePrevious = true;
  bool _metricsExpanded = false;

  @override
  void initState() {
    super.initState();
    // Le modelo do aparelho e versao do app uma vez: sem isso o cabecalho
    // do relatorio sai sem dizer onde o teste foi feito.
    ref.read(laboratoryAppBridgeProvider).aquecer();
  }

  Future<void> _runTask(LaboratoryLevelId level) async {
    final notifier = ref.read(laboratorySessionControllerProvider.notifier);
    await notifier.startAcceptance(
      level,
      includePrevious: _includePrevious,
    );
    if (!mounted) return;
    final sessionState = ref.read(laboratorySessionControllerProvider);
    if (!sessionState.isRunning) return;
    final runtime = ref.read(laboratoryRuntimeBridgeProvider);
    if (!runtime.canOpenEditor) {
      AureaSnack.show(
        context,
        'Tarefa iniciada. Abra um projeto para continuar no editor.',
      );
      return;
    }
    try {
      await runtime.openEditorForTask(level);
    } catch (error) {
      if (!mounted) return;
      AureaSnack.show(context, 'Nao consegui abrir o editor: $error');
    }
  }

  Future<void> _openReport() async {
    final notifier = ref.read(laboratorySessionControllerProvider.notifier);
    final report = await notifier.generateReport();
    if (!mounted || report == null) return;
    await showLaboratoryReportSheet(
      context,
      reportText: report.text,
      attachments: report.attachments,
      onShare: (plainText, attachments) => notifier.shareReport(report),
    );
  }

  Future<void> _continueInEditor(LaboratoryLevelId level) async {
    final runtime = ref.read(laboratoryRuntimeBridgeProvider);
    if (!runtime.canOpenEditor) {
      AureaSnack.show(context, 'Abra um projeto para continuar a tarefa.');
      return;
    }
    try {
      await runtime.openEditorForTask(level);
    } catch (error) {
      if (!mounted) return;
      AureaSnack.show(context, 'Nao consegui abrir o editor: $error');
    }
  }

  void _toggleLevel(
    LaboratoryLevelDefinition definition,
    bool enabled,
    LaboratoryLevelSelection before,
  ) {
    ref
        .read(laboratoryControllerProvider.notifier)
        .setEnabled(definition.id, enabled);
    final after = ref.read(laboratoryControllerProvider);
    if (!enabled) return;
    final dependencies = after.enabled.difference(before.enabled)
      ..remove(definition.id)
      ..remove(LaboratoryLevelId.core);
    if (dependencies.isEmpty) return;
    final labels = dependencies
        .map((id) => LaboratoryLevelCatalog.definition(id).title)
        .join(', ');
    AureaSnack.show(context, '$labels ligado como dependencia');
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(laboratoryControllerProvider);
    final sessionState = ref.watch(laboratorySessionControllerProvider);
    final runtime = ref.watch(laboratoryRuntimeBridgeProvider);
    final activeRun = sessionState.activeRun;
    final liveMetrics = activeRun?.metrics ??
        _metricsFrom(runtime.samplePerformance());

    ref.listen<String?>(
      laboratorySessionControllerProvider.select(
        (value) => value.errorMessage,
      ),
      (previous, next) {
        if (next == null || next == previous) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AureaSnack.show(context, next);
          ref
              .read(laboratorySessionControllerProvider.notifier)
              .clearError();
        });
      },
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laboratorio'),
        actions: [
          Semantics(
            button: true,
            label: 'Gerar relatorio',
            child: IconButton(
              tooltip: 'Gerar relatorio',
              onPressed: sessionState.session != null ||
                      sessionState.recentSessions.isNotEmpty
                  ? _openReport
                  : null,
              icon: const Icon(CupertinoIcons.doc_plaintext),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
              sliver: SliverList.list(
                children: [
                  const _LaboratoryIntro(),
                  const SizedBox(height: 16),
                  LaboratoryMetricsOverlay(
                    metrics: liveMetrics,
                    expanded: _metricsExpanded,
                    onToggleExpanded: () => setState(
                      () => _metricsExpanded = !_metricsExpanded,
                    ),
                  ),
                  if (sessionState.isRunning && activeRun != null) ...[
                    const SizedBox(height: 16),
                    _ActiveSessionCard(
                      run: activeRun,
                      stepCount: sessionState.activeTask?.steps.length ?? 0,
                      busy: sessionState.busy,
                      onContinue: () => _continueInEditor(activeRun.level),
                      onReport: _openReport,
                      onCancel: () => ref
                          .read(
                            laboratorySessionControllerProvider.notifier,
                          )
                          .cancelSession(),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(child: _SectionTitle('Niveis')),
                      TextButton(
                        onPressed: sessionState.isRunning
                            ? null
                            : () => ref
                                .read(laboratoryControllerProvider.notifier)
                                .enableAll(),
                        child: const Text('Ligar todos'),
                      ),
                      TextButton(
                        onPressed: sessionState.isRunning
                            ? null
                            : () => ref
                                .read(laboratoryControllerProvider.notifier)
                                .reset(),
                        child: const Text('So nucleo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _PreviousTaskOption(
                    value: _includePrevious,
                    enabled: !sessionState.isRunning,
                    onChanged: (value) =>
                        setState(() => _includePrevious = value),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.surface,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        for (var index = 0;
                            index < LaboratoryLevelCatalog.ordered.length;
                            index++) ...[
                          _LevelRow(
                            definition:
                                LaboratoryLevelCatalog.ordered[index],
                            enabled: selection.isEnabled(
                              LaboratoryLevelCatalog.ordered[index].id,
                            ),
                            running: activeRun?.level ==
                                LaboratoryLevelCatalog.ordered[index].id,
                            sessionLocked: sessionState.isRunning,
                            busy: sessionState.busy,
                            visibilityCheck: _checkFor(
                              sessionState.session,
                              LaboratoryLevelCatalog.ordered[index].id,
                            ),
                            onToggle: (value) => _toggleLevel(
                              LaboratoryLevelCatalog.ordered[index],
                              value,
                              selection,
                            ),
                            onRun: () => _runTask(
                              LaboratoryLevelCatalog.ordered[index].id,
                            ),
                          ),
                          if (index + 1 <
                              LaboratoryLevelCatalog.ordered.length)
                            Padding(
                              padding: const EdgeInsets.only(left: 58),
                              child: Divider(color: AppColors.hairline),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (sessionState.loadingHistory) ...[
                    const SizedBox(height: 18),
                    const Center(child: CupertinoActivityIndicator()),
                  ] else if (sessionState.recentSessions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle('Ultima sessao'),
                    const SizedBox(height: 8),
                    _HistoryCard(
                      session: sessionState.recentSessions.first,
                      onReport: _openReport,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  UiVisibilityCheck? _checkFor(
    LaboratorySession? session,
    LaboratoryLevelId level,
  ) {
    final checks = session?.uiChecks ?? const <UiVisibilityCheck>[];
    for (final check in checks.reversed) {
      if (check.level == level) return check;
    }
    return null;
  }

  LaboratoryMetrics _metricsFrom(PerformanceSample? sample) => sample == null
      ? const LaboratoryMetrics()
      : const LaboratoryMetrics().recordPerformance(sample);
}

class _LaboratoryIntro extends StatelessWidget {
  const _LaboratoryIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.violet.withValues(alpha: 0.22),
            AppColors.lime.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LevelBadge(code: '10', emphasized: true),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teste o app sem mexer no codigo',
                  style: TextStyle(
                    color: AppColors.onDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Cada interruptor atualiza o editor na hora. As tarefas '
                  'registram toques, tempo, fps, metricas e prints.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousTaskOption extends StatelessWidget {
  const _PreviousTaskOption({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: 'Rodar primeiro a tarefa anterior',
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 8, 9, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.arrow_turn_up_left,
              size: 18,
              color: AppColors.muted,
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rodar primeiro a tarefa anterior',
                    style: TextStyle(
                      color: AppColors.onDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Opcional; ajuda a encontrar regressao entre niveis.',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            CupertinoSwitch(
              value: value,
              activeTrackColor: AppColors.lime,
              thumbColor: value ? const Color(0xFF0B0E12) : null,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.definition,
    required this.enabled,
    required this.running,
    required this.sessionLocked,
    required this.busy,
    required this.visibilityCheck,
    required this.onToggle,
    required this.onRun,
  });

  final LaboratoryLevelDefinition definition;
  final bool enabled;
  final bool running;
  final bool sessionLocked;
  final bool busy;
  final UiVisibilityCheck? visibilityCheck;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final dependencyLabels = definition.dependencies
        .where((level) => level != LaboratoryLevelId.core)
        .map((level) => LaboratoryLevelCatalog.definition(level).title)
        .join(', ');
    final check = visibilityCheck;
    final statusColor = check == null
        ? AppColors.muted
        : check.visible
        ? AppColors.lime
        : Theme.of(context).colorScheme.error;
    final statusText = check == null
        ? definition.expectedUi
        : check.visible
        ? 'UI confirmada · ${definition.expectedUi}'
        : 'Falha automatica · ${definition.expectedUi}';
    final canRun = enabled && !sessionLocked && !busy;

    return Semantics(
      container: true,
      label: 'Nivel ${definition.id.code}, ${definition.title}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 9, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LevelBadge(code: definition.id.code, emphasized: enabled),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          definition.title,
                          style: const TextStyle(
                            color: AppColors.onDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (definition.alwaysEnabled)
                        const Text(
                          'sempre ligado',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        CupertinoSwitch(
                          value: enabled,
                          activeTrackColor: AppColors.lime,
                          thumbColor:
                              enabled ? const Color(0xFF0B0E12) : null,
                          onChanged: sessionLocked ? null : onToggle,
                        ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (dependencyLabels.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Depende de $dependencyLabels',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: running
                            ? AppColors.violet
                            : AppColors.lime,
                        backgroundColor: (running
                                ? AppColors.violet
                                : AppColors.lime)
                            .withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: canRun ? onRun : null,
                      icon: Icon(
                        running
                            ? CupertinoIcons.play_circle_fill
                            : CupertinoIcons.play_circle,
                        size: 17,
                      ),
                      label: Text(
                        running ? 'Em andamento' : 'Rodar tarefa de aceite',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.code, required this.emphasized});

  final String code;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: emphasized ? AppColors.accentDim : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: emphasized
              ? AppColors.lime.withValues(alpha: 0.42)
              : AppColors.hairline,
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          color: emphasized ? AppColors.lime : AppColors.muted,
          fontSize: code.length > 1 ? 12 : 14,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.run,
    required this.stepCount,
    required this.busy,
    required this.onContinue,
    required this.onReport,
    required this.onCancel,
  });

  final AcceptanceStepRun run;
  final int stepCount;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback onReport;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.play_circle_fill,
                color: AppColors.violet,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nivel ${run.level.code} · passo ${run.stepNumber} de $stepCount',
                  style: const TextStyle(
                    color: AppColors.onDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            run.instruction,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : onContinue,
                icon: const Icon(CupertinoIcons.arrow_right_circle, size: 17),
                label: const Text('Continuar no editor'),
              ),
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(CupertinoIcons.doc_plaintext, size: 17),
                label: const Text('Relatorio'),
              ),
              TextButton(
                onPressed: busy ? null : onCancel,
                child: const Text('Encerrar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.session, required this.onReport});

  final LaboratorySession session;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final passed = session.stepRuns
        .where((run) => run.outcome == StepOutcome.passed)
        .length;
    final failed = session.stepRuns.where((run) => run.outcome.isFailure).length;
    final skipped = session.stepRuns
        .where((run) => run.outcome == StepOutcome.skipped)
        .length;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onReport,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.clock,
                color: AppColors.muted,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(session.createdAt),
                      style: const TextStyle(
                        color: AppColors.onDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$passed passaram · $failed falharam · $skipped pulados',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month · $hour:$minute';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
