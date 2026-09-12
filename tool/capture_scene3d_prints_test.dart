import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/estudio/estudio_da_cena.dart';
import 'package:aurea/src/features/editor/presentation/estudio/estado_do_estudio.dart';
import 'package:aurea/src/features/editor/presentation/estudio/scene3d_theme.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_objetos.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_animacao.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_propriedades.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_adicionar.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_camera.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_luzes.dart';
import 'package:aurea/src/features/editor/presentation/estudio/folha_de_exportar.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';

class _MemoriaProjetos extends ProjectsController {
  @override
  List<VideoProject> build() => [];
  @override
  void upsert(VideoProject p) => state = [p];
}

Future<void> carregarFontes() async {
  for (final family in [
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    '.AppleSystemUIFont',
    'FlutterTest',
    'Ahem',
  ]) {
    try {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf')))
          .load();
    } catch (_) {}
  }
  try {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  } catch (_) {}
  try {
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')
          ..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf')))
        .load();
  } catch (_) {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await carregarFontes();
  });

  testWidgets('Capturar prints da nova UI do Scene 3D', (tester) async {
    const dir = 'output/ui_prints';
    Directory(dir).createSync(recursive: true);

    tester.view.physicalSize = const Size(820, 1720);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      prevOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = prevOnError);

    final container = ProviderContainer(
      overrides: [
        projectsControllerProvider.overrideWith(_MemoriaProjetos.new),
      ],
    );
    addTearDown(container.dispose);

    final sceneLayer = Scene3DLayer(
      id: 'camada_cena',
      name: 'Cena 3D Studio',
      startTime: Duration.zero,
      duration: const Duration(seconds: 10),
      camera: Camera3D(
        name: 'Câmera Principal',
        posX: AnimatedDouble(0),
        posY: AnimatedDouble(150),
        posZ: AnimatedDouble(800),
      ),
      scene: Scene3D(
        nodes: [
          SceneNode(
            id: 'node_casa',
            name: 'Casa Moderna',
            kind: Element3DKind.cube,
            size: 150,
            x: AnimatedDouble(0),
            y: AnimatedDouble(0),
            z: AnimatedDouble(0),
          ),
          SceneNode(
            id: 'node_carro',
            name: 'Carro Esportivo',
            kind: Element3DKind.cube,
            size: 80,
            x: AnimatedDouble(120),
            y: AnimatedDouble(-40),
            z: AnimatedDouble(60),
          ),
          SceneNode(
            id: 'node_arvore',
            name: 'Árvore',
            kind: Element3DKind.cylinder,
            size: 90,
            x: AnimatedDouble(-140),
            y: AnimatedDouble(20),
            z: AnimatedDouble(-30),
          ),
        ],
        lights: [
          Light3D(
            kind: Light3DKind.directional,
            intensity: AnimatedDouble(1.0),
            color: Colors.white,
          ),
          Light3D(
            kind: Light3DKind.point,
            intensity: AnimatedDouble(1.2),
            color: const Color(0xFF27E38C),
          ),
          Light3D(
            kind: Light3DKind.ambient,
            intensity: AnimatedDouble(0.6),
            color: Colors.white,
          ),
        ],
      ),
    );

    final projeto = VideoProject(
      id: 'demo_scene3d',
      name: 'Scene 3D Redesign',
      createdAt: DateTime.now(),
      aspectRatio: 9 / 16,
      resolutionHeight: 1280,
      layers: [sceneLayer],
    );

    final controller = container.read(editorControllerProvider.notifier);
    controller.openProject(projeto);

    final playback = PlaybackController(
      vsync: const TestVSync(),
      durationOf: () => const Duration(seconds: 10),
    );
    addTearDown(playback.dispose);

    Future<void> gravar(String nome) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('root_capture')),
        );
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        File('$dir/$nome.png').writeAsBytesSync(bytes);
        // Também copia para a pasta do brain para ser visível como artefato
        const brainDir = r'C:\Users\SnyX\.gemini\antigravity\brain\057d1835-61ef-4d15-8857-bbe013719b6a';
        File('$brainDir/$nome.png').writeAsBytesSync(bytes);
        image.dispose();
      });
    }

    Widget appWrap(Widget child) => UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: const ValueKey('root_capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: Scene3DTheme.bg,
            canvasColor: Scene3DTheme.bg,
          ),
          home: Scaffold(
            backgroundColor: Scene3DTheme.bg,
            body: child,
          ),
        ),
      ),
    );

    Widget sheetModalWrap(String title, Widget body) => Stack(
      children: [
        // Fundo com a viewport 3D
        EstudioDaCena(layerId: sceneLayer.id, playback: playback),
        // Overlay escuro
        Container(color: Colors.black.withValues(alpha: 0.5)),
        // Folha modal estilizada exatamente como o mockup
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 620),
            decoration: const BoxDecoration(
              color: Scene3DTheme.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(color: Scene3DTheme.border, width: 1.5),
                left: BorderSide(color: Scene3DTheme.border, width: 1.5),
                right: BorderSide(color: Scene3DTheme.border, width: 1.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Scene3DTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Scene3DSheetHeader(title: title),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // ==========================================
    // 1. TELA PRINCIPAL (Tela 1 do mockup)
    // Top bar [ < ][ Exportar ], toolbar flutuante 8 ferramentas à esquerda,
    // cubo de orientação 3D à direita, gizmo XYZ, Perspectiva pill, scrub bar
    // com play/pause e 00:00/00:10, e bottom navigation bar 4 abas.
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        EstudioDaCena(
          layerId: sceneLayer.id,
          playback: playback,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_01_tela_principal');

    // ==========================================
    // 2. OBJETOS (OUTLINER) (Tela 2 do mockup)
    // Filter chips (Todos, Modelos, Luzes, Câmeras), árvore hierárquica,
    // olhos de visibilidade, botão inferior [+ Adicionar Objeto].
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Objetos',
          FolhaDeObjetos(layerId: sceneLayer.id, tempo: Duration.zero),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_02_objetos');

    // ==========================================
    // 3. ANIMAÇÃO (CURVAS & KEYFRAMES) (Tela 3 do mockup)
    // Seletor dropdown, abas de modo (Posição, Rotação, Escala), gráfico Bézier
    // interativo com 3 canais (Verde X, Azul Y, Vermelho Z), lista de faixas
    // com olhos, botões (+ Adicionar, Ajustar, Excluir).
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Animação',
          FolhaDeAnimacao(layerId: sceneLayer.id, playback: playback),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_03_animacao');

    // ==========================================
    // 4. PROPRIEDADES (INSPECTOR) (Tela 4 do mockup)
    // Card banner do item (Casa Moderna, Modelo 3D), seções colapsáveis
    // Transformação (X, Y, Z com valores e pílulas), Material, Textura,
    // switches de Sombras e Renderização.
    // ==========================================
    container.read(noSelecionadoProvider.notifier).state = 'node_casa';
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Propriedades',
          FolhaDePropriedades(layerId: sceneLayer.id, tempo: Duration.zero),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_04_propriedades');

    // ==========================================
    // 5. ADICIONAR OBJETO (ASSET BROWSER) (Tela 5 do mockup)
    // Abas (Modelos, Luzes, Câmeras), busca 🔍, grade 2 colunas com cards visuais
    // (Casa Moderna, Carro Esportivo, Árvore, Pedra, etc.), botão inferior [+ Adicionar].
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Adicionar Objeto',
          FolhaDeAdicionar(
            layerId: sceneLayer.id,
            tempo: Duration.zero,
            aoAvisar: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_05_adicionar');

    // ==========================================
    // 6. CÂMERA (Tela 6 do mockup)
    // Card live preview FOV 45°, pílulas (Livre, Órbita, Fixa), vetores de Posição
    // e Alvo (Target) com reset, slider FOV 45°, botão [↻ Redefinir].
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Câmera',
          FolhaDeCamera(layerId: sceneLayer.id, tempo: Duration.zero),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_06_camera');

    // ==========================================
    // 7. LUZES (Tela 7 do mockup)
    // Switches Luz Direcional, Luz Pontual, Luz Ambiente, swatch de cor, slider
    // de intensidade (1.2), slider de ângulo (45°), botão [↻ Redefinir].
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Luzes',
          FolhaDeLuzes(layerId: sceneLayer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_07_luzes');

    // ==========================================
    // 8. EXPORTAR (Tela 8 do mockup)
    // Pílulas de formato (Vídeo, Imagem), dropdown resolução (1080p Full HD),
    // dropdown taxa de quadros (30 FPS), duração 00:10, botão verde [📤 Exportar].
    // ==========================================
    await tester.pumpWidget(
      appWrap(
        sheetModalWrap(
          'Exportar Cena 3D',
          FolhaDeExportar(layerId: sceneLayer.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await gravar('scene3d_08_exportar');
  });
}
