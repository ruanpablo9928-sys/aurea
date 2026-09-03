import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/laboratory_level.dart';
import '../domain/laboratory_session.dart';

abstract final class LaboratoryStorageKeys {
  static const levels = 'laboratory.levels.v1';
  static const sessions = 'laboratory.sessions.v1';
}

abstract interface class LaboratoryRepository {
  Future<LaboratoryLevelSelection> loadLevelSelection();
  Future<void> saveLevelSelection(LaboratoryLevelSelection selection);
  Future<List<LaboratorySession>> loadSessions();
  Future<void> saveSession(LaboratorySession session);
  Future<void> deleteSession(String id);
}

/// Persistencia pequena e portavel usando a dependencia que o app ja injeta.
/// Prints ficam como URIs; bytes de imagem nunca sao colocados nas preferencias.
class SharedPreferencesLaboratoryRepository implements LaboratoryRepository {
  SharedPreferencesLaboratoryRepository(
    this.preferences, {
    this.maximumSessions = 20,
  }) : assert(maximumSessions > 0);

  final SharedPreferences preferences;
  final int maximumSessions;

  @override
  Future<LaboratoryLevelSelection> loadLevelSelection() async {
    try {
      final raw = preferences.getString(LaboratoryStorageKeys.levels);
      return raw == null
          ? LaboratoryLevelSelection()
          : LaboratoryLevelSelection.fromJson(jsonDecode(raw));
    } on Object {
      return LaboratoryLevelSelection();
    }
  }

  @override
  Future<void> saveLevelSelection(LaboratoryLevelSelection selection) async {
    await preferences.setString(
      LaboratoryStorageKeys.levels,
      jsonEncode(selection.toJson()),
    );
  }

  @override
  Future<List<LaboratorySession>> loadSessions() async {
    try {
      final raw = preferences.getString(LaboratoryStorageKeys.sessions);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Iterable) return const [];
      final sessions = <LaboratorySession>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          sessions.add(
            LaboratorySession.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        } on Object {
          // Uma sessao corrompida nao esconde as demais.
        }
      }
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return List.unmodifiable(sessions);
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> saveSession(LaboratorySession session) async {
    final sessions = await loadSessions();
    final updated = <LaboratorySession>[
      session,
      for (final current in sessions)
        if (current.id != session.id) current,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final kept = updated.take(maximumSessions);
    await preferences.setString(
      LaboratoryStorageKeys.sessions,
      jsonEncode([for (final current in kept) current.toJson()]),
    );
  }

  @override
  Future<void> deleteSession(String id) async {
    final sessions = await loadSessions();
    await preferences.setString(
      LaboratoryStorageKeys.sessions,
      jsonEncode([
        for (final session in sessions)
          if (session.id != id) session.toJson(),
      ]),
    );
  }
}
