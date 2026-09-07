import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// EXPRESSIONS EM TODA PROPRIEDADE ANIMAVEL.
///
/// O pedido foi "wiggle(2, 20) controlando Glow Intensity" e
/// "Math.sin(time * 2) * 50 controlando Blur Amount". O vinculo mora no
/// AnimatedDouble — o tipo de TODO parametro de efeito, transformacao e
/// animador de texto — entao quem le `valueAt` recebe a expressao
/// aplicada sem saber que ela existe. E o que se prova aqui.
///
/// O teste que mais importa e o das edicoes: AnimatedDouble e imutavel e
/// cada `with*` constroi um objeto novo. Bastava UM deles esquecer o
/// campo e a expressao sumiria calada na primeira mexida de keyframe —
/// o tipo de bug que so aparece semanas depois, como "minha expressao
/// se perdeu".
void main() {
  Duration t(num s) => Duration(microseconds: (s * 1000000).round());
  AnimatedDouble comExpr(double base, String fonte,
          [List<Keyframe<double>>? kfs]) =>
      AnimatedDouble(base, kfs, LoopSpec.none, fonte);

  group('a expressao controla o valor', () {
    test('Math.sin(time * 2) * 50 — o exemplo do pedido', () {
      final a = comExpr(0, 'Math.sin(time * 2) * 50');
      expect(a.valueAt(Duration.zero), closeTo(0, 1e-9));
      // sin(pi/2) = 1 em time = pi/4.
      expect(a.valueAt(t(3.14159265 / 4)), closeTo(50, 1e-3));
      expect(a.valueAt(t(3.14159265 / 4)), isNot(a.valueAt(t(1))));
    });

    test('value e o que a propriedade teria SEM a expressao', () {
      // Keyframes de 10 a 30 num segundo; a expressao dobra.
      final a = comExpr(0, 'value * 2', [
        Keyframe(time: Duration.zero, value: 10),
        Keyframe(time: t(1), value: 30),
      ]);
      expect(a.valueAt(Duration.zero), closeTo(20, 1e-9));
      expect(a.valueAt(t(.5)), closeTo(40, 1e-9), reason: 'value=20 no meio');
      expect(a.valueAt(t(1)), closeTo(60, 1e-9));
    });

    test('sem expressao, nada muda', () {
      final a = AnimatedDouble(7, [
        Keyframe(time: Duration.zero, value: 7),
        Keyframe(time: t(1), value: 9),
      ]);
      expect(a.hasExpression, isFalse);
      expect(a.valueAt(t(.5)), closeTo(8, 1e-9));
      // Texto vazio ou so espacos tambem e "sem expressao".
      expect(AnimatedDouble(1, null, LoopSpec.none, '   ').valueAt(t(1)), 1);
    });

    test('wiggle e determinista tambem por aqui', () {
      final a = comExpr(100, 'wiggle(2, 20)');
      expect(a.valueAt(t(1.3)), a.valueAt(t(1.3)));
      expect(a.valueAt(t(1.3)), isNot(a.valueAt(t(2.7))));
      expect(a.valueAt(t(1.3)), inInclusiveRange(80 - .001, 120 + .001));
    });
  });

  group('erro nao derruba nada', () {
    test('expressao que nao compila devolve o valor cru e expoe o erro', () {
      final a = comExpr(42, '1 +');
      expect(a.valueAt(t(1)), 42);
      expect(a.expressionError, isNotNull);
      expect(a.expressionError!.linha, greaterThan(0));
    });

    test('expressao que compila mas falha ao rodar: valor cru + erro', () {
      final a = comExpr(5, 'naoExiste * 2');
      expect(a.expressionError, isNull, reason: 'compila — o nome so falha ao rodar');
      expect(a.valueAt(t(1)), 5);
      expect(AnimatedDouble.runtimeErrors['naoExiste * 2'], isNotNull);
      expect(AnimatedDouble.runtimeErrors['naoExiste * 2']!.trecho, 'naoExiste');
    });

    test('resultado nao finito e recusado', () {
      // Nao ha divisao por zero (o motor devolve 0), mas o contrato do
      // AnimatedDouble e nunca entregar NaN/Infinity a quem desenha.
      final a = comExpr(3, 'Math.sqrt(-1)');
      expect(a.valueAt(t(1)).isFinite, isTrue);
    });
  });

  group('a expressao sobrevive a toda edicao', () {
    const fonte = 'value + 1';
    final base = comExpr(10, fonte, [
      Keyframe(time: Duration.zero, value: 10),
      Keyframe(time: t(1), value: 20),
    ]);

    final edicoes = <String, AnimatedDouble Function(AnimatedDouble)>{
      'withBase': (a) => a.withBase(99),
      'withLoop': (a) => a.withLoop(LoopSpec.none),
      'withKeyframe': (a) => a.withKeyframe(t(2), 30),
      'withoutKeyframe (um de dois)': (a) => a.withoutKeyframe(t(1)),
      'edited': (a) => a.edited(t(.5), 15),
      'withEase': (a) => a.withEase(Duration.zero, Easing.easeIn),
      'withEaseAll': (a) => a.withEaseAll(Easing.easeOut),
      'reversedInTime': (a) => a.reversedInTime(),
    };

    for (final MapEntry(key: nome, value: edita) in edicoes.entries) {
      test(nome, () {
        final depois = edita(base);
        expect(depois.expression, fonte,
            reason: '$nome apagou a expressao em silencio');
        expect(depois.hasExpression, isTrue);
      });
    }

    test('tirar o ULTIMO keyframe nao assa a expressao na base', () {
      final um = base.withoutKeyframe(t(1)); // sobra o de 0s (valor 10)
      final nenhum = um.withoutKeyframe(Duration.zero);
      expect(nenhum.isAnimated, isFalse);
      expect(nenhum.expression, fonte);
      // A base e o valor CRU (10), e a expressao continua por cima (11).
      // Se a base tivesse recebido valueAt, seria 11 e o resultado 12 —
      // a expressao aplicada duas vezes.
      expect(nenhum.base, 10);
      expect(nenhum.valueAt(t(5)), 11);
    });

    test('withExpression poe, troca e tira', () {
      final a = AnimatedDouble(4);
      expect(a.withExpression('value * 3').valueAt(t(1)), 12);
      expect(a.withExpression('value * 3').withExpression('value + 1').valueAt(t(1)), 5);
      expect(a.withExpression('value * 3').withExpression(null).hasExpression, isFalse);
    });
  });

  group('num efeito de verdade', () {
    test('o parametro do efeito le a expressao', () {
      final blur = EffectInstance(
        type: EffectType.gaussianBlur,
        params: {'raio': comExpr(10, 'Math.sin(time * 2) * 50')},
      );
      expect(blur.paramAt('raio', Duration.zero), closeTo(0, 1e-9));
      expect(blur.paramAt('raio', t(3.14159265 / 4)), closeTo(50, 1e-3));
    });

    test('salvar e abrir o projeto mantem a expressao viva', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addShapeLayer(Duration.zero);
      final p = c.state;
      c.openProject(
        p.copyWith(
          layers: [
            for (final l in p.layers)
              l.copyLayer(
                effects: [
                  EffectInstance(
                    type: EffectType.gaussianBlur,
                    params: {
                      'raio': comExpr(4, 'value + time * 10', [
                        Keyframe(time: Duration.zero, value: 4),
                        Keyframe(time: t(2), value: 8),
                      ]),
                    },
                  ),
                ],
              ),
          ],
        ),
      );

      final json = projectToJson(container.read(editorControllerProvider));
      final volta = projectFromJson(json);
      final efeito = volta.layers.first.effects.single;
      final raio = efeito.params['raio']!;

      expect(raio.expression, 'value + time * 10',
          reason: 'a expressao nao voltou do arquivo');
      expect(raio.keyframes, hasLength(2), reason: 'os keyframes se perderam');
      // value em t=1 e 6 (meio do caminho 4->8); +10 da 16.
      expect(efeito.paramAt('raio', t(1)), closeTo(16, 1e-9));
    });

    test('projeto antigo, sem o campo, abre sem expressao', () {
      // Um AnimatedDouble gravado antes deste campo existir.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addShapeLayer(Duration.zero);
      final json = projectToJson(container.read(editorControllerProvider));
      final volta = projectFromJson(json);
      final layer = volta.layers.first;
      expect(layer.opacity.hasExpression, isFalse);
      expect(layer.opacity.expression, isNull);
    });
  });
}
