import '../domain/acceptance_task.dart';
import '../domain/laboratory_level.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';

typedef LaboratoryClock = DateTime Function();
typedef LaboratoryIdFactory = String Function();

/// Motor independente de UI para uma sessao guiada do Laboratorio.
///
/// Toda operacao atualiza [session] de forma sincronica. A camada de estado
/// pode persistir a nova sessao depois de cada chamada, sem acoplar o dominio
/// ao Flutter.
class LaboratorySessionEngine {
  LaboratorySessionEngine._(this._session, this._clock);

  factory LaboratorySessionEngine.create({
    required LaboratoryLevelSelection levels,
    required LaboratoryEnvironment environment,
    required Iterable<AcceptanceTaskDefinition> tasks,
    LaboratoryClock? clock,
    LaboratoryIdFactory? idFactory,
  }) {
    final resolvedClock = clock ?? DateTime.now;
    final createdAt = resolvedClock();
    final resolvedId =
        idFactory?.call() ?? 'lab-${createdAt.toUtc().microsecondsSinceEpoch}';
    return LaboratorySessionEngine._(
      LaboratorySession(
        id: resolvedId,
        createdAt: createdAt,
        environment: environment,
        enabledLevels: levels,
        tasks: tasks,
      ),
      resolvedClock,
    );
  }

  factory LaboratorySessionEngine.resume(
    LaboratorySession session, {
    LaboratoryClock? clock,
  }) => LaboratorySessionEngine._(session, clock ?? DateTime.now);

  LaboratorySession _session;
  final LaboratoryClock _clock;

  LaboratorySession get session => _session;

  /// Registra a prova de que a UI apareceu. Uma resposta negativa cria, na
  /// mesma operacao, uma falha automatica anterior ao primeiro passo humano.
  LaboratorySession checkUiVisibility(
    LaboratoryLevelId level, {
    required bool visible,
    String? expectedUi,
    String? details,
  }) {
    _ensureRunning();
    if (!_session.enabledLevels.isEnabled(level)) {
      throw StateError('O nivel ${level.code} nao esta ligado.');
    }
    final now = _clock();
    final expectation =
        expectedUi ?? LaboratoryLevelCatalog.definition(level).expectedUi;
    final check = UiVisibilityCheck(
      level: level,
      expectedUi: expectation,
      visible: visible,
      checkedAt: now,
      details: details,
    );
    final checks = [
      for (final current in _session.uiChecks)
        if (current.level != level) current,
      check,
    ];
    var runs = _session.stepRuns;
    final automaticId = 'ui-visibility:${level.name}';
    if (!visible && !runs.any((run) => run.stepId == automaticId)) {
      final note = details?.trim();
      runs = [
        ...runs,
        AcceptanceStepRun(
          level: level,
          stepId: automaticId,
          stepNumber: 0,
          instruction: 'UI esperada visivel: $expectation',
          startedAt: now,
          finishedAt: now,
          outcome: StepOutcome.automaticFailure,
          testerNote: note == null || note.isEmpty
              ? 'Nivel ligado, mas a UI nao apareceu.'
              : note,
        ),
      ];
    }
    _session = _session.copyWith(uiChecks: checks, stepRuns: runs);
    return _session;
  }

  /// Ordem opcional que automatiza a regra de rodar primeiro o nivel anterior.
  List<AcceptanceTaskDefinition> taskOrderFor(
    LaboratoryLevelId level, {
    bool includePrevious = false,
  }) {
    final ordered =
        _session.tasks
            .where((task) => _session.enabledLevels.isEnabled(task.level))
            .toList()
          ..sort((a, b) => a.level.sortOrder.compareTo(b.level.sortOrder));
    final targetIndex = ordered.indexWhere((task) => task.level == level);
    if (targetIndex < 0) {
      throw StateError('Tarefa do nivel ${level.code} ausente.');
    }
    if (!includePrevious || targetIndex == 0) {
      return [ordered[targetIndex]];
    }
    return [ordered[targetIndex - 1], ordered[targetIndex]];
  }

  LaboratorySession startStep(
    LaboratoryLevelId level,
    String stepId, {
    bool allowRepeat = false,
  }) {
    _ensureRunning();
    if (_session.activeStep != null) {
      throw StateError('Finalize o passo ativo antes de iniciar outro.');
    }
    if (!_session.enabledLevels.isEnabled(level)) {
      throw StateError('O nivel ${level.code} nao esta ligado.');
    }
    if (_session.levelsAwaitingUiCheck.isNotEmpty) {
      final codes = _session.levelsAwaitingUiCheck
          .map((item) => item.code)
          .join(', ');
      throw StateError('Verifique a UI dos niveis antes do teste: $codes.');
    }
    final task = _session.taskFor(level);
    final definition = task.stepById(stepId);
    if (!allowRepeat &&
        _session.stepRuns.any(
          (run) => run.level == level && run.stepId == stepId,
        )) {
      throw StateError('O passo $stepId ja foi executado.');
    }
    final run = AcceptanceStepRun(
      level: level,
      stepId: definition.id,
      stepNumber: task.steps.indexOf(definition) + 1,
      instruction: definition.instruction,
      startedAt: _clock(),
    );
    _session = _session.copyWith(stepRuns: [..._session.stepRuns, run]);
    return _session;
  }

  LaboratorySession recordTouch([int count = 1]) => _updateActive(
    (run) => run.copyWith(metrics: run.metrics.recordTouch(count)),
  );

  LaboratorySession recordPerformance(PerformanceSample sample) =>
      _updateActive(
        (run) => run.copyWith(
          metrics: run.metrics
              .recordPerformance(sample)
              .copyWith(elapsed: _elapsedSince(run.startedAt)),
        ),
      );

  LaboratorySession attach(LaboratoryAttachment attachment) => _updateActive(
    (run) => run.copyWith(attachments: [...run.attachments, attachment]),
  );

  /// [failed] nao bloqueia o proximo passo; ele apenas fica registrado.
  LaboratorySession finishStep(StepOutcome outcome, {String? note}) {
    if (!outcome.isFinished || outcome == StepOutcome.automaticFailure) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    return _updateActive((run) {
      final now = _clock();
      return run.copyWith(
        finishedAt: now,
        outcome: outcome,
        testerNote: note?.trim(),
        clearTesterNote: note == null || note.trim().isEmpty,
        metrics: run.metrics.copyWith(
          elapsed: _elapsedSince(run.startedAt, now),
        ),
      );
    });
  }

  LaboratorySession complete() {
    _ensureRunning();
    if (_session.activeStep != null) {
      throw StateError('Finalize o passo ativo antes de encerrar a sessao.');
    }
    _session = _session.copyWith(
      status: LaboratorySessionStatus.completed,
      finishedAt: _clock(),
    );
    return _session;
  }

  LaboratorySession cancel() {
    _ensureRunning();
    if (_session.activeStep != null) {
      finishStep(StepOutcome.skipped, note: 'Sessao cancelada.');
    }
    _session = _session.copyWith(
      status: LaboratorySessionStatus.cancelled,
      finishedAt: _clock(),
    );
    return _session;
  }

  LaboratorySession _updateActive(
    AcceptanceStepRun Function(AcceptanceStepRun run) update,
  ) {
    _ensureRunning();
    final active = _session.activeStep;
    if (active == null) throw StateError('Nao ha passo ativo.');
    _session = _session.copyWith(
      stepRuns: [
        for (final run in _session.stepRuns)
          if (identical(run, active)) update(run) else run,
      ],
    );
    return _session;
  }

  Duration _elapsedSince(DateTime start, [DateTime? end]) {
    final value = (end ?? _clock()).difference(start);
    return value.isNegative ? Duration.zero : value;
  }

  void _ensureRunning() {
    if (_session.status != LaboratorySessionStatus.running) {
      throw StateError('A sessao nao esta em andamento.');
    }
  }
}
