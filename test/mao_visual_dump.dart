// Dump visual da MAO ENTERRADA pelo pintor em CPU: pinta um quadro de
// cada plano e grava PNG, para conferir enquadramento, silhueta e luz
// sem depender do aparelho.
//
// Rodar:  flutter test test/mao_visual_dump.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/texture_cache.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/camera_cuts.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/domain/mao_enterrada_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _out =
    r'C:\Users\SnyX\AppData\Local\Temp\claude\C--Users-SnyX-Documents-Projetos---Claude-Aurea\c74a663a-6520-43d0-bb20-71b9ea4f5cc0\scratchpad\mao';

/// Dois instantes por plano: a entrada do corte e o meio dele.
const _instantes = [0.9, 2.4, 4.2, 6.4, 8.3, 10.4, 11.9, 13.8];

void main() {
  testWidgets('dump mao enterrada', (tester) async {
    await tester.runAsync(() async {
      Directory(_out).createSync(recursive: true);
      final projeto = buildMaoEnterradaTemplate();
      final cena = projeto.layers.whereType<Scene3DLayer>().single;
      // ignore: avoid_print
      print(
        'nos: ${cena.scene.nodes.length}  '
        'cameras: ${1 + cena.extraCameras.length}  '
        'tomadas: ${cena.shots.length}',
      );

      // As texturas geradas precisam estar decodificadas ANTES de pintar:
      // sem isso o ceu sai branco chapado, que foi o que aconteceu na
      // primeira rodada.
      for (final n in cena.scene.nodes) {
        for (final m in n.modelAsset?.data['materials'] as List? ?? const []) {
          final img = (m as Map)['image'] as String?;
          if (img != null) await TextureCache.instance.prepare(img);
        }
        final ip = n.material.imagePath;
        if (ip != null) await TextureCache.instance.prepare(ip);
      }

      const size = Size(1280, 536);
      for (var i = 0; i < _instantes.length; i++) {
        final segundos = _instantes[i];
        final t = Duration(microseconds: (segundos * 1000000).round());
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = projeto.backgroundColor,
        );
        final cam = resolveCamera(
          [cena.camera, ...cena.extraCameras],
          cena.shots,
          t,
          cena.camera,
        );
        Scene3DPainter(
          scene: cena.scene,
          camera: cena.camera,
          resolvedCamera: cam,
          view: SceneView.camera,
          time: t,
        ).paint(canvas, size);
        final img = await rec.endRecording().toImage(1280, 536);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_out\\mao_${i.toString().padLeft(2, '0')}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        // ignore: avoid_print
        print('mao_${i.toString().padLeft(2, '0')} = ${segundos}s');
      }

      // A MINIATURA DA GALERIA sai do mesmo lugar que os quadros de
      // conferencia: se a cena mudar, a miniatura muda junto. Cartao de
      // modelo que mostra outra coisa e pior que cartao sem imagem.
      const mini = Size(640, 268);
      final t = Duration(microseconds: (2400 * 1000).round());
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(
        Offset.zero & mini,
        Paint()..color = projeto.backgroundColor,
      );
      Scene3DPainter(
        scene: cena.scene,
        camera: cena.camera,
        resolvedCamera: resolveCamera(
          [cena.camera, ...cena.extraCameras],
          cena.shots,
          t,
          cena.camera,
        ),
        view: SceneView.camera,
        time: t,
      ).paint(canvas, mini);
      final capa = await rec.endRecording().toImage(640, 268);
      final capaPng = await capa.toByteData(format: ui.ImageByteFormat.png);
      File('assets/templates/mao-enterrada.png')
          .writeAsBytesSync(capaPng!.buffer.asUint8List());
      // ignore: avoid_print
      print('miniatura: ${capaPng.lengthInBytes ~/ 1024} kB');
    });
  });
}
