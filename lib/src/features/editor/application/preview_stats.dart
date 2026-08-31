import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gear.dart';

/// Overlay de diagnostico do preview (specs motor-de-preview §7 e
/// arquitetura-de-marchas §9): sem numeros, todo "travou" vira
/// adivinhacao.
final debugOverlayProvider = StateProvider<bool>((ref) => false);

/// Medidores do preview. O compositor chama [tick] a cada frame que ele
/// REALMENTE compoe — com o portao de marchas, cena estatica compoe ~0/s
/// (o analogo Flutter de "o player nao compoe, so toca").
abstract final class PreviewStats {
  /// Composicoes por segundo (janela de 1 s).
  static final ValueNotifier<int> compsPerSec = ValueNotifier(0);

  /// Camadas compostas no ultimo frame.
  static final ValueNotifier<int> layersInFrame = ValueNotifier(0);

  /// Marcha ativa + motivo (classificador PR-G1).
  static final ValueNotifier<GearDecision?> gear = ValueNotifier(null);

  /// Variancia do intervalo entre ticks do clock, em ms (§6: suavidade e
  /// cadencia, nao media de fps). Janela de ~1 s.
  static final ValueNotifier<double> tickVarianceMs = ValueNotifier(0);

  /// Percentual do tempo de uso em M1+M2 (instrumentacao do PR-G1: se
  /// passar de 60%, o ganho da fase nativa esta provado).
  static final ValueNotifier<int> lowGearPercent = ValueNotifier(0);

  static int _count = 0;
  static int _windowStartMs = 0;

  static void tick(int layers) {
    layersInFrame.value = layers;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_windowStartMs == 0) _windowStartMs = now;
    _count++;
    final span = now - _windowStartMs;
    if (span >= 1000) {
      compsPerSec.value = (_count * 1000 / span).round();
      _count = 0;
      _windowStartMs = now;
    }
  }

  /// Janela deslizante de comps/s zera sozinha quando o portao segura as
  /// recomposicoes (nenhum tick chega para fechar a janela).
  static void idle() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_windowStartMs != 0 && now - _windowStartMs >= 1000) {
      compsPerSec.value =
          (_count * 1000 / (now - _windowStartMs)).round();
      _count = 0;
      _windowStartMs = now;
    }
  }

  // ---- marcha: tempo acumulado por classe (M1+M2 vs resto) ----
  static int _gearSinceMs = 0;
  static int _lowMs = 0;
  static int _highMs = 0;

  static void setGear(GearDecision decision) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev = gear.value;
    if (_gearSinceMs != 0 && prev != null) {
      final span = now - _gearSinceMs;
      if (prev.gear == PreviewGear.m1 || prev.gear == PreviewGear.m2) {
        _lowMs += span;
      } else {
        _highMs += span;
      }
      final total = _lowMs + _highMs;
      if (total > 0) {
        lowGearPercent.value = (_lowMs * 100 / total).round();
      }
    }
    _gearSinceMs = now;
    if (prev?.gear != decision.gear || prev?.reason != decision.reason) {
      gear.value = decision;
    }
  }

  // ---- cadencia: variancia do intervalo entre ticks ----
  static final List<double> _intervals = <double>[];
  static int _lastTickUs = 0;

  static void clockTick() {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (_lastTickUs != 0) {
      _intervals.add((now - _lastTickUs) / 1000.0);
      if (_intervals.length > 32) _intervals.removeAt(0);
      if (_intervals.length >= 8) {
        final mean =
            _intervals.reduce((a, b) => a + b) / _intervals.length;
        var acc = 0.0;
        for (final v in _intervals) {
          acc += (v - mean) * (v - mean);
        }
        final std = math.sqrt(acc / _intervals.length);
        // Atualiza com moderacao para nao virar ruido visual.
        if ((std - tickVarianceMs.value).abs() > 0.1) {
          tickVarianceMs.value = double.parse(std.toStringAsFixed(1));
        }
      }
    }
    _lastTickUs = now;
  }

  /// Pausou/retomou: intervalo atravessando a pausa nao e jitter.
  static void clockReset() {
    _lastTickUs = 0;
    _intervals.clear();
  }
}
