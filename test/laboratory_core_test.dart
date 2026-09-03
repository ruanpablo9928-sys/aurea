import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/features/laboratory/application/laboratory_controller.dart';
import 'package:aurea/src/features/laboratory/application/laboratory_report_generator.dart';
import 'package:aurea/src/features/laboratory/application/laboratory_repository.dart';
import 'package:aurea/src/features/laboratory/application/laboratory_session_engine.dart';
import 'package:aurea/src/features/laboratory/domain/acceptance_task.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_acceptance_catalog.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_level.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_metrics.dart';
import 'package:aurea/src/features/laboratory/domain/laboratory_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('niveis e feature gate', () {
    test('core e dependencias sao normalizados nos dois sentidos', () {
      final clone = LaboratoryLevelSelection().enable(
        LaboratoryLevelId.nullAndClone,
      );

      expect(clone.isEnabled(LaboratoryLevelId.core), isTrue);
      expect(clone.isEnabled(LaboratoryLevelId.scene3d), isTrue);
      expect(clone.isEnabled(LaboratoryLevelId.nullAndClone), isTrue);
      expect(clone.isEnabled(LaboratoryLevelId.panorama), isFalse);

      final panorama = clone.enable(LaboratoryLevelId.panorama);
      final withoutScene = panorama.disable(LaboratoryLevelId.scene3d);
      expect(withoutScene.enabled, {LaboratoryLevelId.core});
      expect(withoutScene.disable(LaboratoryLevelId.core), withoutScene);
    });

    test('controller persiste e atualiza espelho sincronico', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(() {
        container.dispose();
        LaboratoryFeatureGate.force(LaboratoryLevelSelection());
      });

      container
          .read(laboratoryControllerProvider.notifier)
          .setEnabled(LaboratoryLevelId.panorama, true);
      expect(LaboratoryFeatureGate.isEnabled(8), isTrue);
      expect(LaboratoryFeatureGate.isEnabled(81), isTrue);
      expect(LaboratoryFeatureGate.isEnabled(9), isFalse);
      await Future<void>.delayed(Duration.zero);

      final repository = SharedPreferencesLaboratoryRepository(preferences);
      final loaded = await repository.loadLevelSelection();
      expect(loaded.isEnabled(LaboratoryLevelId.panorama), isTrue);
      expect(loaded.isEnabled(LaboratoryLevelId.scene3d), isTrue);
    });
  });

  test('catalogo cobre todos os niveis e associa ativos reproduziveis', () {
    expect(
      LaboratoryAcceptanceCatalog.all.map((task) => task.level).toSet(),
      LaboratoryLevelId.values.toSet(),
    );
    final captions = LaboratoryAcceptanceCatalog.forLevel(
      LaboratoryLevelId.captions,
    );
    final assetIds = captions.steps
        .expand((step) => step.assets)
        .map((asset) => asset.id)
        .toSet();
    expect(assetIds, contains(LaboratoryAssetId.spokenVideo));
    expect(assetIds, contains(LaboratoryAssetId.silentVideo));

    final scene = LaboratoryAcceptanceCatalog.forLevel(
      LaboratoryLevelId.scene3d,
    );
    expect(
      scene.steps.expand((step) => step.assets).map((asset) => asset.id),
      containsAll([LaboratoryAssetId.smallGlb, LaboratoryAssetId.largeGlb]),
    );
  });

  group('sessao guiada', () {
    late DateTime now;
    late LaboratorySessionEngine engine;

    setUp(() {
      now = DateTime.utc(2026, 9, 2, 12);
      final task = AcceptanceTaskDefinition(
        level: LaboratoryLevelId.shapes,
        title: 'Shapes',
        steps: [
          AcceptanceStepDefinition(
            id: 'move-points',
            instruction: 'Mover dois pontos.',
          ),
          AcceptanceStepDefinition(id: 'export', instruction: 'Exportar.'),
        ],
      );
      engine = LaboratorySessionEngine.create(
        levels: LaboratoryLevelSelection([LaboratoryLevelId.shapes]),
        environment: const LaboratoryEnvironment(
          deviceModel: 'Moto G52',
          operatingSystem: 'Android 13',
          appVersion: 'v1.0.0-beta+47',
        ),
        tasks: [task],
        clock: () => now,
        idFactory: () => 'session-1',
      );
    });

    test('UI ausente falha automaticamente antes do checklist', () {
      expect(
        () => engine.startStep(LaboratoryLevelId.shapes, 'move-points'),
        throwsStateError,
      );

      engine.checkUiVisibility(
        LaboratoryLevelId.shapes,
        visible: false,
        details: 'Biblioteca nao apareceu',
      );

      final failure = engine.session.stepRuns.single;
      expect(failure.outcome, StepOutcome.automaticFailure);
      expect(failure.stepNumber, 0);
      expect(failure.testerNote, 'Biblioteca nao apareceu');

      // A falha fica no relatorio, mas nao interrompe os passos humanos.
      expect(
        () => engine.startStep(LaboratoryLevelId.shapes, 'move-points'),
        returnsNormally,
      );
    });

    test('mede toque, tempo, fps e overlay e continua depois de falha', () {
      engine.checkUiVisibility(LaboratoryLevelId.shapes, visible: true);
      engine.startStep(LaboratoryLevelId.shapes, 'move-points');
      engine.recordTouch(3);
      engine.recordPerformance(
        const PerformanceSample(
          fps: 32,
          gear: 'M4',
          drawCalls: 12,
          renderPasses: 6,
          liveDecoders: 2,
          allocationsPerFrame: 340,
          thermalState: ThermalState.fair,
        ),
      );
      engine.recordPerformance(
        const PerformanceSample(
          fps: 28,
          gear: 'M4',
          drawCalls: 12,
          renderPasses: 6,
          liveDecoders: 2,
          audioUnderruns: 1,
          allocationsPerFrame: 340,
          thermalState: ThermalState.fair,
        ),
      );
      engine.attach(
        LaboratoryAttachment(
          id: 'print-1',
          kind: LaboratoryAttachmentKind.screenshot,
          uri: '/prints/step-1.png',
          createdAt: now,
        ),
      );
      now = now.add(const Duration(seconds: 41));
      engine.finishStep(StepOutcome.failed, note: 'faltou o trackpad');

      final failed = engine.session.stepRuns.single;
      expect(failed.metrics.touchCount, 3);
      expect(failed.metrics.elapsed, const Duration(seconds: 41));
      expect(failed.metrics.averageFps, 30);
      expect(failed.metrics.minimumFps, 28);
      expect(failed.metrics.audioUnderruns, 1);

      engine.startStep(LaboratoryLevelId.shapes, 'export');
      now = now.add(const Duration(seconds: 2));
      engine.finishStep(StepOutcome.passed);
      expect(engine.session.stepRuns.map((run) => run.outcome), [
        StepOutcome.failed,
        StepOutcome.passed,
      ]);
    });

    test('JSON preserva resultados, metricas e anexos', () {
      engine.checkUiVisibility(LaboratoryLevelId.shapes, visible: true);
      engine.startStep(LaboratoryLevelId.shapes, 'move-points');
      engine.recordTouch();
      engine.attach(
        LaboratoryAttachment(
          id: 'print',
          kind: LaboratoryAttachmentKind.screenshot,
          uri: '/print.png',
          createdAt: now,
        ),
      );
      now = now.add(const Duration(seconds: 1));
      engine.finishStep(StepOutcome.passed);

      final restored = LaboratorySession.fromJson(engine.session.toJson());
      expect(restored.id, 'session-1');
      expect(restored.stepRuns.single.metrics.touchCount, 1);
      expect(restored.attachments.single.uri, '/print.png');
      expect(restored.uiChecks.single.visible, isTrue);
    });

    test('relatorio e texto simples com print e alertas objetivos', () {
      engine.checkUiVisibility(LaboratoryLevelId.shapes, visible: true);
      engine.startStep(LaboratoryLevelId.shapes, 'move-points');
      engine.recordTouch(3);
      engine.recordPerformance(
        const PerformanceSample(
          fps: 24.1,
          gear: 'M4',
          renderPasses: 6,
          liveDecoders: 2,
          allocationsPerFrame: 340,
        ),
      );
      engine.attach(
        LaboratoryAttachment(
          id: 'print',
          kind: LaboratoryAttachmentKind.screenshot,
          uri: '/print.png',
          createdAt: now,
        ),
      );
      now = now.add(const Duration(seconds: 41));
      engine.finishStep(StepOutcome.failed, note: 'nao tem seletor de cor');

      final report = const LaboratoryReportGenerator().generate(engine.session);
      expect(report.text, contains('Moto G52 · Android 13'));
      expect(report.text, contains('1 ✗ Mover dois pontos.'));
      expect(report.text, contains('3 toques · 00:41 · 24,1 fps'));
      expect(report.text, contains('abaixo de 30'));
      expect(report.text, contains('marcha M4 · 0 chamadas · 6 passes'));
      expect(report.text, contains('340 alocacoes/frame'));
      expect(report.text, contains('Prints: 1 passo 1'));
      expect(report.attachments.single.uri, '/print.png');
    });
  });

  test('repository ignora sessao corrompida e preserva as validas', () async {
    SharedPreferences.setMockInitialValues({
      LaboratoryStorageKeys.sessions: '[42, {"tasks": []}]',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesLaboratoryRepository(preferences);
    final loaded = await repository.loadSessions();

    // O mapa minimo e recuperavel; o item que nao e mapa e ignorado.
    expect(loaded, hasLength(1));
    expect(loaded.single.enabledLevels.enabled, {LaboratoryLevelId.core});
  });
}
