import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'keyframe.dart';

/// Efeitos aplicaveis a uma camada (blocos combinaveis, ordem importa).
/// Novos tipos SEMPRE no fim: a serializacao guarda o indice.
enum EffectType {
  gaussianBlur,
  lightGlow,
  tint,
  glowVol,
  tremor,
  glitch,
  rgbSplit,
  echo,
  spatialEcho,
  radialAberration,
}

class EffectSpec {
  const EffectSpec({
    required this.name,
    required this.params,
    this.hasColor = false,
  });

  final String name;

  /// nome do parametro -> (rotulo, valor inicial, min, max)
  final Map<String, (String, double, double, double)> params;
  final bool hasColor;
}

const effectSpecs = <EffectType, EffectSpec>{
  EffectType.gaussianBlur: EffectSpec(
    name: 'Desfoque gaussiano',
    params: {
      'amount': ('Intensidade', 0.25, 0.0, 1.0),
    },
  ),
  EffectType.lightGlow: EffectSpec(
    name: 'Brilho de luz',
    params: {
      'diffusion': ('Difusao', 0.25, 0.0, 1.0),
      'threshold': ('Limite', 0.70, 0.0, 1.0),
      'intensity': ('Intensidade', 1.0, 0.0, 1.0),
    },
    hasColor: true,
  ),
  EffectType.tint: EffectSpec(
    name: 'Tonalizar',
    params: {
      'strength': ('Forca', 0.5, 0.0, 1.0),
    },
    hasColor: true,
  ),
  // Glow com pirâmide de 3 niveis, aberracao RGB e tonalizacao opcional
  // (aproximacao do Glow Volumetrico; conservacao plena exige linear).
  EffectType.glowVol: EffectSpec(
    name: 'Glow volumetrico',
    params: {
      'raio': ('Raio', 0.35, 0.02, 1.0),
      'intensidade': ('Intensidade', 0.8, 0.0, 2.0),
      'aberracao': ('Aberracao', 0.0, 0.0, 1.0),
      'tonalizar': ('Tonalizar', 0.0, 0.0, 1.0),
    },
    hasColor: true,
  ),
  // Tremor de camera: aleatorio e REPETIVEL, com fase integrada — animar
  // a frequencia acelera de verdade, sem salto.
  EffectType.tremor: EffectSpec(
    name: 'Tremor',
    params: {
      'amplitude': ('Amplitude', 60.0, 0.0, 300.0),
      'frequencia': ('Frequencia', 8.0, 0.0, 30.0),
      'estilo': ('Estilo', 0.0, 0.0, 2.0),
      'zoom': ('Zoom', 0.0, 0.0, 1.0),
      'inclinacao': ('Inclinacao', 0.0, 0.0, 30.0),
      'rgb': ('Franja RGB', 0.0, 0.0, 1.0),
      'semente': ('Semente', 0.0, 0.0, 100.0),
    },
  ),
  // Seis operadores sincronizados por um modulador mestre (quantidade +
  // velocidade); tiques deterministicos e seekaveis.
  EffectType.glitch: EffectSpec(
    name: 'Glitch modular',
    params: {
      'quantidade': ('Quantidade', 1.0, 0.0, 2.0),
      'velocidade': ('Velocidade', 1.0, 0.0, 10.0),
      'intervalo': ('Intervalo', 0.5, 0.05, 2.0),
      'deslize': ('Deslize', 0.6, 0.0, 1.0),
      'escala': ('Escala', 0.3, 0.0, 1.0),
      'cor': ('Cor', 0.4, 0.0, 1.0),
      'luz': ('Luz', 0.3, 0.0, 1.0),
      'desfoque': ('Desfoque', 0.2, 0.0, 1.0),
      'rgb': ('Separacao RGB', 0.5, 0.0, 1.0),
      'semente': ('Semente', 0.0, 0.0, 100.0),
    },
  ),
  EffectType.rgbSplit: EffectSpec(
    name: 'Separacao RGB',
    params: {
      'deslocamento': ('Deslocamento', 20.0, 0.0, 100.0),
      'angulo': ('Angulo', 0.0, -180.0, 180.0),
    },
  ),
  // Eco: re-renderiza a camada em tempos anteriores (deterministico —
  // trilhas de movimento de keyframes/transform). Matiz > 0 = RASTRO
  // COLORIDO: cada copia ganha uma rotacao de matiz propria.
  EffectType.echo: EffectSpec(
    name: 'Eco / rastro',
    params: {
      'ecos': ('Ecos', 3.0, 1.0, 8.0),
      'intervalo': ('Intervalo', 0.08, 0.02, 0.5),
      'decaimento': ('Decaimento', 0.55, 0.1, 0.95),
      'matiz': ('Matiz/copia', 0.0, 0.0, 120.0),
    },
  ),
  // Eco ESPACIAL (AUREA-2 §2 item 28): repeticao no espaco com
  // transformacao progressiva por copia.
  EffectType.spatialEcho: EffectSpec(
    name: 'Eco espacial',
    params: {
      'copias': ('Copias', 5.0, 1.0, 12.0),
      'dx': ('Desloc X', 40.0, -300.0, 300.0),
      'dy': ('Desloc Y', 0.0, -300.0, 300.0),
      'escala': ('Escala/copia', 96.0, 50.0, 150.0),
      'rotacao': ('Rot/copia', 0.0, -90.0, 90.0),
      'decaimento': ('Decaimento', 0.7, 0.1, 1.0),
      'matiz': ('Matiz/copia', 0.0, 0.0, 120.0),
    },
  ),
  // Aberracao cromatica RADIAL (item 14): cresce do centro para a
  // borda, como lente real — diferente do RGB Split.
  EffectType.radialAberration: EffectSpec(
    name: 'Aberracao radial',
    params: {
      'quantidade': ('Quantidade', 0.3, 0.0, 1.0),
    },
  ),
};

/// Instancia de efeito numa camada. TODO parametro numerico e animavel
/// (trilha de keyframes propria, avaliada no tempo local da camada).
class EffectInstance {
  EffectInstance({
    String? id,
    required this.type,
    Map<String, AnimatedDouble>? params,
    this.color = const Color(0xFFFF5566),
    this.enabled = true,
  })  : id = id ?? const Uuid().v4(),
        params = Map.unmodifiable(params ??
            {
              for (final e in effectSpecs[type]!.params.entries)
                e.key: AnimatedDouble(e.value.$2),
            });

  final String id;
  final EffectType type;
  final Map<String, AnimatedDouble> params;
  final Color color;
  final bool enabled;

  EffectSpec get spec => effectSpecs[type]!;

  AnimatedDouble track(String key) =>
      params[key] ?? AnimatedDouble(spec.params[key]?.$2 ?? 0);

  /// Valor do parametro no tempo local da camada.
  double paramAt(String key, Duration local) => track(key).valueAt(local);

  EffectInstance copyWith({
    Map<String, AnimatedDouble>? params,
    Color? color,
    bool? enabled,
  }) {
    return EffectInstance(
      id: id,
      type: type,
      params: params ?? this.params,
      color: color ?? this.color,
      enabled: enabled ?? this.enabled,
    );
  }

  /// Edita valor: keyframe automatico se o parametro ja anima.
  EffectInstance withParamEdited(String key, Duration local, double value) =>
      copyWith(params: {...params, key: track(key).edited(local, value)});

  /// Diamante do parametro: liga/desliga keyframe no tempo local.
  EffectInstance withParamKeyframeToggled(String key, Duration local) {
    final t = track(key);
    return copyWith(params: {
      ...params,
      key: t.hasKeyframeAt(local)
          ? t.withoutKeyframe(local)
          : t.withKeyframe(local, t.valueAt(local)),
    });
  }

  /// Tempos (locais) com keyframe em qualquer parametro.
  Iterable<Duration> get keyframeTimes sync* {
    for (final t in params.values) {
      for (final k in t.keyframes) {
        yield k.time;
      }
    }
  }

  bool get hasAnimation => params.values.any((t) => t.isAnimated);

  EffectInstance duplicated() =>
      EffectInstance(type: type, params: params, color: color, enabled: enabled);
}
