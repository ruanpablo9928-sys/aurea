import 'dart:math' as math;

import 'keyframe.dart';
import 'text_animator.dart';

/// AUTORIA de animacao de texto (spec AUREA-autoria-de-texto): ninguem
/// aprende range selector. A pessoa pensa "cada palavra 40 ms depois da
/// anterior, cada uma levando 700 ms" — a RECEITA aceita isso e compila
/// para o motor de animadores que ja existe. Nao ha segundo caminho de
/// avaliacao: a receita vira um TextAnimator de verdade.

/// Unidade que se move de cada vez.
enum RecipeUnit { character, word, line, all }

/// Em que ordem as unidades entram.
enum RecipeOrder { start, end, center, edges, random }

/// Entrada, saida ou enfase (em loop).
enum RecipeKind { entrada, saida, enfase }

/// Curva de cada unidade. Vai para easeHigh/easeLow do seletor — NUNCA
/// para os keyframes do offset: a curva molda a transicao de CADA
/// unidade; se fosse para o offset, distorceria o espacamento entre
/// elas e o escalonamento sairia errado.
enum RecipeCurve {
  linear,
  suave,
  desaceleracao,
  desaceleracaoLonga,
  desaceleracaoForte,
  mola,
  elastica,
}

String recipeCurveLabel(RecipeCurve c) => switch (c) {
      RecipeCurve.linear => 'Linear',
      RecipeCurve.suave => 'Suave',
      RecipeCurve.desaceleracao => 'Desaceleracao',
      RecipeCurve.desaceleracaoLonga => 'Desaceleracao longa',
      RecipeCurve.desaceleracaoForte => 'Desaceleracao forte',
      RecipeCurve.mola => 'Mola',
      RecipeCurve.elastica => 'Elastica',
    };

/// (easeHigh, easeLow) do seletor + se o animador permite overshoot.
({double high, double low, bool overshoot}) recipeCurveEase(
    RecipeCurve c) {
  return switch (c) {
    RecipeCurve.linear => (high: 0, low: 0, overshoot: false),
    RecipeCurve.suave => (high: 40, low: 40, overshoot: false),
    RecipeCurve.desaceleracao => (high: 60, low: 0, overshoot: false),
    RecipeCurve.desaceleracaoLonga => (high: 85, low: 0, overshoot: false),
    RecipeCurve.desaceleracaoForte => (high: 95, low: 15, overshoot: false),
    // Mola/elastica passam do alvo: o overshoot vive no animador.
    RecipeCurve.mola => (high: 80, low: -35, overshoot: true),
    RecipeCurve.elastica => (high: 90, low: -60, overshoot: true),
  };
}

/// O que acontece com cada unidade. O valor e o ESTADO DE PARTIDA: com
/// cobertura 1 a unidade esta nele, com cobertura 0 esta no normal.
enum RecipeIngredient { aparecer, deslizar, escalar, girar, espacar, digitar }

String recipeIngredientLabel(RecipeIngredient i) => switch (i) {
      RecipeIngredient.aparecer => 'Aparecer',
      RecipeIngredient.deslizar => 'Deslizar',
      RecipeIngredient.escalar => 'Escalar',
      RecipeIngredient.girar => 'Girar',
      RecipeIngredient.espacar => 'Espacar',
      RecipeIngredient.digitar => 'Digitar',
    };

/// Um ingrediente com seus numeros (distancia/angulo/percentual).
class RecipeStep {
  const RecipeStep(this.ingredient, {this.amount = 0, this.angleDeg = 90});

  final RecipeIngredient ingredient;

  /// Deslizar: px. Escalar: % de partida. Girar: graus. Espacar: px.
  final double amount;

  /// Deslizar: direcao em graus (90 = vem de baixo, subindo).
  final double angleDeg;

  RecipeStep copyWith({double? amount, double? angleDeg}) => RecipeStep(
        ingredient,
        amount: amount ?? this.amount,
        angleDeg: angleDeg ?? this.angleDeg,
      );
}

/// A receita: seis controles que geram o rig sozinhos.
class TextRecipe {
  const TextRecipe({
    this.name = 'Receita',
    this.steps = const [RecipeStep(RecipeIngredient.aparecer)],
    this.unit = RecipeUnit.character,
    this.order = RecipeOrder.start,
    this.stagger = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 600),
    this.curve = RecipeCurve.desaceleracao,
    this.kind = RecipeKind.entrada,
    this.seed = 1,
  });

  final String name;
  final List<RecipeStep> steps;
  final RecipeUnit unit;
  final RecipeOrder order;

  /// Intervalo entre uma unidade e a seguinte.
  final Duration stagger;

  /// Quanto cada unidade leva.
  final Duration duration;

  final RecipeCurve curve;
  final RecipeKind kind;
  final int seed;

  TextRecipe copyWith({
    String? name,
    List<RecipeStep>? steps,
    RecipeUnit? unit,
    RecipeOrder? order,
    Duration? stagger,
    Duration? duration,
    RecipeCurve? curve,
    RecipeKind? kind,
    int? seed,
  }) {
    return TextRecipe(
      name: name ?? this.name,
      steps: steps ?? this.steps,
      unit: unit ?? this.unit,
      order: order ?? this.order,
      stagger: stagger ?? this.stagger,
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      kind: kind ?? this.kind,
      seed: seed ?? this.seed,
    );
  }

  /// total = (N-1)*s + d
  Duration totalFor(int n) {
    final units = n < 1 ? 1 : n;
    return stagger * (units - 1) + duration;
  }

  /// SAIDA = ENTRADA invertida: inverte a ordem e a direcao do
  /// deslizamento. Ninguem quer montar a saida de novo.
  TextRecipe mirrored() {
    return copyWith(
      kind: RecipeKind.saida,
      order: switch (order) {
        RecipeOrder.start => RecipeOrder.end,
        RecipeOrder.end => RecipeOrder.start,
        RecipeOrder.center => RecipeOrder.edges,
        RecipeOrder.edges => RecipeOrder.center,
        RecipeOrder.random => RecipeOrder.random,
      },
      steps: [
        for (final s in steps)
          s.ingredient == RecipeIngredient.deslizar
              ? s.copyWith(angleDeg: s.angleDeg + 180)
              : s,
      ],
    );
  }
}

SelectorBasedOn _basedOn(RecipeUnit u) => switch (u) {
      RecipeUnit.character => SelectorBasedOn.characters,
      RecipeUnit.word => SelectorBasedOn.words,
      RecipeUnit.line => SelectorBasedOn.lines,
      RecipeUnit.all => SelectorBasedOn.characters,
    };

SelectorOrder _selectorOrder(RecipeOrder o) => switch (o) {
      RecipeOrder.start => SelectorOrder.identity,
      RecipeOrder.end => SelectorOrder.inverse,
      RecipeOrder.center => SelectorOrder.center,
      RecipeOrder.edges => SelectorOrder.edges,
      RecipeOrder.random => SelectorOrder.random,
    };

/// Propriedades do animador para os ingredientes da receita.
List<AnimatorProperty> _propertiesOf(TextRecipe r) {
  final out = <AnimatorProperty>[];
  for (final s in r.steps) {
    switch (s.ingredient) {
      case RecipeIngredient.aparecer:
      case RecipeIngredient.digitar:
        out.add(AnimatorProperty(
            type: TextAnimProp.opacity, value: AnimatedDouble(0)));
      case RecipeIngredient.deslizar:
        final rad = s.angleDeg * math.pi / 180;
        final dx = math.cos(rad) * s.amount;
        final dy = math.sin(rad) * s.amount;
        if (dx.abs() > 1e-9) {
          out.add(AnimatorProperty(
              type: TextAnimProp.positionX, value: AnimatedDouble(dx)));
        }
        if (dy.abs() > 1e-9) {
          out.add(AnimatorProperty(
              type: TextAnimProp.positionY, value: AnimatedDouble(dy)));
        }
      case RecipeIngredient.escalar:
        out.add(AnimatorProperty(
            type: TextAnimProp.scale, value: AnimatedDouble(s.amount)));
      case RecipeIngredient.girar:
        out.add(AnimatorProperty(
            type: TextAnimProp.rotation, value: AnimatedDouble(s.amount)));
      case RecipeIngredient.espacar:
        out.add(AnimatorProperty(
            type: TextAnimProp.tracking, value: AnimatedDouble(s.amount)));
    }
  }
  return out;
}

/// Cobertura que a receita PROMETE para a unidade [i] de [n] em [t]:
///
///     c_i(t) = 1 - clamp( (t - i*s) / d , 0, 1 )
///
/// Cobertura 1 = unidade no estado de partida (escondida/deslocada);
/// 0 = no estado normal. E a leitura direta de "a unidade i comeca em
/// i*s e leva d" — sem seletor nenhum no meio.
double recipeCoverageAt(TextRecipe r, int i, int n, Duration t) {
  if (n <= 0) return 0;
  final idx = orderMapIndex(_selectorOrder(r.order), i, n, r.seed);
  final s = r.stagger.inMicroseconds;
  final d = r.duration.inMicroseconds;
  final startUs = idx * s;
  final tUs = t.inMicroseconds;
  if (d <= 0) return tUs >= startUs ? 0.0 : 1.0;
  final p = ((tUs - startUs) / d).clamp(0.0, 1.0);
  return 1 - p;
}

/// COMPILA a receita para o motor de animadores (PR-R2).
///
/// Derivacao, com p_i = (idx + 0.5)/N a posicao que o motor usa:
///
///     queremos  c_i = 1 - (t - i*s)/d
///     com rampa ASCENDENTE numa janela [lo, lo+w]:  c_i = (p_i - lo)/w
///     => coeficiente de i:  w*s/d = 1/N   =>   w = d / (N*s)
///     => constante:         lo(t) = 0.5/N - w + (w/d)*t   (LINEAR em t)
///
/// Por isso o offset varre LINEARMENTE e a curva do usuario vai no
/// ease do seletor: e o que mantem o espacamento entre unidades intacto.
TextAnimator compileRecipe(TextRecipe r, int unitCount) {
  final n = unitCount < 1 ? 1 : unitCount;
  final ease = recipeCurveEase(r.curve);
  final props = _propertiesOf(r);
  final d = r.duration.inMicroseconds.toDouble();
  final s = r.stagger.inMicroseconds.toDouble();
  final based =
      r.unit == RecipeUnit.all ? SelectorBasedOn.characters : _basedOn(r.unit);

  // DEGENERADO: tudo junto (s = 0, ou uma unidade so). Sem varredura —
  // a cobertura e uniforme e cai de 1 a 0 pelo proprio amount.
  if (s <= 0 || n <= 1 || r.unit == RecipeUnit.all) {
    final total = d <= 0 ? 1 : d;
    return TextAnimator(
      name: r.name,
      allowOvershoot: ease.overshoot,
      selectors: [
        RangeSelector(
          basedOn: based,
          shape: SelectorShape.square,
          start: AnimatedDouble(0),
          end: AnimatedDouble(1),
          smoothness: AnimatedDouble(0),
          easeHigh: AnimatedDouble(ease.high),
          easeLow: AnimatedDouble(ease.low),
          amount: AnimatedDouble(100)
              .withKeyframe(Duration.zero, 100)
              .withKeyframe(
                  Duration(microseconds: total.round()), 0),
        ),
      ],
      properties: props,
    );
  }

  // Largura da janela e varredura linear da borda.
  // DEGENERADO: d = 0 -> janela infinitesimal = degrau (maquina de
  // escrever): a unidade liga de uma vez, em sequencia.
  final w = d <= 0 ? 1e-6 : d / (n * s);
  final total = (n - 1) * s + d;
  final loStart = 0.5 / n - w;
  final loEnd = 1 - 0.5 / n;

  return TextAnimator(
    name: r.name,
    allowOvershoot: ease.overshoot,
    selectors: [
      RangeSelector(
        basedOn: based,
        order: _selectorOrder(r.order),
        randomSeed: r.seed,
        shape: SelectorShape.rampUp,
        // Quem ainda nao foi alcancado permanece no estado de partida.
        holdBeyond: true,
        start: AnimatedDouble(0),
        end: AnimatedDouble(w),
        offset: AnimatedDouble(loStart)
            .withKeyframe(Duration.zero, loStart)
            .withKeyframe(Duration(microseconds: total.round()), loEnd),
        easeHigh: AnimatedDouble(ease.high),
        easeLow: AnimatedDouble(ease.low),
      ),
    ],
    properties: props,
  );
}

/// BIBLIOTECA (PR-R5): receitas sao DADOS, nao codigo.
abstract final class RecipeLibrary {
  static const entrada = <TextRecipe>[
    TextRecipe(
      name: 'Apple',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 12, angleDeg: 90),
      ],
      unit: RecipeUnit.word,
      stagger: Duration(milliseconds: 40),
      duration: Duration(milliseconds: 700),
      curve: RecipeCurve.desaceleracaoLonga,
    ),
    TextRecipe(
      name: 'Maquina de escrever',
      steps: [RecipeStep(RecipeIngredient.digitar)],
      unit: RecipeUnit.character,
      stagger: Duration(milliseconds: 60),
      duration: Duration.zero,
      curve: RecipeCurve.linear,
    ),
    TextRecipe(
      name: 'Pop elastico',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.escalar, amount: 40),
      ],
      unit: RecipeUnit.character,
      stagger: Duration(milliseconds: 35),
      duration: Duration(milliseconds: 600),
      curve: RecipeCurve.mola,
    ),
    TextRecipe(
      name: 'Chicote',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 200, angleDeg: 0),
      ],
      unit: RecipeUnit.word,
      stagger: Duration(milliseconds: 50),
      duration: Duration(milliseconds: 500),
      curve: RecipeCurve.desaceleracaoForte,
    ),
    TextRecipe(
      name: 'Do centro',
      steps: [
        RecipeStep(RecipeIngredient.escalar),
        RecipeStep(RecipeIngredient.aparecer),
      ],
      unit: RecipeUnit.character,
      order: RecipeOrder.center,
      stagger: Duration(milliseconds: 30),
      duration: Duration(milliseconds: 800),
      curve: RecipeCurve.elastica,
    ),
    TextRecipe(
      name: 'Cascata',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 40, angleDeg: 90),
      ],
      unit: RecipeUnit.character,
      stagger: Duration(milliseconds: 25),
      duration: Duration(milliseconds: 500),
      curve: RecipeCurve.suave,
    ),
    TextRecipe(
      name: 'Espacar',
      steps: [
        RecipeStep(RecipeIngredient.espacar, amount: 40),
        RecipeStep(RecipeIngredient.aparecer),
      ],
      unit: RecipeUnit.all,
      stagger: Duration.zero,
      duration: Duration(milliseconds: 900),
      curve: RecipeCurve.desaceleracaoLonga,
    ),
    TextRecipe(
      name: 'Domino',
      steps: [
        RecipeStep(RecipeIngredient.girar, amount: 90),
        RecipeStep(RecipeIngredient.aparecer),
      ],
      unit: RecipeUnit.character,
      stagger: Duration(milliseconds: 45),
      duration: Duration(milliseconds: 550),
      curve: RecipeCurve.mola,
    ),
    TextRecipe(
      name: 'Linha a linha',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 30, angleDeg: 90),
      ],
      unit: RecipeUnit.line,
      stagger: Duration(milliseconds: 120),
      duration: Duration(milliseconds: 600),
      curve: RecipeCurve.desaceleracao,
    ),
    TextRecipe(
      name: 'Desembaralhar',
      steps: [RecipeStep(RecipeIngredient.aparecer)],
      unit: RecipeUnit.character,
      order: RecipeOrder.random,
      stagger: Duration(milliseconds: 30),
      duration: Duration(milliseconds: 400),
      curve: RecipeCurve.suave,
    ),
    TextRecipe(
      name: 'Subir com desfoque',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 60, angleDeg: 90),
      ],
      unit: RecipeUnit.word,
      stagger: Duration(milliseconds: 60),
      duration: Duration(milliseconds: 800),
      curve: RecipeCurve.desaceleracaoLonga,
    ),
    TextRecipe(
      name: 'Explodir para dentro',
      steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.escalar, amount: 300),
      ],
      unit: RecipeUnit.character,
      order: RecipeOrder.random,
      stagger: Duration(milliseconds: 20),
      duration: Duration(milliseconds: 600),
      curve: RecipeCurve.desaceleracao,
    ),
  ];
}
