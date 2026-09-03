import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';
import '../application/laboratory_controller.dart';
import '../application/laboratory_report_generator.dart';
import '../application/laboratory_repository.dart';
import '../application/laboratory_session_engine.dart';
import '../domain/acceptance_task.dart';
import '../domain/laboratory_acceptance_catalog.dart';
import '../domain/laboratory_level.dart';
import '../domain/laboratory_session.dart';
import 'laboratory_asset_button.dart';
import 'laboratory_runtime_bridge.dart';

class LaboratorySessionUiState {
  const LaboratorySessionUiState({
    this.session,
    this.taskQueue = const [],
    this.recentSessions = const [],
    this.assetStates = const {},
    this.report,
    this.busy = false,
    this.loadingHistory = true,
    this.errorMessage,
  });

  final LaboratorySession? session;
  final List<LaboratoryLevelId> taskQueue;
  final List<LaboratorySession> recentSessions;
  final Map<LaboratoryAssetId, LaboratoryAssetViewState> assetStates;
  final LaboratoryReport? report;
  final bool busy;
  final bool loadingHistory;
  final String? errorMessage;

  bool get isRunning =>
      session?.status == LaboratorySessionStatus.running &&
      session?.activeStep != null;

  AcceptanceStepRun? get activeRun => session?.activeStep;

  AcceptanceTaskDefinition? get activeTask {
    final run = activeRun;
    if (run == null) return null;
    for (final task in session!.tasks) {
      if (task.level == run.level) return task;
    }
    return null;
  }

  AcceptanceStepDefinition? get activeStep {
    final run = activeRun;
    final task = activeTask;
    if (run == null || task == null) return null;
    for (final step in task.steps) {
      if (step.id == run.stepId) return step;
    }
    return null;
  }

  LaboratorySessionUiState copyWith({
    LaboratorySession? session,
    bool clearSession = false,
    List<LaboratoryLevelId>? taskQueue,
    List<LaboratorySession>? recentSessions,
    Map<LaboratoryAssetId, LaboratoryAssetViewState>? assetStates,
    LaboratoryReport? report,
    bool clearReport = false,
    bool? busy,
    bool? loadingHistory,
    String? errorMessage,
    bool clearError = false,
  }) => LaboratorySessionUiState(
    session: clearSession ? null : session ?? this.session,
    taskQueue: taskQueue ?? this.taskQueue,
    recentSessions: recentSessions ?? this.recentSessions,
    assetStates: assetStates ?? this.assetStates,
    report: clearReport ? null : report ?? this.report,
    busy: busy ?? this.busy,
    loadingHistory: loadingHistory ?? this.loadingHistory,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}

class LaboratorySessionController extends Notifier<LaboratorySessionUiState> {
  LaboratorySessionEngine? _engine;
  LaboratoryRepository? _repository;
  Timer? _performanceTimer;

  @override
  LaboratorySessionUiState build() {
    final preferences = ref.read(sharedPreferencesProvider);
    _repository = SharedPreferencesLaboratoryRepository(preferences);
    ref.onDispose(() => _performanceTimer?.cancel());
    unawaited(_loadHistory());
    return const LaboratorySessionUiState();
  }

  Future<void> _loadHistory() async {
    try {
      final sessions = await _repository!.loadSessions();
      state = state.copyWith(
        recentSessions: sessions,
        loadingHistory: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loadingHistory: false,
        errorMessage: _errorText(error),
      );
    }
  }

  Future<void> startAcceptance(
    LaboratoryLevelId level, {
    bool includePrevious = false,
  }) async {
    if (state.busy) return;
    state = state.copyWith(
      busy: true,
      clearError: true,
      clearReport: true,
      assetStates: const {},
    );
    try {
      final levels = ref.read(laboratoryControllerProvider);
      if (!levels.isEnabled(level)) {
        throw StateError('Ligue o nivel ${level.code} antes de testar.');
      }
      final runtime = ref.read(laboratoryRuntimeBridgeProvider);
      final tasks = LaboratoryAcceptanceCatalog.all
          .where((task) => levels.isEnabled(task.level))
          .toList(growable: false);
      final engine = LaboratorySessionEngine.create(
        levels: levels,
        environment: runtime.readEnvironment(),
        tasks: tasks,
      );
      _engine = engine;

      for (final enabled in levels.enabled) {
        if (enabled == LaboratoryLevelId.core) continue;
        var visible = false;
        String? details;
        try {
          visible = await runtime.isUiVisible(enabled);
          if (!visible) {
            details = 'A integracao nao confirmou a UI esperada.';
          }
        } catch (error) {
          details = 'Falha ao verificar a UI: ${_errorText(error)}';
        }
        engine.checkUiVisibility(
          enabled,
          visible: visible,
          details: details,
        );
      }

      final ordered = engine.taskOrderFor(
        level,
        includePrevious: includePrevious,
      );
      final queue = [for (final task in ordered) task.level];
      final first = ordered.first;
      engine.startStep(first.level, first.steps.first.id);
      await _save(engine.session);
      state = state.copyWith(
        session: engine.session,
        taskQueue: queue,
        busy: false,
        clearError: true,
      );
      _startPerformanceSampler();
    } catch (error) {
      _engine = null;
      state = state.copyWith(
        busy: false,
        errorMessage: _errorText(error),
      );
    }
  }

  void recordTouch([int count = 1]) {
    final engine = _engine;
    if (engine == null || engine.session.activeStep == null) return;
    try {
      engine.recordTouch(count);
      state = state.copyWith(session: engine.session);
    } on StateError {
      // Um toque na transicao entre passos nao pertence a nenhum deles.
    }
  }

  Future<void> finishStep(StepOutcome outcome, {String? note}) async {
    final engine = _engine;
    final active = engine?.session.activeStep;
    if (engine == null || active == null || state.busy) return;
    state = state.copyWith(busy: true, clearError: true);
    String? softError;
    try {
      final runtime = ref.read(laboratoryRuntimeBridgeProvider);
      if (outcome == StepOutcome.failed && runtime.canCaptureScreenshot) {
        try {
          final attachment = await runtime.captureScreenshot(
            level: active.level,
            stepId: active.stepId,
          );
          engine.attach(attachment);
        } catch (error) {
          softError = 'A falha foi registrada, mas o print nao: '
              '${_errorText(error)}';
        }
      }
      engine.finishStep(outcome, note: note);
      final next = _nextStep(engine.session, active);
      LaboratoryReport? report;
      if (next == null) {
        engine.complete();
        _performanceTimer?.cancel();
        report = const LaboratoryReportGenerator().generate(engine.session);
      } else {
        engine.startStep(next.$1, next.$2.id);
      }
      await _save(engine.session);
      state = state.copyWith(
        session: engine.session,
        report: report,
        busy: false,
        errorMessage: softError,
        clearError: softError == null,
        assetStates: const {},
      );
    } catch (error) {
      state = state.copyWith(
        session: engine.session,
        busy: false,
        errorMessage: _errorText(error),
      );
    }
  }

  (LaboratoryLevelId, AcceptanceStepDefinition)? _nextStep(
    LaboratorySession session,
    AcceptanceStepRun completed,
  ) {
    final currentTask = session.taskFor(completed.level);
    final stepIndex = currentTask.steps.indexWhere(
      (step) => step.id == completed.stepId,
    );
    if (stepIndex >= 0 && stepIndex + 1 < currentTask.steps.length) {
      return (completed.level, currentTask.steps[stepIndex + 1]);
    }
    final taskIndex = state.taskQueue.indexOf(completed.level);
    if (taskIndex < 0 || taskIndex + 1 >= state.taskQueue.length) return null;
    final nextLevel = state.taskQueue[taskIndex + 1];
    final nextTask = session.taskFor(nextLevel);
    return (nextLevel, nextTask.steps.first);
  }

  Future<void> loadAsset(TestAssetRequirement asset) async {
    final runtime = ref.read(laboratoryRuntimeBridgeProvider);
    if (!runtime.canLoadAssets) {
      _setAssetState(
        asset.id,
        const LaboratoryAssetViewState(
          state: LaboratoryAssetLoadState.failed,
          errorMessage: 'Carregador ainda nao conectado',
        ),
      );
      return;
    }
    _setAssetState(
      asset.id,
      const LaboratoryAssetViewState(
        state: LaboratoryAssetLoadState.loading,
      ),
    );
    try {
      final uri = await runtime.prepareAsset(asset);
      if (uri.trim().isEmpty) {
        throw StateError('O carregador nao devolveu o caminho do ativo.');
      }
      _setAssetState(
        asset.id,
        LaboratoryAssetViewState(
          state: LaboratoryAssetLoadState.ready,
          localUri: uri,
        ),
      );
    } catch (error) {
      _setAssetState(
        asset.id,
        LaboratoryAssetViewState(
          state: LaboratoryAssetLoadState.failed,
          errorMessage: _errorText(error),
        ),
      );
    }
  }

  void _setAssetState(
    LaboratoryAssetId id,
    LaboratoryAssetViewState assetState,
  ) {
    state = state.copyWith(
      assetStates: {...state.assetStates, id: assetState},
    );
  }

  Future<void> captureScreenshot() async {
    final engine = _engine;
    final active = engine?.session.activeStep;
    final runtime = ref.read(laboratoryRuntimeBridgeProvider);
    if (engine == null || active == null) return;
    if (!runtime.canCaptureScreenshot) {
      state = state.copyWith(errorMessage: 'Captura de tela indisponivel.');
      return;
    }
    try {
      final attachment = await runtime.captureScreenshot(
        level: active.level,
        stepId: active.stepId,
      );
      if (attachment.uri.trim().isEmpty) {
        throw StateError('A captura nao devolveu um arquivo.');
      }
      engine.attach(attachment);
      await _save(engine.session);
      state = state.copyWith(session: engine.session, clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _errorText(error));
    }
  }

  Future<LaboratoryReport?> generateReport() async {
    final session = state.session ?? state.recentSessions.firstOrNull;
    if (session == null) {
      state = state.copyWith(errorMessage: 'Ainda nao ha uma sessao registrada.');
      return null;
    }
    final report = const LaboratoryReportGenerator().generate(session);
    state = state.copyWith(report: report, clearError: true);
    return report;
  }

  Future<void> shareReport([LaboratoryReport? value]) async {
    final report = value ?? state.report ?? await generateReport();
    if (report == null) return;
    final runtime = ref.read(laboratoryRuntimeBridgeProvider);
    if (!runtime.canShare) {
      state = state.copyWith(
        errorMessage: 'Compartilhamento do sistema indisponivel.',
      );
      return;
    }
    try {
      await runtime.shareReport(
        plainText: report.text,
        attachments: report.attachments,
      );
      state = state.copyWith(clearError: true);
    } catch (error) {
      state = state.copyWith(errorMessage: _errorText(error));
      rethrow;
    }
  }

  Future<void> cancelSession() async {
    final engine = _engine;
    if (engine == null || engine.session.status != LaboratorySessionStatus.running) {
      return;
    }
    try {
      engine.cancel();
      _performanceTimer?.cancel();
      final report = const LaboratoryReportGenerator().generate(engine.session);
      await _save(engine.session);
      state = state.copyWith(
        session: engine.session,
        report: report,
        busy: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _errorText(error), busy: false);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  void _startPerformanceSampler() {
    _performanceTimer?.cancel();
    _performanceTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        final engine = _engine;
        if (engine == null || engine.session.activeStep == null) return;
        final sample = ref.read(laboratoryRuntimeBridgeProvider).samplePerformance();
        if (sample == null) return;
        try {
          engine.recordPerformance(sample);
          state = state.copyWith(session: engine.session);
        } on StateError {
          // O passo pode ter terminado entre a amostra e a escrita.
        }
      },
    );
  }

  Future<void> _save(LaboratorySession session) async {
    await _repository!.saveSession(session);
    final sessions = await _repository!.loadSessions();
    state = state.copyWith(recentSessions: sessions);
  }

  String _errorText(Object error) {
    final raw = error.toString();
    return raw
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Unsupported operation: ', '')
        .trim();
  }
}

final laboratorySessionControllerProvider =
    NotifierProvider<LaboratorySessionController, LaboratorySessionUiState>(
      LaboratorySessionController.new,
    );

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
