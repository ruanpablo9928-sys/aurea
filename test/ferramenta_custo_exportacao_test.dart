import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// FERRAMENTA DE MESA: quanto custa um quadro no caminho VELHO e no NOVO.
///
/// Nao afirma nada — mede. O caminho velho da exportacao levava cada
/// quadro assim:
///
///   GPU → CPU  →  codificar PNG (zlib)  →  gravar no disco
///                  ... e depois, numa segunda passada ...
///   ler do disco  →  decodificar PNG  →  buffer  →  codificador
///
/// O PNG nao existia por nenhum motivo de imagem: era so o jeito de os
/// pixels irem do Dart ao codificador nativo. Esta bancada mede as duas
/// pontas que dependem do Dart — comprimir e gravar — porque sao as que
/// a correcao eliminou.
///
/// Os numeros sao de DESKTOP. Um celular custa mais, e a diferenca entre
/// os dois caminhos cresce junto: o zlib e CPU pura.
void main() {
  testWidgets('custo por quadro: PNG contra bytes crus', (tester) async {
    await tester.runAsync(() async {
      final pasta = Directory('build/export_bench')
        ..createSync(recursive: true);

      Future<void> medir(String nome, int largura, int altura) async {
        // Um quadro parecido com uma composicao de verdade: degrade,
        // formas e texto. PNG comprime imagem lisa bem demais; medir com
        // um retangulo chapado daria um numero mentiroso.
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        final area = Rect.fromLTWH(0, 0, largura.toDouble(), altura.toDouble());
        canvas.drawRect(
          area,
          Paint()
            ..shader = ui.Gradient.linear(
              area.topLeft,
              area.bottomRight,
              const [Color(0xff1b2a4a), Color(0xffd8a06a), Color(0xff102015)],
              const [0, .55, 1],
            ),
        );
        for (var i = 0; i < 60; i++) {
          canvas.drawCircle(
            Offset(((i * 137) % largura).toDouble(), ((i * 211) % altura).toDouble()),
            18 + (i % 7) * 9,
            Paint()..color = Color(0xff000000 | (i * 4109937)),
          );
        }
        final imagem = await rec.endRecording().toImage(largura, altura);

        // 1. O caminho VELHO: comprimir em PNG.
        final relogioPng = Stopwatch()..start();
        final png = await imagem.toByteData(format: ui.ImageByteFormat.png);
        relogioPng.stop();

        // 2. E gravar no disco.
        final arquivo = File('${pasta.path}/quadro.png');
        final relogioDisco = Stopwatch()..start();
        arquivo.writeAsBytesSync(png!.buffer.asUint8List());
        relogioDisco.stop();

        // 3. O caminho NOVO: os bytes como estao.
        final relogioCru = Stopwatch()..start();
        final cru = await imagem.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        relogioCru.stop();
        imagem.dispose();

        final velho = relogioPng.elapsedMicroseconds / 1000 +
            relogioDisco.elapsedMicroseconds / 1000;
        final novo = relogioCru.elapsedMicroseconds / 1000;
        final quadros = 10 * 60 * 30; // dez minutos a 30 fps
        String min(double msPorQuadro) =>
            (msPorQuadro * quadros / 1000 / 60).toStringAsFixed(1);

        // ignore: avoid_print
        print(
          '$nome  '
          'PNG ${relogioPng.elapsedMilliseconds} ms + disco '
          '${relogioDisco.elapsedMilliseconds} ms = '
          '${velho.toStringAsFixed(0)} ms/quadro  |  '
          'cru ${novo.toStringAsFixed(0)} ms/quadro  |  '
          '10 min a 30 fps: ${min(velho)} min -> ${min(novo)} min  |  '
          'disco: ${(png.lengthInBytes * quadros / 1024 / 1024 / 1024).toStringAsFixed(1)} GB -> 0',
        );
      }

      await medir('720p ', 1280, 720);
      await medir('1080p', 1920, 1080);
      await medir('4K   ', 3840, 2160);

      pasta.deleteSync(recursive: true);
    });
  });
}
