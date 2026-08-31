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
}

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
    required this.name,
    required this.params,
    this.hasColor = false,
    this.category = 'Estilizar',
    this.synonyms = const [],
    this.cost = 1,
    this.procedural = false,
  });

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
    name: 'Desfoque gaussiano',
    category: 'Desfoque',
    synonyms: ['blur', 'gaussian', 'suavizar'],
    params: {
      'amount': EffectParam('Intensidade', 0.25, 0.0, 1.0),
    },
  ),
  EffectType.lightGlow: EffectSpec(
    name: 'Brilho de luz',
    category: 'Luz',
    synonyms: ['glow', 'bloom', 'brilho'],
    params: {
      'diffusion': EffectParam('Difusao', 0.25, 0.0, 1.0),
      'threshold': EffectParam('Limite', 0.70, 0.0, 1.0),
      'intensity': EffectParam('Intensidade', 1.0, 0.0, 1.0),
    },
    hasColor: true,
  ),
  EffectType.tint: EffectSpec(
    name: 'Tonalizar',
    category: 'Cor',
    synonyms: ['tint', 'colorir'],
    params: {
      'strength': EffectParam('Forca', 0.5, 0.0, 1.0),
    },
    hasColor: true,
  ),
  // Glow com pirâmide de 3 niveis, aberracao RGB e tonalizacao opcional
  // (aproximacao do Glow Volumetrico; conservacao plena exige linear).
  EffectType.glowVol: EffectSpec(
    name: 'Glow volumetrico',
    category: 'Luz',
    synonyms: ['bloom', 'volumetric', 'brilho'],
    cost: 3,
    params: {
      'raio': EffectParam('Raio', 0.35, 0.02, 1.0, relative: true),
      'intensidade': EffectParam('Intensidade', 0.8, 0.0, 2.0),
      'aberracao': EffectParam('Aberracao', 0.0, 0.0, 1.0),
      'tonalizar': EffectParam('Tonalizar', 0.0, 0.0, 1.0),
    },
    hasColor: true,
  ),
  // Tremor de camera: aleatorio e REPETIVEL, com fase integrada — animar
  // a frequencia acelera de verdade, sem salto.
  EffectType.tremor: EffectSpec(
    name: 'Tremor',
    category: 'Distorcao',
    synonyms: ['shake', 'camera shake', 'tremer'],
    procedural: true,
    params: {
      'amplitude':
          EffectParam('Amplitude', 60.0, 0.0, 300.0, relative: true),
      'frequencia': EffectParam('Frequencia', 8.0, 0.0, 30.0),
      'estilo': EffectParam('Estilo', 0.0, 0.0, 2.0,
          kind: ParamKind.choice,
          options: ['Normal', 'Nervoso', 'Saltos']),
      'zoom': EffectParam('Zoom', 0.0, 0.0, 1.0),
      'inclinacao': EffectParam('Inclinacao', 0.0, 0.0, 30.0),
      'rgb': EffectParam('Franja RGB', 0.0, 0.0, 1.0),
      'semente': EffectParam('Semente', 0.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
  ),
  // Seis operadores sincronizados por um modulador mestre (quantidade +
  // velocidade); tiques deterministicos e seekaveis.
  EffectType.glitch: EffectSpec(
    name: 'Glitch modular',
    category: 'Glitch',
    synonyms: ['glitch', 'datamosh', 'erro'],
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
    name: 'Separacao RGB',
    category: 'Lente',
    synonyms: ['rgb split', 'chromatic', 'canal'],
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
    name: 'Eco / rastro',
    category: 'Desfoque',
    synonyms: ['echo', 'trail', 'rastro', 'motion trail'],
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
    name: 'Eco espacial',
    category: 'Estilizar',
    synonyms: ['echo', 'repeat', 'repeticao'],
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
    name: 'Aberracao cromatica',
    category: 'Lente',
    synonyms: ['chromatic aberration', 'franja', 'lente'],
    cost: 2,
    params: {
      'quantidade': EffectParam('Quantidade', 0.3, 0.0, 1.0),
    },
  ),

  // ------------------------- catalogo, lote 1 -------------------------

  EffectType.levels: EffectSpec(
    name: 'Niveis',
    category: 'Cor',
    synonyms: ['levels', 'contraste', 'gama', 'brilho'],
    params: {
      'entradaMin': EffectParam('Entrada min', 0.0, 0.0, 1.0),
      'entradaMax': EffectParam('Entrada max', 1.0, 0.0, 1.0),
      'gama': EffectParam('Gama', 1.0, 0.2, 3.0),
      'saidaMin': EffectParam('Saida min', 0.0, 0.0, 1.0),
      'saidaMax': EffectParam('Saida max', 1.0, 0.0, 1.0),
    },
  ),
  EffectType.curves: EffectSpec(
    name: 'Curvas',
    category: 'Cor',
    synonyms: ['curves', 'curva', 'contraste'],
    params: {
      'contraste': EffectParam('Contraste S', 0.0, -1.0, 1.0),
      'brilho': EffectParam('Brilho', 0.0, -1.0, 1.0),
      'sombras': EffectParam('Levantar sombras', 0.0, 0.0, 1.0),
      'altas': EffectParam('Baixar altas', 0.0, 0.0, 1.0),
    },
  ),
  EffectType.vibrance: EffectSpec(
    name: 'Vibracao',
    category: 'Cor',
    synonyms: ['vibrance', 'saturacao', 'vivid'],
    params: {
      'vibracao': EffectParam('Vibracao', 0.0, -1.0, 1.0),
      'saturacao': EffectParam('Saturacao', 0.0, -1.0, 1.0),
      // O que separa cor bonita de cor berrante: satura o resto sem
      // deixar o rosto laranja.
      'protecaoPele': EffectParam('Protecao de pele', 0.6, 0.0, 1.0),
    },
  ),
  EffectType.whiteBalance: EffectSpec(
    name: 'Balanco de branco',
    category: 'Cor',
    synonyms: ['white balance', 'temperatura', 'matiz', 'wb'],
    params: {
      'temperatura': EffectParam('Temperatura', 0.0, -1.0, 1.0),
      'matiz': EffectParam('Matiz', 0.0, -1.0, 1.0),
    },
  ),
  EffectType.colorWheels: EffectSpec(
    name: 'Rodas de cor',
    category: 'Cor',
    synonyms: ['color wheels', 'lift gamma gain', 'gradacao'],
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
    name: 'Unmult (tira o preto)',
    category: 'Luz',
    synonyms: ['unmult', 'screen', 'tirar fundo preto', 'overlay'],
    params: {
      'limiar': EffectParam('Limiar', 0.0, 0.0, 1.0),
      'suavidade': EffectParam('Suavidade', 0.5, 0.0, 1.0),
    },
  ),
  EffectType.vignette: EffectSpec(
    name: 'Vinheta',
    category: 'Lente',
    synonyms: ['vignette', 'borda escura'],
    params: {
      'quantidade': EffectParam('Quantidade', 0.5, 0.0, 1.0),
      'raio': EffectParam('Raio', 0.7, 0.1, 1.5, relative: true),
      'suavidade': EffectParam('Suavidade', 0.5, 0.0, 1.0),
    },
    hasColor: true,
  ),
  EffectType.directionalBlur: EffectSpec(
    name: 'Desfoque direcional',
    category: 'Desfoque',
    synonyms: ['directional blur', 'motion blur', 'movimento'],
    cost: 2,
    params: {
      'comprimento':
          EffectParam('Comprimento', 20.0, 0.0, 120.0, relative: true),
      'angulo': EffectParam('Angulo', 0.0, -180.0, 180.0),
    },
  ),
  EffectType.radialBlur: EffectSpec(
    name: 'Desfoque radial',
    category: 'Desfoque',
    synonyms: ['radial blur', 'zoom blur', 'giro'],
    cost: 3,
    params: {
      'quantidade': EffectParam('Quantidade', 0.3, 0.0, 1.0),
      'modo': EffectParam('Modo', 0.0, 0.0, 1.0,
          kind: ParamKind.choice, options: ['Zoom', 'Giro']),
      'amostras': EffectParam('Amostras', 6.0, 2.0, 16.0),
    },
  ),
  EffectType.lightRays: EffectSpec(
    name: 'Raios volumetricos',
    category: 'Luz',
    synonyms: ['god rays', 'light rays', 'raios', 'deus'],
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
    name: 'Mosaico',
    category: 'Estilizar',
    synonyms: ['mosaic', 'pixelate', 'pixel', 'censura'],
    params: {
      'blocos': EffectParam('Blocos', 24.0, 3.0, 160.0),
    },
  ),
  EffectType.filmGrain: EffectSpec(
    name: 'Grao de filme',
    category: 'Textura',
    synonyms: ['grain', 'grao', 'ruido', 'filme'],
    procedural: true,
    params: {
      'intensidade': EffectParam('Intensidade', 0.25, 0.0, 1.0),
      'tamanho': EffectParam('Tamanho', 1.5, 0.5, 6.0),
      'semente': EffectParam('Semente', 1.0, 0.0, 100.0,
          kind: ParamKind.seed),
    },
  ),
  EffectType.fractalNoise: EffectSpec(
    name: 'Ruido fractal',
    category: 'Textura',
    synonyms: ['fractal noise', 'perlin', 'nuvem', 'fumaca'],
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
    name: 'Dano digital',
    category: 'Glitch',
    synonyms: ['digital damage', 'blocos', 'corrupcao', 'datamosh'],
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
    name: 'Zoom warp',
    category: 'Distorcao',
    synonyms: ['zoom warp', 'punch', 'impacto', 'dolly'],
    cost: 2,
    params: {
      'quantidade': EffectParam('Quantidade', 0.2, -1.0, 1.0),
      'rastro': EffectParam('Rastro', 0.3, 0.0, 1.0),
      'amostras': EffectParam('Amostras', 5.0, 2.0, 12.0),
    },
  ),
  EffectType.posterize: EffectSpec(
    name: 'Posterizar',
    category: 'Estilizar',
    synonyms: ['posterize', 'niveis', 'cartoon'],
    params: {
      'niveis': EffectParam('Niveis', 6.0, 2.0, 32.0),
    },
  ),

  // ------------------------------------------------------- lote 2

  /// REMAPEAMENTO DE TEMPO, igual ao do After Effects: em vez de mexer
  /// na velocidade, voce anima QUAL INSTANTE da camada aparece agora.
  /// Congelar, voltar, acelerar no meio — tudo vira keyframe de tempo.
  EffectType.timeRemap: EffectSpec(
    name: 'Remapear tempo',
    category: 'Tempo',
    synonyms: ['time remap', 'tempo', 'congelar', 'freeze', 'reverso',
      'velocidade', 'speed ramp'],
    cost: 1,
    params: {
      'tempo': EffectParam('Tempo (s)', 0.0, 0.0, 60.0),
    },
  ),

  EffectType.pixelSort: EffectSpec(
    name: 'Ordenar pixels',
    category: 'Estilizar',
    synonyms: ['pixel sort', 'sorting', 'databend', 'arrastar'],
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
    name: 'Rastreador de blobs',
    category: 'Estilizar',
    synonyms: ['blob tracker', 'tracking', 'alvo', 'hud', 'mira'],
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
    name: 'Deslocar turbulento',
    category: 'Distorcer',
    synonyms: ['turbulent displace', 'turbulencia', 'ondular', 'liquido',
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
    name: 'Mascara de nitidez',
    category: 'Lente',
    synonyms: ['unsharp mask', 'nitidez', 'sharpen', 'foco'],
    params: {
      'quantidade': EffectParam('Quantidade', 0.8, 0.0, 3.0),
      'raio': EffectParam('Raio', 3.0, 0.5, 40.0, relative: true),
      'limiar': EffectParam('Limiar', 0.0, 0.0, 1.0),
    },
  ),

  EffectType.motionTile: EffectSpec(
    name: 'Mosaico de movimento',
    category: 'Estilizar',
    synonyms: ['motion tile', 'ladrilho', 'repetir', 'tile', 'espelhar'],
    cost: 2,
    params: {
      'largura': EffectParam('Largura do bloco', 100.0, 10.0, 300.0),
      'altura': EffectParam('Altura do bloco', 100.0, 10.0, 300.0),
      'saidaLargura': EffectParam('Largura da saida', 200.0, 100.0, 600.0),
      'saidaAltura': EffectParam('Altura da saida', 200.0, 100.0, 600.0),
      'deslocX': EffectParam('Deslocar X', 0.0, -200.0, 200.0),
      'deslocY': EffectParam('Deslocar Y', 0.0, -200.0, 200.0),
      'espelhar': EffectParam('Espelhar bordas', 1.0, 0.0, 1.0,
          kind: ParamKind.toggle),
      'desvanecer': EffectParam('Desvanecer', 0.0, 0.0, 1.0),
    },
  ),

  EffectType.bend: EffectSpec(
    name: 'Entortar',
    category: 'Distorcer',
    synonyms: ['bend', 'curvar', 'arco', 'entortar', 'wave warp'],
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
    name: 'CC Semear',
    category: 'Estilizar',
    synonyms: ['cc scatterize', 'semear', 'dispersar', 'scatter',
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
    name: 'CC Split',
    category: 'Distorcer',
    synonyms: ['cc split', 'dividir', 'rasgar', 'abrir', 'separar'],
    cost: 2,
    params: {
      'divisao': EffectParam('Divisao', 40.0, 0.0, 400.0, relative: true),
      'angulo': EffectParam('Angulo', 0.0, -180.0, 180.0),
      'centro': EffectParam('Centro', 0.5, 0.0, 1.0),
      'suavidade': EffectParam('Suavidade', 0.0, 0.0, 1.0),
    },
  ),

  EffectType.vhs: EffectSpec(
    name: 'VHS',
    category: 'Estilizar',
    synonyms: ['vhs', 'fita', 'analogico', 'retro', 'tv', 'scanline'],
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
    name: 'Filme danificado',
    category: 'Estilizar',
    synonyms: ['film damage', 'filme', 'velho', 'riscos', 'poeira',
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
    name: 'Glitchify',
    category: 'Estilizar',
    synonyms: ['glitch', 'glitchify', 'datamosh', 'erro', 'digital',
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
};

/// Categorias do catalogo, na ordem em que aparecem.
const effectCategories = <String>[
  'Cor',
  'Luz',
  'Lente',
  'Desfoque',
  'Glitch',
  'Distorcao',
  'Distorcer',
  'Estilizar',
  'Textura',
  'Tempo',
];

/// BUSCA (§5): nome, categoria e SINONIMOS. Quem digita "bloom" acha
/// Glow; quem digita "pixelate" acha Mosaico.
List<EffectType> searchEffects(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return effectSpecs.keys.toList();
  return [
    for (final e in effectSpecs.entries)
      if (e.value.name.toLowerCase().contains(q) ||
          e.value.category.toLowerCase().contains(q) ||
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
