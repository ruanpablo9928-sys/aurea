import 'dart:math' as math;

import 'audio_effect.dart';

/// One graph shared by audition and export. Reverse is processed on disk by
/// the service; FFmpeg's areverse buffers the complete clip in memory.
String audioEffectGraph(List<AudioEffect> effects) {
  final graph = <String>[
    '[0:a]aformat=sample_rates=48000:channel_layouts=stereo[a0]',
  ];
  var current = 'a0', serial = 0;
  String next() => 'a${++serial}';
  void chain(String filter) {
    final out = next();
    graph.add('[$current]$filter[$out]');
    current = out;
  }

  void wet(String filter, double dry, double wet) {
    final a = next(), b = next(), processed = next(), out = next();
    graph.add('[$current]asplit=2[$a][$b]');
    graph.add('[$b]$filter[$processed]');
    graph.add(
      '[$a][$processed]amix=inputs=2:duration=first:normalize=0:weights=\'$dry $wet\'[$out]',
    );
    current = out;
  }

  double gain(double db) => math.pow(10, db / 20).toDouble();
  for (final fx in effects.where((e) => e.enabled)) {
    final p = fx.value;
    switch (fx.type) {
      case AudioEffectType.backwards:
        throw StateError('Reverse must use the bounded disk pass');
      case AudioEffectType.bassTreble:
        chain('bass=g=${p('bass')}:f=200,treble=g=${p('treble')}:f=6000');
      case AudioEffectType.compressor:
        chain(
          'acompressor=threshold=${gain(p('threshold')).clamp(0.000976563, 1)}:ratio=${p('ratio').clamp(1, 20)}'
          ':knee=${gain(p('knee')).clamp(1, 8)}:attack=${p('attack')}:release=${p('release')},volume=${p('makeup')}dB,'
          'volume=${1 / gain(p('limit'))},alimiter=limit=1:level=0:latency=1,volume=${gain(p('limit'))}',
        );
      case AudioEffectType.delay:
        final times = <double>[], amounts = <double>[];
        var amount = p('amount') / 100;
        for (var i = 1; i <= 64 && amount > 0.0001; i++) {
          times.add(p('time') * i);
          amounts.add(amount);
          amount *= p('feedback') / 100;
        }
        if (times.isEmpty) {
          chain('volume=${p('dry') / 100}');
        } else {
          // aecho accepts at most 90 seconds per tap. Keep every requested
          // repeat by splitting longer tails into delayed, bounded groups.
          final groups = <int, List<int>>{};
          for (var i = 0; i < times.length; i++) {
            final group = ((times[i] - 1) / 90000).floor();
            groups.putIfAbsent(group, () => []).add(i);
          }
          var filter = 'aecho=0:1:${times.join('|')}:${amounts.join('|')}';
          if (groups.length > 1) {
            final inputs = [for (final _ in groups.keys) next()];
            final outputs = [for (final _ in groups.keys) next()];
            final parts = <String>[
              'asplit=${groups.length}${inputs.map((s) => '[$s]').join()}',
            ];
            var branch = 0;
            for (final entry in groups.entries) {
              final offset = entry.key * 90000;
              final delays = entry.value
                  .map((i) => times[i] - offset)
                  .join('|');
              final decays = entry.value.map((i) => amounts[i]).join('|');
              parts.add(
                '[${inputs[branch]}]aecho=0:1:$delays:$decays'
                '${offset == 0 ? '' : ',adelay=$offset:all=1'}[${outputs[branch]}]',
              );
              branch++;
            }
            parts.add(
              '${outputs.map((s) => '[$s]').join()}'
              'amix=inputs=${outputs.length}:normalize=0',
            );
            filter = parts.join(';');
          }
          wet(filter, p('dry') / 100, p('wet') / 100);
        }
      case AudioEffectType.distortion:
        final x = '(val(ch)*${gain(p('gain')) * (1 + p('drive') / 5)})';
        final expression = switch (p('type').round()) {
          1 => 'clip($x,-1,1)',
          2 => 'atan($x)*2/PI',
          3 => '$x/(1+abs($x))',
          4 => '(tanh($x+0.3)-tanh(0.3))',
          5 => 'sgn($x)*sqrt(min(1,abs($x)))',
          _ => 'tanh($x)',
        };
        wet(
          "aeval=exprs='$expression':c=same,acrusher=bits=${p('bits')}:samples=${p('downsample')}:mix=1",
          1 - p('mix') / 100,
          p('mix') / 100,
        );
        chain('volume=${p('volume') / 100}');
      case AudioEffectType.flangeChorus:
        // Phase is stereo LFO separation; each additional voice has its own
        // delayed branch. No full-file sample buffers are retained.
        final voices = p('voices').round(), split = next();
        final branches = [for (var i = 0; i <= voices; i++) '${split}v$i'];
        graph.add(
          '[$current]asplit=${voices + 1}${branches.map((b) => '[$b]').join()}',
        );
        final mix = <String>[branches.first];
        for (var i = 0; i < voices; i++) {
          final out = next(), separation = p('time') * (i + 1);
          final pan = p('stereo') < 0.5
              ? ''
              : i.isEven
              ? ',pan=stereo|c0=c0|c1=0*c1'
              : ',pan=stereo|c0=0*c0|c1=c1';
          graph.add(
            '[${branches[i + 1]}]adelay=${separation.round()}:all=1,'
            'flanger=delay=0:depth=${p('depth') / 10}:speed=${p('rate').clamp(0.1, 10)}:width=100:phase=${(p('phase') * (i + 1) / 3.6) % 100}'
            '$pan,volume=${(p('invert') >= 0.5 ? -1 : 1) / voices}[$out]',
          );
          mix.add(out);
        }
        final out = next();
        graph.add(
          '${mix.map((b) => '[$b]').join()}amix=inputs=${mix.length}:duration=first:normalize=0:'
          "weights='${p('dry') / 100} ${List.filled(voices, p('wet') / 100).join(' ')}'[$out]",
        );
        current = out;
      case AudioEffectType.gate:
        chain(
          'agate=threshold=${gain(p('threshold'))}:ratio=9000:range=0:attack=${p('attack')}:release=${p('release')}',
        );
      case AudioEffectType.highLowPass:
        wet(
          '${p('type') < 0.5 ? 'highpass' : 'lowpass'}=f=${p('frequency')}',
          p('dry') / 100,
          p('wet') / 100,
        );
      case AudioEffectType.modulator:
        final wave = p('wave') < 0.5
            ? 'sin(2*PI*${p('rate')}*t)'
            : '(2/PI*asin(sin(2*PI*${p('rate')}*t)))';
        chain(
          "vibrato=f=${p('rate')}:d=${p('depth') / 100},aeval=exprs='val(ch)*(1-${p('amplitude') / 200}+${p('amplitude') / 200}*$wave)':c=same",
        );
      case AudioEffectType.parametricEq:
        for (var i = 1; i <= 3; i++) {
          if (p('on$i') >= 0.5) {
            chain(
              'equalizer=f=${p('freq$i')}:t=o:w=${p('width$i')}:g=${p('gain$i')}',
            );
          }
        }
      case AudioEffectType.reverb:
        final taps = 4 + (p('diffusion') * 0.2).round();
        final times = [
          for (var i = 0; i < taps; i++)
            p('time') + i * p('decay') * 1000 / taps,
        ];
        final amounts = [
          for (var i = 0; i < taps; i++)
            math.exp(-6.9 * (times[i] - p('time')) / (p('decay') * 1000)) /
                math.sqrt(taps),
        ];
        wet(
          'aecho=0:1:${times.join('|')}:${amounts.join('|')},lowpass=f=${500 + p('brightness') * 175}',
          p('dry') / 100,
          p('wet') / 100,
        );
      case AudioEffectType.stereoMixer:
        final sign = p('invert') >= 0.5 ? -1 : 1, pan = p('pan') / 100;
        chain(
          'pan=stereo|c0=${sign * p('left') / 100 * (1 - math.max(0, pan))}*c0+${sign * p('right') / 100 * math.max(0, -pan)}*c1'
          '|c1=${sign * p('right') / 100 * (1 - math.max(0, -pan))}*c1+${sign * p('left') / 100 * math.max(0, pan)}*c0',
        );
      case AudioEffectType.tone:
        final waves = <String>[];
        for (var i = 1; i <= 5; i++) {
          final f = p('freq$i');
          if (f <= 0) continue;
          final phase = '(2*PI*$f*t)';
          waves.add(switch (p('wave').round()) {
            1 => 'sgn(sin($phase))',
            2 => '2/PI*asin(sin($phase))',
            3 => '2*(mod($f*t,1))-1',
            4 => '2*mod(abs(sin((n+1)*${12.9898 + i})*43758.5453),1)-1',
            _ => 'sin($phase)',
          });
        }
        chain(
          "aeval=exprs='(${waves.isEmpty ? '0' : waves.join('+')})*${p('level') / 100}':c=same",
        );
    }
  }
  graph.add('[$current]anull[afx]');
  return graph.join(';');
}
