// Captures the actual Aurea widgets and exercises their controls. No mock UI.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/model_import_service.dart';
import 'package:aurea/src/features/editor/application/texture_cache.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/template_pack.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/editor/presentation/am/am_timeline.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/editor/presentation/am/scene3d_studio.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';

class MemoryProjects extends ProjectsController {
  @override
  List<VideoProject> build() => [];
  @override
  void upsert(VideoProject p) => state = [p];
}

class TouchPainter extends CustomPainter {
  TouchPainter(this.points);
  final List<Offset> points;
  @override
  void paint(Canvas c, Size s) {
    for (final p in points) {
      c.drawCircle(p, 16, Paint()..color = const Color(0x557c62ff));
      c.drawCircle(
        p,
        16,
        Paint()
          ..color = const Color(0xffb8ff3d)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.drawCircle(p, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(TouchPainter old) => true;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final family in [
      'Aurea Motion Sans',
      'Roboto',
      '.SF Pro Text',
      '.SF Pro Display',
      '.SF UI Text',
      '.SF UI Display',
    ]) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('record a real UI walkthrough of scene gestures, keys and cuts', (
    tester,
  ) async {
    const dir = 'output/tutorial-scene3d/recording';
    Directory(dir).createSync(recursive: true);
    tester.view.physicalSize = const Size(430, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [projectsControllerProvider.overrideWith(MemoryProjects.new)],
    );
    addTearDown(container.dispose);
    final model = await tester.runAsync(
      () => readModel3DFiles(['output/void/ASTRONAUTA.glb']),
    );
    await tester.runAsync(() async {
      for (final m in model!.data['materials'] as List) {
        if (m['image'] != null) await TextureCache.instance.prepare(m['image']);
      }
    });
    final controller = container.read(editorControllerProvider.notifier);
    final demo = VideoProject(
      id: 'tutorial_scene3d',
      name: 'Aprenda Cena 3D',
      createdAt: DateTime(2026, 9, 6),
      aspectRatio: 9 / 16,
      resolutionHeight: 1280,
      fps: 30,
      layers: [
        Scene3DLayer(
          id: 'demo',
          name: 'Astronauta • Cena 3D',
          startTime: Duration.zero,
          duration: const Duration(seconds: 10),
          position: AnimatedOffset(const Offset(360, 640)),
          camera: Camera3D(
            name: 'Camera 1',
            posZ: AnimatedDouble(440),
            focalLength: AnimatedDouble(50),
          ),
          showHelpers: false,
          scene: Scene3D(
            showFloorGrid: false,
            background: const Color(0xff020612),
            ambient: .45,
            nodes: [
              SceneNode(
                id: 'astro',
                name: 'Astronauta',
                modelAsset: model,
                size: 100,
              ),
            ],
            lights: [
              Light3D(
                intensity: AnimatedDouble(1.15),
                direction: const Vec3(-.4, -.6, -.8),
              ),
            ],
          ),
        ),
      ],
    );
    controller.openProject(demo);
    final touches = ValueNotifier<List<Offset>>([]);
    addTearDown(touches.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('recording-root'),
          child: Stack(
            textDirection: TextDirection.ltr,
            fit: StackFit.expand,
            children: [
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                  platform: TargetPlatform.iOS,
                  fontFamily: 'Aurea Motion Sans',
                ),
                home: const EditorScreen(),
              ),
              IgnorePointer(
                child: ValueListenableBuilder<List<Offset>>(
                  valueListenable: touches,
                  builder: (_, p, _) => CustomPaint(painter: TouchPainter(p)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final clips = <Map<String, Object>>[];
    String chapter = '01 • ABRIR A CENA';
    Future<void> capture(String caption, {double seconds = 3}) async {
      await tester.pump();
      expect(tester.takeException(), isNull);
      final name = 'screen-${clips.length.toString().padLeft(4, '0')}.png';
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('recording-root')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      clips.add({
        'file': name,
        'duration': seconds,
        'chapter': chapter,
        'caption': caption,
      });
      File('$dir/clips.json').writeAsStringSync(jsonEncode(clips));
    }

    Future<void> tap(
      Finder target,
      String caption, {
      double seconds = 3,
    }) async {
      if (target.hitTestable().evaluate().isEmpty &&
          target.evaluate().length == 1) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
      }
      expect(target.hitTestable(), findsOneWidget);
      final p = tester.getCenter(target.hitTestable());
      touches.value = [p];
      await capture(caption, seconds: .5);
      await tester.tap(target.hitTestable());
      await tester.pumpAndSettle();
      touches.value = [];
      await capture(caption, seconds: seconds);
    }

    Finder viewport() => find
        .byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              w.painter is Scene3DPainter &&
              (w.painter as Scene3DPainter).view == SceneView.camera,
        )
        .last;
    Future<void> drag(Offset start, Offset delta, String caption) async {
      final gesture = await tester.startGesture(start);
      touches.value = [start];
      for (var i = 1; i <= 12; i++) {
        final p = start + delta * (i / 12);
        await gesture.moveTo(p);
        touches.value = [p];
        await tester.pump(const Duration(milliseconds: 80));
        await capture(caption, seconds: .1);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      touches.value = [];
      await capture(caption, seconds: 2.5);
    }

    await capture('Cena 3D: navegação, keyframes e troca de câmera.');
    final bar = find
        .descendant(
          of: find.byType(AmTimeline),
          matching: find.text('Astronauta • Cena 3D'),
        )
        .first;
    await tap(bar, 'Toque na camada para abrir suas ferramentas.');
    await tap(find.text('Cena 3D'), 'Entre em Cena 3D para abrir o Estúdio.');
    expect(find.byType(Scene3DStudio), findsOneWidget);
    if (Platform.environment['AUREA_TUTORIAL_STAGE'] == 'intro') return;

    chapter = '02 • NAVEGAR';
    await tap(
      find.text('Auto-key ligado'),
      'Desligue Auto-key enquanto procura o enquadramento.',
    );
    await tap(find.text('Navegar'), 'Ative Navegar para controlar a câmera.');
    final viewRect = tester.getRect(viewport());
    await drag(
      viewRect.center,
      const Offset(60, 12),
      'Arraste com um dedo para orbitar a câmera.',
    );
    final left = viewRect.center - const Offset(45, 0),
        right = viewRect.center + const Offset(45, 0);
    final g1 = await tester.startGesture(left, pointer: 3),
        g2 = await tester.startGesture(right, pointer: 4);
    for (var i = 1; i <= 10; i++) {
      final d = Offset(i * 2.0, 0);
      await g1.moveTo(left - d);
      await g2.moveTo(right + d);
      touches.value = [left - d, right + d];
      await tester.pump(const Duration(milliseconds: 80));
      await capture('Faça uma pinça para aproximar a câmera.', seconds: .1);
    }
    await g1.up();
    await g2.up();
    touches.value = [];
    await tester.pumpAndSettle();
    await capture('A pinça muda a distância. Ela não altera a lente.');

    chapter = '03 • ANIMAR O OBJETO';
    await tap(
      find.text('Navegar'),
      'Desative Navegar para manipular o objeto.',
    );
    await tap(
      find.text('Camera 1').last,
      'O nome abaixo da prévia escolhe o alvo da edição.',
    );
    await tap(
      find.text('Astronauta').last,
      'Escolha Astronauta para animar o modelo.',
    );
    await tap(
      find.text('Auto-key desligado'),
      'Ligue Auto-key para gravar os movimentos.',
    );
    await tap(
      find.byTooltip('Adicionar keyframe'),
      'No tempo zero, marque o primeiro keyframe.',
    );
    final ruler = find.byKey(const ValueKey('scene-motion-time'));
    // Use the exact same callback as the UI ruler to land on a precise frame.
    touches.value = [tester.getCenter(ruler)];
    await capture('Avance a régua de tempo até 2 segundos.', seconds: .5);
    tester.widget<AmTickRuler>(ruler).onChanged(2);
    touches.value = [];
    await tester.pumpAndSettle();
    await capture('Agora estamos em 2,00 s.');
    await tap(
      find.text('Girar'),
      'Escolha Girar para mudar a orientação do astronauta.',
    );
    await drag(
      tester.getRect(viewport()).center,
      const Offset(55, 0),
      'Arraste o modelo. Auto-key grava o segundo estado.',
    );
    final edited =
        container.read(editorControllerProvider).layerById('demo')
            as Scene3DLayer;
    expect(edited.scene.nodes.first.rotY.isAnimated, isTrue);
    await tap(
      find.byTooltip('Keyframe anterior'),
      'As setas saltam entre os keyframes.',
    );
    await tap(
      find.byTooltip('Proximo keyframe'),
      'Compare o início e o fim do movimento.',
    );
    await tap(
      find.byTooltip('Curva do movimento'),
      'Abra as curvas para mudar o ritmo.',
    );
    await tap(
      find.text('Suave'),
      'Suave deixa a partida e a chegada mais graduais.',
    );
    tester.widget<AmTickRuler>(ruler).onChanged(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reproduzir cena'));
    await tester.pump();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await capture(
        'Reproduza para conferir o movimento entre os keyframes.',
        seconds: .1,
      );
    }
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pumpAndSettle();

    chapter = '04 • CRIAR CÂMERAS';
    await tap(
      find.byIcon(CupertinoIcons.chevron_down).first,
      'Volte à timeline principal.',
    );
    await tap(
      find
          .descendant(
            of: find.byType(AmTimeline),
            matching: find.text('Astronauta • Cena 3D'),
          )
          .first,
      'Abra novamente as ferramentas da camada.',
    );
    // The expanded layer menu exposes the camera utility.
    if (find.byTooltip('Cameras').hitTestable().evaluate().isEmpty) {
      await tap(
        find
            .descendant(
              of: find.byType(AmTimeline),
              matching: find.text('Astronauta • Cena 3D'),
            )
            .first,
        'Toque na camada selecionada para abrir o menu.',
      );
    }
    await tap(
      find.byTooltip('Cameras'),
      'Abra Cameras, pelo ícone de filmadora.',
    );
    await tap(
      find.text('Nova camera (enquadramento atual)'),
      'Adicione uma segunda câmera.',
    );
    await tap(
      find.text('Nova camera (enquadramento atual)'),
      'Adicione uma terceira câmera.',
    );
    await tap(
      find.text('Nova camera (enquadramento atual)'),
      'Agora temos quatro câmeras para quatro tomadas.',
    );
    await tap(
      find.text('Camera 1 (principal)'),
      'Em 0 s, toque na câmera 1 para gravar o primeiro corte.',
    );
    // Close the actual sheet with back, seek the main ruler through its public controller.
    Future<void> closeSheet() async {
      await tap(
        find.byTooltip('Fechar painel'),
        'Feche o painel para voltar à timeline.',
        seconds: 1,
      );
    }

    await closeSheet();
    for (var i = 1; i < 4; i++) {
      final timeline = tester.widget<AmTimeline>(find.byType(AmTimeline).first);
      timeline.playback.seek(Duration(milliseconds: i * 2500));
      await tester.pumpAndSettle();
      await capture(
        'Posicione a timeline em ${(i * 2.5).toStringAsFixed(2)} s.',
      );
      await tap(
        find.text('Mais ações'),
        'Toque em Mais ações para abrir o menu da camada.',
      );
      await tap(find.byTooltip('Cameras'), 'Abra Cameras no tempo escolhido.');
      await tap(
        find.text('Camera ${i + 1}'),
        'Toque na câmera ${i + 1}: isso grava um corte aqui.',
      );
      if (i == 3) {
        await tester.ensureVisible(find.text('Tomadas'));
        await tester.pumpAndSettle();
        await capture('Quatro tomadas: 0 s, 2,5 s, 5 s e 7,5 s.', seconds: 4);
      }
      await closeSheet();
    }
    final finalLayer =
        container.read(editorControllerProvider).layerById('demo')
            as Scene3DLayer;
    expect(finalLayer.shots.length, 4);
    chapter = '05 • EDITAR A TOMADA';
    await tap(
      find.text('Mais ações'),
      'Abra Mais ações para voltar à Cena 3D.',
    );
    await tap(
      find.text('Cena 3D'),
      'No Estúdio, escolha o trecho da câmera que quer editar.',
    );
    tester
        .widget<AmTickRuler>(find.byKey(const ValueKey('scene-motion-time')))
        .onChanged(6);
    await tester.pumpAndSettle();
    await capture(
      'Em 6 s, a câmera ativa é a Camera 3. Confira o nome.',
      seconds: 4,
    );
    await tap(find.text('Navegar'), 'Ative Navegar para ajustar esta tomada.');
    await drag(
      tester.getRect(viewport()).center,
      const Offset(-45, 0),
      'O gesto agora altera a câmera 3, dentro da sua tomada.',
    );
    chapter = 'PRONTO PARA PRATICAR';
    await capture(
      'Objeto = modelo. Câmera = enquadramento. Tomada = corte.',
      seconds: 5,
    );
    File('output/tutorial-scene3d/DEMONSTRACAO.aurea').writeAsStringSync(
      jsonEncode(
        TemplatePack(
          name: 'Tutorial • Cena 3D',
          project: container.read(editorControllerProvider),
        ).toJson(),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
