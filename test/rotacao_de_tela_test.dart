import 'dart:math' as math;

import 'package:aurea/src/features/editor/domain/rotacao_de_tela.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:flutter_test/flutter_test.dart';

/// O MESMO GIRO EM TODO LUGAR.
///
/// O beta pareou um texto 3D e um sistema de partículas ao mesmo nulo e
/// girou o nulo: um inclinou para um lado, o outro para o outro. O palco
/// gira texto com uma Matrix4 em que +Z é perto; os pintores giram à mão
/// num mundo em que +Z é longe. A matriz é a mesma — o sentido do Z é
/// que espelha o giro. Este teste fixa que, depois do espelho, o que os
/// pintores desenham é o que o palco desenha.
void main() {
  /// O topo de um cartão (y para cima é negativo na tela).
  const topo = (x: 0.0, y: -1.0, z: 0.0);

  test('girar em X leva o topo para o MESMO lado que o palco', () {
    // No palco: rotateX(+30°) sobre o topo.
    final m = Matrix4.identity()..rotateX(30 * math.pi / 180);
    final palco = m.transform3(Vector3(topo.x, topo.y, topo.z));

    // Nos pintores (Z para longe), com o espelho aplicado.
    final pintor = girarComoOPalco(topo.x, topo.y, topo.z, 30, 0);

    // A altura na tela bate.
    expect(pintor.y, closeTo(palco.y, 1e-9));
    // E a PROFUNDIDADE tambem — lembrando que o pintor conta +Z como
    // longe e o palco como perto: o mesmo lado e o sinal OPOSTO.
    expect(pintor.z, closeTo(-palco.z, 1e-9));
    // Sem o espelho, o topo iria para o lado contrario: e o bug.
    expect(pintor.z * palco.z, lessThan(0));
  });

  test('girar em Y leva a lateral para o mesmo lado que o palco', () {
    const direita = (x: 1.0, y: 0.0, z: 0.0);
    final m = Matrix4.identity()..rotateY(40 * math.pi / 180);
    final palco = m.transform3(Vector3(direita.x, direita.y, direita.z));
    final pintor = girarComoOPalco(direita.x, direita.y, direita.z, 0, 40);
    expect(pintor.x, closeTo(palco.x, 1e-9));
    expect(pintor.z, closeTo(-palco.z, 1e-9));
  });

  test('X depois Y, na ordem do palco', () {
    // O palco aplica rotateY(ry)..rotateX(rx) a matriz — o vetor recebe
    // X primeiro. Os pintores fazem o mesmo. Um giro composto tem de
    // bater ponto a ponto, nao so eixo a eixo.
    final m = Matrix4.identity()
      ..rotateY(25 * math.pi / 180)
      ..rotateX(-15 * math.pi / 180);
    final p = Vector3(0.3, -0.8, 0.2);
    final palco = m.transform3(p.clone());
    // O ESPELHO VALE NA ENTRADA E NA SAIDA: o mesmo ponto do palco, no
    // mundo dos pintores, tem o Z trocado — e volta com o Z trocado.
    final pintor = girarComoOPalco(p.x, p.y, -p.z, -15, 25);
    expect(pintor.x, closeTo(palco.x, 1e-9));
    expect(pintor.y, closeTo(palco.y, 1e-9));
    expect(pintor.z, closeTo(-palco.z, 1e-9));
  });

  test('sem giro, nada muda', () {
    final r = girarComoOPalco(0.5, -0.25, 0.75, 0, 0);
    expect(r.x, 0.5);
    expect(r.y, -0.25);
    expect(r.z, 0.75);
  });
}
