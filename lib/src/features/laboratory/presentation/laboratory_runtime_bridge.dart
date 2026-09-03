import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/laboratory_app_bridge.dart';
import '../domain/acceptance_task.dart';
import '../domain/laboratory_level.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';

/// Fronteira entre a interface do Laboratorio e recursos do aparelho/editor.
///
/// O provider tem um fallback deliberadamente indisponivel: sem uma ponte
/// real, a UI nunca declara um ativo carregado nem uma captura concluida.
abstract interface class LaboratoryRuntimeBridge {
  bool get canLoadAssets;
  bool get canCaptureScreenshot;
  bool get canShare;
  bool get canOpenEditor;

  LaboratoryEnvironment readEnvironment();
  Future<bool> isUiVisible(LaboratoryLevelId level);
  Future<String> prepareAsset(TestAssetRequirement asset);
  Future<LaboratoryAttachment> captureScreenshot({
    required LaboratoryLevelId level,
    required String stepId,
  });
  PerformanceSample? samplePerformance();
  Future<void> shareReport({
    required String plainText,
    required List<LaboratoryAttachment> attachments,
  });
  Future<void> openEditorForTask(LaboratoryLevelId level);
}

/// No app, a ponte de verdade; nos testes de dominio, a indisponivel
/// (que nao toca em plataforma nenhuma).
final laboratoryRuntimeBridgeProvider = Provider<LaboratoryRuntimeBridge>(
  (ref) => ref.watch(laboratoryAppBridgeProvider),
);

/// Implementacao segura enquanto a plataforma ainda nao registrou servicos.
class UnavailableLaboratoryRuntimeBridge implements LaboratoryRuntimeBridge {
  const UnavailableLaboratoryRuntimeBridge();

  @override
  bool get canCaptureScreenshot => false;

  @override
  bool get canLoadAssets => false;

  @override
  bool get canOpenEditor => false;

  @override
  bool get canShare => false;

  @override
  LaboratoryEnvironment readEnvironment() => LaboratoryEnvironment(
    deviceModel: Platform.localHostname.isEmpty
        ? 'Dispositivo desconhecido'
        : Platform.localHostname,
    operatingSystem:
        '${Platform.operatingSystem} '
        '${Platform.operatingSystemVersion}',
    appVersion: '1.1.0+2',
  );

  @override
  Future<bool> isUiVisible(LaboratoryLevelId level) async => false;

  @override
  Future<String> prepareAsset(TestAssetRequirement asset) =>
      Future.error(UnsupportedError('Carregador de ativos indisponivel.'));

  @override
  Future<LaboratoryAttachment> captureScreenshot({
    required LaboratoryLevelId level,
    required String stepId,
  }) => Future.error(UnsupportedError('Captura de tela indisponivel.'));

  @override
  PerformanceSample? samplePerformance() => null;

  @override
  Future<void> shareReport({
    required String plainText,
    required List<LaboratoryAttachment> attachments,
  }) => Future.error(UnsupportedError('Compartilhamento indisponivel.'));

  @override
  Future<void> openEditorForTask(LaboratoryLevelId level) =>
      Future.error(UnsupportedError('Navegacao para o editor indisponivel.'));
}

typedef LaboratoryUiProbe = Future<bool> Function(LaboratoryLevelId level);
typedef LaboratoryAssetPreparer = Future<String> Function(
  TestAssetRequirement asset,
);
typedef LaboratoryScreenshotCapture = Future<LaboratoryAttachment> Function({
  required LaboratoryLevelId level,
  required String stepId,
});
typedef LaboratoryPerformanceSampler = PerformanceSample? Function();
typedef LaboratoryReportSender = Future<void> Function({
  required String plainText,
  required List<LaboratoryAttachment> attachments,
});
typedef LaboratoryEditorOpener = Future<void> Function(LaboratoryLevelId level);

/// Adaptador de callbacks para a integracao nao precisar criar uma classe.
class CallbackLaboratoryRuntimeBridge implements LaboratoryRuntimeBridge {
  const CallbackLaboratoryRuntimeBridge({
    required this.environment,
    required this.uiProbe,
    this.assetPreparer,
    this.screenshotCapture,
    this.performanceSampler,
    this.reportSender,
    this.editorOpener,
  });

  final LaboratoryEnvironment Function() environment;
  final LaboratoryUiProbe uiProbe;
  final LaboratoryAssetPreparer? assetPreparer;
  final LaboratoryScreenshotCapture? screenshotCapture;
  final LaboratoryPerformanceSampler? performanceSampler;
  final LaboratoryReportSender? reportSender;
  final LaboratoryEditorOpener? editorOpener;

  @override
  bool get canCaptureScreenshot => screenshotCapture != null;

  @override
  bool get canLoadAssets => assetPreparer != null;

  @override
  bool get canOpenEditor => editorOpener != null;

  @override
  bool get canShare => reportSender != null;

  @override
  LaboratoryEnvironment readEnvironment() => environment();

  @override
  Future<bool> isUiVisible(LaboratoryLevelId level) => uiProbe(level);

  @override
  Future<String> prepareAsset(TestAssetRequirement asset) {
    final callback = assetPreparer;
    if (callback == null) {
      return Future.error(
        UnsupportedError('Carregador de ativos indisponivel.'),
      );
    }
    return callback(asset);
  }

  @override
  Future<LaboratoryAttachment> captureScreenshot({
    required LaboratoryLevelId level,
    required String stepId,
  }) {
    final callback = screenshotCapture;
    if (callback == null) {
      return Future.error(UnsupportedError('Captura de tela indisponivel.'));
    }
    return callback(level: level, stepId: stepId);
  }

  @override
  PerformanceSample? samplePerformance() => performanceSampler?.call();

  @override
  Future<void> shareReport({
    required String plainText,
    required List<LaboratoryAttachment> attachments,
  }) {
    final callback = reportSender;
    if (callback == null) {
      return Future.error(UnsupportedError('Compartilhamento indisponivel.'));
    }
    return callback(plainText: plainText, attachments: attachments);
  }

  @override
  Future<void> openEditorForTask(LaboratoryLevelId level) {
    final callback = editorOpener;
    if (callback == null) {
      return Future.error(
        UnsupportedError('Navegacao para o editor indisponivel.'),
      );
    }
    return callback(level);
  }
}
