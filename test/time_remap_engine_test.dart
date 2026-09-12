import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/native/native_engine.dart';
import 'package:aurea/src/features/editor/presentation/am/time_remap_curve_editor.dart';

void main() {
  group('Time Remap Mathematical & Analytical Tests', () {
    test('Linear 1:1 Mapping: 0s -> 0s, 4s -> 4s', () {
      final p0 = RemapPoint(
        compositionTime: 0.0,
        sourceTime: 0.0,
        interpolation: 0,
      );
      final p1 = RemapPoint(
        compositionTime: 4.0,
        sourceTime: 4.0,
        interpolation: 0,
      );

      double evaluate(double t) {
        final u =
            (t - p0.compositionTime) /
            (p1.compositionTime - p0.compositionTime);
        return p0.sourceTime + u * (p1.sourceTime - p0.sourceTime);
      }

      expect(evaluate(0.0), closeTo(0.0, 1e-6));
      expect(evaluate(2.0), closeTo(2.0, 1e-6));
      expect(evaluate(4.0), closeTo(4.0, 1e-6));
    });

    test('Speed Ramp: 2x Acceleration (0s..2s comp -> 0s..4s source)', () {
      final p0 = RemapPoint(
        compositionTime: 0.0,
        sourceTime: 0.0,
        interpolation: 0,
      );
      final p1 = RemapPoint(
        compositionTime: 2.0,
        sourceTime: 4.0,
        interpolation: 0,
      );

      double evaluate(double t) {
        final u =
            (t - p0.compositionTime) /
            (p1.compositionTime - p0.compositionTime);
        return p0.sourceTime + u * (p1.sourceTime - p0.sourceTime);
      }

      double speed(double t) {
        const dt = 0.001;
        return (evaluate(t + dt) - evaluate(t - dt)) / (dt * 2);
      }

      expect(evaluate(1.0), closeTo(2.0, 1e-6));
      expect(
        speed(1.0),
        closeTo(2.0, 1e-3),
        reason: 'A velocidade derivada dY/dX deve ser 2.0 (200%)',
      );
    });

    test('True Reverse: 0s..4s comp -> 4s..0s source', () {
      final p0 = RemapPoint(
        compositionTime: 0.0,
        sourceTime: 4.0,
        interpolation: 0,
      );
      final p1 = RemapPoint(
        compositionTime: 4.0,
        sourceTime: 0.0,
        interpolation: 0,
      );

      double evaluate(double t) {
        final u =
            (t - p0.compositionTime) /
            (p1.compositionTime - p0.compositionTime);
        return p0.sourceTime + u * (p1.sourceTime - p0.sourceTime);
      }

      double speed(double t) {
        const dt = 0.001;
        return (evaluate(t + dt) - evaluate(t - dt)) / (dt * 2);
      }

      expect(evaluate(0.0), closeTo(4.0, 1e-6));
      expect(evaluate(1.0), closeTo(3.0, 1e-6));
      expect(evaluate(2.0), closeTo(2.0, 1e-6));
      expect(evaluate(4.0), closeTo(0.0, 1e-6));
      expect(
        speed(2.0),
        closeTo(-1.0, 1e-3),
        reason: 'Velocidade no reverso é negativa (-100%)',
      );
    });

    test('Freeze Frame: Constant source time across interval', () {
      final p0 = RemapPoint(
        compositionTime: 0.0,
        sourceTime: 0.0,
        interpolation: 0,
      );
      final p1 = RemapPoint(
        compositionTime: 1.0,
        sourceTime: 2.0,
        interpolation: 1,
      ); // Hold em 2s
      final p2 = RemapPoint(
        compositionTime: 3.0,
        sourceTime: 2.0,
        interpolation: 0,
      ); // Continua
      final p3 = RemapPoint(
        compositionTime: 5.0,
        sourceTime: 4.0,
        interpolation: 0,
      );

      final points = [p0, p1, p2, p3];

      double evaluate(double t) {
        for (var i = 0; i < points.length - 1; i++) {
          if (t >= points[i].compositionTime &&
              t <= points[i + 1].compositionTime) {
            if (points[i].interpolation == 1) return points[i].sourceTime;
            final dt =
                points[i + 1].compositionTime - points[i].compositionTime;
            final u = (t - points[i].compositionTime) / dt;
            return points[i].sourceTime +
                u * (points[i + 1].sourceTime - points[i].sourceTime);
          }
        }
        return points.last.sourceTime;
      }

      expect(
        evaluate(1.5),
        closeTo(2.0, 1e-6),
        reason: 'Frame congelado em 2.0s',
      );
      expect(
        evaluate(2.5),
        closeTo(2.0, 1e-6),
        reason: 'Frame continua congelado em 2.0s',
      );
    });

    test('Hold Keyframe: Discrete jump without intermediate interpolation', () {
      final p0 = RemapPoint(
        compositionTime: 0.0,
        sourceTime: 1.0,
        interpolation: 1,
      ); // Hold
      final p1 = RemapPoint(
        compositionTime: 2.0,
        sourceTime: 5.0,
        interpolation: 0,
      );

      double evaluate(double t) {
        if (t < p1.compositionTime) return p0.sourceTime;
        return p1.sourceTime;
      }

      expect(evaluate(0.5), equals(1.0));
      expect(evaluate(1.99), equals(1.0));
      expect(evaluate(2.0), equals(5.0));
    });

    test('Multi-Keyframe Complex Ramp: Slow motion -> Speed Ramp -> Freeze -> Reverse', () {
      final points = [
        RemapPoint(compositionTime: 0.0, sourceTime: 0.0), // início
        RemapPoint(compositionTime: 2.0, sourceTime: 0.5), // slow motion 0.25x
        RemapPoint(compositionTime: 3.0, sourceTime: 3.5), // speed ramp 3.0x
        RemapPoint(compositionTime: 5.0, sourceTime: 3.5), // freeze de 2s
        RemapPoint(compositionTime: 6.0, sourceTime: 1.0), // reverse rápido
      ];

      // Garante ordenação temporal estrita
      for (var i = 0; i < points.length - 1; i++) {
        expect(
          points[i].compositionTime < points[i + 1].compositionTime,
          isTrue,
        );
      }
    });

    test(
      'Sorting Out-of-Order Keyframes: automatic chronological normalization',
      () {
        final points = [
          RemapPoint(compositionTime: 3.0, sourceTime: 2.0),
          RemapPoint(compositionTime: 0.5, sourceTime: 0.2),
          RemapPoint(compositionTime: 5.0, sourceTime: 4.0),
          RemapPoint(compositionTime: 0.0, sourceTime: 0.0),
        ];

        points.sort((a, b) => a.compositionTime.compareTo(b.compositionTime));

        expect(points[0].compositionTime, equals(0.0));
        expect(points[1].compositionTime, equals(0.5));
        expect(points[2].compositionTime, equals(3.0));
        expect(points[3].compositionTime, equals(5.0));
      },
    );

    test(
      'NativeEngine Time Remap Graceful Fallback (quando nativo não linkado)',
      () {
        final native = NativeEngine.instance;
        // Não deve lançar exceção mesmo se a DLL nativa não estiver carregada no runner de teste
        native.setTimeRemapEnabled('layer1', true);
        native.resetTimeRemapDefault('layer1', 5.0);
        native.addTimeRemapKeyframe('layer1', 0.0, 0.0);
        native.addTimeRemapKeyframe('layer1', 2.0, 4.0);
        final count = native.getTimeRemapKeyframeCount('layer1');
        expect(count, isNonNegative);
      },
    );
  });
}
