// A CAIXA DE VALOR: o unico jeito de cravar um numero no painel novo.
//
// As tres superficies (almofada, dial, fita) sao relativas de proposito
// e nenhuma delas chega em exatamente 540,0 com o dedo. Se esta caixa
// nao abrir, ou abrir e ler o numero errado, o painel inteiro fica sem
// como receber um valor exato — e a reforma que tirou o `Slider` teria
// tirado tambem a unica precisao que o deslizante ainda dava.
//
// O TESTE DA ACESSIBILIDADE NAO E ENFEITE: o campo se declara botao, e
// `excludeSemantics` apaga a acao de toque que o `GestureDetector`
// publicaria. Sem a acao repetida no `Semantics`, o leitor de tela
// oferece "toque duas vezes para ativar" e o toque duplo nao faz nada —
// um defeito que nenhuma captura de tela mostra.
import 'package:aurea/src/features/editor/presentation/widgets/campo_de_valor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _montar(
  WidgetTester tester, {
  required String rotulo,
  required double valor,
  int casas = 1,
  String sufixo = '',
  String? nome,
  void Function(double)? aoDigitar,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Center(
        child: CampoDeValor(
          rotulo: rotulo,
          valor: valor,
          casas: casas,
          sufixo: sufixo,
          nome: nome,
          aoDigitar: aoDigitar,
        ),
      ),
    ),
  ),
);

void main() {
  group('o numero na tela', () {
    test('vem em pt-BR com casas fixas', () {
      expect(numeroPtBr(540), '540,0');
      expect(numeroPtBr(0, casas: 2), '0,00');
      // A COLUNA DA VIRGULA E O PONTO DO CASO: um valor com mais
      // precisao nao pode alargar o campo e desalinhar a fila.
      expect(numeroPtBr(540.19), '540,2');
    });

    test('nao mostra menos zero', () {
      // -0,04 com uma casa arredonda para '-0,0': um sinal de menos que
      // nao quer dizer nada e que pisca durante o arrasto.
      expect(numeroPtBr(-0.04), '0,0');
      expect(numeroPtBr(-0.0001, casas: 2), '0,00');
    });

    test('valor quebrado vira zero, e nao a palavra NaN', () {
      expect(numeroPtBr(double.nan), '0,0');
      expect(numeroPtBr(double.infinity, casas: 2), '0,00');
    });
  });

  group('o numero de volta', () {
    test('le virgula e ponto', () {
      // Quem escolhe a tecla decimal e o teclado do sistema, e nao o
      // app: o mesmo projeto anda entre aparelho em ingles e em pt-BR.
      expect(numeroDePtBr('540,5'), 540.5);
      expect(numeroDePtBr('540.5'), 540.5);
    });

    test('le de volta o que este arquivo escreveu', () {
      expect(numeroDePtBr('45°'), 45);
      expect(numeroDePtBr(' 120 %'), 120);
    });

    test('texto ilegivel devolve nulo, e nao zero', () {
      // Zero e um valor legitimo: engolir 'abc' como zero apagaria em
      // silencio o que ja estava no parametro.
      expect(numeroDePtBr('abc'), isNull);
      expect(numeroDePtBr(''), isNull);
      expect(numeroDePtBr('Infinity'), isNull);
      expect(numeroDePtBr('NaN'), isNull);
    });
  });

  testWidgets('nao existe deslizante nenhum no campo', (tester) async {
    await _montar(tester, rotulo: 'x', valor: 540, aoDigitar: (_) {});
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(CupertinoSlider), findsNothing);
  });

  testWidgets('o leitor de tela consegue ABRIR o campo', (tester) async {
    final handle = tester.ensureSemantics();
    double? recebido;
    await _montar(
      tester,
      rotulo: 'x',
      valor: 540,
      aoDigitar: (v) => recebido = v,
    );

    expect(
      tester.getSemantics(find.byType(CampoDeValor)),
      isSemantics(
        label: 'Valor de x',
        value: '540,0',
        isButton: true,
        // A ACAO DE TOQUE, e nao o toque com o dedo: e por ela que o
        // VoiceOver e o TalkBack abrem o campo, e era exatamente ela que
        // `excludeSemantics` apagava. Um campo que se anuncia botao e
        // nao tem esta acao e um botao que so funciona para quem enxerga.
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('campo-de-valor-entrada')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('campo-de-valor-entrada')),
      '12,5',
    );
    await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
    await tester.pumpAndSettle();
    expect(recebido, 12.5);

    handle.dispose();
  });

  testWidgets('cancelar nao mexe no valor', (tester) async {
    var avisou = false;
    await _montar(
      tester,
      rotulo: 'x',
      valor: 540,
      aoDigitar: (_) => avisou = true,
    );
    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('campo-de-valor-entrada')),
      '12,5',
    );
    await tester.tap(find.byKey(const ValueKey('campo-de-valor-cancelar')));
    await tester.pumpAndSettle();
    expect(avisou, isFalse);
  });

  testWidgets('texto ilegivel fecha sem avisar ninguem', (tester) async {
    var avisou = false;
    await _montar(
      tester,
      rotulo: 'x',
      valor: 540,
      aoDigitar: (_) => avisou = true,
    );
    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('campo-de-valor-entrada')),
      'abc',
    );
    await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
    await tester.pumpAndSettle();
    expect(avisou, isFalse);
  });

  testWidgets('sem callback o campo nao convida a tocar', (tester) async {
    final handle = tester.ensureSemantics();
    await _montar(tester, rotulo: 'z', valor: 0);

    expect(
      tester.getSemantics(find.byType(CampoDeValor)),
      isSemantics(isButton: false, hasTapAction: false),
    );

    // SEM CALLBACK, SEM SUBLINHADO: o sublinhado e a promessa de que da
    // para digitar, e o campo apagado nao tem essa promessa a fazer.
    final numero = tester.widget<Text>(find.text('0,0'));
    expect(numero.style?.decoration, TextDecoration.none);

    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('campo-de-valor-entrada')), findsNothing);

    handle.dispose();
  });

  testWidgets('rotulo vazio ainda tem nome para quem ouve', (tester) async {
    final handle = tester.ensureSemantics();
    await _montar(
      tester,
      rotulo: '',
      nome: 'Difusao',
      valor: 0.25,
      casas: 3,
      aoDigitar: (_) {},
    );

    // Na linha de parametro o nome mora no chip da esquerda, que nao
    // existe para quem ouve a tela.
    expect(
      tester.getSemantics(find.byType(CampoDeValor)),
      isSemantics(label: 'Valor de Difusao', value: '0,250'),
    );

    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();
    // O TITULO DO TECLADO E A UNICA PISTA de o que se esta digitando: em
    // branco, o dialogo pergunta um numero sem dizer de que.
    expect(find.text('Valor de Difusao'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('o sufixo nao entra no campo de digitar', (tester) async {
    await _montar(
      tester,
      rotulo: 'X Skew',
      valor: 12,
      casas: 2,
      sufixo: '°',
      aoDigitar: (_) {},
    );
    expect(find.text('12,00°'), findsOneWidget);

    await tester.tap(find.byType(CampoDeValor));
    await tester.pumpAndSettle();
    final entrada = tester.widget<CupertinoTextField>(
      find.byKey(const ValueKey('campo-de-valor-entrada')),
    );
    // Ter de desviar do '°' com o cursor e trabalho que o campo poupa.
    expect(entrada.controller!.text, '12,00');
    // E ele ja nasce selecionado: quem abre quer TROCAR o numero.
    expect(entrada.controller!.selection.textInside('12,00'), '12,00');
  });
}
