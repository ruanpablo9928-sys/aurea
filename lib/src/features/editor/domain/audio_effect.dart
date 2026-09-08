import 'dart:convert';

enum AudioEffectType {
  backwards,
  bassTreble,
  compressor,
  delay,
  distortion,
  flangeChorus,
  gate,
  highLowPass,
  modulator,
  parametricEq,
  reverb,
  stereoMixer,
  tone,
}

class AudioParam {
  const AudioParam(
    this.label,
    this.initial,
    this.min,
    this.max, {
    this.options = const [],
  });
  final String label;
  final double initial, min, max;
  final List<String> options;
}

class AudioEffectSpec {
  const AudioEffectSpec(this.name, this.params);
  final String name;
  final Map<String, AudioParam> params;
}

const audioEffectSpecs = <AudioEffectType, AudioEffectSpec>{
  AudioEffectType.backwards: AudioEffectSpec('Backwards · Reverso', {
    'swap': AudioParam('Trocar canais', 0, 0, 1, options: ['Nao', 'Sim']),
  }),
  AudioEffectType.bassTreble: AudioEffectSpec(
    'Bass & Treble · Graves e agudos',
    {
      'bass': AudioParam('Graves (dB)', 0, -30, 30),
      'treble': AudioParam('Agudos (dB)', 0, -30, 30),
    },
  ),
  AudioEffectType.compressor: AudioEffectSpec('Compressor', {
    'threshold': AudioParam('Limiar (dB)', -16, -60, 0),
    'ratio': AudioParam('Razao', 3, 1, 20),
    'knee': AudioParam('Joelho (dB)', 15, 0, 18),
    'attack': AudioParam('Ataque (ms)', 6, 0.01, 400),
    'release': AudioParam('Soltura (ms)', 440, 1, 4000),
    'makeup': AudioParam('Compensacao (dB)', 0, -30, 30),
    'limit': AudioParam('Limite de saida (dB)', 0, -30, 0),
  }),
  AudioEffectType.delay: AudioEffectSpec('Delay · Eco', {
    'time': AudioParam('Tempo (ms)', 250, 1, 2000),
    'amount': AudioParam('Primeiro eco (%)', 50, 0, 100),
    'feedback': AudioParam('Realimentacao (%)', 35, 0, 90),
    'dry': AudioParam('Original (%)', 100, 0, 100),
    'wet': AudioParam('Efeito (%)', 50, 0, 100),
  }),
  AudioEffectType.distortion: AudioEffectSpec('Distortion · Distorcao', {
    'type': AudioParam(
      'Tipo',
      0,
      0,
      5,
      options: [
        'Soft Clip',
        'Hard Clip',
        'Saturation 1',
        'Saturation 2',
        'Tube',
        'Fuzz',
      ],
    ),
    'drive': AudioParam('Drive (%)', 25, 0, 100),
    'gain': AudioParam('Ganho de entrada (dB)', 0, -30, 30),
    'mix': AudioParam('Mistura (%)', 100, 0, 100),
    'volume': AudioParam('Saida (%)', 50, 0, 100),
    'bits': AudioParam('Resolucao (bits)', 16, 2, 24),
    'downsample': AudioParam('Downsample', 1, 1, 32),
  }),
  AudioEffectType.flangeChorus: AudioEffectSpec('Flange & Chorus', {
    'time': AudioParam('Separacao (ms)', 3, 0.1, 60),
    'voices': AudioParam('Vozes', 2, 1, 8),
    'rate': AudioParam('Modulacao (Hz)', 0.3, 0.1, 10),
    'depth': AudioParam('Profundidade (%)', 50, 0, 100),
    'phase': AudioParam('Fase entre vozes', 90, 0, 360),
    'invert': AudioParam('Inverter fase', 0, 0, 1, options: ['Nao', 'Sim']),
    'stereo': AudioParam('Vozes estereo', 1, 0, 1, options: ['Nao', 'Sim']),
    'dry': AudioParam('Original (%)', 50, 0, 100),
    'wet': AudioParam('Efeito (%)', 50, 0, 100),
  }),
  AudioEffectType.gate: AudioEffectSpec('Gate', {
    'threshold': AudioParam('Limiar (dB)', -40, -60, 0),
    'attack': AudioParam('Ataque (ms)', 10, 0.01, 1000),
    'release': AudioParam('Soltura (ms)', 220, 5, 4000),
  }),
  AudioEffectType.highLowPass: AudioEffectSpec('High-Low Pass · Filtro', {
    'type': AudioParam(
      'Passagem',
      0,
      0,
      1,
      options: ['Passa-alta', 'Passa-baixa'],
    ),
    'frequency': AudioParam('Corte (Hz)', 1000, 20, 20000),
    'dry': AudioParam('Original (%)', 0, 0, 100),
    'wet': AudioParam('Efeito (%)', 100, 0, 100),
  }),
  AudioEffectType.modulator: AudioEffectSpec('Modulator · Modulador', {
    'wave': AudioParam(
      'Onda de amplitude',
      0,
      0,
      1,
      options: ['Seno', 'Triangulo'],
    ),
    'rate': AudioParam('Frequencia (Hz)', 5, 0.1, 20),
    'depth': AudioParam('Vibrato (%)', 20, 0, 100),
    'amplitude': AudioParam('Tremolo (%)', 50, 0, 100),
  }),
  AudioEffectType.parametricEq: AudioEffectSpec('Parametric EQ · Equalizador', {
    'on1': AudioParam('Banda 1', 1, 0, 1, options: ['Desligada', 'Ligada']),
    'freq1': AudioParam('Frequencia 1 (Hz)', 200, 20, 20000),
    'width1': AudioParam('Largura 1 (oitavas)', 1, 0.1, 4),
    'gain1': AudioParam('Ganho 1 (dB)', 0, -30, 30),
    'on2': AudioParam('Banda 2', 1, 0, 1, options: ['Desligada', 'Ligada']),
    'freq2': AudioParam('Frequencia 2 (Hz)', 1000, 20, 20000),
    'width2': AudioParam('Largura 2 (oitavas)', 1, 0.1, 4),
    'gain2': AudioParam('Ganho 2 (dB)', 0, -30, 30),
    'on3': AudioParam('Banda 3', 1, 0, 1, options: ['Desligada', 'Ligada']),
    'freq3': AudioParam('Frequencia 3 (Hz)', 6000, 20, 20000),
    'width3': AudioParam('Largura 3 (oitavas)', 1, 0.1, 4),
    'gain3': AudioParam('Ganho 3 (dB)', 0, -30, 30),
  }),
  AudioEffectType.reverb: AudioEffectSpec('Reverb · Reverberacao', {
    'time': AudioParam('Reflexao inicial (ms)', 40, 1, 300),
    'diffusion': AudioParam('Difusao (%)', 60, 0, 100),
    'decay': AudioParam('Decaimento (s)', 1.2, 0.1, 8),
    'brightness': AudioParam('Brilho (%)', 60, 0, 100),
    'dry': AudioParam('Original (%)', 100, 0, 100),
    'wet': AudioParam('Efeito (%)', 30, 0, 100),
  }),
  AudioEffectType.stereoMixer: AudioEffectSpec('Stereo Mixer · Mixer estereo', {
    'left': AudioParam('Nivel esquerdo (%)', 100, 0, 200),
    'right': AudioParam('Nivel direito (%)', 100, 0, 200),
    'pan': AudioParam('Panorama', 0, -100, 100),
    'invert': AudioParam('Inverter fase', 0, 0, 1, options: ['Nao', 'Sim']),
  }),
  AudioEffectType.tone: AudioEffectSpec('Tone · Gerador de tons', {
    'wave': AudioParam(
      'Onda',
      0,
      0,
      4,
      options: [
        'Seno',
        'Quadrada',
        'Triangulo',
        'Dente de serra',
        'Ruido branco',
      ],
    ),
    'freq1': AudioParam('Tom 1 (Hz)', 440, 0, 20000),
    'freq2': AudioParam('Tom 2 (Hz)', 0, 0, 20000),
    'freq3': AudioParam('Tom 3 (Hz)', 0, 0, 20000),
    'freq4': AudioParam('Tom 4 (Hz)', 0, 0, 20000),
    'freq5': AudioParam('Tom 5 (Hz)', 0, 0, 20000),
    'level': AudioParam('Nivel (%)', 10, 0, 100),
  }),
};

class AudioEffect {
  const AudioEffect(this.type, {this.values = const {}, this.enabled = true});
  final AudioEffectType type;
  final Map<String, double> values;
  final bool enabled;
  AudioEffectSpec get spec => audioEffectSpecs[type]!;
  double value(String key) {
    final p = spec.params[key]!;
    final v = values[key] ?? p.initial;
    return v.isFinite ? v.clamp(p.min, p.max) : p.initial;
  }

  AudioEffect edit(String key, double value) =>
      AudioEffect(type, values: {...values, key: value}, enabled: enabled);
  AudioEffect toggle() => AudioEffect(type, values: values, enabled: !enabled);
  Map<String, Object> toJson() => {
    'type': type.name,
    'enabled': enabled,
    'values': values,
  };
  static AudioEffect? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final type = AudioEffectType.values
        .where((e) => e.name == raw['type'])
        .firstOrNull;
    if (type == null) return null;
    final values = raw['values'];
    return AudioEffect(
      type,
      enabled: raw['enabled'] != false,
      values: {
        if (values is Map)
          for (final e in values.entries)
            if (e.key is String && e.value is num && (e.value as num).isFinite)
              e.key as String: (e.value as num).toDouble(),
      },
    );
  }

  String get cacheKey => jsonEncode(toJson());
}
