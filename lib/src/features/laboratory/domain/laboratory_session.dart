import 'acceptance_task.dart';
import 'laboratory_level.dart';
import 'laboratory_metrics.dart';

enum LaboratoryAttachmentKind { screenshot, file }

/// Referencia persistivel a um print ou arquivo que sera enviado com o texto.
class LaboratoryAttachment {
  const LaboratoryAttachment({
    required this.id,
    required this.kind,
    required this.uri,
    required this.createdAt,
    this.label,
    this.mimeType,
  });

  final String id;
  final LaboratoryAttachmentKind kind;
  final String uri;
  final DateTime createdAt;
  final String? label;
  final String? mimeType;

  bool get isScreenshot => kind == LaboratoryAttachmentKind.screenshot;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'uri': uri,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (label != null) 'label': label,
    if (mimeType != null) 'mimeType': mimeType,
  };

  factory LaboratoryAttachment.fromJson(Map<String, Object?> json) =>
      LaboratoryAttachment(
        id: json['id']?.toString() ?? 'attachment',
        kind: LaboratoryAttachmentKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => LaboratoryAttachmentKind.file,
        ),
        uri: json['uri']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        label: json['label']?.toString(),
        mimeType: json['mimeType']?.toString(),
      );
}

enum StepOutcome { pending, passed, failed, skipped, automaticFailure }

extension StepOutcomeX on StepOutcome {
  bool get isFinished => this != StepOutcome.pending;
  bool get isFailure =>
      this == StepOutcome.failed || this == StepOutcome.automaticFailure;
}

class AcceptanceStepRun {
  AcceptanceStepRun({
    required this.level,
    required this.stepId,
    required this.stepNumber,
    required this.instruction,
    required this.startedAt,
    this.outcome = StepOutcome.pending,
    this.finishedAt,
    this.metrics = const LaboratoryMetrics(),
    this.testerNote,
    Iterable<LaboratoryAttachment> attachments = const [],
  }) : attachments = List.unmodifiable(attachments),
       assert(stepNumber >= 0),
       assert(
         outcome == StepOutcome.pending || finishedAt != null,
         'Um resultado final precisa de finishedAt.',
       );

  final LaboratoryLevelId level;
  final String stepId;

  /// Zero e reservado para verificacoes automaticas, antes do checklist.
  final int stepNumber;
  final String instruction;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final StepOutcome outcome;
  final LaboratoryMetrics metrics;
  final String? testerNote;
  final List<LaboratoryAttachment> attachments;

  bool get isActive => outcome == StepOutcome.pending;

  AcceptanceStepRun copyWith({
    DateTime? finishedAt,
    StepOutcome? outcome,
    LaboratoryMetrics? metrics,
    String? testerNote,
    bool clearTesterNote = false,
    Iterable<LaboratoryAttachment>? attachments,
  }) => AcceptanceStepRun(
    level: level,
    stepId: stepId,
    stepNumber: stepNumber,
    instruction: instruction,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    outcome: outcome ?? this.outcome,
    metrics: metrics ?? this.metrics,
    testerNote: clearTesterNote ? null : testerNote ?? this.testerNote,
    attachments: attachments ?? this.attachments,
  );

  Map<String, Object?> toJson() => {
    'level': level.name,
    'stepId': stepId,
    'stepNumber': stepNumber,
    'instruction': instruction,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toUtc().toIso8601String(),
    'outcome': outcome.name,
    'metrics': metrics.toJson(),
    if (testerNote != null) 'testerNote': testerNote,
    if (attachments.isNotEmpty)
      'attachments': [
        for (final attachment in attachments) attachment.toJson(),
      ],
  };

  factory AcceptanceStepRun.fromJson(Map<String, Object?> json) {
    final rawMetrics = json['metrics'];
    final rawAttachments = json['attachments'];
    return AcceptanceStepRun(
      level:
          LaboratoryLevelIdX.tryParse(json['level']?.toString() ?? '') ??
          LaboratoryLevelId.core,
      stepId: json['stepId']?.toString() ?? 'step',
      stepNumber: (json['stepNumber'] as num?)?.toInt() ?? 0,
      instruction: json['instruction']?.toString() ?? 'Executar passo',
      startedAt:
          DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      finishedAt: DateTime.tryParse(json['finishedAt']?.toString() ?? ''),
      outcome: StepOutcome.values.firstWhere(
        (value) => value.name == json['outcome'],
        orElse: () => StepOutcome.pending,
      ),
      metrics: rawMetrics is Map
          ? LaboratoryMetrics.fromJson(_stringMap(rawMetrics))
          : const LaboratoryMetrics(),
      testerNote: json['testerNote']?.toString(),
      attachments: [
        if (rawAttachments is Iterable)
          for (final attachment in rawAttachments)
            if (attachment is Map)
              LaboratoryAttachment.fromJson(_stringMap(attachment)),
      ],
    );
  }
}

class UiVisibilityCheck {
  const UiVisibilityCheck({
    required this.level,
    required this.expectedUi,
    required this.visible,
    required this.checkedAt,
    this.details,
  });

  final LaboratoryLevelId level;
  final String expectedUi;
  final bool visible;
  final DateTime checkedAt;
  final String? details;

  Map<String, Object?> toJson() => {
    'level': level.name,
    'expectedUi': expectedUi,
    'visible': visible,
    'checkedAt': checkedAt.toUtc().toIso8601String(),
    if (details != null) 'details': details,
  };

  factory UiVisibilityCheck.fromJson(Map<String, Object?> json) =>
      UiVisibilityCheck(
        level:
            LaboratoryLevelIdX.tryParse(json['level']?.toString() ?? '') ??
            LaboratoryLevelId.core,
        expectedUi: json['expectedUi']?.toString() ?? 'UI do nivel',
        visible: json['visible'] as bool? ?? false,
        checkedAt:
            DateTime.tryParse(json['checkedAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        details: json['details']?.toString(),
      );
}

class LaboratoryEnvironment {
  const LaboratoryEnvironment({
    required this.deviceModel,
    required this.operatingSystem,
    required this.appVersion,
    this.locale,
  });

  final String deviceModel;
  final String operatingSystem;
  final String appVersion;
  final String? locale;

  Map<String, Object?> toJson() => {
    'deviceModel': deviceModel,
    'operatingSystem': operatingSystem,
    'appVersion': appVersion,
    if (locale != null) 'locale': locale,
  };

  factory LaboratoryEnvironment.fromJson(Map<String, Object?> json) =>
      LaboratoryEnvironment(
        deviceModel:
            json['deviceModel']?.toString() ?? 'Dispositivo desconhecido',
        operatingSystem:
            json['operatingSystem']?.toString() ?? 'Sistema desconhecido',
        appVersion: json['appVersion']?.toString() ?? 'versao desconhecida',
        locale: json['locale']?.toString(),
      );
}

enum LaboratorySessionStatus { running, completed, cancelled }

class LaboratorySession {
  LaboratorySession({
    required this.id,
    required this.createdAt,
    required this.environment,
    required this.enabledLevels,
    required Iterable<AcceptanceTaskDefinition> tasks,
    this.status = LaboratorySessionStatus.running,
    this.finishedAt,
    Iterable<UiVisibilityCheck> uiChecks = const [],
    Iterable<AcceptanceStepRun> stepRuns = const [],
  }) : tasks = List.unmodifiable(tasks),
       uiChecks = List.unmodifiable(uiChecks),
       stepRuns = List.unmodifiable(stepRuns) {
    if (this.stepRuns.where((run) => run.isActive).length > 1) {
      throw ArgumentError('Apenas um passo pode estar ativo.');
    }
  }

  final String id;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final LaboratoryEnvironment environment;
  final LaboratoryLevelSelection enabledLevels;
  final List<AcceptanceTaskDefinition> tasks;
  final List<UiVisibilityCheck> uiChecks;
  final List<AcceptanceStepRun> stepRuns;
  final LaboratorySessionStatus status;

  AcceptanceStepRun? get activeStep {
    for (final run in stepRuns) {
      if (run.isActive) return run;
    }
    return null;
  }

  Iterable<LaboratoryAttachment> get attachments sync* {
    for (final run in stepRuns) {
      yield* run.attachments;
    }
  }

  Set<LaboratoryLevelId> get levelsAwaitingUiCheck {
    final checked = {for (final check in uiChecks) check.level};
    return enabledLevels.enabled
        .where((level) => level != LaboratoryLevelId.core)
        .where((level) => !checked.contains(level))
        .toSet();
  }

  bool get hasAutomaticFailures =>
      stepRuns.any((run) => run.outcome == StepOutcome.automaticFailure);

  AcceptanceTaskDefinition taskFor(LaboratoryLevelId level) =>
      tasks.firstWhere((task) => task.level == level);

  LaboratorySession copyWith({
    DateTime? finishedAt,
    LaboratoryLevelSelection? enabledLevels,
    Iterable<AcceptanceTaskDefinition>? tasks,
    LaboratorySessionStatus? status,
    Iterable<UiVisibilityCheck>? uiChecks,
    Iterable<AcceptanceStepRun>? stepRuns,
  }) => LaboratorySession(
    id: id,
    createdAt: createdAt,
    finishedAt: finishedAt ?? this.finishedAt,
    environment: environment,
    enabledLevels: enabledLevels ?? this.enabledLevels,
    tasks: tasks ?? this.tasks,
    status: status ?? this.status,
    uiChecks: uiChecks ?? this.uiChecks,
    stepRuns: stepRuns ?? this.stepRuns,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toUtc().toIso8601String(),
    'environment': environment.toJson(),
    'enabledLevels': enabledLevels.toJson(),
    'tasks': [for (final task in tasks) task.toJson()],
    'status': status.name,
    'uiChecks': [for (final check in uiChecks) check.toJson()],
    'stepRuns': [for (final run in stepRuns) run.toJson()],
  };

  factory LaboratorySession.fromJson(Map<String, Object?> json) {
    final rawEnvironment = json['environment'];
    final rawTasks = json['tasks'];
    final rawChecks = json['uiChecks'];
    final rawRuns = json['stepRuns'];
    return LaboratorySession(
      id: json['id']?.toString() ?? 'session',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      finishedAt: DateTime.tryParse(json['finishedAt']?.toString() ?? ''),
      environment: rawEnvironment is Map
          ? LaboratoryEnvironment.fromJson(_stringMap(rawEnvironment))
          : const LaboratoryEnvironment(
              deviceModel: 'Dispositivo desconhecido',
              operatingSystem: 'Sistema desconhecido',
              appVersion: 'versao desconhecida',
            ),
      enabledLevels: LaboratoryLevelSelection.fromJson(json['enabledLevels']),
      tasks: [
        if (rawTasks is Iterable)
          for (final task in rawTasks)
            if (task is Map)
              AcceptanceTaskDefinition.fromJson(_stringMap(task)),
      ],
      status: LaboratorySessionStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => LaboratorySessionStatus.running,
      ),
      uiChecks: [
        if (rawChecks is Iterable)
          for (final check in rawChecks)
            if (check is Map) UiVisibilityCheck.fromJson(_stringMap(check)),
      ],
      stepRuns: [
        if (rawRuns is Iterable)
          for (final run in rawRuns)
            if (run is Map) AcceptanceStepRun.fromJson(_stringMap(run)),
      ],
    );
  }
}

Map<String, Object?> _stringMap(Map<dynamic, dynamic> value) =>
    value.map((key, item) => MapEntry(key.toString(), item));
