import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../editor/domain/project_store.dart';
import '../../editor/domain/video_project.dart';
import 'bundled_project_installation.dart';

/// Persistencia dos projetos: um JSON por projeto em
/// `<documentos do app>/projects/<id>.json`, escrito de forma atomica
/// (.tmp -> rename) para nunca deixar arquivo pela metade.
class ProjectRepository {
  ProjectRepository({Directory? directory, this.installBundledExamples = true})
    : _cached = directory;

  final bool installBundledExamples;
  Directory? _cached;
  Future<void>? _installing;
  final Map<String, Future<void>> _writes = {};

  Future<void> _enqueue(String id, Future<void> Function() action) {
    final previous = _writes[id] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => action());
    _writes[id] = next;
    return next.whenComplete(() {
      if (identical(_writes[id], next)) _writes.remove(id);
    });
  }

  Future<Directory> _dir() async {
    if (_cached != null) return _cached!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/projects');
    if (!d.existsSync()) d.createSync(recursive: true);
    return _cached = d;
  }

  Future<List<VideoProject>> loadAll() async {
    final dir = await _dir();
    if (installBundledExamples) {
      try {
        await (_installing ??= installBundledAbyss(dir));
      } catch (e) {
        // A full disk must not hide projects that are already saved. Retry
        // installation on the next read; the installer never overwrites edits.
        _installing = null;
        debugPrint('Exemplo ABISMO ainda nao instalado: $e');
      }
    }
    await Future.wait(
      _writes.values.toList().map((f) => f.catchError((Object _) {})),
    );
    final out = <VideoProject>[];
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json = await compute(_readProjectJson, f.path);
        out.add(projectFromJson(json));
      } catch (e) {
        // Arquivo corrompido nao derruba a lista inteira.
        debugPrint('Projeto ilegivel ${f.path}: $e');
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// O id vira NOME DE ARQUIVO. Ele nasce de um uuid, mas um projeto
  /// vindo de fora (importacao, arquivo editado na mao) poderia trazer
  /// "../" e escrever fora da pasta — entao so passa o que e seguro.
  static String _safeId(String id) {
    final clean = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return clean.isEmpty ? 'projeto' : clean;
  }

  Future<void> flush() async {
    await Future.wait(_writes.values.toList());
  }

  Future<void> save(
    VideoProject project,
  ) => _enqueue(_safeId(project.id), () async {
    final dir = await _dir();
    final path = '${dir.path}/${_safeId(project.id)}.json';
    // Domain-to-map keeps model buffers by reference; expensive JSON encoding
    // and disk I/O run outside the UI isolate. Per-project ordering prevents a
    // slow older autosave overwriting a newer edit or resurrecting a deletion.
    await compute(_writeProjectJson, (path, projectToJson(project)));
  });

  Future<void> delete(String id) => _enqueue(_safeId(id), () async {
    final dir = await _dir();
    final file = File('${dir.path}/${_safeId(id)}.json');
    if (await file.exists()) await file.delete();
  });
}

Map<String, dynamic> _readProjectJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void _writeProjectJson((String, Map<String, dynamic>) message) {
  final tmp = File('${message.$1}.tmp');
  tmp.writeAsStringSync(jsonEncode(message.$2), flush: true);
  tmp.renameSync(message.$1);
}
