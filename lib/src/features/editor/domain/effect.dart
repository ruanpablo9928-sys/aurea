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
  // --- catalogo, lote 1 (spec AUREA-catalogo-de-efeitos) ---
  levels,
  vibrance,
  whiteBalance,
  colorWheels,
  unmult,
  vignette,
  directionalBlur,
  radialBlur,
  lightRays,
  mosaic,
  filmGrain,
  fractalNoise,
  digitalDamage,
  zoomWarp,
  posterize,
  curves,
  // --- lote 2 ---
  timeRemap,
  pixelSort,
  blobTracker,
  turbulentDisplace,
  unsharpMask,
  motionTile,
  bend,
  ccScatterize,
  ccSplit,
  vhs,
  filmDamage,
  glitchify,
  // --- lote 3 (AUREA-six-effects-english) ---
  forceMotionBlur,
}

/// O tipo a partir do IDENTIFICADOR estavel.
///
/// E o caminho de leitura do arquivo. Guardar o efeito pelo INDICE do
/// enum era uma bomba-relogio: bastava alguem inserir um efeito no meio
/// da lista para todo projeto salvo virar outro efeito. O id nunca muda.
EffectType? effectTypeFromId(String id) {
  for (final e in effectSpecs.entries) {
    if (e.value.id == id) return e.key;
  }
  return _aliasesDeId[id];
}

/// NOMES ANTIGOS que ainda aparecem em arquivo. Renomear nao pode
/// quebrar o que ja existe.
const _aliasesDeId = <String, EffectType>{
  'cc_split': EffectType.ccSplit,
  'cc_scatterize': EffectType.ccScatterize,
  'cc_semear': EffectType.ccScatterize,
  'glow_vol': EffectType.glowVol,
  'volumetric_glow': EffectType.glowVol,
  'tremor': EffectType.tremor,
  'light_glow': EffectType.lightGlow,
  'radial_aberration': EffectType.radialAberration,
  'spatial_echo': EffectType.spatialEcho,
  'pixel_sort': EffectType.pixelSort,
};

/// PARAMETROS RENOMEADOS: chave antiga -> chave nova.
///
/// Renomear nao pode quebrar preset nem projeto salvo. Quem le o arquivo
/// passa por aqui antes de montar o efeito, e a chave antiga vira a
/// nova sem ninguem perceber.
const effectParamAliases = <EffectType, Map<String, String>>{
  EffectType.tremor: {
    'frequencia': 'frequency',
    'estilo': 'style',
    'inclinacao': 'tilt_random_amplitude',
    'semente': 'seed',
    'fase': 'phase',
    'rgb': 'rgb_randomness',
  },
  EffectType.glowVol: {
    'raio': 'radius',
    'intensidade': 'exposure',
    'aberracao': 'red_radius_multiplier',
    'tonalizar': 'tint_amount',
  },
  EffectType.motionTile: {
    'largura': 'tile_width',
    'altura': 'tile_height',
    'saidaLargura': 'output_width',
    'saidaAltura': 'output_height',
    'deslocX': 'phase',
    'espelhar': 'mirror_edges',
  },
};

/// A chave de hoje para uma chave que pode ser de ontem.
String resolveParamKey(EffectType type, String key) =>
    effectParamAliases[type]?[key] ?? key;

/// O identificador de um tipo.
String effectIdOf(EffectType t) => effectSpecs[t]!.id;

/// TIPO do parametro (PR-C1). Sem isto, todo efeito que precisa de uma
/// cor ou de um ponto fica morto na tela: a UI so sabia desenhar numero.
enum ParamKind {
  number,
  color,

  /// Ponto 2D arrastavel no palco (guardado em 0..1 do tamanho).
  point,

  /// Lista de opcoes em chips.
  choice,

  /// Numero inteiro que semeia ruido (nunca interpola).
  seed,

  /// Alterna liga/desliga.
  toggle,
}

class EffectParam {
  const EffectParam(
    this.label,
    this.initial,
    this.min,
    this.max, {
    this.kind = ParamKind.number,
    this.options = const [],
    this.relative = false,
  });

  final String label;
  final double initial;
  final double min;
  final double max;
  final ParamKind kind;

  /// Rotulos das opcoes quando [kind] e choice.
  final List<String> options;

  /// RELATIVO AO TAMANHO (presets §2.3): distancia, raio e ponto sao
  /// normalizados pelo tamanho da camada ao salvar um preset e
  /// desnormalizados ao aplicar — senao um preset feito em 1080x1920
  /// sai errado numa camada 1920x1080. Cor, angulo e switch NAO.
  final bool relative;
}

class EffectSpec {
  const EffectSpec({
    required this.id,
    required this.name,
    required this.params,
    this.hasColor = false,
    this.category = 'Estilizar',
    this.synonyms = const [],
    this.cost = 1,
    this.procedural = false,
  });

  /// IDENTIFICADOR ESTAVEL, em snake_case e em ingles.
  ///
  /// E o que vai no arquivo. O nome muda de idioma, a categoria muda de
  /// arrumacao, a posicao no enum muda quando entra efeito novo — o id
  /// nao muda nunca, e e por isso que projeto e preset salvos continuam
  /// abrindo.
  final String id;

  /// Nome canonico, em INGLES. Onde o efeito existe no After Effects,
  /// segue o vocabulario de la.
  final String name;

  final Map<String, EffectParam> params;

  /// Cor principal do efeito (alem dos parametros de cor).
  final bool hasColor;

  /// Categoria do catalogo.
  final String category;

  /// BUSCA COM SINONIMOS (§5): quem digita "rgb split" acha Separacao
  /// RGB; "bloom" acha Glow; "green screen" acharia Chroma Key.
  final List<String> synonyms;

  /// Custo estimado por frame (1 = barato, 3 = caro).
  final int cost;

  /// Movimento gerado por procedimento — pode ser ASSADO em keyframes.
  final bool procedural;
}

const effectSpecs = <EffectType, EffectSpec>{
  EffectType.gaussianBlur: EffectSpec(
    id: 'gaussian_blur',
    name: 'Gaussian Blur',
    category: 'Blur',
    synonyms: ['desfoque', 'gaussiano', 'blur', 'gaussian', 'suavizar'],
    params: {
      'amount': EffectParam('Intensidade', 0.25, 0.0, 1.0),
    },
  ),
  EffectType.lightGlow: EffectSpec(
    id: 'glow',
    name: 'Glow',
    category: 'Light',
    synonyms: ['brilho', 'luz', 'glow', 'bloom', 'brilho'],
    params: {
      'diffusion': EffectParam('Difusao', 0.25, 0.0, 1.0),
      'threshold': EffectParam('Limite', 0.70, 0.0, 1.0),
      'intensity': EffectParam('Intensidade', 1.0, 0.0, 1.0),
    },
    hasColor: true,
  ),
  EffectType.tint: EffectSpec(
    id: 'tint',
    name: 'Tint',
    category: 'Color',
    synonyms: ['tonalizar', 'tint', 'colorir'],
    params: {
      'strength': EffectParam('Forca', 0.5, 0.0, 1.0),
    },
    hasColor: true,
  ),
  // Glow com pirâmide de 3 niveis, aberracao RGB e tonalizacao opcional
  // (aproximacao do Glow Volumetrico; conservacao plena exige linear).
  EffectType.glowVol: EffectSpec(
    id: 'deep_glow',
    name: 'Deep Glow',
    category: 'Light',
    synonyms: [
      'glow', 'volumetrico', 'bloom', 'volumetric', 'brilho', 'deep glow',
      'luz',
    ],
    cost: 3,
    params: {
      // --- Core ---
      // Raio em FRACAO do menor lado da composicao (0,04 ~ 80 px em
      // 1080p). Em pixel absoluto, o mesmo numero daria glows de
      // tamanhos diferentes so por trocar a resolucao.
      'radius': EffectParam('Radius', 0.04, 0.0, 1.0, relative: true),
      'exposure': EffectParam('Exposure', 1.0, -5.0, 5.0),
      'threshold': EffectParam('Threshold', 1.0, 0.0, 4.0),
      'threshold_mode': EffectParam('Threshold Mode', 0.0, 0.0, 1.0,
          kind: ParamKind.choice,
          options: ['Luminance', 'Chrominance']),
      'threshold_softness':
          EffectParam('Threshold Softness', 0.2, 0.0, 1.0),
      'quality': EffectParam('Quality', 1.0, 0.0, 2.0,
          kind: ParamKind.choice, options: ['Draft', 'Normal', 'High']),
      'downsample': EffectParam('Downsample', 2.0, 1.0, 8.0),
      'glow_mode': EffectParam('Glow Mode', 0.0, 0.0, 1.0,
          kind: ParamKind.choice, options: ['Exponential', 'Iris']),

      // --- Color ---
      'red_radius_multiplier':
          EffectParam('Red Radius Multiplier', 1.0, 0.5, 2.0),
      'green_radius_multiplier':
          EffectParam('Green Radius Multiplier', 1.0, 0.5, 2.0),
      'blue_radius_multiplier':
          EffectParam('Blue Radius Multiplier', 1.0, 0.5, 2.0),
      'tint_mode': EffectParam('Tint Mode', 0.0, 0.0, 3.0,
          kind: ParamKind.choice,
          options: ['None', 'Solid', 'Gradient', 'Image Based']),
      'tint_amount': EffectParam('Tint Amount', 1.0, 0.0, 1.0),
      'glow_saturation': EffectParam('Glow Saturation', 100.0, 0.0, 200.0),

      // --- Look ---
      'aspect_ratio': EffectParam('Aspect Ratio', 1.0, 0.1, 10.0),
      'enable_angle': EffectParam('Enable Angle', 0.0, 0.0, 1.0,
          kind: ParamKind.toggle),
      'angle': EffectParam('Angle', 0.0, -360.0, 360.0),
      'tonemapping': EffectParam('Tonemapping', 0.0, 0.0, 3.0,
          kind: ParamKind.choice,
          options: ['ACES Filmic', 'Reinhard', 'Reinhard 2', 'Clamp']),
      'lens_dirt_amount': EffectParam('Lens Dirt Amount', 50.0, 0.0, 200.0),
      'noise_reduction': EffectParam('Noise Reduction', 0.0, 0.0, 100.0),

      // --- Composite ---
      'blend_mode': EffectParam('Blend Mode', 0.0, 0.0, 2.0,
          kind: ParamKind.choice, options: ['Add', 'Screen', 'Normal']),
      'glow_only': EffectParam('Glow Only', 0.0, 0.0, 1.0,
          kind: ParamKind.toggle),
    },
    hasColor: true,
  ),
  // Tremor de camera: aleatorio e REPETIVEL, com fase integrada — animar
  // a frequencia acelera de verdade, sem salto.
  EffectType.tremor: EffectSpec(
    id: 'shake',
    name: 'Shake',
    category: 'Distort',
    synonyms: [
      'tremor', 'shake', 'camera shake', 'tremer', 'camera na mao',
      'handheld',
    ],
    procedural: true,
    cost: 2,
    params: {
      // --- General ---
      'style': EffectParam('Style', 0.0, 0.0, 2.0,
          kind: ParamKind.choice,
          options: ['Normal', 'Nervous', 'Jumpy']),
      'amplitude':
          EffectParam('Amplitude', 1.0, 0.0, 20.0, relative: true),
      'frequency': EffectParam('Frequency', 8.0, 0.0, 60.0),
      'phase': EffectParam('Phase', 0.0, -360.0, 360.0),
      'stillness': EffectParam('Stillness', 0.7, 0.0, 1.0),
      'twitch_frequency': EffectParam('Twitch Frequency', 2.0, 0.0, 20.0),
      'drift': EffectParam('Drift', 0.3, 0.0, 1.0),
      'center_bias': EffectParam('Center Bias', 0.0, 0.0, 1.0),
      'z_distance': EffectParam('Z Distance', 1.0, 0.001, 10.0),
      'motion_blur': EffectParam('Motion Blur', 0.0, 0.0, 1.0,
          kind: ParamKind.toggle),
      'blur_length': EffectParam('Blur Length', 1.0, 0.0, 10.0),
      'seed': EffectParam('Seed', 0.0, 0.0, 100.0, kind: ParamKind.seed),
      'edges': EffectParam('X / Y Edges', 0.0, 0.0, 2.0,
          kind: ParamKind.choice,
          options: ['Reflect', 'Tile', 'None']),

      // --- Por eixo: a componente ALEATORIA e a de ONDA sao separadas.
      // E o que faz parecer camera na mao em vez de senoide.
      'x_random_amplitude':
          EffectParam('X Random Amplitude', 0.2, 0.0, 5.0),
      'x_random_frequency':
          EffectParam('X Random Frequency', 1.0, 0.0, 10.0),
      'x_wave_amplitude': EffectParam('X Wave Amplitude', 0.0, 0.0, 5.0),
      'x_wave_frequency': EffectParam('X Wave Frequency', 0.5, 0.0, 20.0),
      'x_phase': EffectParam('X Phase', 0.0, -360.0, 360.0),

      'y_random_amplitude':
          EffectParam('Y Random Amplitude', 0.1, 0.0, 5.0),
      'y_random_frequency':
          EffectParam('Y Random Frequency', 1.0, 0.0, 10.0),
      'y_wave_amplitude': EffectParam('Y Wave Amplitude', 0.0, 0.0, 5.0),
      'y_wave_frequency': EffectParam('Y Wave Frequency', 0.5, 0.0, 20.0),
      'y_phase': EffectParam('Y Phase', 0.0, -360.0, 360.0),

      'z_random_amplitude':
          EffectParam('Z Random Amplitude', 0.0, 0.0, 5.0),
      'z_random_frequency':
          EffectParam('Z Random Frequency', 1.0, 0.0, 10.0),
      'z_wave_amplitude': EffectParam('Z Wave Amplitude', 0.0, 0.0, 5.0),
      'z_wave_frequency': EffectParam('Z Wave Frequency', 0.5, 0.0, 20.0),
      'z_phase': EffectParam('Z Phase', 0.0, -360.0, 360.0),

      'tilt_random_amplitude':
          EffectParam('Tilt Random Amplitude', 0.0, 0.0, 5.0),
      'tilt_random_frequency':
          EffectParam('Tilt Random Frequency', 1.0, 0.0, 10.0),
      'tilt_wave_amplitude':
          EffectParam('Tilt Wave Amplitude', 0.0, 0.0, 5.0),
      'tilt_wave_frequency':
          EffectParam('Tilt Wave Frequency', 0.5, 0.0, 20.0),
      'tilt_phase': EffectParam('Tilt Phase', 0.0, -360.0, 360.0),

      // --- RGB: fase por canal desloca o canal NO TEMPO. O vermelho se
      // move antes, os outros seguem — franja organica, muito melhor que
      // um deslocamento estatico.
      'red_amplitude': EffectParam('Red Amplitude', 1.0, 0.0, 5.0),
      'green_amplitude': EffectParam('Green Amplitude', 1.0, 0.0, 5.0),
      'blue_amplitude': EffectParam('Blue Amplitude', 1.0, 0.0, 5.0),
      'red_phase': EffectParam('Red Phase', 0.0, -360.0, 360.0),
      'green_phase': EffectParam('Green Phase', 0.0, -360.0, 360.0),
      'blue_phase': EffectParam('Blue Phase', 0.0, -360.0, 360.0),
      'rgb_randomness': EffectParam('RGB Randomness', 0.0, 0.0, 1.0),
      'rgb_frequency': EffectParam('RGB Frequency', 2.0, 0.0, 30.0),
    },
  ),
  // Seis operadores sincronizados por um modulador mestre (quantidade +
  // velocidade); tiques deterministicos e seekaveis.
  EffectType.glitch: EffectSpec(
    id: 'glitch',
    name: 'Glitch',
    category: 'Glitch',
    synonyms: ['glitch', 'modular', 'glitch', 'datamosh', 'erro'],
    cost: 2,
    procedural: true,
    params: {
      'quantidade': EffectParam('Quantidade', 1.0, 0.0, 2.0),
      'velocidade': EffectParam('Velocidade', 1.0, 0.0, 10.0),
      'intervalo': EffectParam('Intervalo', 0.5, 0.05, 2.0),
      'deslize': EffectParam('Deslize', 0.6, 0.0, 1.0),
      'escala': EffectParam('Escala', 0.3, 0.0, 1.0),
      'cor': EffectParam('Cor', 0.4, 0.0, 1.0),
      'luz': EffectParam('Luz', 0.3, 0.0, 1.0),
      'desfoque': EffectParam('Desfoque', 0.2, 0.0, 1.0),
      'rgb': EffectParam('Separacao RGB', 0.5, 0.0, 1.0),
      'semente': EffectParam('Semente', 0.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
  ),
  EffectType.rgbSplit: EffectSpec(
    id: 'rgb_split',
    name: 'RGB Split',
    category: 'Lens',
    synonyms: ['separacao', 'rgb', 'rgb split', 'chromatic', 'canal'],
    params: {
      'deslocamento':
          EffectParam('Deslocamento', 20.0, 0.0, 100.0, relative: true),
      'angulo': EffectParam('Angulo', 0.0, -180.0, 180.0),
    },
  ),
  // Eco: re-renderiza a camada em tempos anteriores (deterministico —
  // trilhas de movimento de keyframes/transform). Matiz > 0 = RASTRO
  // COLORIDO: cada copia ganha uma rotacao de matiz propria.
  EffectType.echo: EffectSpec(
    id: 'echo',
    name: 'Echo',
    category: 'Blur',
    synonyms: ['eco', 'rastro', 'echo', 'trail', 'rastro', 'motion trail'],
    cost: 3,
    params: {
      'ecos': EffectParam('Ecos', 3.0, 1.0, 8.0),
      'intervalo': EffectParam('Intervalo', 0.08, 0.02, 0.5),
      'decaimento': EffectParam('Decaimento', 0.55, 0.1, 0.95),
      'matiz': EffectParam('Matiz/copia', 0.0, 0.0, 120.0),
    },
  ),
  // Eco ESPACIAL (AUREA-2 §2 item 28): repeticao no espaco com
  // transformacao progressiva por copia.
  EffectType.spatialEcho: EffectSpec(
    id: 'space_echo',
    name: 'Space Echo',
    category: 'Stylize',
    synonyms: ['eco', 'espacial', 'echo', 'repeat', 'repeticao'],
    cost: 2,
    params: {
      'copias': EffectParam('Copias', 5.0, 1.0, 12.0),
      'dx': EffectParam('Desloc X', 40.0, -300.0, 300.0, relative: true),
      'dy': EffectParam('Desloc Y', 0.0, -300.0, 300.0, relative: true),
      'escala': EffectParam('Escala/copia', 96.0, 50.0, 150.0),
      'rotacao': EffectParam('Rot/copia', 0.0, -90.0, 90.0),
      'decaimento': EffectParam('Decaimento', 0.7, 0.1, 1.0),
      'matiz': EffectParam('Matiz/copia', 0.0, 0.0, 120.0),
    },
  ),
  // Aberracao cromatica RADIAL (item 14): cresce do centro para a
  // borda, como lente real — diferente do RGB Split.
  EffectType.radialAberration: EffectSpec(
    id: 'chromatic_aberration',
    name: 'Chromatic Aberration',
    category: 'Lens',
    synonyms: ['aberracao', 'cromatica', 'chromatic aberration', 'franja', 'lente'],
    cost: 2,
    params: {
      'quantidade': EffectParam('Quantidade', 0.3, 0.0, 1.0),
    },
  ),

  // ------------------------- catalogo, lote 1 -------------------------

  EffectType.levels: EffectSpec(
    id: 'levels',
    name: 'Levels',
    category: 'Color',
    synonyms: ['niveis', 'levels', 'contraste', 'gama', 'brilho'],
    params: {
      'entradaMin': EffectParam('Entrada min', 0.0, 0.0, 1.0),
      'entradaMax': EffectParam('Entrada max', 1.0, 0.0, 1.0),
      'gama': EffectParam('Gama', 1.0, 0.2, 3.0),
      'saidaMin': EffectParam('Saida min', 0.0, 0.0, 1.0),
      'saidaMax': EffectParam('Saida max', 1.0, 0.0, 1.0),
    },
  ),
  EffectType.curves: EffectSpec(
    id: 'curves',
    name: 'Curves',
    category: 'Color',
    synonyms: ['curvas', 'curves', 'curva', 'contraste'],
    params: {
      'contraste': EffectParam('Contraste S', 0.0, -1.0, 1.0),
      'brilho': EffectParam('Brilho', 0.0, -1.0, 1.0),
      'sombras': EffectParam('Levantar sombras', 0.0, 0.0, 1.0),
      'altas': EffectParam('Baixar altas', 0.0, 0.0, 1.0),
    },
  ),
  EffectType.vibrance: EffectSpec(
    id: 'vibrance',
    name: 'Vibrance',
    category: 'Color',
    synonyms: ['vibracao', 'vibrance', 'saturacao', 'vivid'],
    params: {
      'vibracao': EffectParam('Vibracao', 0.0, -1.0, 1.0),
      'saturacao': EffectParam('Saturacao', 0.0, -1.0, 1.0),
      // O que separa cor bonita de cor berrante: satura o resto sem
      // deixar o rosto laranja.
      'protecaoPele': EffectParam('Protecao de pele', 0.6, 0.0, 1.0),
    },
  ),
  EffectType.whiteBalance: EffectSpec(
    id: 'white_balance',
    name: 'White Balance',
    category: 'Color',
    synonyms: ['balanco', 'branco', 'white balance', 'temperatura', 'matiz', 'wb'],
    params: {
      'temperatura': EffectParam('Temperatura', 0.0, -1.0, 1.0),
      'matiz': EffectParam('Matiz', 0.0, -1.0, 1.0),
    },
  ),
  EffectType.colorWheels: EffectSpec(
    id: 'color_wheels',
    name: 'Color Wheels',
    category: 'Color',
    synonyms: ['rodas', 'cor', 'color wheels', 'lift gamma gain', 'gradacao'],
    params: {
      'sombrasR': EffectParam('Sombras R', 0.0, -0.5, 0.5),
      'sombrasG': EffectParam('Sombras G', 0.0, -0.5, 0.5),
      'sombrasB': EffectParam('Sombras B', 0.0, -0.5, 0.5),
      'altasR': EffectParam('Altas R', 0.0, -0.5, 0.5),
      'altasG': EffectParam('Altas G', 0.0, -0.5, 0.5),
      'altasB': EffectParam('Altas B', 0.0, -0.5, 0.5),
    },
  ),
  // O efeito mais subestimado da lista: fogo, fumaca, faisca e vazamento
  // de luz vem todos em video com fundo preto.
  EffectType.unmult: EffectSpec(
    id: 'unmult',
    name: 'Unmult',
    category: 'Light',
    synonyms: ['unmult', 'tira', 'preto', 'unmult', 'screen', 'tirar fundo preto', 'overlay'],
    params: {
      'limiar': EffectParam('Limiar', 0.0, 0.0, 1.0),
      'suavidade': EffectParam('Suavidade', 0.5, 0.0, 1.0),
    },
  ),
  EffectType.vignette: EffectSpec(
    id: 'vignette',
    name: 'Vignette',
    category: 'Lens',
    synonyms: ['vinheta', 'vignette', 'borda escura'],
    params: {
      'quantidade': EffectParam('Quantidade', 0.5, 0.0, 1.0),
      'raio': EffectParam('Raio', 0.7, 0.1, 1.5, relative: true),
      'suavidade': EffectParam('Suavidade', 0.5, 0.0, 1.0),
    },
    hasColor: true,
  ),
  EffectType.directionalBlur: EffectSpec(
    id: 'directional_blur',
    name: 'Directional Blur',
    category: 'Blur',
    synonyms: ['desfoque', 'direcional', 'directional blur', 'motion blur', 'movimento'],
    cost: 2,
    params: {
      'comprimento':
          EffectParam('Comprimento', 20.0, 0.0, 120.0, relative: true),
      'angulo': EffectParam('Angulo', 0.0, -180.0, 180.0),
    },
  ),
  EffectType.radialBlur: EffectSpec(
    id: 'radial_blur',
    name: 'Radial Blur',
    category: 'Blur',
    synonyms: ['desfoque', 'radial', 'radial blur', 'zoom blur', 'giro'],
    cost: 3,
    params: {
      'quantidade': EffectParam('Quantidade', 0.3, 0.0, 1.0),
      'modo': EffectParam('Modo', 0.0, 0.0, 1.0,
          kind: ParamKind.choice, options: ['Zoom', 'Giro']),
      'amostras': EffectParam('Amostras', 6.0, 2.0, 16.0),
    },
  ),
  EffectType.lightRays: EffectSpec(
    id: 'light_rays',
    name: 'Light Rays',
    category: 'Light',
    synonyms: ['raios', 'volumetricos', 'god rays', 'light rays', 'raios', 'deus'],
    cost: 3,
    params: {
      'comprimento': EffectParam('Comprimento', 0.4, 0.0, 1.0),
      'intensidade': EffectParam('Intensidade', 0.7, 0.0, 2.0),
      'amostras': EffectParam('Amostras', 8.0, 2.0, 20.0),
      'centroX': EffectParam('Origem X', 0.5, 0.0, 1.0,
          kind: ParamKind.point, relative: true),
      'centroY': EffectParam('Origem Y', 0.3, 0.0, 1.0,
          kind: ParamKind.point, relative: true),
    },
    hasColor: true,
  ),
  EffectType.mosaic: EffectSpec(
    id: 'mosaic',
    name: 'Mosaic',
    category: 'Stylize',
    synonyms: ['mosaico', 'mosaic', 'pixelate', 'pixel', 'censura'],
    params: {
      'blocos': EffectParam('Blocos', 24.0, 3.0, 160.0),
    },
  ),
  EffectType.filmGrain: EffectSpec(
    id: 'film_grain',
    name: 'Film Grain',
    category: 'Stylize',
    synonyms: ['grao', 'filme', 'grain', 'grao', 'ruido', 'filme'],
    procedural: true,
    params: {
      'intensidade': EffectParam('Intensidade', 0.25, 0.0, 1.0),
      'tamanho': EffectParam('Tamanho', 1.5, 0.5, 6.0),
      'semente': EffectParam('Semente', 1.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
  ),
  EffectType.fractalNoise: EffectSpec(
    id: 'fractal_noise',
    name: 'Fractal Noise',
    category: 'Generate',
    synonyms: ['ruido', 'fractal', 'fractal noise', 'perlin', 'nuvem', 'fumaca'],
    cost: 2,
    procedural: true,
    params: {
      'escala': EffectParam('Escala', 0.25, 0.02, 1.0),
      'complexidade': EffectParam('Complexidade', 3.0, 1.0, 6.0),
      'contraste': EffectParam('Contraste', 1.0, 0.1, 3.0),
      'evolucao': EffectParam('Evolucao', 0.0, 0.0, 20.0),
      'opacidade': EffectParam('Opacidade', 0.6, 0.0, 1.0),
      'semente': EffectParam('Semente', 3.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
    hasColor: true,
  ),
  EffectType.digitalDamage: EffectSpec(
    id: 'digital_damage',
    name: 'Digital Damage',
    category: 'Glitch',
    synonyms: ['dano', 'digital', 'digital damage', 'blocos', 'corrupcao', 'datamosh'],
    cost: 2,
    procedural: true,
    params: {
      'blocos': EffectParam('Blocos', 6.0, 1.0, 24.0),
      'altura': EffectParam('Altura', 0.08, 0.01, 0.4),
      'deslocamento':
          EffectParam('Deslocamento', 0.15, 0.0, 1.0, relative: true),
      'cor': EffectParam('Corrupcao de cor', 0.4, 0.0, 1.0),
      'intervalo': EffectParam('Intervalo', 0.4, 0.05, 2.0),
      'semente': EffectParam('Semente', 5.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
  ),
  EffectType.zoomWarp: EffectSpec(
    id: 'zoom_warp',
    name: 'Zoom Warp',
    category: 'Distort',
    synonyms: ['zoom', 'warp', 'zoom warp', 'punch', 'impacto', 'dolly'],
    cost: 2,
    params: {
      'quantidade': EffectParam('Quantidade', 0.2, -1.0, 1.0),
      'rastro': EffectParam('Rastro', 0.3, 0.0, 1.0),
      'amostras': EffectParam('Amostras', 5.0, 2.0, 12.0),
    },
  ),
  EffectType.posterize: EffectSpec(
    id: 'posterize',
    name: 'Posterize',
    category: 'Stylize',
    synonyms: ['posterizar', 'posterize', 'niveis', 'cartoon'],
    params: {
      'niveis': EffectParam('Niveis', 6.0, 2.0, 32.0),
    },
  ),

  // ------------------------------------------------------- lote 2

  /// REMAPEAMENTO DE TEMPO, igual ao do After Effects: em vez de mexer
  /// na velocidade, voce anima QUAL INSTANTE da camada aparece agora.
  /// Congelar, voltar, acelerar no meio — tudo vira keyframe de tempo.
  EffectType.timeRemap: EffectSpec(
    id: 'time_remap',
    name: 'Time Remap',
    category: 'Time',
    synonyms: ['remapear', 'tempo', 'time remap', 'tempo', 'congelar', 'freeze', 'reverso',
      'velocidade', 'speed ramp'],
    cost: 1,
    params: {
      'tempo': EffectParam('Tempo (s)', 0.0, 0.0, 60.0),
    },
  ),

  EffectType.pixelSort: EffectSpec(
    id: 'pixel_sorter',
    name: 'Pixel Sorter',
    category: 'Stylize',
    synonyms: ['ordenar', 'pixels', 'pixel sort', 'sorting', 'databend', 'arrastar'],
    cost: 3,
    params: {
      'limiar': EffectParam('Limiar', 0.55, 0.0, 1.0),
      'comprimento':
          EffectParam('Comprimento', 60.0, 0.0, 400.0, relative: true),
      'direcao': EffectParam('Direcao', 0.0, 0.0, 3.0,
          kind: ParamKind.choice,
          options: ['Baixo', 'Cima', 'Direita', 'Esquerda']),
      'densidade': EffectParam('Densidade', 0.5, 0.05, 1.0),
      'semente': EffectParam('Semente', 1.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  /// RASTREADOR DE BLOBS: os marcadores de rastreio como elemento
  /// grafico. Nao e visao computacional — sao alvos que voce posiciona e
  /// anima, que e para o que o efeito e usado em motion.
  EffectType.blobTracker: EffectSpec(
    id: 'blob_tracker',
    name: 'Blob Tracker',
    category: 'Stylize',
    synonyms: ['rastreador', 'blobs', 'blob tracker', 'tracking', 'alvo', 'hud', 'mira'],
    hasColor: true,
    params: {
      'quantidade': EffectParam('Quantidade', 4.0, 1.0, 16.0),
      'tamanho': EffectParam('Tamanho', 90.0, 10.0, 400.0, relative: true),
      'espalhar': EffectParam('Espalhar', 0.6, 0.0, 1.0),
      'velocidade': EffectParam('Velocidade', 0.4, 0.0, 3.0),
      'traco': EffectParam('Traco', 2.0, 0.5, 8.0),
      'cantos': EffectParam('So os cantos', 1.0, 0.0, 1.0,
          kind: ParamKind.toggle),
      'semente': EffectParam('Semente', 7.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  EffectType.turbulentDisplace: EffectSpec(
    id: 'turbulent_displace',
    name: 'Turbulent Displace',
    category: 'Distort',
    synonyms: ['deslocar', 'turbulento', 'turbulent displace', 'turbulencia', 'ondular', 'liquido',
      'warp'],
    cost: 3,
    params: {
      'quantidade':
          EffectParam('Quantidade', 40.0, 0.0, 300.0, relative: true),
      'tamanho': EffectParam('Tamanho', 60.0, 5.0, 300.0, relative: true),
      'complexidade': EffectParam('Complexidade', 2.0, 1.0, 5.0),
      'evolucao': EffectParam('Evolucao', 0.0, -3600.0, 3600.0),
      'semente': EffectParam('Semente', 1.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  /// MASCARA DE NITIDEZ de verdade: original + quantidade * (original -
  /// borrado), com limiar para nao realcar ruido.
  EffectType.unsharpMask: EffectSpec(
    id: 'unsharp_mask',
    name: 'Unsharp Mask',
    category: 'Lens',
    synonyms: ['mascara', 'nitidez', 'unsharp mask', 'nitidez', 'sharpen', 'foco'],
    params: {
      'quantidade': EffectParam('Quantidade', 0.8, 0.0, 3.0),
      'raio': EffectParam('Raio', 3.0, 0.5, 40.0, relative: true),
      'limiar': EffectParam('Limiar', 0.0, 0.0, 1.0),
    },
  ),

  EffectType.motionTile: EffectSpec(
    id: 'motion_tile',
    name: 'Motion Tile',
    category: 'Stylize',
    synonyms: ['mosaico', 'movimento', 'motion tile', 'ladrilho', 'repetir', 'tile', 'espelhar'],
    cost: 2,
    params: {
      // Todas as medidas sao % DAS DIMENSOES DA CAMADA DE ENTRADA, como
      // no After Effects. Em pixel, o mesmo numero daria ladrilhos de
      // tamanhos diferentes ao trocar a resolucao.
      'tile_center': EffectParam('Tile Center X', 0.5, 0.0, 1.0,
          kind: ParamKind.point, relative: true),
      'tile_center_y': EffectParam('Tile Center Y', 0.5, 0.0, 1.0,
          kind: ParamKind.point, relative: true),
      'tile_width': EffectParam('Tile Width', 100.0, 1.0, 300.0),
      'tile_height': EffectParam('Tile Height', 100.0, 1.0, 300.0),
      'output_width': EffectParam('Output Width', 100.0, 1.0, 600.0),
      'output_height': EffectParam('Output Height', 100.0, 1.0, 600.0),
      'mirror_edges': EffectParam('Mirror Edges', 0.0, 0.0, 1.0,
          kind: ParamKind.toggle),
      'phase': EffectParam('Phase', 0.0, -360.0, 360.0),
      'horizontal_phase_shift':
          EffectParam('Horizontal Phase Shift', 0.0, 0.0, 1.0,
              kind: ParamKind.toggle),
    },
  ),

  EffectType.bend: EffectSpec(
    id: 'bend',
    name: 'Bend',
    category: 'Distort',
    synonyms: ['entortar', 'bend', 'curvar', 'arco', 'entortar', 'wave warp'],
    cost: 2,
    params: {
      'quantidade': EffectParam('Quantidade', 40.0, -300.0, 300.0,
          relative: true),
      'eixo': EffectParam('Eixo', 0.0, 0.0, 1.0,
          kind: ParamKind.choice, options: ['Horizontal', 'Vertical']),
      'curvatura': EffectParam('Curvatura', 1.0, 0.2, 4.0),
      'ancora': EffectParam('Ancora', 0.5, 0.0, 1.0),
    },
  ),

  /// CC SEMEAR (CC Scatterize): quebra a imagem em graos e espalha.
  EffectType.ccScatterize: EffectSpec(
    id: 'seed',
    name: 'Seed',
    category: 'Stylize',
    synonyms: ['semear', 'cc scatterize', 'semear', 'dispersar', 'scatter',
      'desintegrar', 'particulas'],
    cost: 3,
    params: {
      'dispersao':
          EffectParam('Dispersao', 60.0, 0.0, 400.0, relative: true),
      'grao': EffectParam('Grao', 24.0, 4.0, 120.0, relative: true),
      'rotacao': EffectParam('Rotacao', 0.0, -180.0, 180.0),
      'transferencia': EffectParam('Transferencia', 1.0, 0.0, 1.0),
      'gravidade': EffectParam('Gravidade', 0.0, -1.0, 1.0),
      'semente': EffectParam('Semente', 3.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  /// CC SPLIT: a imagem se abre em duas metades a partir de dois pontos.
  EffectType.ccSplit: EffectSpec(
    id: 'split',
    name: 'Split',
    category: 'Distort',
    synonyms: ['split', 'cc split', 'dividir', 'rasgar', 'abrir', 'separar'],
    cost: 2,
    params: {
      'divisao': EffectParam('Divisao', 40.0, 0.0, 400.0, relative: true),
      'angulo': EffectParam('Angulo', 0.0, -180.0, 180.0),
      'centro': EffectParam('Centro', 0.5, 0.0, 1.0),
      'suavidade': EffectParam('Suavidade', 0.0, 0.0, 1.0),
    },
  ),

  EffectType.vhs: EffectSpec(
    id: 'vhs',
    name: 'VHS',
    category: 'Stylize',
    synonyms: ['vhs', 'vhs', 'fita', 'analogico', 'retro', 'tv', 'scanline'],
    cost: 2,
    params: {
      'intensidade': EffectParam('Intensidade', 0.6, 0.0, 1.0),
      'linhas': EffectParam('Linhas', 0.5, 0.0, 1.0),
      'sangramento': EffectParam('Sangramento', 0.5, 0.0, 1.0),
      'tremor': EffectParam('Tremor', 0.35, 0.0, 1.0),
      'ruido': EffectParam('Ruido', 0.3, 0.0, 1.0),
      'desbotar': EffectParam('Desbotar', 0.4, 0.0, 1.0),
      'semente': EffectParam('Semente', 5.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  EffectType.filmDamage: EffectSpec(
    id: 'film_damage',
    name: 'Film Damage',
    category: 'Stylize',
    synonyms: ['filme', 'danificado', 'film damage', 'filme', 'velho', 'riscos', 'poeira',
      'super 8', 'granulado'],
    cost: 2,
    params: {
      'poeira': EffectParam('Poeira', 0.5, 0.0, 1.0),
      'riscos': EffectParam('Riscos', 0.4, 0.0, 1.0),
      'cintilacao': EffectParam('Cintilacao', 0.35, 0.0, 1.0),
      'granulacao': EffectParam('Granulacao', 0.4, 0.0, 1.0),
      'queimado': EffectParam('Queimado', 0.3, 0.0, 1.0),
      'salto': EffectParam('Salto de quadro', 0.25, 0.0, 1.0),
      'semente': EffectParam('Semente', 11.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  EffectType.glitchify: EffectSpec(
    id: 'glitchify',
    name: 'Glitchify',
    category: 'Glitch',
    synonyms: ['glitchify', 'glitch', 'glitchify', 'datamosh', 'erro', 'digital',
      'corromper'],
    cost: 3,
    params: {
      'intensidade': EffectParam('Intensidade', 0.6, 0.0, 1.0),
      'blocos': EffectParam('Blocos', 8.0, 1.0, 40.0),
      'deslocamento':
          EffectParam('Deslocamento', 60.0, 0.0, 400.0, relative: true),
      'cor': EffectParam('Separacao de cor', 0.5, 0.0, 1.0),
      'velocidade': EffectParam('Velocidade', 8.0, 0.5, 40.0),
      'ruidoLinha': EffectParam('Linhas de erro', 0.4, 0.0, 1.0),
      'semente': EffectParam('Semente', 13.0, 1.0, 999.0,
          kind: ParamKind.seed),
    },
  ),

  EffectType.forceMotionBlur: EffectSpec(
    id: 'force_motion_blur',
    name: 'Force Motion Blur',
    category: 'Blur',
    synonyms: [
      'motion blur', 'borrao', 'movimento', 'forcar', 'obturador',
      'shutter',
    ],
    cost: 3,
    params: {
      // Mais amostras do que a composicao permite, e funciona SEM
      // keyframe de transform: pega tambem o movimento que veio de
      // efeito, que o motion blur da composicao nao ve.
      'samples': EffectParam('Motion Blur Samples', 16.0, 2.0, 64.0),
      'shutter_angle': EffectParam('Shutter Angle', 180.0, 0.0, 720.0),
      'native_motion_blur': EffectParam(
          'Native Motion Blur', 0.0, 0.0, 2.0,
          kind: ParamKind.choice, options: ['Off', 'On', 'Only']),
    },
  ),

};

/// Categorias do catalogo, na ordem em que aparecem.
/// CATEGORIAS, em ingles como os nomes. A arrumacao do catalogo e a
/// primeira coisa que a pessoa le, e misturar idioma ali confunde mais
/// do que ajuda.
const effectCategories = <String>[
  'Color',
  'Light',
  'Lens',
  'Blur',
  'Distort',
  'Stylize',
  'Glitch',
  'Time',
  'Generate',
  'Utility',
];

/// A categoria escrita em portugues, para a busca aceitar os dois
/// idiomas: quem digita "cor" acha os efeitos de Color.
const _categoriaEmPortugues = <String, String>{
  'Color': 'cor',
  'Light': 'luz',
  'Lens': 'lente',
  'Blur': 'desfoque',
  'Distort': 'distorcer distorcao',
  'Stylize': 'estilizar',
  'Glitch': 'glitch',
  'Time': 'tempo',
  'Generate': 'gerar textura',
  'Utility': 'utilitario',
};

/// BUSCA (§5): nome, categoria e SINONIMOS. Quem digita "bloom" acha
/// Glow; quem digita "pixelate" acha Mosaico.
List<EffectType> searchEffects(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return effectSpecs.keys.toList();
  return [
    for (final e in effectSpecs.entries)
      if (e.value.name.toLowerCase().contains(q) ||
          e.value.id.contains(q) ||
          e.value.category.toLowerCase().contains(q) ||
          (_categoriaEmPortugues[e.value.category] ?? '').contains(q) ||
          e.value.synonyms.any((s) => s.contains(q)))
        e.key,
  ];
}

List<EffectType> effectsInCategory(String category) => [
      for (final e in effectSpecs.entries)
        if (e.value.category == category) e.key,
    ];

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
                e.key: AnimatedDouble(e.value.initial),
            });

  final String id;
  final EffectType type;
  final Map<String, AnimatedDouble> params;
  final Color color;
  final bool enabled;

  EffectSpec get spec => effectSpecs[type]!;

  AnimatedDouble track(String key) =>
      params[key] ?? AnimatedDouble(spec.params[key]?.initial ?? 0);

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
