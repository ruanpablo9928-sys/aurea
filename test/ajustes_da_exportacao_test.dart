// OS AJUSTES DA EXPORTACAO, antes de comecar.
//
// `ExportSettings` estava escrito, testado e completo — resolucao, fps,
// formato, codec, qualidade, taxa de bits na mao — e era INALCANCAVEL:
// o unico construtor real era `const ExportVideoScreen()`, sem ajuste
// nenhum. Toda exportacao saia no tamanho do projeto, em H.264, na
// qualidade media, e a tela comecava a renderizar sozinha antes de
// perguntar coisa alguma.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/export/domain/export_settings.dart';
import 'package:aurea/src/features/export/presentation/export_video_screen.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/repositorio_sem_disco.dart';

Future<ProviderContainer> _montar(WidgetTester tester) async {
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
  c.setComposition(aspectRatio: 9 / 16, resolutionHeight: 1920);
  c.addTextLayer(Duration.zero, text: 'Um');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ExportVideoScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('a tela abre perguntando, e nao renderizando', (tester) async {
    await _montar(tester);
    expect(find.bySemanticsLabel('Exportar'), findsOneWidget);
    expect(find.text('Formato'), findsOneWidget);
    expect(find.text('Tamanho'), findsOneWidget);
    expect(find.text('Quadros por segundo'), findsOneWidget);
  });

  testWidgets('todo tamanho, formato e codec tem um chip', (tester) async {
    await _montar(tester);
    for (final t in ExportSize.values) {
      expect(
        find.bySemanticsLabel('Tamanho ${exportSizeLabel(t)}'),
        findsOneWidget,
      );
    }
    for (final f in ExportFormat.values) {
      expect(
        find.bySemanticsLabel('Formato ${exportFormatLabel(f)}'),
        findsOneWidget,
      );
    }
    for (final c in ExportCodec.values) {
      expect(
        find.bySemanticsLabel('Codec ${exportCodecLabel(c)}'),
        findsOneWidget,
      );
    }
  });

  testWidgets('a previsao acompanha o tamanho escolhido', (tester) async {
    final c = await _montar(tester);
    final p = c.read(editorControllerProvider);
    // "Original" nao e o numero cru do projeto: tudo sai PAR, porque o
    // H.264 exige. Um projeto de altura impar mostraria um tamanho que
    // o arquivo nao teria.
    final (ow, oh) = const ExportSettings().resolve(
      p.outputWidth,
      p.outputHeight,
    );
    expect(find.textContaining('$ow x $oh'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Tamanho 720p'));
    await tester.pump();
    // Pedir 720p num projeto em pe tem de dar 720 de ALTURA: a largura
    // acompanha a proporcao, senao "720p" viraria um video deitado.
    final (lw, lh) = const ExportSettings(
      size: ExportSize.p720,
    ).resolve(p.outputWidth, p.outputHeight);
    expect(lh, 720);
    expect(find.textContaining('$lw x $lh'), findsOneWidget);
  });

  testWidgets('a sequencia PNG esconde codec e qualidade', (tester) async {
    await _montar(tester);
    expect(find.text('Codec'), findsOneWidget);
    expect(find.text('Qualidade'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Formato Sequencia PNG'));
    await tester.pump();

    // Nao passa por codificador nenhum: oferecer os dois seria escolha
    // que o arquivo ignora.
    expect(find.text('Codec'), findsNothing);
    expect(find.text('Qualidade'), findsNothing);
    expect(find.textContaining('transparencia'), findsOneWidget);
  });

  testWidgets('o fps do projeto aparece como opcao, e nomeado', (
    tester,
  ) async {
    final c = await _montar(tester);
    final fps = c.read(editorControllerProvider).fps;
    expect(
      find.bySemanticsLabel('Quadros por segundo Do projeto ($fps)'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Quadros por segundo 60'));
    await tester.pump();
    expect(find.textContaining('60 qps'), findsOneWidget);
  });

  group('a qualidade deixou de ser ignorada', () {
    test('so os ajustes mandam na taxa de bits', () {
      // Havia DUAS fontes de verdade para o mesmo botao, e esta conta so
      // olhava os ajustes quando havia taxa na mao, HEVC ou tamanho
      // diferente do original. No caminho comum — MP4, tamanho original,
      // H.264 — escolher "alta" era silenciosamente ignorado.
      const alta = ExportSettings(quality: 'alta');
      const media = ExportSettings();
      const baixa = ExportSettings(quality: 'baixa');
      expect(
        alta.bitrateFor(1080, 1920, 30),
        greaterThan(media.bitrateFor(1080, 1920, 30)),
      );
      expect(
        baixa.bitrateFor(1080, 1920, 30),
        lessThan(media.bitrateFor(1080, 1920, 30)),
      );
    });
  });
}
