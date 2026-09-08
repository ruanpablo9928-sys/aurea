import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/audio_effect.dart';
import '../domain/audio_effect_graph.dart';
import '../domain/layer.dart';
import '../domain/cut_ops.dart';

/// Reverses interleaved stereo f32 frames with a fixed 64 KiB working buffer.
Future<void> reverseStereoPcm((String, String, bool) files) async {
  final input = await File(files.$1).open(),
      output = await File(files.$2).open(mode: FileMode.write);
  try {
    var end = await input.length();
    end -= end % 8;
    while (end > 0) {
      final size = end.clamp(0, 65536);
      end -= size;
      await input.setPosition(end);
      final bytes = await input.read(size), reversed = Uint8List(size);
      for (var i = 0; i < size; i += 8) {
        final from = size - i - 8;
        if (files.$3) {
          reversed.setRange(i, i + 4, bytes, from + 4);
          reversed.setRange(i + 4, i + 8, bytes, from);
        } else {
          reversed.setRange(i, i + 8, bytes, from);
        }
      }
      await output.writeFrom(reversed);
    }
  } finally {
    await input.close();
    await output.close();
  }
}

class AudioRenderService {
  AudioRenderService._();
  static final instance = AudioRenderService._();
  final revision = ValueNotifier(0);
  final _ready = <String, String>{}, _errors = <String, String>{};
  final _pending = <String, Future<String>>{};
  Future<void> _queue = Future.value();
  static AudioSpec? spec(Layer l) => switch (l) {
    AudioLayer a => a.audio,
    VideoLayer v => v.audio,
    _ => null,
  };
  static String source(Layer l) => switch (l) {
    AudioLayer a => a.sourcePath,
    VideoLayer v => v.sourcePath,
    _ => '',
  };
  static Duration offset(Layer l) => switch (l) {
    AudioLayer a => a.sourceOffset,
    VideoLayer v => v.sourceOffset,
    _ => Duration.zero,
  };
  static Duration span(Layer l) => switch (l) {
    AudioLayer a => a.sourceSpan,
    VideoLayer v => videoSourceSpan(v),
    _ => l.duration,
  };
  static bool needed(Layer l) => spec(l)?.processing.isNeutral == false;
  final _keys = Expando<String>();
  String key(Layer l) => _keys[l] ??= sha256
      .convert(
        utf8.encode(
          'audio-v1:${source(l)}:${offset(l).inMicroseconds}:${span(l).inMicroseconds}:${spec(l)?.processing.cacheKey}',
        ),
      )
      .toString();
  String? ready(Layer l) => _ready[key(l)];
  String? error(Layer l) => _errors[key(l)];
  bool busy(Layer l) => _pending.containsKey(key(l));
  Future<String> prepare(Layer layer) {
    if (!needed(layer)) return Future.value(source(layer));
    final k = key(layer), path = _ready[k];
    if (path != null) return Future.value(path);
    if (_pending[k] != null) return _pending[k]!;
    final completer = Completer<String>();
    _pending[k] = completer.future;
    _errors.remove(k);
    revision.value++;
    _queue = _queue.then((_) async {
      try {
        final path = await _render(layer, k);
        _ready[k] = path;
        completer.complete(path);
      } catch (e) {
        _errors[k] = 'Nao foi possivel preparar os efeitos de audio.';
        completer.completeError(e);
      } finally {
        _pending.remove(k);
        revision.value++;
      }
    });
    return completer.future;
  }

  Future<void> _run(List<String> args) async {
    final session = await FFmpegKit.executeWithArguments([
      '-v',
      'error',
      '-y',
      ...args,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      throw StateError(
        'Falha no processamento de audio: ${await session.getFailStackTrace()}',
      );
    }
  }

  Future<String> _render(Layer layer, String key) async {
    final base = await getApplicationSupportDirectory();
    final dir = await Directory('${base.path}/audio_effects')
        .create(recursive: true);
    final target = File('${dir.path}/$key.wav');
    if (await target.exists() && await target.length() > 44) return target.path;
    final scratch = await Directory('${dir.path}/work_$key')
        .create(recursive: true);
    var stage = 0, current = '${scratch.path}/0.f32';
    final p = spec(layer)!.processing;
    final cleanup = <String>[
      if (p.denoise > 0) 'afftdn=nr=${(p.denoise * 30).clamp(0.01, 97)}',
      if (p.voice > 0)
        'highpass=f=80,acompressor=threshold=0.125:ratio=${1 + 2 * p.voice}:makeup=1.25',
      if (p.deEsser > 0) 'deesser=i=${p.deEsser.clamp(0, 1)}',
      if (p.lowDb != 0) 'bass=g=${p.lowDb}',
      if (p.midDb != 0) 'equalizer=f=1000:t=o:w=1:g=${p.midDb}',
      if (p.highDb != 0) 'treble=g=${p.highDb}',
    ];
    final duration = span(layer).inMicroseconds / 1000000.0;
    try {
      await _run([
        '-i',
        source(layer),
        '-ss',
        '${offset(layer).inMicroseconds / 1000000.0}',
        '-t',
        '$duration',
        '-map',
        '0:a:0',
        '-vn',
        '-sn',
        '-dn',
        if (cleanup.isNotEmpty) ...['-af', cleanup.join(',')],
        '-ac',
        '2',
        '-ar',
        '48000',
        '-f',
        'f32le',
        current,
      ]);
      final batch = <AudioEffect>[];
      Future<void> flush() async {
        if (batch.isEmpty) return;
        final output = '${scratch.path}/${++stage}.f32';
        await _run([
          '-f',
          'f32le',
          '-ar',
          '48000',
          '-ac',
          '2',
          '-i',
          current,
          '-filter_complex',
          audioEffectGraph(batch),
          '-map',
          '[afx]',
          '-t',
          '$duration',
          '-f',
          'f32le',
          output,
        ]);
        await File(current).delete();
        current = output;
        batch.clear();
      }

      for (final effect in p.effects.where((e) => e.enabled)) {
        if (effect.type == AudioEffectType.backwards) {
          await flush();
          final output = '${scratch.path}/${++stage}.f32';
          await compute(reverseStereoPcm, (
            current,
            output,
            effect.value('swap') >= 0.5,
          ));
          await File(current).delete();
          current = output;
        } else {
          batch.add(effect);
        }
      }
      await flush();
      // Preserve original source positions: both players and export already
      // seek using sourceOffset. Silence before the clip maintains that clock.
      await _run([
        '-f',
        'f32le',
        '-ar',
        '48000',
        '-ac',
        '2',
        '-i',
        current,
        '-af',
        'apad=whole_dur=$duration,atrim=duration=$duration,adelay=${(offset(layer).inMicroseconds * 48000 / 1000000).round()}S:all=1',
        '-c:a',
        'pcm_s16le',
        '-rf64',
        'auto',
        target.path,
      ]);
      return target.path;
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }
}
