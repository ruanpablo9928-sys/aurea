// A CENA 3D E O RASTREIO VOLTARAM A TER PORTA.
//
// O estudio 3D foi apagado por inteiro com a UI antiga (commit
// `7fe26b6`) e nunca foi reconstruido. A auditoria contou **48 comandos
// 3D com zero chamadores**: a cena renderizava e nao havia um botao que
// mexesse nela. O solver de camera — essencial, homografia, SVD, nuvem
// de pontos e a recusa honesta de tripe — estava vivo e testado, e o
// unico caminho ate ele nao tinha chamador.
//
// Estes testes cobram a PORTA. O solve em si tem testes proprios
// (`camera_solver3d_test.dart`), e nao roda aqui: ele le um video.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/camera_solver3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_de_rastreio.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, PlaybackController p, String id});

Future<_Bancada> _montar(
  WidgetTester tester,
  String categoria, {
  bool video = false,
}) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  if (video) {
    c.addVideoLayer(
      Duration.zero,
      'clipe.mp4',
      'Clipe',
      const Duration(seconds: 5),
      fonte: const Duration(seconds: 5),
    );
  } else {
    c.addScene3DLayer(Duration.zero);
  }
  final camada = container.read(editorControllerProvider).layers.single;
  container.read(selectedLayerProvider.notifier).state = camada.id;

  final playback = PlaybackController(
    vsync: _Vsync(),
    durationOf: () => container.read(editorControllerProvider).duration,
  );
  addTearDown(playback.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final atual = ref
                  .watch(editorControllerProvider)
                  .layers
                  .where((l) => l.id == camada.id)
                  .firstOrNull;
              if (atual == null) return const SizedBox.shrink();
              return ControlesDaCategoria(
                categoriaId: categoria,
                camada: atual,
                playback: playback,
                aoVoltar: () {},
              );
            },
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback, id: camada.id);
}

Scene3DLayer _cena(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id)
        as Scene3DLayer;

Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
}

void main() {
  group('o cartao', () {
    test('cena 3D ganha "Cena e camera"; texto nao', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addScene3DLayer(Duration.zero);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camadas = container.read(editorControllerProvider).layers;
      final cena = camadas.whereType<Scene3DLayer>().single;
      final texto = camadas.whereType<TextLayer>().single;
      expect(categoriasDaCamada(cena).map((x) => x.id), contains('cena'));
      expect(
        categoriasDaCamada(texto).map((x) => x.id),
        isNot(contains('cena')),
      );
    });

    test('video ganha "Rastrear a camera"; audio nao', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addVideoLayer(
        Duration.zero,
        'c.mp4',
        'Clipe',
        const Duration(seconds: 2),
      );
      final id = c.addAudioLayer(
        Duration.zero,
        'a.m4a',
        'Audio',
        const Duration(seconds: 2),
      );
      final camadas = container.read(editorControllerProvider).layers;
      final video = camadas.whereType<VideoLayer>().single;
      final audio = camadas.firstWhere((l) => l.id == id);
      expect(
        categoriasDaCamada(video).map((x) => x.id),
        contains('rastreio'),
      );
      expect(
        categoriasDaCamada(audio).map((x) => x.id),
        isNot(contains('rastreio')),
      );
    });
  });

  group('de onde se olha', () {
    testWidgets('as sete vistas estao la, e trocam', (tester) async {
      final m = await _montar(tester, 'cena');
      expect(_cena(m.c, m.id).view, SceneView.camera);

      for (final v in const [
        SceneView.camera,
        SceneView.front,
        SceneView.back,
        SceneView.left,
        SceneView.right,
        SceneView.top,
        SceneView.bottom,
      ]) {
        expect(
          find.bySemanticsLabel('Vista ${sceneViewLabel(v)}'),
          findsOneWidget,
          reason: '${sceneViewLabel(v)} existia no motor e nao na tela',
        );
      }

      await _tocar(tester, 'Vista Topo');
      expect(
        _cena(m.c, m.id).view,
        SceneView.top,
        reason: 'o palco lia `view` e ela ficava presa em "Camera" para sempre',
      );
    });

    testWidgets('ortografica liga e desliga', (tester) async {
      final m = await _montar(tester, 'cena');
      expect(_cena(m.c, m.id).camera.orthographic, isFalse);

      await _tocar(tester, 'Perspectiva');
      expect(_cena(m.c, m.id).camera.orthographic, isTrue);
      expect(find.bySemanticsLabel('Ortografica (sem fuga)'), findsOneWidget);
    });

    testWidgets('a lente muda, e o angulo acompanha', (tester) async {
      final m = await _montar(tester, 'cena');
      final antes = _cena(m.c, m.id).camera.fovAt(Duration.zero);

      await tester.tap(find.bySemanticsLabel('Valor de Lente'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, '18');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('campo-de-valor-ok')));
      await tester.pumpAndSettle();

      final cena = _cena(m.c, m.id);
      expect(cena.camera.focalLength.valueAt(Duration.zero), 18);
      expect(
        cena.camera.fovAt(Duration.zero),
        greaterThan(antes),
        reason: 'lente mais curta e angulo mais aberto',
      );
    });
  });

  group('cameras', () {
    testWidgets('criar, cortar e apagar', (tester) async {
      final m = await _montar(tester, 'cena');
      expect(_cena(m.c, m.id).allCameras, hasLength(1));

      await _tocar(tester, 'Nova camera');
      expect(_cena(m.c, m.id).allCameras, hasLength(2));

      final nova = _cena(m.c, m.id).allCameras.last;
      await _tocar(tester, 'Cortar para ${nova.name}');
      expect(
        _cena(m.c, m.id).shots,
        hasLength(1),
        reason: 'trocar de camera nao tinha superficie nenhuma',
      );
      expect(_cena(m.c, m.id).shots.single.cameraId, nova.id);

      await _tocar(tester, 'Apagar ${nova.name}');
      expect(_cena(m.c, m.id).allCameras, hasLength(1));
    });

    testWidgets('a camera da cena nao oferece apagar', (tester) async {
      final m = await _montar(tester, 'cena');
      final base = _cena(m.c, m.id).camera;
      // Sem nenhuma nao ha do que renderizar, e o motor cairia de volta
      // nela de qualquer jeito: um botao que nao faz nada e pior que
      // botao nenhum.
      expect(find.bySemanticsLabel('Apagar ${base.name}'), findsNothing);
      expect(find.bySemanticsLabel('Duplicar ${base.name}'), findsOneWidget);
    });

    testWidgets('duplicar copia o enquadramento', (tester) async {
      final m = await _montar(tester, 'cena');
      final base = _cena(m.c, m.id).camera;
      await _tocar(tester, 'Duplicar ${base.name}');

      final copias = _cena(m.c, m.id).allCameras;
      expect(copias, hasLength(2));
      expect(copias.last.posZ.base, base.posZ.base);
      expect(copias.last.id, isNot(base.id));
    });
  });

  group('movimento pronto', () {
    testWidgets('os cinco rigs estao la', (tester) async {
      await _montar(tester, 'cena');
      for (final r in CameraRig.values) {
        expect(
          find.bySemanticsLabel('Rig ${cameraRigLabel(r)}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('um rig grava keyframes de verdade', (tester) async {
      final m = await _montar(tester, 'cena');
      expect(_cena(m.c, m.id).camera.posX.isAnimated, isFalse);

      await _tocar(tester, 'Rig ${cameraRigLabel(CameraRig.orbit)}');

      final cam = _cena(m.c, m.id).camera;
      final animou =
          cam.posX.isAnimated || cam.posZ.isAnimated || cam.posY.isAnimated;
      expect(
        animou,
        isTrue,
        reason: 'o rig gera keyframes REAIS, e nao um efeito escondido',
      );
    });
  });

  group('rastrear', () {
    testWidgets('a ficha abre com as escolhas e o botao', (tester) async {
      await _montar(tester, 'rastreio', video: true);
      for (final m in ModoDoSolve.values) {
        expect(find.bySemanticsLabel('Modo ${m.emPalavras}'), findsOneWidget);
      }
      for (final t in TipoDeTomada.values) {
        expect(
          find.bySemanticsLabel('Tomada ${t.emPalavras}'),
          findsOneWidget,
        );
      }
      expect(find.bySemanticsLabel('Rastrear a camera'), findsOneWidget);
      // Sem solve ainda, nao ha ficha nem cena para criar.
      expect(
        find.bySemanticsLabel('Criar a cena 3D em cima do clipe'),
        findsNothing,
      );
    });

    testWidgets('trocar o modo troca a explicacao', (tester) async {
      final m = await _montar(tester, 'rastreio', video: true);
      expect(m.c.read(modoDoSolveProvider), ModoDoSolve.equilibrado);

      await _tocar(tester, 'Modo ${ModoDoSolve.preciso.emPalavras}');
      expect(m.c.read(modoDoSolveProvider), ModoDoSolve.preciso);
      expect(
        find.text(ModoDoSolve.preciso.explicacao),
        findsOneWidget,
        reason: 'a explicacao existia no motor e nunca foi mostrada',
      );
    });
  });
}
