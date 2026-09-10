// A ALMOFADA: TAMANHO PROPRIO, ACUMULADO, E TOQUE QUE NAO EDITA.
//
// Tres regras que nao aparecem numa tela parada, e que ja quebraram:
// (1) a almofada e uma AREA — num pai que so afrouxa as restricoes ela
// nascia do tamanho da propria dica, pequena demais para os quatro
// cantos serem desenhados; (2) o gesto devolve o ACUMULADO desde o
// inicio, e nao o delta do quadro, que e o que impede a camada de
// derivar alguns pixels ao longo do arrasto; (3) um toque sem
// movimento nao abre lote de edicao — o reconhecedor de arrasto ganha a
// arena sozinho e chama comecar e terminar num tap, e o desfazer
// ficava com um passo que nao desfaz nada.
import 'package:aurea/src/features/editor/presentation/widgets/almofada_de_arrasto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _sozinha(Widget filho) => Directionality(
      textDirection: TextDirection.ltr,
      child: filho,
    );

const _dica = 'Deslize aqui para mover a camada';

Color? _corDaDica(WidgetTester tester) =>
    tester.widget<Text>(find.text(_dica)).style?.color;

void main() {
  testWidgets('num pai frouxo a almofada nao encolhe ate a dica', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sozinha(Column(children: [AlmofadaDeArrasto(aoMover: (_) {})])),
    );
    final tamanho = tester.getSize(find.byType(AlmofadaDeArrasto));
    expect(tamanho.height, 160);
    expect(tamanho.width, greaterThan(300));
  });

  testWidgets('num pai que manda a altura, a almofada obedece', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sozinha(
        Center(
          child: SizedBox(
            height: 214,
            child: AlmofadaDeArrasto(aoMover: (_) {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AlmofadaDeArrasto)).height, 214);
  });

  testWidgets('o arrasto devolve o acumulado, e nao o delta do quadro', (
    tester,
  ) async {
    final vistos = <Offset>[];
    final ordem = <String>[];
    await tester.pumpWidget(
      _sozinha(
        AlmofadaDeArrasto(
          aoMover: (d) {
            ordem.add('mover');
            vistos.add(d);
          },
          aoComecar: () => ordem.add('comecar'),
          aoTerminar: () => ordem.add('terminar'),
        ),
      ),
    );

    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(AlmofadaDeArrasto)),
    );
    await gesto.moveBy(const Offset(30, 0));
    await gesto.moveBy(const Offset(10, 20));
    await gesto.up();
    await tester.pump();

    expect(vistos.last, const Offset(40, 20));
    // A FOTO DA POSICAO INICIAL VEM ANTES DO PRIMEIRO PASSO.
    expect(ordem.first, 'comecar');
    expect(ordem.last, 'terminar');
    expect(ordem.where((e) => e == 'comecar').length, 1);
    expect(ordem.where((e) => e == 'terminar').length, 1);
  });

  testWidgets('o toque simples nao abre nem fecha lote de edicao', (
    tester,
  ) async {
    var comecos = 0;
    var fins = 0;
    await tester.pumpWidget(
      _sozinha(
        AlmofadaDeArrasto(
          aoMover: (_) {},
          aoComecar: () => comecos++,
          aoTerminar: () => fins++,
        ),
      ),
    );
    await tester.tap(find.byType(AlmofadaDeArrasto));
    await tester.pump();
    expect(comecos, 0);
    expect(fins, 0);
  });

  testWidgets('a dica some no arrasto sem mudar o tamanho da area', (
    tester,
  ) async {
    await tester.pumpWidget(
      _sozinha(Column(children: [AlmofadaDeArrasto(aoMover: (_) {})])),
    );
    final antes = tester.getSize(find.byType(AlmofadaDeArrasto));
    expect(_corDaDica(tester)?.a, 1);

    final gesto = await tester.startGesture(
      tester.getCenter(find.byType(AlmofadaDeArrasto)),
    );
    await gesto.moveBy(const Offset(40, 0));
    await tester.pump();

    expect(_corDaDica(tester)?.a, 0);
    expect(tester.getSize(find.byType(AlmofadaDeArrasto)), antes);

    await gesto.up();
    await tester.pump();
    expect(_corDaDica(tester)?.a, 1);
  });

  testWidgets('o alvo tocavel tem rotulo de acessibilidade', (
    tester,
  ) async {
    await tester.pumpWidget(_sozinha(AlmofadaDeArrasto(aoMover: (_) {})));
    expect(find.bySemanticsLabel('Mover a camada'), findsOneWidget);
  });
}
