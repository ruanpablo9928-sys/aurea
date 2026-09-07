// Dump visual do PRISMA pelo pintor em CPU: pinta quadros escolhidos do
// loop e grava PNG, para conferir composicao, tempo e orientacao contra
// a referencia sem depender do aparelho. Sem bloom, sem desfoque de
// camada, sem glitch — so a geometria, as texturas e as cameras.
//
// Rodar:  flutter test test/prisma_visual_dump.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/application/texture_cache.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/domain/prisma_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _out =
    r'C:\Users\SnyX\AppData\Local\Temp\claude\C--Users-SnyX-Documents-Projetos---Claude-Aurea\c74a663a-6520-43d0-bb20-71b9ea4f5cc0\scratchpad\prisma';

/// Os instantes (em segundos do loop) que se conferem — um ou dois por
/// cena, nos momentos que a referencia mostra de forma mais clara.
const _instantes = [
  0.5, 1.6, 2.4, 3.6, 4.8, 5.3, 6.6, 7.6, 9.3, 10.9, 12.3, 13.6, 15.2, 15.7, 16.5,
];

void main() {
  testWidgets('dump prisma', (tester) async {
    await tester.runAsync(() async {
      Directory(_out).createSync(recursive: true);
      final p = buildPrismaTemplate();
      final layers = p.layers.whereType<Scene3DLayer>().toList();

      // As texturas geradas precisam estar decodificadas antes de pintar.
      for (final l in layers) {
        for (final n in l.scene.nodes) {
          for (final m in n.modelAsset?.data['materials'] as List? ?? const []) {
            final img = (m as Map)['image'] as String?;
            if (img != null) await TextureCache.instance.prepare(img);
          }
          final ip = n.material.imagePath;
          if (ip != null) await TextureCache.instance.prepare(ip);
        }
      }

      final fundo = layers.singleWhere((l) => l.id == 'prisma_fundo');
      const size = Size(720, 720);
      for (var i = 0; i < _instantes.length; i++) {
        final tg = _instantes[i];
        final t = Duration(microseconds: (tg * 1000000).round());
        final ativas = layers
            .where(
              (l) =>
                  l.id != 'prisma_fundo' &&
                  l.startTime <= t &&
                  t < l.startTime + l.duration,
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        final rec = ui.PictureRecorder();
        final canvas = Canvas(rec);
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF070609));
        void pintar(Scene3DLayer l) {
          Scene3DPainter(
            scene: l.scene,
            camera: l.camera,
            view: SceneView.camera,
            time: t - l.startTime,
          ).paint(canvas, size);
        }

        pintar(fundo);
        for (final l in ativas) {
          pintar(l);
        }
        final img = await rec.endRecording().toImage(720, 720);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$_out\\p_${i.toString().padLeft(2, '0')}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        // ignore: avoid_print
        print('p_${i.toString().padLeft(2, '0')} = ${tg}s: ${ativas.map((l) => l.name).join(' + ')}');
      }
    });
  });
}
