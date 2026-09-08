import 'dart:math' as math;

/// O GIRO 3D DO PALCO, num lugar só.
///
/// O palco desenha texto, forma e vídeo com uma `Matrix4` que tem
/// perspectiva no termo (3,2) = -1/1200: ali **+Z é perto** do olho. Os
/// pintores de partículas e de objeto 3D fazem a conta à mão e tratam
/// **+Z como longe** (`persp = f / (f + z)`). A matriz de rotação é a
/// mesma nos dois — só o sentido do Z é oposto.
///
/// Espelhar um eixo conjuga a rotação: girar +θ em X num mundo com Z
/// para longe é a MESMA imagem que girar -θ em X num mundo com Z para
/// perto. Então o mesmo giro de um nulo, herdado por um texto e por um
/// sistema de partículas, inclinava cada um para um lado — foi o "um
/// rotaciona pra um lado e o outro pro outro" do beta, e é exatamente
/// isso que este arquivo fecha: os pintores passam a usar o ângulo já
/// espelhado, e o giro vira o mesmo em todo lugar.
///
/// Z (giro no plano da tela) não muda de sentido com o espelho e fica
/// como está.

/// O sinal que leva um ângulo em graus do palco para o mundo dos
/// pintores. Um só número, para o dia em que os pintores passarem a
/// desenhar com +Z para perto — aí ele vira +1 e nada mais muda.
const double espelhoDoPalco = -1;

/// Ângulo X em radianos, já no sentido dos pintores.
double rxDoPalco(double rotXDeg) => rotXDeg * espelhoDoPalco * math.pi / 180;

/// Ângulo Y em radianos, já no sentido dos pintores.
double ryDoPalco(double rotYDeg) => rotYDeg * espelhoDoPalco * math.pi / 180;

/// Gira um ponto do jeito dos pintores (X depois Y), com os ângulos já
/// espelhados. Devolve (x, y, z) com +Z para longe — a convenção deles.
({double x, double y, double z}) girarComoOPalco(
  double x,
  double y,
  double z,
  double rotXDeg,
  double rotYDeg,
) {
  final rx = rxDoPalco(rotXDeg), ry = ryDoPalco(rotYDeg);
  final cxr = math.cos(rx), sxr = math.sin(rx);
  final cyr = math.cos(ry), syr = math.sin(ry);
  final y1 = y * cxr - z * sxr;
  final z1 = y * sxr + z * cxr;
  final x1 = x * cyr + z1 * syr;
  final z2 = -x * syr + z1 * cyr;
  return (x: x1, y: y1, z: z2);
}
