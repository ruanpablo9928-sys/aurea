// ABRIR ISOLATE NO CAMINHO DA CENA 3D CUSTA MAIS QUE O TRABALHO.
//
// Medido no iPhone 13, registro do build 69:
//
//     12470 ms   9x  pior 1960 ms   cena 3D: ambiente > abrir isolate
//     12471 ms 309x  pior 1960 ms   cena 3D: sincronizar > ambiente
//
// Os dois totais sao o mesmo numero: abrir o isolate era 100% do custo do
// ambiente. E a parte SINCRONA de `Isolate.run`, no fio que recebe o
// toque, e nao e so a primeira que custa — a media das nove foi 1.385 ms.
//
// O mesmo `Isolate.run` custa 2 ms num desktop, e o calculo que ele
// evitava custa 13-26 ms (`test/bancada_ambiente_test.dart`). Ou seja:
// abrir o isolate saia vinte vezes mais caro do que fazer a conta.
//
// Este teste existe porque a tentacao de "jogar isso para um isolate" e
// grande e a intuicao esta errada aqui. Quatro entregas se passaram ate o
// aparelho conseguir dizer isso.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a ponte da cena 3D nao abre isolate', () {
    final fonte = File(
      'lib/src/features/editor/application/scene3d_gpu.dart',
    ).readAsStringSync();
    // So o que e CODIGO conta; os comentarios explicam justamente por que
    // nao se usa isolate aqui.
    final codigo = fonte
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      codigo.contains('Isolate.run'),
      isFalse,
      reason:
          'voltou a abrir isolate na ponte da cena 3D: no iPhone 13 isso '
          'custa ~1.400 ms sincronos por chamada, contra 13-26 ms do '
          'calculo que ele evita',
    );
    expect(
      codigo.contains('compute('),
      isFalse,
      reason: '`compute` abre um isolate igual; vale a mesma medida',
    );
  });
}
