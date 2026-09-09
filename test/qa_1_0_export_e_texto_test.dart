// QA 1.0 — CAMPANHA 6: O QUE SAI NO ARQUIVO, E O TEXTO QUE ANIMA.
//
// Tres perguntas que so o PIXEL responde:
//
//   1. O que se ve na previa e o que sai no video? Fora as ajudas de
//      edicao, tem de ser o MESMO quadro. Uma diferenca aqui e a pior
//      classe de bug do aplicativo: a pessoa so descobre depois de
//      exportar, e nao tem como consertar sem refazer.
//   2. Cada preset de animacao de texto ANIMA mesmo? Um preset que
//      grava e reabre certinho mas nao mexe um pixel passa em todo teste
//      de persistencia e ainda assim nao funciona.
//   3. Um arquivo chamado "meu vídeo final 🎬 (2).mp4" volta com o nome
//      que tinha? Acento, espaco e emoji sao o caso NORMAL de quem grava
//      no celular.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/font_service.dart';
import 'package:aurea/src/features/editor/application/video_layer_manager.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/text_anim.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _lado = 128.0;

/// Desenha o projeto no instante pedido e devolve os bytes crus.
Future<Uint8List> _quadro(
  WidgetTester tester,
  VideoProject p,
  Duration quando, {
  required bool exportando,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(editorControllerProvider.notifier).openProject(p);
  final tempo = ValueNotifier(quando);
  addTearDown(tempo.dispose);
  final videos = VideoLayerManager();
  addTearDown(videos.dispose);
  final chave = GlobalKey();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: chave,
            child: SizedBox(
              width: _lado,
              height: _lado,
              child: ColoredBox(
                color: const Color(0xFF000000),
                child: CompositionView(
                  time: tempo,
                  videos: videos,
                  selectedId: null,
                  exporting: exportando,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 16));
  final boundary =
      chave.currentContext!.findRenderObject() as RenderRepaintBoundary;
  late Uint8List bytes;
  await tester.runAsync(() async {
    final imagem = await boundary.toImage();
    final dados = (await imagem.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    bytes = Uint8List.fromList(
      dados.buffer.asUint8List(dados.offsetInBytes, dados.lengthInBytes),
    );
    imagem.dispose();
  });
  return bytes;
}

/// Quantos pixels diferem entre dois quadros do mesmo tamanho.
int _pixeisDiferentes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return -1;
  var n = 0;
  for (var i = 0; i + 3 < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2]) n++;
  }
  return n;
}

VideoProject _projeto(List<Layer> camadas) => VideoProject(
  name: 'qa',
  createdAt: DateTime(2026, 9, 8),
  aspectRatio: 1,
  resolutionHeight: _lado.round(),
  backgroundColor: const Color(0xFF07070B),
  layers: camadas,
);

void main() {
  setUpAll(() async {
    // Sem uma familia registrada, o texto sai em blocos — o teste
    // continuaria valido, mas o motivo de uma falha ficaria obscuro.
    for (final f in ['Aurea Motion Sans', 'Roboto', 'FlutterTest']) {
      FontService.instance.registrarSemArquivo(f);
    }
  });

  group('a previa e o arquivo mostram a mesma coisa', () {
    testWidgets('sem ajudas na cena, exportar da o MESMO quadro', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(256, 256);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final projeto = _projeto([
        TextLayer(
          id: 'txt',
          name: 'Texto',
          text: 'AUREA',
          fontSize: 28,
          fontFamily: 'Roboto',
          color: const Color(0xFFFFFFFF),
          startTime: Duration.zero,
          duration: const Duration(seconds: 6),
          position: AnimatedOffset(const Offset(64, 40)),
        ),
        ShapeLayer(
          id: 'forma',
          name: 'Forma',
          startTime: Duration.zero,
          duration: const Duration(seconds: 6),
          position: AnimatedOffset(const Offset(64, 90)),
          scaleX: AnimatedDouble(0.4),
          scaleY: AnimatedDouble(0.4),
          contents: [
            ShapePath(primitive: ShapePrimitive.ellipse),
            ShapeFill(color: const Color(0xFFB8FF3D)),
          ],
        ),
      ]);

      final t = const Duration(milliseconds: 1500);
      final naPrevia = await _quadro(tester, projeto, t, exportando: false);
      final noArquivo = await _quadro(tester, projeto, t, exportando: true);
      expect(
        _pixeisDiferentes(naPrevia, noArquivo),
        0,
        reason: 'o que se ve na previa nao e o que sai no arquivo',
      );
    });

    testWidgets('camada 3D vazia: as ajudas ficam so na previa', (
      tester,
    ) async {
      // A cena 3D desenha grade e eixos para se saber onde se esta. Isso
      // e ajuda de edicao: aparece na previa, nunca no arquivo.
      tester.view.physicalSize = const Size(256, 256);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.openProject(_projeto(const []));
      c.addScene3DLayer(Duration.zero);
      final comCena = container.read(editorControllerProvider);

      final t = const Duration(milliseconds: 500);
      final naPrevia = await _quadro(tester, comCena, t, exportando: false);
      final noArquivo = await _quadro(tester, comCena, t, exportando: true);
      // Nao se exige igualdade aqui: exige-se que o ARQUIVO nao tenha
      // mais tinta que a previa. Ajuda pode sumir; nao pode aparecer.
      final fundo = await _quadro(
        tester,
        _projeto(const []),
        t,
        exportando: true,
      );
      final tintaNoArquivo = _pixeisDiferentes(noArquivo, fundo);
      final tintaNaPrevia = _pixeisDiferentes(naPrevia, fundo);
      expect(
        tintaNoArquivo,
        lessThanOrEqualTo(tintaNaPrevia),
        reason: 'o arquivo tem MAIS coisa desenhada que a previa',
      );
    });
  });

  group('todo preset de texto anima de verdade', () {
    testWidgets('cada preset muda o quadro em algum instante', (tester) async {
      tester.view.physicalSize = const Size(256, 256);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // AMOSTRAS espalhadas de proposito: as entradas acontecem nos
      // primeiros milissegundos, as enfases repetem em ciclos de 0,7 a
      // 2 segundos, e as saidas so no fim da camada. Uma amostra so, ou
      // duas em fase, nao provam nada — o Blink pisca com periodo de
      // 700 ms e em 0 e 350 ms esta exatamente na mesma fase.
      const instantes = <Duration>[
        Duration.zero,
        Duration(milliseconds: 90),
        Duration(milliseconds: 180),
        Duration(milliseconds: 350),
        Duration(milliseconds: 600),
        Duration(milliseconds: 1200),
        Duration(milliseconds: 2000),
        Duration(milliseconds: 3900),
      ];

      final parados = <String>[];
      for (final spec in textAnimCatalog) {
        final slot = spec.slots.first;
        final camada = TextLayer(
          id: 'txt',
          name: 'T',
          text: 'AUREA',
          fontSize: 34,
          fontFamily: 'Roboto',
          // COR SATURADA de proposito: metade dos presets mexe em matiz
          // e em saturacao, e branco nao muda de cor quando se gira o
          // matiz — com texto branco esses presets pareceriam parados
          // sem estarem.
          color: const Color(0xFFFF4D2E),
          startTime: Duration.zero,
          duration: const Duration(seconds: 4),
          position: AnimatedOffset(const Offset(64, 64)),
          anims: [TextAnim(specId: spec.id, slot: slot)],
        );
        final projeto = _projeto([camada]);
        Uint8List? referencia;
        var mudou = false;
        for (final t in instantes) {
          final quadro = await _quadro(tester, projeto, t, exportando: true);
          if (referencia == null) {
            referencia = quadro;
          } else if (_pixeisDiferentes(referencia, quadro) > 0) {
            mudou = true;
            break;
          }
        }
        if (!mudou) parados.add('${spec.id}/${slot.name}');
      }
      expect(
        parados,
        isEmpty,
        reason:
            'estes presets nao mexeram um pixel em NENHUM dos oito '
            'instantes medidos:\n${parados.join("\n")}',
      );
    });
  });

  group('nome de arquivo de gente de verdade', () {
    test('espaco, acento, emoji e simbolo voltam identicos do arquivo', () {
      final nomes = <String>[
        'meu vídeo final 🎬 (2).mp4',
        'Ação & Reação #3 [100%].mov',
        'ÁÉÍÓÚ àèìòù ãõ ç ñ.mp4',
        'arquivo   com   espaços   demais.mp4',
        "aspas 'simples' e \"duplas\".mp4",
        'caminho\\com\\barra\\invertida.mp4',
        '日本語のファイル名.mp4',
      ];
      final falhas = <String>[];
      for (final nome in nomes) {
        final caminho = '/uma/pasta com espaço/$nome';
        final camada = VideoLayer(
          id: 'v',
          name: nome,
          sourcePath: caminho,
          startTime: Duration.zero,
          duration: const Duration(seconds: 3),
        );
        try {
          final volta = projectFromJson(projectToJson(_projeto([camada])));
          final lida = volta.layers.single as VideoLayer;
          if (lida.sourcePath != caminho) {
            falhas.add('caminho de "$nome" voltou como "${lida.sourcePath}"');
          }
          if (lida.name != nome) {
            falhas.add('nome "$nome" voltou como "${lida.name}"');
          }
        } catch (erro) {
          falhas.add('"$nome": EXPLODIU ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('o texto da camada aceita emoji, acento e escrita da direita', () {
      final textos = <String>[
        'Olá, mundo! 🌍✨',
        'ÁÉÍÓÚÇÃÕ',
        'مرحبا بالعالم',
        'x' * 5000,
        '\n\n\n',
        'linha 1\nlinha 2\tcom tabulacao',
      ];
      final falhas = <String>[];
      for (final texto in textos) {
        final camada = TextLayer(
          id: 't',
          name: 'T',
          text: texto,
          startTime: Duration.zero,
          duration: const Duration(seconds: 2),
        );
        try {
          final volta = projectFromJson(projectToJson(_projeto([camada])));
          final lida = volta.layers.single as TextLayer;
          if (lida.text != texto) {
            final resumo = texto.length > 20
                ? '${texto.substring(0, 20)}... (${texto.length})'
                : texto;
            falhas.add('"$resumo" voltou diferente');
          }
        } catch (erro) {
          falhas.add('EXPLODIU com ${texto.length} caracteres ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });
}
