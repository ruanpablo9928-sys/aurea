import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../editor/domain/project_store.dart';
import '../../editor/domain/video_project.dart';

/// Persistencia dos projetos: um JSON por projeto em
/// `<documentos do app>/projects/<id>.json`, escrito de forma atomica
/// (.tmp -> rename) para nunca deixar arquivo pela metade.
class ProjectRepository {
  Directory? _cached;

  Future<Directory> _dir() async {
    if (_cached != null) return _cached!;
    final docs = await getApplicationDocumentsDirectory();
    final d = Directory('${docs.path}/projects');
    if (!d.existsSync()) d.createSync(recursive: true);
    return _cached = d;
  }

  Future<List<VideoProject>> loadAll() async {
    final dir = await _dir();
    final out = <VideoProject>[];
    for (final f in dir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(f.readAsStringSync());
        out.add(projectFromJson(json as Map<String, dynamic>));
      } catch (e) {
        // Arquivo corrompido nao derruba a lista inteira.
        debugPrint('Projeto ilegivel ${f.path}: $e');
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> save(VideoProject project) async {
    final dir = await _dir();
    final file = File('${dir.path}/${project.id}.json');
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(projectToJson(project)));
    if (file.existsSync()) file.deleteSync();
    tmp.renameSync(file.path);
  }

  Future<void> delete(String id) async {
    final dir = await _dir();
    final file = File('${dir.path}/$id.json');
    if (file.existsSync()) file.deleteSync();
  }
}
