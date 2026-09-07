import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/domain/flor_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// FERRAMENTA DE MESA: desenha quadros da FLOR em arquivo.
///
/// Nao afirma nada — serve para OLHAR. Uma cena 3D montada em codigo e
/// escrita as cegas; sem um quadro na tela nao ha como saber se a flor
/// ficou flor. Tambem e daqui que sai a miniatura do cartao na Inicio:
/// uma foto do que a cena realmente e, e nao um desenho a parte que
/// envelhece sozinho.
void main() {
  testWidgets('quadros da FLOR', (tester) async {
    // toImage e assincrono DE VERDADE (passa pela thread de raster). O
    // relogio do testWidgets e falso: sem runAsync o await nunca volta.
    await tester.runAsync(() async {
    final projeto = buildFlorTemplate();
    final camada = projeto.layers.whereType<Scene3DLayer>().single;
    final cameras = [camada.camera, ...camada.extraCameras];
    final pasta = Directory('build/flor')..createSync(recursive: true);

    Future<void> quadro(String nome, Camera3D cam, double s, ui.Size tam) async {
      final t = Duration(microseconds: (s * 1000000).round());
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & tam,
        Paint()..color = camada.scene.background ?? const Color(0xff000000),
      );
      Scene3DPainter(
        scene: camada.scene,
        camera: cam,
        view: SceneView.camera,
        time: t,
        overrideCamera: cam.renderAt(t),
      ).paint(canvas, tam);
      final img = await rec.endRecording().toImage(
        tam.width.round(),
        tam.height.round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${pasta.path}/$nome.png').writeAsBytesSync(
        png!.buffer.asUint8List(),
      );
      img.dispose();
    }

    // Um quadro no meio de cada tomada — e um extra da 2, que e a macro.
    await quadro('01-luz', cameras[0], 1.7, const ui.Size(640, 360));
    await quadro('02-detalhe', cameras[1], 5.1, const ui.Size(640, 360));
    await quadro('03-respira', cameras[2], 8.4, const ui.Size(640, 360));

    // A MINIATURA do cartao: o cartao e 156x118, entao 468x354 (3x).
    await quadro('miniatura', cameras[0], 2.6, const ui.Size(468, 354));
    File('build/flor/miniatura.png').copySync('assets/templates/flor.png');

    // ignore: avoid_print
    print('quadros em ${pasta.absolute.path}');
    });
  });
}
