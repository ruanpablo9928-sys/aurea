import 'package:aurea/src/features/editor/domain/text_animator.dart';
import 'package:aurea/src/features/editor/domain/text_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ordem de ATIVACAO: indices ordenados pelo indice remapeado.
List<int> _activationOrder(SelectorOrder order, int n, {int seed = 1}) {
  final ranked = [
    for (var i = 0; i < n; i++) (orderMapIndex(order, i, n, seed), i),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final r in ranked) r.$2];
}

void main() {
  group('orderMap (PR-R1)', () {
    test('CENTRO com 7 unidades: 3, depois 2 e 4, 1 e 5, 0 e 6', () {
      expect(_activationOrder(SelectorOrder.center, 7),
          [3, 2, 4, 1, 5, 0, 6]);
    });

    test('CENTRO com numero par comeca no par do meio', () {
      expect(_activationOrder(SelectorOrder.center, 4), [1, 2, 0, 3]);
    });

    test('BORDAS e o inverso do centro (meio por ultimo)', () {
      final ordem = _activationOrder(SelectorOrder.edges, 7);
      expect(ordem.last, 3);
      expect(ordem.take(2), containsAll([0, 6]));
    });

    test('identidade e inversa', () {
      expect(_activationOrder(SelectorOrder.identity, 4), [0, 1, 2, 3]);
      expect(_activationOrder(SelectorOrder.inverse, 4), [3, 2, 1, 0]);
    });

    test('todas as ordens sao PERMUTACOES (nenhuma unidade some)', () {
      for (final o in SelectorOrder.values) {
        for (final n in [1, 2, 5, 7, 12]) {
          final vistos = {
            for (var i = 0; i < n; i++) orderMapIndex(o, i, n, 7),
          };
          expect(vistos.length, n, reason: '$o com n=$n');
          expect(vistos.reduce((a, b) => a > b ? a : b), n - 1);
        }
      }
    });
  });

  group('compilacao da receita (PR-R2)', () {
    const r = TextRecipe(
      steps: [RecipeStep(RecipeIngredient.aparecer)],
      unit: RecipeUnit.character,
      stagger: Duration(milliseconds: 40),
      duration: Duration(milliseconds: 700),
      curve: RecipeCurve.linear,
    );

    test('FIDELIDADE: receita avaliada direto == rig compilado', () {
      const n = 9;
      final rig = compileRecipe(r, n);
      final total = r.totalFor(n);
      for (var step = 0; step <= 40; step++) {
        final t = total * (step / 40);
        for (var i = 0; i < n; i++) {
          final direta = recipeCoverageAt(r, i, n, t);
          final compilada = rig.coverageAt(i, n, t);
          expect(compilada, closeTo(direta, 1e-9),
              reason: 'unidade $i em ${t.inMilliseconds}ms');
        }
      }
    });

    test('fidelidade tambem com ordem CENTRO e unidades pares', () {
      final rc = r.copyWith(order: RecipeOrder.center);
      const n = 8;
      final rig = compileRecipe(rc, n);
      final total = rc.totalFor(n);
      for (var step = 0; step <= 20; step++) {
        final t = total * (step / 20);
        for (var i = 0; i < n; i++) {
          expect(rig.coverageAt(i, n, t),
              closeTo(recipeCoverageAt(rc, i, n, t), 1e-9));
        }
      }
    });

    test('cada unidade parte de 1 e chega a 0 no tempo certo', () {
      const n = 5;
      final rig = compileRecipe(r, n);
      // Unidade 2 comeca em 2*40 = 80 ms e leva 700 ms.
      expect(rig.coverageAt(2, n, const Duration(milliseconds: 80)),
          closeTo(1, 1e-9));
      expect(rig.coverageAt(2, n, const Duration(milliseconds: 430)),
          closeTo(0.5, 1e-9));
      expect(rig.coverageAt(2, n, const Duration(milliseconds: 780)),
          closeTo(0, 1e-9));
      // Antes da vez dela, continua inteira no estado de partida.
      expect(rig.coverageAt(4, n, Duration.zero), closeTo(1, 1e-9));
      // E no fim de tudo, ninguem ficou para tras.
      final fim = r.totalFor(n);
      for (var i = 0; i < n; i++) {
        expect(rig.coverageAt(i, n, fim), closeTo(0, 1e-9));
      }
    });

    test('s = d: a janela cobre exatamente um espacamento', () {
      final rr = r.copyWith(
          stagger: const Duration(milliseconds: 300),
          duration: const Duration(milliseconds: 300));
      const n = 6;
      final sel = compileRecipe(rr, n).selectors.first as RangeSelector;
      // w = d/(N*s) = 1/N = um espacamento de unidade.
      expect(sel.end.valueAt(Duration.zero), closeTo(1 / n, 1e-12));
    });

    test('d = 0: maquina de escrever, cada unidade liga de uma vez', () {
      final tw = r.copyWith(duration: Duration.zero);
      const n = 5;
      final rig = compileRecipe(tw, n);
      // Unidade 2 liga em 80 ms: antes cheia, depois zerada.
      expect(rig.coverageAt(2, n, const Duration(milliseconds: 79)),
          closeTo(1, 0.02));
      expect(rig.coverageAt(2, n, const Duration(milliseconds: 81)),
          closeTo(0, 0.02));
    });

    test('s = 0: todas as unidades ao mesmo tempo', () {
      final junto = r.copyWith(stagger: Duration.zero);
      const n = 7;
      final rig = compileRecipe(junto, n);
      final meio = const Duration(milliseconds: 350);
      final c0 = rig.coverageAt(0, n, meio);
      for (var i = 1; i < n; i++) {
        expect(rig.coverageAt(i, n, meio), closeTo(c0, 1e-9));
      }
      expect(c0, closeTo(0.5, 0.02));
    });

    test('N = 1 cai no caso "tudo junto"', () {
      final rig = compileRecipe(r, 1);
      expect(rig.coverageAt(0, 1, Duration.zero), closeTo(1, 1e-9));
      expect(rig.coverageAt(0, 1, const Duration(milliseconds: 700)),
          closeTo(0, 1e-9));
    });

    test('a curva NAO vai para o offset (espacamento intacto)', () {
      final lin = compileRecipe(r, 6).selectors.first as RangeSelector;
      final mola = compileRecipe(r.copyWith(curve: RecipeCurve.mola), 6)
          .selectors
          .first as RangeSelector;
      // Mesmos keyframes de offset; so o ease muda.
      for (var k = 0; k < lin.offset.keyframes.length; k++) {
        expect(mola.offset.keyframes[k].value,
            closeTo(lin.offset.keyframes[k].value, 1e-12));
      }
      expect(mola.easeHigh.valueAt(Duration.zero),
          isNot(lin.easeHigh.valueAt(Duration.zero)));
    });

    test('ingredientes viram propriedades do animador', () {
      const combo = TextRecipe(steps: [
        RecipeStep(RecipeIngredient.aparecer),
        RecipeStep(RecipeIngredient.deslizar, amount: 12, angleDeg: 90),
        RecipeStep(RecipeIngredient.escalar, amount: 40),
      ]);
      final props = compileRecipe(combo, 5).properties;
      final tipos = props.map((p) => p.type).toSet();
      expect(tipos, contains(TextAnimProp.opacity));
      expect(tipos, contains(TextAnimProp.positionY));
      expect(tipos, contains(TextAnimProp.scale));
      // Deslizar de baixo: so Y, sem X.
      expect(tipos, isNot(contains(TextAnimProp.positionX)));
    });
  });

  group('saida espelhada (PR-R7)', () {
    test('inverte ordem e direcao do deslizamento', () {
      const entrada = TextRecipe(
        steps: [RecipeStep(RecipeIngredient.deslizar, amount: 20, angleDeg: 90)],
        order: RecipeOrder.start,
      );
      final saida = entrada.mirrored();
      expect(saida.kind, RecipeKind.saida);
      expect(saida.order, RecipeOrder.end);
      expect(saida.steps.first.angleDeg, 270);
    });
  });

  group('biblioteca (PR-R5)', () {
    test('as 12 receitas de entrada compilam e sao neutras no fim', () {
      expect(RecipeLibrary.entrada.length, 12);
      for (final r in RecipeLibrary.entrada) {
        const n = 7;
        final rig = compileRecipe(r, n);
        expect(rig.properties, isNotEmpty, reason: r.name);
        final fim = r.totalFor(n);
        for (var i = 0; i < n; i++) {
          // I2 (neutralidade): terminada a animacao, nada e alterado.
          expect(rig.coverageAt(i, n, fim), closeTo(0, 0.001),
              reason: '${r.name}, unidade $i');
        }
      }
    });
  });
}
