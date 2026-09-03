import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/prefs.dart';
import '../domain/laboratory_level.dart';
import 'laboratory_repository.dart';

/// Espelho sincronico para pontos quentes que nao recebem um [Ref].
///
/// Widgets devem preferir [laboratoryControllerProvider], que e reativo.
abstract final class LaboratoryFeatureGate {
  static LaboratoryLevelSelection _selection = LaboratoryLevelSelection();

  static LaboratoryLevelSelection get selection => _selection;

  static bool isLevelEnabled(LaboratoryLevelId level) =>
      _selection.isEnabled(level);

  /// Consulta conveniente pelos numeros publicos: 0..9 e 81 para o 8.1.
  static bool isEnabled(int level) {
    final id = _fromNumber(level);
    return id != null && isLevelEnabled(id);
  }

  static void force(LaboratoryLevelSelection selection) {
    _selection = selection;
  }

  static LaboratoryLevelId? _fromNumber(int level) => switch (level) {
    0 => LaboratoryLevelId.core,
    1 => LaboratoryLevelId.shapes,
    2 => LaboratoryLevelId.text,
    3 => LaboratoryLevelId.effects,
    4 => LaboratoryLevelId.mask,
    5 => LaboratoryLevelId.cut,
    6 => LaboratoryLevelId.apple,
    7 => LaboratoryLevelId.captions,
    8 => LaboratoryLevelId.scene3d,
    81 => LaboratoryLevelId.panorama,
    9 => LaboratoryLevelId.nullAndClone,
    _ => null,
  };
}

class LaboratoryController extends Notifier<LaboratoryLevelSelection> {
  @override
  LaboratoryLevelSelection build() {
    final preferences = ref.read(sharedPreferencesProvider);
    LaboratoryLevelSelection loaded;
    try {
      final raw = preferences.getString(LaboratoryStorageKeys.levels);
      loaded = raw == null
          ? LaboratoryLevelSelection()
          : LaboratoryLevelSelection.fromJson(jsonDecode(raw));
    } on Object {
      loaded = LaboratoryLevelSelection();
    }
    LaboratoryFeatureGate.force(loaded);
    return loaded;
  }

  bool isEnabled(int level) => LaboratoryFeatureGate.isEnabled(level);

  void toggle(LaboratoryLevelId level) {
    setEnabled(level, !state.isEnabled(level));
  }

  void setEnabled(LaboratoryLevelId level, bool enabled) {
    _setSelection(enabled ? state.enable(level) : state.disable(level));
  }

  void enableAll() {
    _setSelection(LaboratoryLevelSelection(LaboratoryLevelId.values));
  }

  void reset() {
    _setSelection(LaboratoryLevelSelection());
  }

  void _setSelection(LaboratoryLevelSelection value) {
    state = value;
    LaboratoryFeatureGate.force(value);
    final preferences = ref.read(sharedPreferencesProvider);
    unawaited(
      preferences.setString(
        LaboratoryStorageKeys.levels,
        jsonEncode(value.toJson()),
      ),
    );
  }
}

final laboratoryControllerProvider =
    NotifierProvider<LaboratoryController, LaboratoryLevelSelection>(
      LaboratoryController.new,
    );
