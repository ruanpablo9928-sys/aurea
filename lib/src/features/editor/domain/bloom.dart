import 'dart:math' as math;

/// PIRAMIDE DE BLOOM — a conta que faz o glow ILUMINAR em vez de LAVAR.
///
/// "Conservacao de energia" tem um significado exato aqui: a soma dos
/// pesos dos niveis e 1. Sem isso, acrescentar um nivel para deixar o
/// glow mais suave tambem o deixa mais claro, e a pessoa fica ajustando
/// intensidade para compensar uma suavidade que nao pediu.
///
/// A piramide tambem e o que separa glow de raio grande bom de glow de
/// raio grande ruim: um passe unico com sigma enorme sai quadrado e com
/// banda; varios niveis com sigma dobrando saem lisos.

/// Quantos niveis a qualidade pede.
int bloomLevels(int quality) => switch (quality) {
      0 => 2, // Draft
      2 => 5, // High
      _ => 3, // Normal
    };

/// Pesos NORMALIZADOS de cada nivel, do mais largo ao mais estreito.
///
/// O nivel estreito pesa mais: e ele que da o nucleo brilhante. Os
/// largos dao o halo. A proporcao e geometrica, e a soma e sempre 1.
List<double> bloomWeights(int levels) {
  if (levels <= 0) return const [];
  if (levels == 1) return const [1.0];
  final brutos = <double>[
    for (var i = 0; i < levels; i++) math.pow(1.6, i).toDouble(),
  ];
  final soma = brutos.reduce((a, b) => a + b);
  // Do mais LARGO (peso menor) para o mais estreito (peso maior).
  return [for (final b in brutos) b / soma];
}

/// O sigma de cada nivel, em pixels, para um raio pedido.
///
/// Dobra a cada nivel: e o que cobre um raio grande com poucos passes.
/// O primeiro nivel e o mais largo.
List<double> bloomSigmas(double radiusPx, int levels) {
  if (levels <= 0 || radiusPx <= 0) return const [];
  final out = <double>[];
  for (var i = 0; i < levels; i++) {
    // i = 0 -> o mais largo.
    out.add(radiusPx / math.pow(2, i));
  }
  return out;
}

/// LIMIAR SUAVE: o quanto de um pixel de luminancia [l] entra no glow.
///
/// Um limiar duro cria uma borda visivel onde o brilho cruza o valor —
/// o glow "liga" de repente numa linha reta no meio do degrade. A
/// suavidade transforma o degrau numa rampa.
double bloomThreshold(double l, double threshold, double softness) {
  final duro = math.max(0.0, l - threshold);
  final s = softness.clamp(0.0, 1.0);
  if (s < 1e-6) return duro;

  // JOELHO SUAVE: a curva quadratica classica de bloom. Ela encosta em
  // zero antes do limiar e encosta na reta depois dele — por isso a
  // funcao inteira cresce sem degrau. A primeira versao que escrevi
  // dava um PULO PARA BAIXO na emenda, e o teste de monotonia pegou.
  final joelho = threshold * s;
  var macio = l - threshold + joelho;
  macio = macio.clamp(0.0, 2 * joelho);
  macio = macio * macio / (4 * joelho + 1e-9);
  return math.max(macio, duro);
}

/// EXPOSICAO em paradas (stops), como em fotografia: +1 dobra a luz.
double exposureGain(double stops) => math.pow(2, stops).toDouble();

/// Mapeamento de tom: comprime a luz que passou de 1 sem estourar num
/// branco chapado.
///
/// 0 = ACES Filmic, 1 = Reinhard, 2 = Reinhard 2, 3 = Clamp.
double tonemap(double x, int mode) {
  final v = math.max(0.0, x);
  switch (mode) {
    case 1:
      return v / (1 + v);
    case 2:
      // Reinhard estendido: o branco de referencia mapeia para 1, e
      // acima dele satura. Sem o aparo, a curva passa de 1 e o "tone
      // mapping" deixa de mapear tom.
      const branco = 4.0;
      return (v * (1 + v / (branco * branco)) / (1 + v)).clamp(0.0, 1.0);
    case 3:
      return v.clamp(0.0, 1.0);
    default:
      // ACES aproximado (Narkowicz): a curva de cinema.
      const a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14;
      return ((v * (a * v + b)) / (v * (c * v + d) + e)).clamp(0.0, 1.0);
  }
}
