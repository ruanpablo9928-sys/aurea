import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/domain/keyframe.dart';

void main() {
  group('AnimatedDouble', () {
    test('sem keyframes devolve o valor base', () {
      final prop = AnimatedDouble(2.5);
      expect(prop.valueAt(const Duration(seconds: 3)), 2.5);
      expect(prop.isAnimated, false);
    });

    test('interpola linearmente entre dois keyframes', () {
      final prop = AnimatedDouble(0)
          .withKeyframe(Duration.zero, 0, Easing.linear)
          .withKeyframe(const Duration(seconds: 2), 100, Easing.linear);
      expect(prop.valueAt(const Duration(seconds: 1)), closeTo(50, 0.001));
    });

    test('segura o valor antes do primeiro e depois do ultimo keyframe', () {
      final prop = AnimatedDouble(0)
          .withKeyframe(const Duration(seconds: 1), 10)
          .withKeyframe(const Duration(seconds: 2), 20);
      expect(prop.valueAt(Duration.zero), 10);
      expect(prop.valueAt(const Duration(seconds: 5)), 20);
    });

    test('busca binaria acha o segmento certo com varios keyframes', () {
      var prop = AnimatedDouble(0);
      for (var s = 0; s <= 10; s++) {
        prop = prop.withKeyframe(
            Duration(seconds: s), s * 10.0, Easing.linear);
      }
      expect(prop.valueAt(const Duration(milliseconds: 7500)),
          closeTo(75, 0.001));
    });

    test('keyframe no mesmo frame substitui o anterior', () {
      final prop = AnimatedDouble(0)
          .withKeyframe(const Duration(seconds: 1), 10)
          .withKeyframe(const Duration(seconds: 1), 99);
      expect(prop.keyframes.length, 1);
      expect(prop.valueAt(const Duration(seconds: 1)), 99);
    });

    test('remover o ultimo keyframe congela o valor atual como base', () {
      final prop = AnimatedDouble(0)
          .withKeyframe(const Duration(seconds: 1), 42);
      final still = prop.withoutKeyframe(const Duration(seconds: 1));
      expect(still.isAnimated, false);
      expect(still.valueAt(Duration.zero), 42);
    });

    test('edited: editar valor NUNCA cria keyframe', () {
      // A regra do produto, acima da convencao do After Effects
      // (`docs/keyframe-explicito.md`). Este teste ja afirmou o
      // contrario — era ele que guardava o defeito.
      final estatica = AnimatedDouble(1).edited(const Duration(seconds: 1), 5);
      expect(estatica.isAnimated, false);
      expect(estatica.base, 5, reason: 'sem marca, editar muda a base');

      final animada = AnimatedDouble(1).withKeyframe(Duration.zero, 1);

      final fora = animada.edited(const Duration(seconds: 1), 5);
      expect(
        fora.keyframes.length,
        1,
        reason: 'animada e FORA de marca: a trilha volta intacta',
      );
      expect(fora.valueAt(const Duration(seconds: 1)), 1);

      final emCima = animada.edited(Duration.zero, 5);
      expect(
        emCima.keyframes.length,
        1,
        reason: 'animada e SOBRE a marca: atualiza, nao duplica',
      );
      expect(emCima.keyframes.single.value, 5);
    });

    test('edited preserva a curva da marca que atualiza', () {
      // O keyframe recem-nascido entrava LINEAR, porque `easeAt`
      // devolve linear quando nao ha marca ali — alem de nascer
      // sozinho, ele achatava a interpolacao ao redor.
      final animada = AnimatedDouble(0)
          .withKeyframe(Duration.zero, 0, Easing.easeInOut)
          .withKeyframe(const Duration(seconds: 2), 10, Easing.easeOut);
      final depois = animada.edited(Duration.zero, 7);
      expect(depois.keyframes.first.ease, Easing.easeInOut);
      expect(depois.keyframes.first.value, 7);
    });

    test('aceitaEdicaoEm diz quando o valor chega ao projeto', () {
      final estatica = AnimatedDouble(1);
      expect(estatica.aceitaEdicaoEm(const Duration(seconds: 1)), isTrue);

      final animada = AnimatedDouble(1).withKeyframe(Duration.zero, 1);
      expect(animada.aceitaEdicaoEm(Duration.zero), isTrue);
      expect(animada.aceitaEdicaoEm(const Duration(seconds: 1)), isFalse);
    });

    test('AnimatedOffset segue a mesma regra', () {
      final animada = AnimatedOffset(
        Offset.zero,
      ).withKeyframe(Duration.zero, Offset.zero);
      final fora = animada.edited(
        const Duration(seconds: 1),
        const Offset(9, 9),
      );
      expect(fora.keyframes.length, 1);
      expect(fora.valueAt(const Duration(seconds: 1)), Offset.zero);
    });
  });

  group('AnimatedOffset', () {
    test('interpola posicao com easing linear', () {
      final prop = AnimatedOffset(Offset.zero)
          .withKeyframe(Duration.zero, Offset.zero, Easing.linear)
          .withKeyframe(
              const Duration(seconds: 2), const Offset(100, 50), Easing.linear);
      final mid = prop.valueAt(const Duration(seconds: 1));
      expect(mid.dx, closeTo(50, 0.001));
      expect(mid.dy, closeTo(25, 0.001));
    });
  });
}
