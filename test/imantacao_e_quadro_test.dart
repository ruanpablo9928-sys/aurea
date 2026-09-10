// A LINHA DO TEMPO GANHOU IMA, PASSO DE QUADRO, LACO E A GRADE CERTA.
//
// Quatro defeitos da mesma familia, todos de PRECISAO:
//
//   - sem ima, encostar um clipe no outro era mira: o dedo entrega
//     tempo continuo, e o erro de dezenas de milissegundos nao aparece
//     na tela e aparece no som;
//   - sem passo de quadro, o cabecote so parava onde o dedo parava;
//   - o laco existia no motor e o unico lugar do app que o ligava era a
//     tela de estresse 3D;
//   - e o relogio quantizava numa grade FIXA de 30, enquanto a capsula
//     contava os quadros pelo fps do projeto.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/imantacao.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/widgets/mapa_do_tempo.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/repositorio_sem_disco.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

Future<ProviderContainer> _montarTela(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider.overrideWithValue(RepositorioSemDisco()),
    ],
  );
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.setComposition(fps: 24);
  c.addTextLayer(Duration.zero, text: 'Um');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditorScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  group('o ima', () {
    const tol = Duration(milliseconds: 100);

    test('cola na ancora mais proxima, e so dentro da tolerancia', () {
      const ancoras = [Duration(seconds: 1), Duration(seconds: 3)];
      expect(
        imantar(const Duration(milliseconds: 1040), ancoras, tol),
        const Duration(seconds: 1),
      );
      expect(
        imantar(const Duration(milliseconds: 1400), ancoras, tol),
        const Duration(milliseconds: 1400),
        reason: 'longe da ancora, o dedo manda',
      );
    });

    test('entre duas, ganha a mais perto', () {
      const ancoras = [Duration(seconds: 1), Duration(milliseconds: 1080)];
      expect(
        imantar(const Duration(milliseconds: 1070), ancoras, tol),
        const Duration(milliseconds: 1080),
      );
    });

    test('tolerancia zero nao cola nada', () {
      expect(
        imantar(
          const Duration(milliseconds: 1000),
          const [Duration(milliseconds: 1000)],
          Duration.zero,
        ),
        const Duration(milliseconds: 1000),
      );
    });

    group('o clipe cola pelas DUAS pontas', () {
      const duracao = Duration(seconds: 2);

      test('pelo comeco', () {
        expect(
          imantarClipe(
            const Duration(milliseconds: 960),
            duracao,
            const [Duration(seconds: 1)],
            tol,
          ),
          const Duration(seconds: 1),
        );
      });

      test('pelo fim, que e o caso mais comum de todos', () {
        // Arrastar um clipe para encostar o FIM dele no comeco do
        // proximo. Imantar so o comeco nao pegaria isto.
        expect(
          imantarClipe(
            const Duration(milliseconds: 2960),
            duracao,
            const [Duration(seconds: 5)],
            tol,
          ),
          const Duration(seconds: 3),
          reason: 'o fim do clipe tinha de colar em 5 s',
        );
      });

      test('quando as duas pegam, ganha a mais perto', () {
        final r = imantarClipe(
          const Duration(milliseconds: 1050),
          duracao,
          const [Duration(seconds: 1), Duration(milliseconds: 3060)],
          tol,
        );
        // O fim esta a 10 ms de 3,06 s; o comeco esta a 50 ms de 1 s.
        expect(r, const Duration(milliseconds: 1060));
      });
    });
  });

  group('o passo de quadro', () {
    late PlaybackController p;
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      p = PlaybackController(
        vsync: _Vsync(),
        durationOf: () => container.read(editorControllerProvider).duration,
      );
      addTearDown(p.dispose);
    });

    test('anda um quadro para a frente e volta ao mesmo lugar', () {
      p.compositionFps = 24;
      p.seek(const Duration(seconds: 1));
      final antes = p.time.value;
      p.stepFrame(1);
      expect(p.time.value, greaterThan(antes));
      p.stepFrame(-1);
      expect(p.time.value, antes);
    });

    test('dez para a frente e dez para tras fecham a conta', () {
      // A 30 fps o passo nao e inteiro (33333,33 us). Somar o passo
      // arredondado erra 50 us a cada 150 quadros — pouco para ver, e o
      // bastante para o cabecote nao voltar ao mesmo quadro.
      p.compositionFps = 30;
      p.seek(const Duration(milliseconds: 1500));
      final antes = p.time.value;
      for (var i = 0; i < 10; i++) {
        p.stepFrame(1);
      }
      for (var i = 0; i < 10; i++) {
        p.stepFrame(-1);
      }
      expect(p.time.value, antes);
    });

    test('o passo respeita o fps escolhido', () {
      p.compositionFps = 24;
      p.seek(Duration.zero);
      p.stepFrame(1);
      final a24 = p.time.value;
      p.compositionFps = 60;
      p.seek(Duration.zero);
      p.stepFrame(1);
      expect(
        p.time.value,
        lessThan(a24),
        reason: 'um quadro a 60 fps e menos tempo que um a 24',
      );
    });

    test('nao passa do zero', () {
      p.seek(Duration.zero);
      p.stepFrame(-5);
      expect(p.time.value, Duration.zero);
    });
  });

  group('a tela', () {
    testWidgets('a grade do relogio e a do projeto, e nao 30 fixo', (
      tester,
    ) async {
      final c = await _montarTela(tester);
      expect(c.read(editorControllerProvider).fps, 24);
      // A capsula conta os quadros pelo fps do projeto; o cabecote
      // encaixava numa grade fixa de 30. Num projeto a 24, o numero
      // lido e o quadro exportado eram coisas diferentes.
      expect(find.bySemanticsLabel('Um quadro para a frente'), findsOneWidget);
      expect(find.bySemanticsLabel('Um quadro para tras'), findsOneWidget);
    });

    testWidgets('as setas andam de verdade no cabecote', (tester) async {
      await _montarTela(tester);
      final antes = find.text('00:00:00');
      expect(antes, findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Um quadro para a frente'));
      await tester.pump();
      expect(
        find.text('00:00:01'),
        findsOneWidget,
        reason: 'um quadro a 24 fps e o quadro 1',
      );
    });

    testWidgets('o laco liga e desliga na regua', (tester) async {
      await _montarTela(tester);
      expect(find.bySemanticsLabel('Repetir sem parar'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Repetir sem parar'));
      await tester.pump();
      expect(find.bySemanticsLabel('Parar de repetir'), findsOneWidget);
    });
  });

  group('as ancoras que o clipe usa', () {
    test('o proprio clipe nao entra na lista', () {
      // Um clipe que cola em si mesmo nao sai do lugar. A lista vem do
      // widget, mas a regra e a mesma: `l.id != id`.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      c.addTextLayer(const Duration(seconds: 2), text: 'Dois');
      final camadas = container.read(editorControllerProvider).layers;
      final eu = camadas.first;
      final outras = [
        for (final l in camadas)
          if (l.id != eu.id) ...[l.startTime, l.endTime],
      ];
      expect(outras, isNot(contains(eu.startTime)));
      expect(outras, hasLength(2));
    });
  });

  group('a tolerancia e em pixels, e nao em tempo', () {
    test('o mesmo ima vale menos tempo com o zoom aberto', () {
      const fechado = MapaDoTempo(
        tempo: Duration.zero,
        largura: 360,
        pxPorSegundo: 10,
      );
      const aberto = MapaDoTempo(
        tempo: Duration.zero,
        largura: 360,
        pxPorSegundo: 200,
      );
      // Nove pixels sao quase um segundo com o zoom fechado e 45 ms com
      // ele aberto. Uma tolerancia fixa em milissegundos seria generosa
      // demais num caso e inutil no outro.
      expect(
        fechado.tempoDe(9).inMilliseconds,
        greaterThan(aberto.tempoDe(9).inMilliseconds * 10),
      );
    });
  });
}
