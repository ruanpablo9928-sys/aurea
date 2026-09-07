import 'package:aurea/src/features/editor/domain/expression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// O MOTOR DE EXPRESSIONS.
///
/// O pedido foi explicito: "nao quero apenas um campo onde o usuario
/// escreve JavaScript e o app ignora". Entao o que estes testes cobram
/// e que a conta REALMENTE controle a propriedade — e que uma conta
/// errada nao derrube nada.
void main() {
  double avaliar(
    String fonte, {
    double time = 0,
    int textIndex = 0,
    int textTotal = 1,
    double selectorValue = 0,
    Object value = 0.0,
  }) {
    final r = avaliarExpressao(
      fonte,
      ExpressionContext(
        time: time,
        textIndex: textIndex,
        textTotal: textTotal,
        selectorValue: selectorValue,
        value: value,
      ),
    );
    expect(r.deuCerto, isTrue, reason: '${r.erro}');
    return r.comoNumero();
  }

  group('a conta basica', () {
    test('numeros, precedencia e parenteses', () {
      expect(avaliar('1 + 2 * 3'), 7);
      expect(avaliar('(1 + 2) * 3'), 9);
      expect(avaliar('10 / 4'), 2.5);
      expect(avaliar('7 % 3'), 1);
      expect(avaliar('-5 + 2'), -3);
      expect(avaliar('2 * -3'), -6);
    });

    test('dividir por zero devolve zero, e nao infinito', () {
      // Infinito atravessa a animacao inteira e reaparece como camada
      // que some sem explicacao.
      expect(avaliar('1 / 0'), 0);
      expect(avaliar('5 % 0'), 0);
    });

    test('comparacao, logica e ternario', () {
      expect(avaliar('3 > 2'), 1);
      expect(avaliar('3 < 2'), 0);
      expect(avaliar('1 && 0'), 0);
      expect(avaliar('1 || 0'), 1);
      expect(avaliar('3 > 2 ? 10 : 20'), 10);
      expect(avaliar('3 < 2 ? 10 : 20'), 20);
    });

    test('variaveis locais', () {
      expect(avaliar('var a = 5; a * 2'), 10);
      expect(avaliar('var a = 2; var b = 3; a * b'), 6);
    });

    test('comentarios nao atrapalham', () {
      expect(avaliar('// nota\n1 + 1'), 2);
      expect(avaliar('1 + /* meio */ 1'), 2);
    });
  });

  group('o vocabulario do After Effects', () {
    test('time, value e index', () {
      expect(avaliar('time', time: 2.5), 2.5);
      expect(avaliar('value + 10', value: 5.0), 15);
      expect(avaliar('time * 30', time: 1), 30);
    });

    test('textIndex conta a partir de 1, como no After Effects', () {
      expect(avaliar('textIndex', textIndex: 0), 1);
      expect(avaliar('textIndex', textIndex: 4), 5);
      expect(avaliar('textTotal', textTotal: 5), 5);
    });

    test('O EXEMPLO DO PEDIDO: textIndex / textTotal * 100', () {
      // "H = pouca influencia ... O = 100%"
      const total = 5;
      final valores = [
        for (var i = 0; i < total; i++)
          avaliar(
            'textIndex / textTotal * 100',
            textIndex: i,
            textTotal: total,
          ),
      ];
      expect(valores, [20, 40, 60, 80, 100]);
    });

    test('selectorValue chega ao alcance da conta', () {
      expect(avaliar('selectorValue', selectorValue: 42), 42);
      expect(avaliar('selectorValue / 2', selectorValue: 80), 40);
    });

    test('clamp, linear, ease', () {
      expect(avaliar('clamp(15, 0, 10)'), 10);
      expect(avaliar('clamp(-3, 0, 10)'), 0);
      expect(avaliar('linear(0.5, 0, 1, 0, 100)'), 100 * 0.5);
      expect(avaliar('linear(2, 0, 1, 0, 100)'), 100, reason: 'fora, prende');
      expect(avaliar('ease(0, 0, 1, 0, 100)'), 0);
      expect(avaliar('ease(1, 0, 1, 0, 100)'), 100);
      // A curva suave passa pelo meio no meio, e sai mais devagar.
      expect(avaliar('ease(0.5, 0, 1, 0, 100)'), closeTo(50, 0.01));
      expect(avaliar('easeIn(0.5, 0, 1, 0, 100)'), lessThan(50));
      expect(avaliar('easeOut(0.5, 0, 1, 0, 100)'), greaterThan(50));
    });

    test('a matematica, com e sem Math.', () {
      expect(avaliar('Math.round(2.6)'), 3);
      expect(avaliar('round(2.4)'), 2);
      expect(avaliar('Math.floor(2.9)'), 2);
      expect(avaliar('Math.abs(-4)'), 4);
      expect(avaliar('Math.max(3, 7)'), 7);
      expect(avaliar('Math.pow(2, 10)'), 1024);
      expect(avaliar('Math.sqrt(16)'), 4);
      expect(avaliar('Math.sin(0)'), 0);
    });

    test('vetores: position + [10, 0] funciona como no AE', () {
      final r = avaliarExpressao(
        'value + [10, 0]',
        ExpressionContext(time: 0, value: [100.0, 50.0]),
      );
      expect(r.deuCerto, isTrue, reason: '${r.erro}');
      expect(r.valor, [110.0, 50.0]);
    });

    test('texto procedural: "Frame: " + Math.round(time * 30)', () {
      final r = avaliarExpressao(
        '"Frame: " + Math.round(time * 30)',
        ExpressionContext(time: 2.0),
      );
      expect(r.valor, 'Frame: 60');
    });
  });

  group('o aleatorio e determinista', () {
    // Sem isto, animacao aleatoria e irreproduzivel: a exportacao nao
    // bate com o preview e abrir o projeto amanha da outro filme.
    test('a mesma semente da o mesmo numero, sempre', () {
      final a = avaliar('seedRandom(7); random(100)');
      final b = avaliar('seedRandom(7); random(100)');
      expect(a, b);
    });

    test('sementes diferentes dao numeros diferentes', () {
      final a = avaliar('seedRandom(1); random(100)');
      final b = avaliar('seedRandom(2); random(100)');
      expect(a, isNot(b));
    });

    test('random respeita os limites pedidos', () {
      for (var s = 0; s < 20; s++) {
        final v = avaliar('seedRandom($s); random(10, 20)');
        expect(v, inInclusiveRange(10, 20));
      }
    });

    test('O EXEMPLO DO PEDIDO: seedRandom(textIndex); wiggle(2, 20)', () {
      // Cada letra com movimento proprio — e o mesmo movimento toda vez.
      final primeira = [
        for (var i = 0; i < 5; i++)
          avaliar('seedRandom(textIndex); wiggle(2, 20)',
              textIndex: i, time: 1.0, value: 0.0),
      ];
      final segunda = [
        for (var i = 0; i < 5; i++)
          avaliar('seedRandom(textIndex); wiggle(2, 20)',
              textIndex: i, time: 1.0, value: 0.0),
      ];
      expect(primeira, segunda, reason: 'nao e determinista');
      expect(primeira.toSet().length, greaterThan(1),
          reason: 'todas as letras receberam o mesmo valor');
      for (final v in primeira) {
        expect(v.abs(), lessThanOrEqualTo(20.001),
            reason: 'wiggle passou da amplitude pedida');
      }
    });

    test('wiggle anda com o tempo, em volta do valor de base', () {
      final t0 = avaliar('wiggle(2, 30)', time: 0, value: 100.0);
      final t1 = avaliar('wiggle(2, 30)', time: 1.7, value: 100.0);
      expect(t0, isNot(t1));
      for (final v in [t0, t1]) {
        expect(v, inInclusiveRange(70 - 0.001, 130 + 0.001));
      }
    });
  });

  group('nada derruba o editor', () {
    test('LACO INFINITO nao existe: e erro de escrita, com lugar', () {
      final (prog, erro) = CompiledExpression.tentar('while(true) {}');
      expect(prog, isNull);
      expect(erro, isNotNull);
      expect(erro!.mensagem, contains('Laco'));
      expect(erro.linha, 1);
      expect(erro.coluna, greaterThan(0));
    });

    test('for e do tambem sao recusados, com a mesma explicacao', () {
      for (final fonte in ['for(;;){}', 'do {} while(1)']) {
        final (_, erro) = CompiledExpression.tentar(fonte);
        expect(erro, isNotNull, reason: fonte);
        expect(erro!.mensagem, contains('Laco'));
      }
    });

    test('wiggle(100000, 100000) devolve numero finito, e rapido', () {
      final relogio = Stopwatch()..start();
      final v = avaliar('wiggle(100000, 100000)', time: 3, value: 0.0);
      relogio.stop();
      expect(v.isFinite, isTrue);
      expect(relogio.elapsedMilliseconds, lessThan(50),
          reason: 'uma expressao roda por caractere e por quadro');
    });

    test('erro de sintaxe vira mensagem com linha e coluna', () {
      final (prog, erro) = CompiledExpression.tentar('1 +\n* 2');
      expect(prog, isNull);
      expect(erro!.linha, 2, reason: 'a linha do erro');
      expect(erro.coluna, 1);
      expect(erro.mensagem, isNotEmpty);
    });

    test('funcao inexistente DIZ o nome, em vez de devolver zero calado', () {
      final r = avaliarExpressao(
        'sourceRectAtTime().width',
        ExpressionContext(time: 0),
      );
      expect(r.deuCerto, isFalse);
      expect(r.erro!.mensagem, contains('sourceRectAtTime'));
      expect(r.erro!.trecho, 'sourceRectAtTime');
    });

    test('nome inexistente aponta o nome e o lugar', () {
      final r = avaliarExpressao('naoExiste + 1', ExpressionContext(time: 0));
      expect(r.deuCerto, isFalse);
      expect(r.erro!.trecho, 'naoExiste');
      expect(r.erro!.coluna, 1);
    });

    test('avaliar NUNCA lanca: o erro vem no resultado', () {
      for (final fonte in [
        '',
        '((((',
        '1 +',
        '"sem fim',
        'a.b.c.d',
        '[1,2][99]',
        '@@@',
      ]) {
        expect(
          () => avaliarExpressao(fonte, ExpressionContext(time: 0)),
          returnsNormally,
          reason: fonte,
        );
        final r = avaliarExpressao(fonte, ExpressionContext(time: 0));
        expect(r.deuCerto, isFalse, reason: fonte);
      }
    });
  });

  group('o custo por caractere', () {
    test('compilar UMA vez e avaliar mil vezes e barato', () {
      // O caminho quente: cem letras a 30 quadros por segundo sao tres
      // mil avaliacoes por segundo de filme. Reanalisar o texto em cada
      // uma seria o fim do preview.
      final prog = CompiledExpression.compilar(
        'seedRandom(textIndex); wiggle(3, 20) + linear(time, 0, 1, 0, 100)',
      );
      final relogio = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        final r = ExpressionEvaluator(
          prog,
          ExpressionContext(
            time: i / 30,
            textIndex: i % 100,
            textTotal: 100,
            value: 0.0,
          ),
        ).avaliar();
        expect(r.deuCerto, isTrue);
      }
      relogio.stop();
      // ignore: avoid_print
      print('1000 avaliacoes: ${relogio.elapsedMilliseconds} ms '
          '(${(relogio.elapsedMicroseconds / 1000).toStringAsFixed(1)} us cada)');
      expect(relogio.elapsedMilliseconds, lessThan(400));
    });
  });
}
