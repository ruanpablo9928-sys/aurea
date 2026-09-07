/// ANGULOS QUE DAO A VOLTA.
///
/// Um dial que le o dedo por `atan2` recebe um angulo entre -180 e 180.
/// Quem gira a camada quer OUTRA coisa: um valor que cresce enquanto o
/// dedo circula — 350, 360, 370, duas voltas, tres. Com o angulo cru,
/// ao cruzar a esquerda do dial o valor saltava de 180 para -180, e a
/// animacao entre dois keyframes "voltava ate o zero" pelo caminho
/// contrario em vez de completar o circulo. Foi o bug do beta.
///
/// Os dois calculos aqui sao o que separa um mostrador de um contador:
/// o DELTA desenrolado entre duas leituras do dedo, e a representacao
/// de um angulo absoluto mais proxima do valor que a camada ja tem.
library;

/// O menor giro que leva de [de] a [para], em graus, em (-180, 180].
///
/// 170 -> -170 e +20 (cruzou a esquerda por cima), nao -340.
double deltaDeAngulo(double de, double para) {
  var d = (para - de) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

/// [alvo] (um angulo absoluto, -180..180) escrito na volta em que
/// [referencia] esta: tocar no dial a 10 graus com a camada em 725 da
/// 730, nao 10 — a camada nao desanda duas voltas por um toque.
double anguloMaisProximo(double alvo, double referencia) =>
    alvo + 360 * ((referencia - alvo) / 360).round();
