import 'dart:ui';

import '../../editor/domain/effect.dart';
import '../../editor/domain/element3d.dart';
import '../../editor/domain/keyframe.dart';
import '../../editor/domain/layer.dart';
import '../../editor/domain/shape.dart';
import '../../editor/domain/video_project.dart';

/// MODELO "PINDOWN": a recriacao de um motion de referencia, cena por
/// cena, com o que o aplicativo faz.
///
/// O original tem 9,33 s a 30 fps em 720 x 1278 e cinco cenas: a casa
/// verde com a faisca orbitando, a virada para vermelho com a casa em
/// chamas, o olho que chora sangue, a espada fincada no chao rachado, e
/// as coroas girando.
///
/// O QUE FOI MEDIDO, nao estimado: a trajetoria da faisca sai quadro a
/// quadro do video (componentes conectados sobre o branco puro), e as
/// paradas do gradiente do horizonte saem da coluna de pixels do
/// original. Por isso os numeros abaixo tem cara de numero medido — sao.
///
/// DUAS COISAS PRECISARAM ENTRAR NO MOTOR para esta recriacao existir:
/// o gradiente de mais de duas paradas (a faixa do horizonte vai de
/// azul-marinho a branco passando por ciano e verde) e o solido Coroa
/// (`crownMesh`, um tubo com a borda de cima em dentes).

// ---------------------------------------------------------- a paleta
// Amostradas do proprio video, no quadro 30.
const _ceuTopo = Color(0xFF041124);
const _ceuBaixo = Color(0xFF15335B);
const _chaoTopo = Color(0xFF0A1F28);
const _chaoMeio = Color(0xFF21476F);
const _chaoVerde = Color(0xFF30BE9A);
const _chaoMenta = Color(0xFF3AFFAD);
const _chaoCiano = Color(0xFF58FFF2);
const _chaoClaro = Color(0xFF9DFFFD);

const _telhado = Color(0xFF28CF92);
const _paredeEscura = Color(0xFF0F3554);
const _vao = Color(0xFF0C2A46);
const _branco = Color(0xFFFFFFFF);

const _coroa = Color(0xFFE8604F);

/// A composicao tem o tamanho do original, para a comparacao quadro a
/// quadro ser direta.
const _largura = 720;
const _altura = 1278;
const _dur = Duration(milliseconds: 9333);

/// A linha do chao, medida: e onde a coluna de pixels despenca.
const double _linhaDoChao = 805;

Duration _s(double seg) => Duration(microseconds: (seg * 1e6).round());
double _f(int quadro) => quadro / 30.0;

const Easing _suave = Easing(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1);
const Easing _mola = Easing.overshoot;

AnimatedDouble _ad(double base, [List<(double, double, Easing)>? kfs]) =>
    AnimatedDouble(base, [
      if (kfs != null)
        for (final k in kfs) Keyframe(time: _s(k.$1), value: k.$2, ease: k.$3),
    ]);

AnimatedOffset _ao(Offset base, [List<(double, Offset, Easing)>? kfs]) =>
    AnimatedOffset(base, [
      if (kfs != null)
        for (final k in kfs) Keyframe(time: _s(k.$1), value: k.$2, ease: k.$3),
    ]);

/// Glow — o original inteiro e desenhado com ele: nada tem borda dura.
EffectInstance _glow({double raio = 60, double intensidade = 0.9}) =>
    EffectInstance(type: EffectType.lightGlow, params: {
      'raio': _ad(raio),
      'intensity': _ad(intensidade * 100),
      'threshold': _ad(28),
    });

ShapeLayer _retangulo({
  required String id,
  required String nome,
  required Offset centro,
  required double w,
  required double h,
  Color? cor,
  ShapeGradientFill? gradiente,
  double raio = 0,
  AnimatedOffset? posicao,
  AnimatedDouble? opacidade,
  AnimatedDouble? sx,
  AnimatedDouble? sy,
  AnimatedDouble? rotacao,
  List<EffectInstance>? efeitos,
  Duration? inicio,
  Duration? duracao,
}) =>
    ShapeLayer(
      id: id,
      name: nome,
      startTime: inicio ?? Duration.zero,
      duration: duracao ?? _dur,
      position: posicao ?? _ao(centro),
      opacity: opacidade,
      scaleX: sx,
      scaleY: sy,
      rotation: rotacao,
      effects: efeitos,
      contents: [
        ShapeParametric(
          kind: ParamShapeKind.rect,
          sizeX: _ad(w),
          sizeY: _ad(h),
          roundness: _ad(raio),
        ),
        if (gradiente != null) gradiente else ShapeFill(color: cor ?? _branco),
      ],
    );

/// Uma forma qualquer por caminho: telhado, empena, arbusto.
ShapeLayer _caminho({
  required String id,
  required String nome,
  required Offset centro,
  required String d,
  required double tamanho,
  Color? cor,
  ShapeGradientFill? gradiente,
  AnimatedOffset? posicao,
  AnimatedDouble? opacidade,
  List<EffectInstance>? efeitos,
  Duration? inicio,
  Duration? duracao,
}) =>
    ShapeLayer(
      id: id,
      name: nome,
      startTime: inicio ?? Duration.zero,
      duration: duracao ?? _dur,
      position: posicao ?? _ao(centro),
      opacity: opacidade,
      effects: efeitos,
      contents: [
        ShapeSvgPath(pathData: d, size: tamanho),
        if (gradiente != null) gradiente else ShapeFill(color: cor ?? _branco),
      ],
    );

// ==================================================== A FAISCA MEDIDA
//
// Centro e largura da faisca em cada segundo quadro, extraidos do video
// por componentes conectados sobre o branco puro. Ela nao orbita em
// circulo: sobe, mergulha para a esquerda, volta e sobe de novo mais
// alto — um oito frouxo. Reproduzir a curva "mais ou menos" e o que faz
// uma recriacao parecer imitacao; aqui os pontos sao os do original.
const _faisca = <(int, double, double, double)>[
  (4, 350, 796, 122),
  (6, 384, 719, 180),
  (8, 385, 642, 180),
  (10, 374, 574, 159),
  (12, 357, 509, 151),
  (14, 343, 460, 122),
  (16, 353, 433, 146),
  (18, 331, 447, 160),
  (20, 297, 520, 134),
  (22, 305, 590, 104),
  (24, 322, 662, 127),
  (26, 381, 697, 142),
  (28, 424, 607, 113),
  (30, 432, 418, 108),
  (32, 409, 261, 119),
  (34, 386, 230, 117),
  (36, 372, 225, 118),
  (38, 363, 238, 116),
  (40, 359, 288, 120),
  (42, 357, 404, 116),
];

/// A faisca de quatro pontas, no caminho medido.
///
/// A escala vem da largura medida dividida pela maior: a faisca pulsa, e
/// o pulso e parte do movimento — sem ele o brilho parece um adesivo
/// deslizando.
ShapeLayer _faiscaLayer() {
  // O tamanho natural da faisca desenhada, medido no proprio render:
  // com escala 1 ela sai com 405 px. A escala de cada quadro e a largura
  // medida no original dividida por isso.
  const maior = 405.0;
  return ShapeLayer(
    id: 'p_faisca',
    name: 'Faisca',
    startTime: _s(_f(3)),
    duration: _s(_f(44) - _f(3)),
    position: AnimatedOffset(
      Offset(_faisca.first.$2, _faisca.first.$3),
      [
        for (final (q, x, y, _) in _faisca)
          Keyframe(
            time: _s(_f(q) - _f(3)),
            value: Offset(x, y),
            ease: _suave,
          ),
      ],
    ),
    scaleX: AnimatedDouble(1, [
      for (final (q, _, _, w) in _faisca)
        Keyframe(time: _s(_f(q) - _f(3)), value: w / maior, ease: _suave),
    ]),
    scaleY: AnimatedDouble(1, [
      for (final (q, _, _, w) in _faisca)
        Keyframe(time: _s(_f(q) - _f(3)), value: w / maior, ease: _suave),
    ]),
    effects: [_glow(raio: 90, intensidade: 1.2)],
    contents: [
      ShapePath(primitive: ShapePrimitive.sparkle),
      ShapeFill(color: _branco),
    ],
  );
}

// ================================================== CENA 1 — A CASA
List<Layer> _cenaDaCasa() {
  const fim = Duration(milliseconds: 1500);
  return [
    // O CEU: rampa vertical escura, com o brilho atras da casa.
    _retangulo(
      id: 'p_ceu',
      nome: 'Ceu',
      centro: const Offset(360, 639),
      w: 760,
      h: 1320,
      gradiente: ShapeGradientFill(
        colorA: _ceuTopo,
        colorB: _ceuBaixo,
        angleDeg: 90,
      ),
      duracao: fim,
    ),
    // O HORIZONTE: a faixa que vai de azul-marinho a quase branco
    // passando por ciano e verde. Sao seis paradas medidas — com duas
    // o meio vira uma mistura suja que nao existe no original, e foi
    // por isso que o gradiente de N paradas entrou no motor.
    _retangulo(
      id: 'p_chao',
      nome: 'Horizonte',
      centro: Offset(360, (_linhaDoChao + _altura) / 2),
      w: 760,
      h: _altura - _linhaDoChao,
      gradiente: ShapeGradientFill(
        colorA: _chaoTopo,
        extras: const [_chaoMeio, _chaoVerde, _chaoMenta, _chaoCiano],
        colorB: _chaoClaro,
        angleDeg: 90,
      ),
      duracao: fim,
    ),

    // A CASA. Empena escura a esquerda, telhado e parede iluminados a
    // direita: e a leitura de "luz vindo da direita" com duas cores
    // chapadas, sem sombreamento nenhum.
    // AS PECAS DA CASA, nas posicoes medidas no quadro 40 do original.
    // A empena (a parede lateral, na sombra) vai primeiro; o telhado e a
    // fachada iluminada entram por cima.
    _retangulo(
      id: 'p_empena',
      nome: 'Empena',
      centro: const Offset(295, 716),
      w: 90,
      h: 198,
      cor: _paredeEscura,
      duracao: fim,
    ),
    _caminho(
      id: 'p_telhado',
      nome: 'Telhado',
      centro: const Offset(380, 654),
      d: 'M12 88 L115 0 L218 88 L230 95 L0 95 Z',
      tamanho: 230,
      gradiente: ShapeGradientFill(
        colorA: const Color(0xFF3CE6A4),
        colorB: _telhado,
        angleDeg: 20,
      ),
      efeitos: [_glow(raio: 40, intensidade: 0.5)],
      duracao: fim,
    ),
    _retangulo(
      id: 'p_chamine',
      nome: 'Chamine',
      centro: const Offset(397, 617),
      w: 25,
      h: 45,
      cor: _paredeEscura,
      duracao: fim,
    ),
    _retangulo(
      id: 'p_parede',
      nome: 'Parede',
      centro: const Offset(410, 764),
      w: 140,
      h: 123,
      gradiente: ShapeGradientFill(
        colorA: const Color(0xFF45F0A8),
        colorB: const Color(0xFF1FA97C),
        angleDeg: 55,
      ),
      efeitos: [_glow(raio: 50, intensidade: 0.7)],
      duracao: fim,
    ),
    _retangulo(
      id: 'p_porta',
      nome: 'Porta',
      centro: const Offset(412, 782),
      w: 25,
      h: 85,
      cor: _vao,
      duracao: fim,
    ),
    for (final (i, x) in [368.0, 453.0].indexed)
      _retangulo(
        id: 'p_janela$i',
        nome: 'Janela',
        centro: Offset(x, 758),
        w: 16,
        h: 34,
        cor: _vao,
        duracao: fim,
      ),

    _faiscaLayer(),
  ];
}

// ============================================= CENA 5 — AS COROAS
//
// Aqui o original deixa de ser 2D: as coroas tem sombreamento de
// verdade, giram nos tres eixos e mostram a parede de dentro. E a unica
// cena que exige a cena 3D — e o solido nao existia.
List<Layer> _cenaDasCoroas() {
  final inicio = _s(_f(208));
  final duracao = _s(_f(280) - _f(208));

  Element3DLayer coroa({
    required String id,
    required Offset centro,
    required double tamanho,
    required double giro0,
    required double giro1,
    required double inclina,
    Duration? atraso,
  }) =>
      Element3DLayer(
        id: id,
        name: 'Coroa',
        startTime: inicio + (atraso ?? Duration.zero),
        duration: duracao - (atraso ?? Duration.zero),
        kind: Element3DKind.crown,
        size: tamanho,
        color: _coroa,
        // Sem as arestas: a referencia e sombreada lisa, e a malha
        // aparecendo entrega que aquilo e um poliedro de 48 lados.
        edges: false,
        position: _ao(centro),
        // O giro e continuo e a inclinacao e fixa: e o que faz cada
        // coroa mostrar um pedaco diferente da parede de dentro.
        rotationY: _ad(giro0, [(0, giro0, Easing.linear),
          (duracao.inMicroseconds / 1e6, giro1, Easing.linear)]),
        rotationX: _ad(inclina),
        scaleX: _ad(0.2, [(0, 0.2, _mola), (0.55, 1.0, _mola)]),
        scaleY: _ad(0.2, [(0, 0.2, _mola), (0.55, 1.0, _mola)]),
        effects: [_glow(raio: 70, intensidade: 0.6)],
      );

  return [
    _retangulo(
      id: 'p_fundo_coroa',
      nome: 'Fundo',
      centro: const Offset(360, 639),
      w: 760,
      h: 1320,
      gradiente: ShapeGradientFill(
        colorA: const Color(0xFF14200E),
        colorB: const Color(0xFF05070A),
        radial: true,
      ),
      inicio: inicio,
      duracao: duracao,
    ),
    coroa(
      id: 'p_coroa_a',
      centro: const Offset(352, 690),
      tamanho: 205,
      giro0: -25,
      giro1: 320,
      inclina: 18,
    ),
    coroa(
      id: 'p_coroa_b',
      centro: const Offset(486, 494),
      tamanho: 120,
      giro0: 40,
      giro1: -280,
      inclina: 26,
      atraso: _s(0.55),
    ),
    coroa(
      id: 'p_coroa_c',
      centro: const Offset(300, 906),
      tamanho: 105,
      giro0: 160,
      giro1: 520,
      inclina: 12,
      atraso: _s(1.2),
    ),
  ];
}

/// O modelo inteiro.
VideoProject buildPindownMotionTemplate() {
  return VideoProject(
    name: 'Pindown — recriacao',
    createdAt: DateTime(2026, 9, 3),
    fps: 30,
    // Em retrato o campo 'resolutionHeight' e o LADO CURTO: a largura.
    // outputHeight sai da divisao pela proporcao.
    aspectRatio: _largura / _altura,
    resolutionHeight: _largura,
    // A PRIMEIRA CAMADA DA LISTA E A DE CIMA (o preview pinta em
    // 'layers.reversed'). O fundo vai por ultimo, como na timeline.
    layers: [
      ..._cenaDasCoroas().reversed,
      ..._cenaDaCasa().reversed,
    ],
  );
}
