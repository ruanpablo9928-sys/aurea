import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/estudio_preferencia.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/estudio_ux.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/editor/presentation/am/scene3d_studio.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A REESTRUTURACAO DA UX DO ESTUDIO 3D.
///
/// O que se prova aqui e o que a missao pediu: a tela simples por
/// padrao (Voltar, a camera no meio, os tres pontos, as quatro
/// ferramentas), o "+" que cria em dois toques, a troca de camera
/// instantanea e a camera nova, as ferramentas de fato transformando
/// (Selecionar so navega), o Focar, o painel da cena com busca e acoes,
/// a selecao multipla com Agrupar, o desfazer, o modo avancado que fica
/// guardado, as dicas que aparecem uma vez — e, no dominio, o olhar
/// para, a grade e a hierarquia em arvore.
void main() {
  Scene3DLayer cena({List<SceneNode>? nos, List<Camera3D> extras = const []}) =>
      Scene3DLayer(
        id: 'scene',
        name: 'Motion',
        startTime: Duration.zero,
        duration: const Duration(seconds: 5),
        scene: Scene3D(
          nodes: nos ?? [SceneNode(id: 'cube', name: 'Cubo manual')],
        ),
        extraCameras: extras,
      );

  Future<ProviderContainer> abrir(
    WidgetTester tester, {
    Scene3DLayer? camada,
    SharedPreferences? prefs,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .openProject(
          container
              .read(editorControllerProvider)
              .copyWith(layers: [camada ?? cena()]),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scene3DStudio(layerId: 'scene')),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Scene3DLayer camadaDe(ProviderContainer c) =>
      c.read(editorControllerProvider).layerById('scene') as Scene3DLayer;

  final viewport = find.byWidgetPredicate(
    (w) =>
        w is CustomPaint &&
        w.painter is Scene3DPainter &&
        (w.painter as Scene3DPainter).view == SceneView.camera,
  );

  Future<void> tocarNoCubo(WidgetTester tester) async {
    await tester.tap(viewport);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Toca num chip da barra de contexto (ela rola: a fonte de teste e
  /// larga e empurra os ultimos para fora da tela).
  Future<void> tocarChip(WidgetTester tester, String chave) async {
    final f = find.byKey(ValueKey(chave));
    expect(f, findsOneWidget, reason: 'chip $chave');
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------- dominio

  group('dominio', () {
    test('encaixar na grade e travar eixo', () {
      expect(encaixar(23, 10), 20);
      expect(encaixar(27, 10), 30);
      expect(encaixar(-14, 10), -10);
      expect(encaixar(5, 0), 5, reason: 'passo zero nao encaixa');
      expect(
        travarEixo(const Vec3(1, 2, 3), EixoTravado.y).toString(),
        'Vec3(0.0, 2.0, 0.0)',
      );
      expect(
        travarEixo(const Vec3(1, 2, 3), EixoTravado.livre).toString(),
        'Vec3(1.0, 2.0, 3.0)',
      );
    });

    test('a hierarquia vem em arvore, com nivel, e a busca ignora acento', () {
      final scene = Scene3D(
        nodes: [
          SceneNode(id: 'a', name: 'Esfera'),
          SceneNode(id: 'g', name: 'Grupo', isNull: true),
          SceneNode(id: 'b', name: 'Cubo', parentId: 'g'),
          SceneNode(id: 'c', name: 'Cone', parentId: 'b'),
          SceneNode(id: 'orfao', name: 'Orfao', parentId: 'sumiu'),
        ],
        lights: [Light3D(id: 'l1')],
      );
      final itens = hierarquiaDaCena(
        scene,
        luzes: scene.lights,
        cameras: [Camera3D(id: 'cam', name: 'Camera')],
        cameraAtiva: 'cam',
      );
      expect(
        [for (final i in itens) '${i.nome}:${i.nivel}'],
        [
          'Esfera:0',
          'Grupo:0',
          'Cubo:1',
          'Cone:2',
          'Orfao:0',
          'Luz direcional:0',
          'Camera:0',
        ],
      );
      expect(itens.firstWhere((i) => i.id == 'g').grupo, isTrue);
      expect(itens.last.ativo, isTrue, reason: 'a camera no ar vem marcada');
      expect(buscarNaCena(itens, 'cÚ').map((i) => i.nome), ['Cubo']);
      expect(buscarNaCena(itens, '').length, itens.length);
      expect(buscarNaCena(itens, 'nada'), isEmpty);
    });

    test(
      'olhar para: a camera segue o objeto no tempo, e vai para o arquivo',
      () {
        final cam = Camera3D(
          id: 'cam',
          posX: AnimatedDouble(0),
          posY: AnimatedDouble(0),
          posZ: AnimatedDouble(900),
          lookAtNodeId: 'cube',
        );
        final layer = Scene3DLayer(
          id: 'scene',
          name: 'M',
          startTime: Duration.zero,
          duration: const Duration(seconds: 4),
          camera: cam,
          scene: Scene3D(
            nodes: [
              SceneNode(
                id: 'cube',
                name: 'Cubo',
                x: AnimatedDouble(0)
                    .withKeyframe(Duration.zero, 0)
                    .withKeyframe(const Duration(seconds: 2), 400),
              ),
            ],
          ),
        );
        expect(layer.cameraAt(Duration.zero).target.x, closeTo(0, 1e-6));
        expect(
          layer.cameraAt(const Duration(seconds: 2)).target.x,
          closeTo(400, 1e-6),
          reason: 'o alvo e a posicao do objeto naquele instante',
        );
        expect(
          layer.cameraAt(const Duration(seconds: 2)).position.z,
          closeTo(900, 1e-6),
          reason: 'so o alvo muda; a posicao e a gravada',
        );

        // Sem o no, a camera volta ao ponto de interesse dela.
        final solta = layer.copyScene(camera: cam.copyWith(clearLookAt: true));
        expect(solta.camera.lookAtNodeId, isNull);
        expect(
          solta.cameraAt(const Duration(seconds: 2)).target.x,
          closeTo(0, 1e-6),
        );

        // O arquivo do projeto guarda e le o alvo.
        final json = projectToJson(
          VideoProject(name: 'p', createdAt: DateTime(2026), layers: [layer]),
        );
        final lido = projectFromJson(json).layers.single as Scene3DLayer;
        expect(lido.camera.lookAtNodeId, 'cube');
      },
    );

    test('duplicar um no copia tudo com id novo', () {
      final n = SceneNode(
        id: 'a',
        name: 'Cubo',
        kind: Element3DKind.torus,
        x: AnimatedDouble(120),
        locked: true,
        parentId: 'pai',
      );
      final d = n.duplicado();
      expect(d.id, isNot('a'));
      expect(d.name, 'Cubo copia');
      expect(d.kind, Element3DKind.torus);
      expect(d.x.base, 120);
      expect(d.locked, isTrue);
      expect(d.parentId, 'pai');
    });
  });

  // ---------------------------------------------------------- tela

  testWidgets(
    'a tela simples: Voltar, a camera no meio, os tres pontos e as quatro ferramentas',
    (tester) async {
      await abrir(tester);
      expect(find.byKey(const ValueKey('estudio-voltar')), findsOneWidget);
      expect(find.text('Cena'), findsOneWidget);
      expect(find.byKey(const ValueKey('estudio-camera')), findsOneWidget);
      expect(
        find.text('Camera'),
        findsOneWidget,
        reason: 'o nome da camera no ar',
      );
      expect(find.byKey(const ValueKey('estudio-mais')), findsOneWidget);
      for (final f in ['Selecionar', 'Mover', 'Girar', 'Escalar']) {
        expect(find.text(f), findsOneWidget, reason: 'ferramenta $f');
      }
      expect(find.byKey(const ValueKey('estudio-adicionar')), findsOneWidget);
      expect(find.byKey(const ValueKey('estudio-focar')), findsOneWidget);
      expect(find.byKey(const ValueKey('estudio-cena')), findsOneWidget);
      expect(find.byKey(const ValueKey('estudio-desfazer')), findsOneWidget);
      expect(find.byKey(const ValueKey('estudio-refazer')), findsOneWidget);
      expect(find.byKey(const ValueKey('scene-motion-time')), findsOneWidget);
      // Sem selecao, a barra de contexto e a da camera.
      expect(find.byKey(const ValueKey('contexto-adicionar')), findsOneWidget);
      expect(find.byKey(const ValueKey('contexto-lente')), findsOneWidget);
      // O modo simples esconde as vistas e os comandos de camera.
      expect(find.text('Enquadrar tudo'), findsNothing);
      expect(find.text('Frente'), findsNothing);
      expect(find.text('Auto-key'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('o + cria um cubo em dois toques e ja o seleciona', (
    tester,
  ) async {
    final c = await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('estudio-adicionar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adicionar-objeto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adicionar-cube')));
    await tester.pumpAndSettle();
    final nos = camadaDe(c).scene.nodes;
    expect(nos.length, 2);
    expect(nos.last.kind, Element3DKind.cube);
    // O novo esta selecionado: a barra de contexto mostra o nome dele.
    expect(find.byKey(const ValueKey('contexto-objeto')), findsOneWidget);
    expect(find.text(nos.last.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o + tambem cria uma luz, e a barra passa a ser a da luz', (
    tester,
  ) async {
    final c = await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('estudio-adicionar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adicionar-luz')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('adicionar-luz-point')));
    await tester.pumpAndSettle();
    expect(camadaDe(c).scene.lights.single.kind, Light3DKind.point);
    expect(find.byKey(const ValueKey('contexto-intensidade')), findsOneWidget);
    expect(find.byKey(const ValueKey('contexto-sombras')), findsOneWidget);
    // Sombras e um toque (a primeira luz ja nasce com sombra: o toque
    // desliga; o segundo liga de novo).
    final antes = camadaDe(c).scene.lights.single.castsShadow;
    await tocarChip(tester, 'contexto-sombras');
    expect(camadaDe(c).scene.lights.single.castsShadow, !antes);
    await tocarChip(tester, 'contexto-sombras');
    expect(camadaDe(c).scene.lights.single.castsShadow, antes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera: nova camera entra no ar, e a troca e um toque', (
    tester,
  ) async {
    final c = await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('estudio-camera')));
    await tester.pumpAndSettle();
    expect(find.text('Nova camera'), findsOneWidget);
    expect(find.text('Pela camera'), findsOneWidget);
    expect(
      find.text('Frente'),
      findsOneWidget,
      reason: 'as vistas moram no menu da camera',
    );
    await tester.tap(find.byKey(const ValueKey('camera-nova')));
    await tester.pumpAndSettle();
    var layer = camadaDe(c);
    expect(layer.allCameras.length, 2);
    final nova = layer.extraCameras.single;
    expect(layer.shots.single.cameraId, nova.id, reason: 'a nova entra no ar');
    expect(
      find.text(nova.name),
      findsWidgets,
      reason: 'o titulo mostra a camera no ar',
    );

    // Com duas cameras aparece a faixa de troca rapida.
    final chipPrincipal = find.byKey(
      ValueKey('faixa-camera-${layer.camera.id}'),
    );
    expect(chipPrincipal, findsOneWidget);
    await tester.tap(chipPrincipal);
    await tester.pumpAndSettle();
    layer = camadaDe(c);
    expect(
      layer.shots.last.cameraId,
      layer.camera.id,
      reason: 'a troca e instantanea',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selecionar so navega; Mover arrasta; Escalar escala', (
    tester,
  ) async {
    final c = await abrir(tester);
    await tocarNoCubo(tester);
    expect(
      find.text('Cubo manual'),
      findsOneWidget,
      reason: 'o toque selecionou',
    );
    final camAntes = camadaDe(c).camera.positionAt(Duration.zero);
    double x() => camadaDe(c).scene.nodeById('cube')!.x.valueAt(Duration.zero);
    double s() =>
        camadaDe(c).scene.nodeById('cube')!.scale.valueAt(Duration.zero);

    // SELECIONAR: arrastar sobre o cubo gira a camera, nao move o cubo.
    await tester.drag(viewport, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(x(), 0, reason: 'em Selecionar o objeto nao se move');
    expect(
      (camadaDe(c).camera.positionAt(Duration.zero) - camAntes).length,
      greaterThan(1),
      reason: 'em Selecionar um dedo orbita',
    );

    // MOVER: o mesmo arrasto move o cubo.
    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(x(), isNot(0), reason: 'em Mover o objeto anda');

    // ESCALAR.
    await tester.tap(find.text('Escalar'));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(s(), greaterThan(1), reason: 'em Escalar o objeto cresce');

    // Um gesto e um passo de desfazer: desfazer devolve a escala 1.
    await tester.tap(find.byKey(const ValueKey('estudio-desfazer')));
    await tester.pumpAndSettle();
    expect(s(), 1);
    expect(x(), isNot(0), reason: 'so o ultimo gesto foi desfeito');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Focar enquadra o selecionado na camera', (tester) async {
    final c = await abrir(
      tester,
      camada: cena(
        nos: [
          SceneNode(id: 'cube', name: 'Cubo manual', x: AnimatedDouble(500)),
        ],
      ),
    );
    await tocarNoCubo(tester);
    // O cubo esta em x=500 e a camera nasce olhando a origem; o toque
    // no centro pode nao pegar o cubo — o Focar sem selecao enquadra
    // a cena inteira, que aqui e o proprio cubo.
    await tester.tap(find.byKey(const ValueKey('estudio-focar')));
    await tester.pumpAndSettle();
    final cam = camadaDe(c).camera;
    expect(
      cam.pointOfInterestAt(Duration.zero).x,
      closeTo(500, 1),
      reason: 'a camera passou a olhar o cubo',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'o painel da cena: buscar, esconder, renomear, duplicar, excluir',
    (tester) async {
      final c = await abrir(
        tester,
        camada: cena(
          nos: [
            SceneNode(id: 'cube', name: 'Cubo manual'),
            SceneNode(
              id: 'esfera',
              name: 'Esfera azul',
              kind: Element3DKind.sphere,
            ),
          ],
        ),
      );
      await tester.tap(find.byKey(const ValueKey('estudio-mais')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mais-cena')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cena-item-cube')), findsOneWidget);
      expect(find.byKey(const ValueKey('cena-item-esfera')), findsOneWidget);

      // Buscar filtra.
      await tester.enterText(
        find.byKey(const ValueKey('estudio-busca')),
        'azul',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cena-item-cube')), findsNothing);
      expect(find.byKey(const ValueKey('cena-item-esfera')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('estudio-busca')), '');
      await tester.pumpAndSettle();

      // O olho esconde.
      await tester.tap(find.byKey(const ValueKey('cena-olho-cube')));
      await tester.pumpAndSettle();
      expect(camadaDe(c).scene.nodeById('cube')!.visible, isFalse);

      // Os tres pontos: renomear.
      await tester.tap(find.byKey(const ValueKey('cena-acoes-esfera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('acao-renomear')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('estudio-nome')),
        'Bola',
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(camadaDe(c).scene.nodeById('esfera')!.name, 'Bola');

      // Duplicar: o painel fecha e a copia fica selecionada.
      await tester.tap(find.byKey(const ValueKey('cena-acoes-esfera')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('acao-duplicar')));
      await tester.pumpAndSettle();
      expect(camadaDe(c).scene.nodes.length, 3);
      expect(
        find.text('Bola copia'),
        findsOneWidget,
        reason: 'a copia esta na barra de contexto',
      );

      // Excluir, pela barra de contexto do selecionado.
      await tocarChip(tester, 'contexto-objeto');
      await tester.tap(find.byKey(const ValueKey('acao-excluir')));
      await tester.pumpAndSettle();
      expect(camadaDe(c).scene.nodes.length, 2);
      expect(find.text('Bola copia'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('material simples muda a cor base sem sair da tela', (
    tester,
  ) async {
    final c = await abrir(tester);
    await tocarNoCubo(tester);
    await tocarChip(tester, 'contexto-material');
    expect(find.byKey(const ValueKey('material-cor')), findsOneWidget);
    final metalico = find.byKey(const ValueKey('material-metalico'));
    expect(metalico, findsOneWidget);
    // O numero se ajusta pela REGUA de arrasto (nenhum slider no app):
    // arrastar para a esquerda sobe o valor.
    final regua = find.descendant(
      of: metalico,
      matching: find.byType(AmTickRuler),
    );
    await tester.drag(regua, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
      camadaDe(c).scene.nodeById('cube')!.material.metallic,
      greaterThan(0.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('toque longo seleciona varios, e Agrupar poe um pai comum', (
    tester,
  ) async {
    final c = await abrir(
      tester,
      camada: cena(
        nos: [
          SceneNode(id: 'a', name: 'A', x: AnimatedDouble(-90)),
          SceneNode(id: 'b', name: 'B', x: AnimatedDouble(90)),
        ],
      ),
    );
    final r = tester.getRect(viewport);
    // O cubo A esta a esquerda do centro, o B a direita (x cresce para a direita).
    Offset em(double frac) => Offset(r.left + r.width * frac, r.center.dy);
    await tester.longPressAt(em(0.36));
    await tester.pumpAndSettle();
    await tester.longPressAt(em(0.64));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('contexto-agrupar')),
      findsOneWidget,
      reason: 'dois selecionados: a barra de varios',
    );
    expect(find.text('2 objetos'), findsOneWidget);
    await tocarChip(tester, 'contexto-agrupar');
    final scene = camadaDe(c).scene;
    final grupo = scene.nodes.where((n) => n.isNull).single;
    expect(scene.nodeById('a')!.parentId, grupo.id);
    expect(scene.nodeById('b')!.parentId, grupo.id);
    expect(
      find.text(grupo.name),
      findsOneWidget,
      reason: 'o grupo fica selecionado',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('o modo avancado devolve vistas e comandos, e fica guardado', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await abrir(tester, prefs: prefs);
    expect(find.text('Enquadrar tudo'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('estudio-mais')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mais-avancado')));
    await tester.pumpAndSettle();
    expect(prefs.getBool(EstudioPreferencia.kAvancado), isTrue);
    // Fecha o menu.
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.text('Enquadrar tudo'), findsOneWidget);
    expect(
      find.text('Frente'),
      findsOneWidget,
      reason: 'as vistas voltaram a tela',
    );
    expect(find.byKey(const ValueKey('ferramenta-grade')), findsOneWidget);
    expect(find.byKey(const ValueKey('eixo-y')), findsOneWidget);
    expect(find.byKey(const ValueKey('tempo-autokey')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('as dicas aparecem uma vez; Entendi guarda', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await abrir(tester, prefs: prefs);
    expect(find.byKey(const ValueKey('estudio-dica')), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('estudio-dica-proxima')),
    );
    await tester.tap(find.byKey(const ValueKey('estudio-dica-proxima')));
    await tester.pumpAndSettle();
    expect(find.text('2/4'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('estudio-dica-entendi')),
    );
    await tester.tap(find.byKey(const ValueKey('estudio-dica-entendi')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('estudio-dica')), findsNothing);
    expect(prefs.getBool(EstudioPreferencia.kDicasVistas), isTrue);

    // Abrir de novo: sem dicas.
    await tester.pumpWidget(const SizedBox());
    await abrir(tester, prefs: prefs);
    expect(find.byKey(const ValueKey('estudio-dica')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a grade encaixa o arrasto em multiplos do passo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      EstudioPreferencia.kAvancado: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = await abrir(tester, prefs: prefs);
    await tester.tap(find.byKey(const ValueKey('ferramenta-grade')));
    await tester.pumpAndSettle();
    await tocarNoCubo(tester);
    await tester.tap(find.text('Mover'));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(37, 0));
    await tester.pumpAndSettle();
    final node = camadaDe(c).scene.nodeById('cube')!;
    final x = node.x.valueAt(Duration.zero);
    expect(x, isNot(0));
    expect(
      (x / passoDeMover - (x / passoDeMover).round()).abs(),
      lessThan(1e-6),
      reason: 'x=$x tem de ser multiplo de $passoDeMover',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Voltar fecha o Estudio e devolve a tela de baixo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .openProject(
          container.read(editorControllerProvider).copyWith(layers: [cena()]),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scene3DStudio(layerId: 'scene'),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Scene3DStudio), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('estudio-voltar')));
    await tester.pumpAndSettle();
    expect(find.byType(Scene3DStudio), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });
}
