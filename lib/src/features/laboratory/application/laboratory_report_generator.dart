import '../domain/laboratory_level.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';

class LaboratoryReport {
  LaboratoryReport({
    required this.text,
    required Iterable<LaboratoryAttachment> attachments,
  }) : attachments = List.unmodifiable(attachments);

  final String text;

  /// Arquivos que a camada de compartilhamento deve enviar junto com o texto.
  final List<LaboratoryAttachment> attachments;
}

class LaboratoryReportOptions {
  const LaboratoryReportOptions({
    this.minimumFps = 30,
    this.allocationWarningThreshold = 300,
  });

  final double minimumFps;
  final int allocationWarningThreshold;
}

/// Gera texto simples, deterministico e legivel tanto por pessoas como agentes.
class LaboratoryReportGenerator {
  const LaboratoryReportGenerator({
    this.options = const LaboratoryReportOptions(),
  });

  final LaboratoryReportOptions options;

  LaboratoryReport generate(LaboratorySession session) {
    final out = StringBuffer();
    final environment = session.environment;
    out.writeln(
      'AUREA · Laboratorio · ${_date(session.createdAt)} · '
      '${environment.deviceModel} · ${environment.operatingSystem} · '
      '${environment.appVersion}',
    );
    final levels = session.enabledLevels.enabled.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    out.writeln(
      'Niveis ligados: ${levels.map((level) => level.code).join(' ')}',
    );

    for (final level in levels) {
      final runs = session.stepRuns.where((run) => run.level == level).toList()
        ..sort((a, b) {
          final number = a.stepNumber.compareTo(b.stepNumber);
          return number != 0 ? number : a.startedAt.compareTo(b.startedAt);
        });
      if (runs.isEmpty) continue;
      final taskTitle = session.tasks
          .where((task) => task.level == level)
          .map((task) => task.title)
          .firstOrNull;
      out.writeln(
        '${level.code} · ${taskTitle ?? LaboratoryLevelCatalog.definition(level).title}',
      );
      for (final run in runs) {
        final stepLabel = run.stepNumber == 0 ? 'UI' : '${run.stepNumber}';
        out.writeln(
          '  $stepLabel ${_symbol(run.outcome)} ${_oneLine(run.instruction)}'
          '  ${_measurement(run.metrics)}',
        );
        final note = run.testerNote?.trim();
        if (note != null && note.isNotEmpty) {
          out.writeln('     "${_oneLine(note)}"');
        }
        if (_hasOverlay(run.metrics)) {
          out.writeln(
            '     Overlay: ${_overlay(run.metrics)}${_overlayWarning(run.metrics)}',
          );
        }
      }
    }

    final screenshots = session.stepRuns
        .expand(
          (run) => run.attachments
              .where((attachment) => attachment.isScreenshot)
              .map((attachment) => (run: run, attachment: attachment)),
        )
        .toList();
    if (screenshots.isNotEmpty) {
      out.writeln(
        'Prints: ${screenshots.map((item) {
          final step = item.run.stepNumber == 0 ? 'UI' : 'passo ${item.run.stepNumber}';
          return '${item.run.level.code} $step';
        }).join(', ')}',
      );
    }
    final otherFiles = session.attachments.where((item) => !item.isScreenshot);
    if (otherFiles.isNotEmpty) {
      out.writeln(
        'Anexos: ${otherFiles.map((item) => item.label ?? item.uri).join(', ')}',
      );
    }

    return LaboratoryReport(
      text: out.toString().trimRight(),
      attachments: session.attachments,
    );
  }

  String _measurement(LaboratoryMetrics metrics) {
    final touches = metrics.touchCount == 1
        ? '1 toque'
        : '${metrics.touchCount} toques';
    final fps = metrics.fpsSampleCount == 0
        ? 'fps —'
        : '${_decimal(metrics.averageFps)} fps';
    final warning =
        metrics.fpsSampleCount > 0 && metrics.averageFps < options.minimumFps
        ? ' ⚠ abaixo de ${options.minimumFps.toStringAsFixed(0)}'
        : '';
    return '$touches · ${_duration(metrics.elapsed)} · $fps$warning';
  }

  String _overlay(LaboratoryMetrics metrics) {
    final temperature = metrics.temperatureCelsius == null
        ? metrics.thermalState.reportLabel
        : '${metrics.thermalState.reportLabel} '
              '(${_decimal(metrics.temperatureCelsius!)} °C)';
    return 'marcha ${metrics.gear ?? '—'} · '
        '${metrics.drawCalls} chamadas · '
        '${metrics.renderPasses} passes · '
        '${metrics.liveDecoders} decoders · '
        '${metrics.audioUnderruns} underruns · '
        '${metrics.allocationsPerFrame} alocacoes/frame · '
        'temperatura $temperature';
  }

  String _overlayWarning(LaboratoryMetrics metrics) {
    final warning =
        metrics.audioUnderruns > 0 ||
        metrics.allocationsPerFrame > options.allocationWarningThreshold ||
        metrics.thermalState == ThermalState.serious ||
        metrics.thermalState == ThermalState.critical;
    return warning ? ' ⚠' : '';
  }

  bool _hasOverlay(LaboratoryMetrics metrics) =>
      metrics.gear != null ||
      metrics.drawCalls > 0 ||
      metrics.renderPasses > 0 ||
      metrics.liveDecoders > 0 ||
      metrics.audioUnderruns > 0 ||
      metrics.allocationsPerFrame > 0 ||
      metrics.thermalState != ThermalState.unknown ||
      metrics.temperatureCelsius != null;

  static String _symbol(StepOutcome outcome) => switch (outcome) {
    StepOutcome.pending => '▶',
    StepOutcome.passed => '✓',
    StepOutcome.failed || StepOutcome.automaticFailure => '✗',
    StepOutcome.skipped => '⏭',
  };

  static String _oneLine(String value) =>
      value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  static String _decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  static String _duration(Duration value) {
    final totalSeconds = value.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final base =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    return hours == 0 ? base : '${hours.toString().padLeft(2, '0')}:$base';
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
