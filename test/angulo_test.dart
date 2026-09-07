import 'package:aurea/src/features/editor/domain/angulo.dart';
import 'package:flutter_test/flutter_test.dart';

/// O DIAL E UM CONTADOR. Duas contas separam um mostrador de -180..180
/// de um valor que da voltas: o delta desenrolado entre duas leituras
/// do dedo, e o angulo absoluto escrito na volta em que a camada esta.
void main() {
  group('deltaDeAngulo', () {
    test('cruzar a esquerda por cima e +20, nao -340', () {
      expect(deltaDeAngulo(170, -170), closeTo(20, 1e-9));
      expect(deltaDeAngulo(-170, 170), closeTo(-20, 1e-9));
    });

    test('passos pequenos sao eles mesmos', () {
      expect(deltaDeAngulo(10, 15), closeTo(5, 1e-9));
      expect(deltaDeAngulo(15, 10), closeTo(-5, 1e-9));
      expect(deltaDeAngulo(350, 10), closeTo(20, 1e-9));
    });

    test('meia volta exata vai para o lado positivo', () {
      expect(deltaDeAngulo(0, 180), closeTo(180, 1e-9));
      expect(deltaDeAngulo(0, -180), closeTo(180, 1e-9));
    });

    test('somando os deltas de uma volta inteira da 360', () {
      var acumulado = 0.0;
      var anterior = 0.0;
      for (var a = 10.0; a <= 360; a += 10) {
        final lido = a > 180 ? a - 360 : a; // o que atan2 devolveria
        acumulado += deltaDeAngulo(anterior, lido);
        anterior = lido;
      }
      expect(acumulado, closeTo(360, 1e-9));
    });
  });

  group('anguloMaisProximo', () {
    test('mantem a volta em que a camada esta', () {
      expect(anguloMaisProximo(10, 725), 730);
      expect(anguloMaisProximo(-170, 200), 190);
      expect(anguloMaisProximo(170, -200), -190);
    });

    test('sem voltas, e o proprio angulo', () {
      expect(anguloMaisProximo(0, 0), 0);
      expect(anguloMaisProximo(90, 100), 90);
      expect(anguloMaisProximo(-90, -100), -90);
    });
  });
}
