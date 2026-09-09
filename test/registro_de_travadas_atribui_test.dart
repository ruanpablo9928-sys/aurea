// O REGISTRO PRECISA DIZER O QUE TRAVOU — E NAO DIZIA.
//
// A primeira versao guardava as marcas numa pilha e lia essa pilha
// dentro do retorno de `addTimingsCallback`. Esse retorno NAO acontece
// durante o quadro: o Flutter junta os tempos em lote e entrega "dentro
// de mais ou menos um segundo". Quando ele chegava, o `finally` de toda
// marca ja havia rodado e a pilha estava vazia.
//
// Resultado: TODA travada saia com `nada marcado`, sempre, por
// construcao. Inclusive uma de 1.800 ms cuja causa estava marcada. Eu li
// isso como prova de que a causa estava fora das marcas e fui procurar
// no lugar errado — duas entregas seguidas.
//
// Estes testes existem para que esse defeito nao volte em silencio.
import 'package:aurea/src/features/editor/application/registro_de_travadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gasta tempo de processador de verdade. `Future.delayed` nao serve:
/// ele devolve o fio, e o que se quer medir aqui e trabalho sincrono
/// segurando o mesmo fio que recebe o toque.
void _trabalhoDe(int ms) {
  final r = Stopwatch()..start();
  var soma = 0;
  while (r.elapsedMilliseconds < ms) {
    for (var i = 0; i < 5000; i++) {
      soma += i;
    }
  }
  // Segura a soma para o compilador nao apagar o laco inteiro.
  if (soma < 0) throw StateError('nunca');
}

void main() {
  setUp(RegistroDeTravadas.limpar);

  test('a marca mede a si mesma e aparece na soma', () {
    RegistroDeTravadas.marcando('trabalho caro', () => _trabalhoDe(60));
    final causas = RegistroDeTravadas.porCausa();
    expect(causas, isNotEmpty, reason: 'a marca nao foi contada');
    expect(causas.first.oQue, 'trabalho caro');
    expect(
      causas.first.somaMs,
      greaterThanOrEqualTo(50),
      reason: 'a marca foi contada, mas sem o tempo que ela gastou',
    );
    expect(causas.first.vezes, 1);
  });

  test('a soma ordena pela marca que mais pesou', () {
    RegistroDeTravadas.marcando('barata', () => _trabalhoDe(5));
    RegistroDeTravadas.marcando('cara', () => _trabalhoDe(80));
    RegistroDeTravadas.marcando('barata', () => _trabalhoDe(5));
    final causas = RegistroDeTravadas.porCausa();
    expect(causas.first.oQue, 'cara');
    expect(causas.last.oQue, 'barata');
    expect(causas.last.vezes, 2);
  });

  test('a marca devolve o valor do corpo e sobrevive a uma excecao', () {
    expect(RegistroDeTravadas.marcando('soma', () => 2 + 2), 4);
    expect(
      () => RegistroDeTravadas.marcando('explode', () => throw StateError('x')),
      throwsStateError,
    );
    // Mesmo tendo estourado, o tempo tem de estar contado.
    expect(
      RegistroDeTravadas.porCausa().map((c) => c.oQue),
      containsAll(<String>['soma', 'explode']),
    );
  });

  testWidgets('a travada do quadro diz QUAL marca a causou', (tester) async {
    RegistroDeTravadas.comecar();
    RegistroDeTravadas.limpar();
    // Um quadro que constroi devagar: e exatamente o caso do relato, um
    // widget cuja construcao segura o fio por mais de um oitavo de
    // segundo.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => RegistroDeTravadas.marcando(
            'construcao lenta de proposito',
            () {
              _trabalhoDe(RegistroDeTravadas.limiteMs + 60);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();

    final travadas = RegistroDeTravadas.travadas;
    expect(
      travadas,
      isNotEmpty,
      reason: 'um quadro de mais de ${RegistroDeTravadas.limiteMs} ms passou '
          'sem ser registrado',
    );
    expect(
      travadas.any((t) => t.oQue.contains('construcao lenta de proposito')),
      isTrue,
      reason:
          'a travada foi registrada como "${travadas.first.oQue}". Era isto '
          'que estava quebrado: a causa estava marcada e o registro dizia '
          'nada marcado',
    );
  });

  testWidgets('o texto para colar traz a versao e a soma por marca', (
    tester,
  ) async {
    RegistroDeTravadas.comecar();
    RegistroDeTravadas.limpar();
    RegistroDeTravadas.marcando('algo caro', () => _trabalhoDe(50));
    final texto = RegistroDeTravadas.emTexto();
    expect(
      texto,
      contains('app='),
      reason: 'sem a versao no registro nao da para saber de qual build ele e',
    );
    expect(texto, contains('POR MARCA'));
    expect(texto, contains('algo caro'));
  });
}
