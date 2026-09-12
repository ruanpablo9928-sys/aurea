import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../../export/application/platform_encoder.dart';
import '../domain/color_look.dart';
import 'enhance_worker.dart';

class EnhanceProgress {
  const EnhanceProgress(this.label, this.fraction);
  final String label;
  final double fraction;
}

/// Owns only its temporary directory and encoder session. Originals are read-only.
class EnhancementJob {
  EnhancementJob({Future<ByteData> Function()? loadModel})
    : _loadModel = loadModel ?? _assetModel;
  final Future<ByteData> Function() _loadModel;
  static Future<ByteData> _assetModel() =>
      rootBundle.load('assets/ai/compressed_esrgan.tflite');
  final progress = ValueNotifier(const EnhanceProgress('Pronto', 0));
  Directory? _directory;
  EnhanceWorker? _worker;
  bool _cancelled = false, _encoding = false, _running = false;
  int? _ffmpegSession;
  String get _cancelPath => '${_directory!.path}/cancel';
  String get _modelPath => '${_directory!.path}/model.tflite';

  Future<void> _prepare() async {
    _cancelled = false;
    _directory ??= await (await getTemporaryDirectory()).createTemp(
      'aurea-enhance-',
    );
    final flag = File(_cancelPath);
    if (await flag.exists()) await flag.delete();
    if (!await File(_modelPath).exists()) {
      final data = await _loadModel();
      await File(_modelPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    _worker ??= await EnhanceWorker.start();
  }

  void _check() {
    if (_cancelled) throw StateError('Cancelado');
  }

  Future<void> cancel() async {
    _cancelled = true;
    if (_directory != null) await File(_cancelPath).writeAsString('cancel');
    final session = _ffmpegSession;
    if (session != null) await FFmpegKit.cancel(session);
  }

  Future<void> _ffmpeg(List<String> args) async {
    _check();
    final done = Completer<FFmpegSession>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      done.complete,
    );
    _ffmpegSession = session.getSessionId();
    if (_cancelled) await FFmpegKit.cancel(_ffmpegSession);
    try {
      final result = await done.future;
      _check();
      if (!ReturnCode.isSuccess(await result.getReturnCode())) {
        throw StateError(
          'Não foi possível processar este arquivo. Tente outro formato.',
        );
      }
    } finally {
      _ffmpegSession = null;
    }
  }

  Future<String> _imageSource(String source) async {
    final extension = source.split('.').last.toLowerCase();
    if (!['heic', 'heif', 'avif'].contains(extension)) return source;
    final converted =
        '${_directory!.path}/source-${DateTime.now().microsecondsSinceEpoch}.png';
    await _ffmpeg(['-y', '-i', source, '-frames:v', '1', converted]);
    return converted;
  }

  Future<(String, String)> preview(
    String source,
    bool video,
    EnhanceSettings settings,
  ) async {
    if (_running) throw StateError('Já existe um processamento em andamento');
    _running = true;
    try {
      await _prepare();
      _check();
      progress.value = const EnhanceProgress('Preparando comparação…', 0);
      var input = source;
      if (video) {
        input =
            '${_directory!.path}/before-${DateTime.now().microsecondsSinceEpoch}.png';
        await _ffmpeg(['-y', '-i', source, '-frames:v', '1', input]);
      } else {
        input = await _imageSource(source);
      }
      final output =
          '${_directory!.path}/preview-${DateTime.now().microsecondsSinceEpoch}.png';
      await _worker!.frame(input, output, _modelPath, _cancelPath, settings);
      _check();
      progress.value = const EnhanceProgress('Comparação pronta', 1);
      return (input, output);
    } finally {
      _running = false;
    }
  }

  Future<File> process(
    String source,
    bool video,
    EnhanceSettings settings,
  ) async {
    if (_running) throw StateError('Já existe um processamento em andamento');
    _running = true;
    try {
      await _prepare();
      _check();
      progress.value = const EnhanceProgress('Preparando arquivo…', 0);
      final result = File(
        '${_directory!.path}/result.${video ? 'mp4' : 'png'}',
      );
      if (video) {
        await _video(source, result.path, settings);
      } else {
        final input = await _imageSource(source);
        await _worker!.frame(
          input,
          result.path,
          _modelPath,
          _cancelPath,
          settings,
        );
      }
      _check();
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/aurea-enhanced',
      );
      await dir.create(recursive: true);
      final saved = await result.copy(
        '${dir.path}/Aurea-${DateTime.now().microsecondsSinceEpoch}.${video ? 'mp4' : 'png'}',
      );
      progress.value = const EnhanceProgress('Concluído', 1);
      return saved;
    } finally {
      if (_encoding) {
        await PlatformEncoder.cancel();
        _encoding = false;
      }
      _running = false;
    }
  }

  Future<void> _video(
    String source,
    String target,
    EnhanceSettings settings,
  ) async {
    if (!await PlatformEncoder.available) {
      throw StateError('Codificador de vídeo indisponível neste aparelho');
    }
    final probe = await FFprobeKit.getMediaInformation(source);
    final info = probe.getMediaInformation();
    final seconds = double.tryParse(info?.getDuration() ?? '') ?? 0;
    if (!seconds.isFinite || seconds <= 0) {
      throw StateError('Não foi possível ler a duração do vídeo');
    }
    // Decode to one fixed clock before enhancement, keeping audio and cuts aligned.
    const fps = 30, batch = 12;
    final count = (seconds * fps).ceil();
    final silent = '${_directory!.path}/silent.mp4';
    for (var first = 0; first < count; first += batch) {
      _check();
      final n = math.min(batch, count - first);
      final pattern = '${_directory!.path}/frame-%03d.png';
      for (var i = 0; i < batch; i++) {
        final old = File(
          '${_directory!.path}/frame-${i.toString().padLeft(3, '0')}.png',
        );
        if (await old.exists()) await old.delete();
      }
      await _ffmpeg([
        '-y',
        '-ss',
        (first / fps).toStringAsFixed(9),
        '-i',
        source,
        '-an',
        '-vf',
        'fps=$fps',
        '-frames:v',
        '$n',
        '-start_number',
        '0',
        pattern,
      ]);
      for (var index = 0; index < n; index++) {
        _check();
        final input = File(
          '${_directory!.path}/frame-${index.toString().padLeft(3, '0')}.png',
        );
        if (!await input.exists()) {
          break; // decoder may end within the last batch
        }
        final output = File('${_directory!.path}/enhanced.png');
        final size = await _worker!.frame(
          input.path,
          output.path,
          _modelPath,
          _cancelPath,
          settings,
          video: true,
        );
        _check();
        if (!_encoding) {
          await PlatformEncoder.start(
            path: silent,
            width: size.$1,
            height: size.$2,
            fps: fps,
            bitrate: (size.$1 * size.$2 * fps * .2).round().clamp(
              4000000,
              80000000,
            ),
          );
          _encoding = true;
        }
        await PlatformEncoder.frame(output.path);
        await input.delete();
        await output.delete();
        progress.value = EnhanceProgress(
          'Melhorando quadro ${first + index + 1} de $count',
          (first + index + 1) / count * .95,
        );
      }
    }
    if (!_encoding || !await PlatformEncoder.finish()) {
      throw StateError('Não foi possível finalizar o vídeo');
    }
    _encoding = false;
    _check();
    progress.value = const EnhanceProgress('Preservando o áudio…', .97);
    await _ffmpeg([
      '-y',
      '-i',
      silent,
      '-i',
      source,
      '-map',
      '0:v:0',
      '-map',
      '1:a?',
      '-c:v',
      'copy',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-t',
      seconds.toStringAsFixed(9),
      '-movflags',
      '+faststart',
      target,
    ]);
  }

  Future<void> close() async {
    await cancel();
    // Call only after preview/process completes, so native resources are released safely.
    if (_running) return;
    await _worker?.close();
    _worker = null;
    if (_directory != null && await _directory!.exists()) {
      await _directory!.delete(recursive: true);
    }
    _directory = null;
    progress.dispose();
  }
}
