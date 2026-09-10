// O DIAL: AS VOLTAS SOMAM E O MIOLO NAO INVENTA ANGULO.
//
// Duas regras da especificacao vivem so aqui, porque nenhuma delas
// aparece na tela parada: que passar de 360 continua em 361 (uma volta
// e meia nao e meia volta) e que atravessar a caixa do numero no centro
// NAO conta como giro. O segundo caso ja quebrou uma vez — o dial
// engolia os quadros de dentro do disco surdo mas guardava o angulo de
// antes de entrar, e cobrava a meia volta inteira na saida.
import 'dart:math' as math;

import 'package:aurea/src/features/editor/presentation/widgets/dial_de_angulo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// O DIAL NUM QUADRADO DE LADO CONHECIDO, para o centro do gesto ser
/// uma conta e nao um chute. As posicoes do caminho sao relativas ao
/// centro do dial.
Future<List<double>> _girar(
  WidgetTester tester,
  List<Offset> caminho, {
  double inicial = 0,
}) async {
  final vistos = <double>[];
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: DialDeAngulo(angulo: inicial, aoMudar: vistos.add),
        ),
      ),
    ),
  );
  final centro = tester.getCenter(find.byType(DialDeAngulo));
  final gesto = await tester.startGesture(centro + caminho.first);
  for (final p in caminho.skip(1)) {
    await gesto.moveTo(centro + p);
  }
  await gesto.up();
  await tester.pump();
  return vistos;
}

/// UM ARCO EM PASSOS DE 15 GRAUS. Passos pequenos de proposito: perto de
/// meia volta por quadro o proprio dial teria razao em achar que o dedo
/// foi para o outro lado.
List<Offset> _arco(double deGraus, double ateGraus, {double raio = 80}) {
  final graus = <double>[];
  for (var a = deGraus; a < ateGraus; a += 15) {
    graus.add(a);
  }
  // O FIM ENTRA SEMPRE, mesmo que nao caia num passo redondo: o teste
  // cobra o angulo final, e um arco que para em 390 provaria outra
  // coisa que nao a que esta escrita no nome.
  graus.add(ateGraus);
  return [
    for (final a in graus)
      Offset(math.cos(a * math.pi / 180), math.sin(a * math.pi / 180)) * raio,
  ];
}

void main() {
  testWidgets('o angulo passa de 360 em vez de enrolar', (tester) async {
    final vistos = await _girar(tester, _arco(0, 400));
    expect(vistos.last, closeTo(400, 1));
  });

  testWidgets('o gesto parte do angulo que ja estava na camada', (
    tester,
  ) async {
    final vistos = await _girar(tester, _arco(0, 90), inicial: 720);
    expect(vistos.last, closeTo(810, 1));
  });

  testWidgets('atravessar o miolo nao gira a camada', (tester) async {
    // DA DIREITA PARA A ESQUERDA PASSANDO PELO CENTRO: meia volta de
    // angulo cru, zero de giro real — o dedo andou em linha reta.
    final vistos = await _girar(tester, const [
      Offset(80, 0),
      Offset(40, 0),
      Offset(10, 0),
      Offset(-10, 0),
      Offset(-40, 0),
      Offset(-80, 0),
    ]);
    for (final v in vistos) {
      expect(v.abs(), lessThan(1), reason: 'saltou para $v');
    }
  });

  testWidgets('comecar em cima do numero nao dispara o valor', (tester) async {
    // A CAIXA DO VALOR FICA NO CENTRO e nao pega o toque para si: o
    // arrasto comeca a dois pixels do centro, onde nao ha angulo que
    // valha. Comecar ACIMA do centro e sair pela direita e o caso que
    // pega: sao 90 graus de angulo cru para zero de giro real.
    final vistos = await _girar(tester, const [
      Offset(0, -2),
      Offset(80, 0),
      Offset(80, 4),
    ]);
    for (final v in vistos) {
      expect(v.abs(), lessThan(10), reason: 'saltou para $v');
    }
  });
}
