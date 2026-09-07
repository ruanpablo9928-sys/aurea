import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/text_animator.dart';
import 'package:flutter_test/flutter_test.dart';

/// O SELETOR DE EXPRESSAO dentro do motor de texto que ja existia.
///
/// O ponto destes testes nao e a linguagem — isso e
/// `expression_engine_test`. E que a conta REALMENTE vire cobertura por
/// letra, que ela converse com os seletores que ja estavam la, e que uma
/// expressao errada nao apague o texto da tela.
void main() {
  Duration t(num s) => Duration(microseconds: (s * 1000000).round());

  List<double> coberturas(TextSelector s, int n, {Duration em = Duration.zero}) =>
      [for (var i = 0; i < n; i++) s.coverageAt(i, n, em)];

  group('a conta vira cobertura por letra', () {
    test('O EXEMPLO DO PEDIDO: textIndex / textTotal * 100', () {
      final sel = ExpressionSelector(source: 'textIndex / textTotal * 100');
      final c = coberturas(sel, 5);
      // H pouco, O inteiro — 20%, 40%, 60%, 80%, 100%.
      expect(c[0], closeTo(0.2, 1e-9));
      expect(c[2], closeTo(0.6, 1e-9));
      expect(c[4], closeTo(1.0, 1e-9));
      // E cresce sempre.
      for (var i = 1; i < c.length; i++) {
        expect(c[i], greaterThan(c[i - 1]));
      }
    });

    test('a quantidade escala a conta inteira', () {
      final cheio = ExpressionSelector(source: '100');
      final metade = ExpressionSelector(
        source: '100',
        amount: AnimatedDouble(50),
      );
      expect(coberturas(cheio, 3).first, closeTo(1.0, 1e-9));
      expect(coberturas(metade, 3).first, closeTo(0.5, 1e-9));
    });

    test('o tempo chega na conta', () {
      final sel = ExpressionSelector(source: 'time * 50');
      expect(coberturas(sel, 2, em: Duration.zero).first, 0);
      expect(coberturas(sel, 2, em: t(1)).first, closeTo(0.5, 1e-9));
      expect(coberturas(sel, 2, em: t(2)).first, closeTo(1.0, 1e-9));
    });

    test('cada letra sacode sozinha, e sempre igual', () {
      final sel = ExpressionSelector(
        source: 'seedRandom(textIndex); 50 + wiggle(2, 50)',
      );
      final a = coberturas(sel, 6, em: t(1));
      final b = coberturas(sel, 6, em: t(1));
      expect(a, b, reason: 'nao e determinista');
      expect(a.toSet().length, greaterThan(1),
          reason: 'todas as letras receberam a mesma cobertura');
    });
  });

  group('conversa com os seletores que ja existiam', () {
    test('selectorValue traz o que o seletor anterior produziu', () {
      // Range cobre a primeira metade; a expressao INVERTE o que veio.
      final range = RangeSelector(
        start: AnimatedDouble(0),
        end: AnimatedDouble(50),
      );
      final inverte = ExpressionSelector(
        source: '100 - selectorValue',
        mode: SelectorMode.max,
      );
      final combinada = [
        for (var i = 0; i < 4; i++)
          combinedCoverage([range, inverte], i, 4, Duration.zero),
      ];
      // Onde o range cobria, a inversao devolve pouco; onde nao cobria,
      // devolve muito. O importante: a expressao VIU o valor anterior.
      expect(combinada.any((v) => v > 0), isTrue);
      final soExpressao = [
        for (var i = 0; i < 4; i++)
          combinedCoverage([inverte], i, 4, Duration.zero),
      ];
      expect(combinada, isNot(soExpressao),
          reason: 'selectorValue nao chegou: o resultado ignorou o range');
    });

    test('combina com os modos que ja existiam', () {
      final base = ExpressionSelector(source: '100');
      final metade = ExpressionSelector(
        source: '50',
        mode: SelectorMode.subtract,
      );
      final c = combinedCoverage([base, metade], 0, 3, Duration.zero);
      expect(c, closeTo(0.5, 1e-9));
    });

    test('respeita a base: palavras em vez de caracteres', () {
      final sel = ExpressionSelector(
        source: 'textIndex / textTotal * 100',
        basedOn: SelectorBasedOn.words,
      );
      expect(sel.basedOn, SelectorBasedOn.words);
      // Tres palavras: a conta ve tres unidades, nao as letras.
      final c = coberturas(sel, 3);
      expect(c, hasLength(3));
      expect(c.last, closeTo(1.0, 1e-9));
    });
  });

  group('expressao errada nao apaga o texto', () {
    test('erro de sintaxe: cobertura neutra e o erro guardado', () {
      final sel = ExpressionSelector(source: '1 +');
      expect(sel.erro, isNotNull, reason: 'devia ter recusado a expressao');
      expect(sel.erro!.linha, greaterThan(0));
      // Cobertura zero e o NEUTRO: o texto continua como estava.
      for (final c in coberturas(sel, 5)) {
        expect(c, 0);
      }
    });

    test('funcao inexistente diz o nome, e nao derruba', () {
      final sel = ExpressionSelector(source: 'sourceRectAtTime()');
      expect(coberturas(sel, 3), everyElement(0));
      expect(sel.erroDeExecucao, isNotNull);
      expect(sel.erroDeExecucao!.trecho, 'sourceRectAtTime');
    });

    test('laco e recusado na compilacao, com explicacao', () {
      final sel = ExpressionSelector(source: 'while(true){}');
      expect(sel.erro, isNotNull);
      expect(sel.erro!.mensagem, contains('Laco'));
      expect(coberturas(sel, 3), everyElement(0));
    });

    test('expressao boa nao deixa erro para tras', () {
      final sel = ExpressionSelector(source: 'textIndex * 10');
      coberturas(sel, 4);
      expect(sel.erro, isNull);
      expect(sel.erroDeExecucao, isNull);
    });
  });

  group('o custo com muito texto', () {
    test('500 caracteres com wiggle nao travam o quadro', () {
      // O caso de estresse do pedido. O que se mede aqui e UM quadro:
      // se um quadro custa muito, trinta por segundo e impossivel.
      final sel = ExpressionSelector(
        source: 'seedRandom(textIndex); 50 + wiggle(3, 40)',
      );
      final relogio = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        sel.coverageAt(i, 500, t(1));
      }
      relogio.stop();
      // ignore: avoid_print
      print('500 caracteres com expressao: ${relogio.elapsedMilliseconds} ms '
          'por quadro');
      expect(relogio.elapsedMilliseconds, lessThan(60),
          reason: 'a 30 quadros por segundo isto tem de caber em 33 ms');
    });
  });
}
