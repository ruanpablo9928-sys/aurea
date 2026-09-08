import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/domain/audio_effect.dart';
import 'package:aurea/src/features/editor/domain/audio_effect_graph.dart';
import 'package:aurea/src/features/editor/domain/streaming_waveform.dart';
import 'package:aurea/src/features/editor/domain/loudness.dart';
import 'package:aurea/src/features/editor/application/audio_render_service.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';

void main() {
  test(
    'streamed waveform and LUFS agree with reference across read boundaries',
    () async {
      final dir = await Directory.systemTemp.createTemp('aurea-audio-test');
      addTearDown(() => dir.delete(recursive: true));
      final samples = Float32List(16000 * 7),
          bytes = ByteData(samples.length * 2);
      for (var i = 0; i < samples.length; i++) {
        final value = (math.sin(i * 2 * math.pi * 440 / 16000) * 12000).round();
        bytes.setInt16(i * 2, value, Endian.little);
        samples[i] = value / 32768;
      }
      final path = '${dir.path}/source.pcm';
      await File(path).writeAsBytes(bytes.buffer.asUint8List());
      final scan = await scanMonoPcm(path);
      expect(scan.peaks.length, 700);
      expect(scan.peaks.every((p) => p > 0.36 && p < 0.37), isTrue);
      expect(scan.lufs, closeTo(integratedLufs(samples, 16000)!, 0.001));
    },
  );
  test('reverse preserves stereo frames and optionally swaps channels across blocks', () async {
    final dir = await Directory.systemTemp.createTemp('aurea-reverse-test');
    addTearDown(() => dir.delete(recursive: true));
    final bytes = ByteData(18000 * 8);
    for (var i = 0; i < 18000; i++) {
      bytes.setFloat32(i * 8, i.toDouble(), Endian.little);
      bytes.setFloat32(i * 8 + 4, -i.toDouble(), Endian.little);
    }
    final source = '${dir.path}/in.f32', output = '${dir.path}/out.f32';
    await File(source).writeAsBytes(bytes.buffer.asUint8List());
    await reverseStereoPcm((source, output, true));
    final result = ByteData.sublistView(await File(output).readAsBytes());
    for (final i in [0, 8191, 8192, 17999]) {
      expect(result.getFloat32(i * 8, Endian.little), -(17999 - i));
      expect(result.getFloat32(i * 8 + 4, Endian.little), 17999 - i);
    }
  });
  test('all audio effects round trip through project storage', () {
    final effects = [
      for (final type in AudioEffectType.values) AudioEffect(type),
    ];
    final layer = AudioLayer(
      name: 'Audio',
      startTime: Duration.zero,
      sourcePath: 'sound.wav',
      duration: const Duration(seconds: 3),
      audio: AudioSpec(processing: AudioProcessing(effects: effects)),
    );
    final project = VideoProject.empty('audio').copyWith(layers: [layer]);
    final json = projectToJson(project);
    final restored = projectFromJson(json).layers.single as AudioLayer;
    expect(restored.audio.processing.cacheKey, layer.audio.processing.cacheKey);
    expect(restored.audio.processing.effects.length, 13);
  });
  final ffmpeg = Platform.environment['AUREA_TEST_FFMPEG'];
  test('delay emits the wet impulse at the requested time', () async {
    final dir = await Directory.systemTemp.createTemp('aurea-echo');
    addTearDown(() => dir.delete(recursive: true));
    final fx = AudioEffect(
      AudioEffectType.delay,
      values: {'dry': 0, 'wet': 100, 'amount': 50, 'feedback': 0, 'time': 250},
    );
    final output = '${dir.path}/echo.f32';
    final result = await Process.run(ffmpeg!, [
      '-v',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      "aevalsrc=exprs='if(eq(n,0),1,0)':s=48000:d=1",
      '-filter_complex',
      audioEffectGraph([fx]),
      '-map',
      '[afx]',
      '-t',
      '1',
      '-f',
      'f32le',
      output,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final bytes = await File(output).readAsBytes();
    final samples = Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes ~/ 4,
    );
    expect(samples[0].abs(), lessThan(0.0001));
    expect(samples[12000 * 2].abs(), greaterThan(0.1));
  }, skip: ffmpeg == null);
  test(
    'all exposed minimum and maximum settings produce valid filter graphs',
    () async {
      final dir = await Directory.systemTemp.createTemp('aurea-audio-bounds');
      addTearDown(() => dir.delete(recursive: true));
      for (final type in AudioEffectType.values.where(
        (t) => t != AudioEffectType.backwards,
      )) {
        for (final maximum in [false, true]) {
          final fx = AudioEffect(
            type,
            values: {
              for (final p in audioEffectSpecs[type]!.params.entries)
                p.key: maximum ? p.value.max : p.value.min,
            },
          );
          final result = await Process.run(ffmpeg!, [
            '-v',
            'error',
            '-y',
            '-f',
            'lavfi',
            '-i',
            'sine=frequency=440:sample_rate=48000:duration=0.1',
            '-filter_complex',
            audioEffectGraph([fx]),
            '-map',
            '[afx]',
            '-t',
            '0.1',
            '-f',
            'f32le',
            '${dir.path}/output.f32',
          ]);
          expect(
            result.exitCode,
            0,
            reason: '$type maximum=$maximum: ${result.stderr}',
          );
        }
      }
    },
    skip: ffmpeg == null,
  );
  for (final type in AudioEffectType.values.where(
    (t) => t != AudioEffectType.backwards,
  )) {
    test(
      'native FFmpeg renders ${type.name} with finite stereo samples',
      () async {
        final dir = await Directory.systemTemp.createTemp('aurea-filter');
        addTearDown(() => dir.delete(recursive: true));
        final output = '${dir.path}/out.f32';
        final result = await Process.run(ffmpeg!, [
          '-v',
          'error',
          '-y',
          '-f',
          'lavfi',
          '-i',
          'sine=frequency=440:sample_rate=48000:duration=1',
          '-filter_complex',
          audioEffectGraph([AudioEffect(type)]),
          '-map',
          '[afx]',
          '-t',
          '1',
          '-f',
          'f32le',
          output,
        ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final bytes = await File(output).readAsBytes();
        expect(bytes.length, 48000 * 8);
        final samples = Float32List.view(
          bytes.buffer,
          bytes.offsetInBytes,
          bytes.lengthInBytes ~/ 4,
        );
        expect(
          samples.every((v) => v.isFinite),
          isTrue,
          reason:
              '$type: non-finite sample at ${samples.indexWhere((v) => !v.isFinite)}',
        );
        expect(samples.any((v) => v.abs() > 0.001), isTrue);
      },
      skip: ffmpeg == null
          ? 'Set AUREA_TEST_FFMPEG to run native DSP validation'
          : false,
    );
  }
}
