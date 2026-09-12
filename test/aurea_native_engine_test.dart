import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/native/aurea_native_bindings.dart';
import 'package:aurea/src/features/native/native_engine.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';

void main() {
  group('Aurea Native Performance Core Tests', () {
    test('NativeEngine singleton can be queried safely', () {
      final engine = NativeEngine.instance;
      expect(engine, isNotNull);
      expect(engine.isInitialized, isFalse);
    });

    test('NativeEngine handles gracefully if native library not bundled on test runner', () {
      final engine = NativeEngine.instance;
      // In host VM test environments without compiled libaurea_native.so/.dll in path,
      // it handles gracefully without crashing:
      if (!engine.isSupported) {
        expect(AureaNativeBindings.isAvailable, isFalse);
        final initialized = engine.initialize(width: 1920, height: 1080, fps: 30);
        expect(initialized, isFalse);
        expect(engine.isInitialized, isFalse);
      }
    });

    test('NativeEngine project sync handles layers, shapes and keyframes safely', () {
      final engine = NativeEngine.instance;

      final shapeLayer = ShapeLayer(
        name: 'Test Rectangle',
        startTime: Duration.zero,
        duration: const Duration(seconds: 5),
        scaleX: AnimatedDouble(1.0, [
          Keyframe<double>(time: Duration.zero, value: 1.0, ease: Easing.linear),
          Keyframe<double>(time: const Duration(seconds: 5), value: 2.0, ease: Easing.easeInOut),
        ]),
      );

      final project = VideoProject(
        name: 'Benchmark Project',
        createdAt: DateTime.now(),
        layers: [shapeLayer],
        fps: 30,
      );

      // Sincronização não deve lançar exceção
      expect(() => engine.syncProject(project), returnsNormally);
    });

    test('NativeEngine 3D pipeline methods handle unsupported environment safely', () {
      final engine = NativeEngine.instance;

      // Se não suportado (ex: VM host sem a biblioteca .so nativa no PATH),
      // nenhum método 3D deve quebrar ou lançar exceção.
      final analysis = engine.analyzeModel('non_existent_file.glb');
      if (!engine.isSupported) {
        expect(analysis, isNull);
      }

      final jobId = engine.startModelImportAsync('dummy.glb');
      if (!engine.isSupported || !engine.isInitialized) {
        expect(jobId, equals(-1));
      }

      final progress = engine.getModelImportProgress(jobId);
      expect(progress, isNotNull);
      if (!engine.isSupported) {
        expect(progress.isDone, isTrue);
      }

      expect(() => engine.cancelModelImport(jobId), returnsNormally);
      expect(() => engine.setScene3DFrameBudget(2.5), returnsNormally);

      final metrics = engine.getScene3DMetrics();
      if (!engine.isInitialized) {
        expect(metrics, isNotNull);
        expect(metrics.drawCalls, equals(0));
        expect(metrics.renderedTriangles, equals(0));
      }
    });
  });
}
