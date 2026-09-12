import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/layer.dart';
import '../domain/temporal_interpolation.dart';

/// Source-time proxy: sourceOffset, reverse and remap all keep the same clock.
/// FFmpeg estimates motion on a small image before encoding intermediate frames.
class OpticalFlowPreview {
  OpticalFlowPreview._();
  static final instance = OpticalFlowPreview._();
  final revision = ValueNotifier<int>(0);
  final Map<String, String> _ready = {};
  final Map<String, String> _errors = {};
  final Set<String> _pending = {};
  Future<void> _queue = Future<void>.value();
  static int rate(VideoLayer layer) => fatorDeInterpolacao(layer) * 30;
  static bool needed(VideoLayer layer) =>
      interpolacaoEfetiva(layer) != InterpolacaoDeQuadros.nenhuma &&
      fatorDeInterpolacao(layer) > 1;
  String _key(VideoLayer layer) =>
      '${layer.sourcePath}|${rate(layer)}|${interpolacaoEfetiva(layer).name}';
  String? ready(VideoLayer layer) => needed(layer) ? _ready[_key(layer)] : null;
  String status(VideoLayer layer) {
    if (!needed(layer)) {
      return 'Ativo. Use uma velocidade abaixo de 1× para suavizar o movimento.';
    }
    final key = _key(layer);
    if (_ready.containsKey(key)) {
      return 'Prévia suavizada pronta. A exportação usa o vídeo original.';
    }
    if (_pending.contains(key)) {
      return 'Preparando quadros suaves em segundo plano…';
    }
    if (_errors.containsKey(key)) {
      return 'Não foi possível preparar a prévia. Toque para tentar novamente.';
    }
    return 'Preparar prévia suave';
  }

  Future<void> ensure(VideoLayer layer, {bool retry = false}) {
    if (!needed(layer)) return Future.value();
    final key = _key(layer);
    if (_ready.containsKey(key) ||
        _pending.contains(key) ||
        (!retry && _errors.containsKey(key))) {
      return Future.value();
    }
    _errors.remove(key);
    _pending.add(key);
    // Notify after build; callers may request a proxy during widget build.
    scheduleMicrotask(() => revision.value++);
    final job = _queue.then((_) => _build(layer, key));
    _queue = job.catchError((Object _) {});
    return job;
  }

  Future<void> _build(VideoLayer layer, String key) async {
    File? partial;
    try {
      final source = File(layer.sourcePath);
      final stat = await source.stat();
      if (stat.type != FileSystemEntityType.file) {
        throw StateError('Missing source');
      }
      final stamp =
          '$key|${stat.size}|${stat.modified.microsecondsSinceEpoch}|v2';
      final name = sha256.convert(utf8.encode(stamp)).toString();
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/aurea-optical-flow');
      await dir.create(recursive: true);
      final target = File('${dir.path}/$name.mp4');
      if (!await target.exists() || await target.length() < 4096) {
        partial = File('${target.path}.part');
        final filter = filtroDeInterpolacao(layer, fps: 30);
        final probe = await FFprobeKit.getMediaInformation(source.path);
        final duration = double.tryParse(
          probe.getMediaInformation()?.getDuration() ?? '',
        );
        if (duration == null || !duration.isFinite || duration <= 0) {
          throw StateError('Source duration unavailable');
        }
        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-threads',
          '2',
          '-i',
          source.path,
          '-map',
          '0:v:0',
          '-map',
          '0:a?',
          '-vf',
          "scale=w='min(480,iw)':h='min(480,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2,tpad=stop_mode=clone:stop=2,${filter}trim=duration=$duration,format=yuv420p",
          '-filter_threads',
          '1',
          '-c:v',
          'mpeg4',
          '-q:v',
          '6',
          '-g',
          '6',
          '-c:a',
          'aac',
          '-b:a',
          '128k',
          '-threads',
          '2',
          '-movflags',
          '+faststart',
          '-f',
          'mp4',
          partial.path,
        ]);
        if (!ReturnCode.isSuccess(await session.getReturnCode()) ||
            !await partial.exists() ||
            await partial.length() < 4096) {
          throw StateError('Interpolation failed');
        }
        await partial.rename(target.path);
      }
      _ready[key] = target.path;
      // Evict completed old caches only; never touch a partial file or source.
      final cached = await dir
          .list()
          .where((f) => f is File && f.path.endsWith('.mp4'))
          .cast<File>()
          .toList();
      cached.sort(
        (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
      );
      var bytes = cached.fold<int>(0, (sum, f) => sum + f.lengthSync());
      for (final file in cached) {
        if (bytes <= 512 * 1024 * 1024) break;
        if (file.path == target.path) continue;
        bytes -= await file.length();
        _ready.removeWhere((_, path) => path == file.path);
        await file.delete();
      }
    } catch (error) {
      _errors[key] = '$error';
      if (partial != null && await partial.exists()) await partial.delete();
    } finally {
      _pending.remove(key);
      revision.value++;
    }
  }
}

class OpticalFlowStatus extends StatelessWidget {
  const OpticalFlowStatus({super.key, required this.layer});
  final VideoLayer layer;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: OpticalFlowPreview.instance.revision,
    builder: (_, _, _) => TextButton.icon(
      icon: const Icon(Icons.motion_photos_on),
      onPressed: () => OpticalFlowPreview.instance.ensure(layer, retry: true),
      label: Text(OpticalFlowPreview.instance.status(layer)),
    ),
  );
}
