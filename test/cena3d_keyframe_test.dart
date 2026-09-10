// A CENA 3D OBEDECE A MESMA REGRA DE KEYFRAME QUE O RESTO DO APP.
//
// Ate aqui ela nao obedecia a regra nenhuma: as 31 trilhas animaveis da
// cena so eram alcancaveis por `updateSceneNode` com uma funcao crua,
// que escreve o que quiser, do jeito que quiser. Nao havia losango
// porque nao havia trilha nomeada a que ligar um losango.
//
// `docs/keyframe-explicito.md` e `docs/estudio-da-cena.md`.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const t0 = Duration.zero;
const t1 = Duration(seconds: 1);
const t2 = Duration(seconds: 2);

typedef _Bancada = ({ProviderContainer c, EditorController e, String id});

_Bancada _cena() {
  final container = ProviderContainer();
  final e = container.read(editorControllerProvider.notifier);
  e.addScene3DLayer(t0);
  final id = container.read(editorControllerProvider).layers.single.id;
  return (c: container, e: e, id: id);
}

Scene3DLayer _camada(_Bancada b) =>
    b.c.read(editorControllerProvider).layerById(b.id)! as Scene3DLayer;

SceneNode _no(_Bancada b) => _camada(b).scene.nodes.single;

void main() {
  test('a cena nasce vazia, e agora ha caminho para o primeiro objeto', () {
    final b = _cena();
    addTearDown(b.c.dispose);
    expect(_camada(b).scene.nodes, isEmpty);

    b.e.addSceneNode(b.id, Element3DKind.cube);

    expect(_camada(b).scene.nodes, hasLength(1));
    expect(_no(b).kind, Element3DKind.cube);
  });

  group('objeto', () {
    test('mexer no valor NAO cria keyframe', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;

      for (final p in PropDoNo.values) {
        b.e.editSceneNodeProp(b.id, id, p, t1, 42);
      }

      for (final p in PropDoNo.values) {
        expect(b.e.sceneNodeKeyframeTimes(_no(b), p), isEmpty, reason: '$p');
        expect(b.e.sceneNodeValueAt(_no(b), p, t0), 42, reason: '$p');
      }
    });

    test('o losango crava, e crava o valor de agora', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;
      b.e.editSceneNodeProp(b.id, id, PropDoNo.x, t1, 120);

      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t1);

      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.x), [t1]);
      expect(b.e.sceneNodeValueAt(_no(b), PropDoNo.x, t1), 120);
      // E so aquela trilha: o losango do X nao marca o Y.
      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.y), isEmpty);
    });

    test('sobre a marca, editar ATUALIZA sem duplicar', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t0);
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t2);

      b.e.editSceneNodeProp(b.id, id, PropDoNo.x, t2, 300);

      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.x), [t0, t2]);
      expect(b.e.sceneNodeValueAt(_no(b), PropDoNo.x, t2), 300);
    });

    test('FORA da marca, a linha do tempo nao muda — fica pendente', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t0);
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t2);

      b.e.editSceneNodeProp(b.id, id, PropDoNo.x, t1, 999);

      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.x), [t0, t2]);
      expect(b.c.read(edicaoPendenteProvider), isNotNull);
      // A previa ja mostra: o projeto VISIVEL tem o valor.
      final visivel =
          b.c.read(projetoVisivelProvider).layerById(b.id)! as Scene3DLayer;
      expect(visivel.scene.nodes.single.x.valueAt(t1), 999);
    });

    test('o losango tira a marca de volta', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.giroY, t1);
      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.giroY), [t1]);

      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.giroY, t1);
      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.giroY), isEmpty);
    });

    test('objeto travado nao aceita edicao nenhuma', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;
      // Objeto novo nao nasce na origem: cada um entra deslocado, para
      // nao empilhar em cima do anterior.
      final ondeEstava = b.e.sceneNodeValueAt(_no(b), PropDoNo.x, t0);
      b.e.setSceneNodeLocked(b.id, id, true);

      b.e.editSceneNodeProp(b.id, id, PropDoNo.x, t0, 500);
      b.e.toggleSceneNodeKeyframe(b.id, id, PropDoNo.x, t0);

      expect(b.e.sceneNodeValueAt(_no(b), PropDoNo.x, t0), ondeEstava);
      expect(b.e.sceneNodeKeyframeTimes(_no(b), PropDoNo.x), isEmpty);
    });
  });

  group('luz', () {
    test('a intensidade anima pela mesma regra', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      // A cena nasce com o rig de tres pontos.
      final luz = _camada(b).scene.lights.first;

      b.e.editSceneLightProp(b.id, luz.id, PropDaLuz.intensidade, t1, 3);
      expect(
        b.e.sceneLightKeyframeTimes(
          _camada(b).scene.lights.first,
          PropDaLuz.intensidade,
        ),
        isEmpty,
      );

      b.e.toggleSceneLightKeyframe(b.id, luz.id, PropDaLuz.intensidade, t1);
      expect(
        b.e.sceneLightKeyframeTimes(
          _camada(b).scene.lights.first,
          PropDaLuz.intensidade,
        ),
        [t1],
      );
    });

    test('os comandos de luz existiam sem um unico chamador', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      final antes = _camada(b).scene.lights.length;

      b.e.addSceneLight(b.id, Light3DKind.spot);
      final nova = _camada(b).scene.lights.last;
      expect(_camada(b).scene.lights, hasLength(antes + 1));

      b.e.setSceneLightCone(b.id, nova.id, 30);
      b.e.setSceneLightShadow(b.id, nova.id, true);
      final depois = _camada(b).scene.lights.last;
      expect(depois.coneDegrees, 30);
      expect(depois.castsShadow, isTrue);

      b.e.removeSceneLight(b.id, nova.id);
      expect(_camada(b).scene.lights, hasLength(antes));
    });
  });

  group('camera', () {
    test('as 23 trilhas aceitam valor sem criar marca', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      final cam = _camada(b).camera.id;

      for (final p in PropDaCamera.values) {
        b.e.editSceneCameraProp(b.id, cam, p, t1, 7);
      }

      for (final p in PropDaCamera.values) {
        expect(
          b.e.sceneCameraKeyframeTimes(_camada(b).camera, p),
          isEmpty,
          reason: '$p',
        );
        expect(
          b.e.sceneCameraValueAt(_camada(b).camera, p, t0),
          7,
          reason: '$p',
        );
      }
    });

    test('a lente parou de apagar os keyframes do rig', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      // O rig de Dolly zoom existe para animar a LENTE junto com a
      // distancia. Mexer no controle de lente jogava fora exatamente o
      // que ele acabara de criar.
      b.e.applyRigToScene(b.id, CameraRig.dollyZoom);
      final marcasDoRig = b.e.sceneCameraKeyframeTimes(
        _camada(b).camera,
        PropDaCamera.lente,
      );
      expect(marcasDoRig, isNotEmpty, reason: 'o rig anima a lente');

      b.e.setCameraFocalLength(b.id, t1, 85);

      expect(
        b.e.sceneCameraKeyframeTimes(_camada(b).camera, PropDaCamera.lente),
        marcasDoRig,
      );
    });

    test('enquadrar nao apaga os keyframes de foco', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.sphere);
      final cam = _camada(b).camera.id;
      b.e.toggleSceneCameraKeyframe(b.id, cam, PropDaCamera.foco, t0);
      b.e.toggleSceneCameraKeyframe(b.id, cam, PropDaCamera.foco, t2);

      b.e.frameSceneAll(b.id);

      expect(
        b.e.sceneCameraKeyframeTimes(_camada(b).camera, PropDaCamera.foco),
        [t0, t2],
      );
    });

    test('a camera extra tambem e alcancavel pelo id', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      final extra = b.e.addScene3DCamera(b.id);
      expect(extra, isNotEmpty);

      b.e.editSceneCameraProp(b.id, extra, PropDaCamera.posX, t0, 250);
      b.e.renameSceneCameraById(b.id, extra, 'Close');

      final c = _camada(b).allCameras.firstWhere((x) => x.id == extra);
      expect(c.posX.valueAt(t0), 250);
      expect(c.name, 'Close');
      // E a camera da cena nao se mexeu.
      expect(_camada(b).camera.posX.valueAt(t0), isNot(250));
    });
  });

  group('o mundo', () {
    test('ambiente, ceu, chao, neblina e piso espelhado tem comando', () {
      final b = _cena();
      addTearDown(b.c.dispose);

      b.e.setSceneEnvironment(b.id, EnvironmentKind.neon);
      b.e.setSceneAmbient(b.id, 1.5);
      b.e.setSceneFloorGrid(b.id, true);
      b.e.setScenePlanarFloor(b.id, true, aspereza: .3);
      b.e.setSceneFog(b.id, densidade: .4, comeco: 500);
      b.e.setSceneTonemap(b.id, false);
      b.e.setSceneMsaa(b.id, true);

      final s = _camada(b).scene;
      expect(s.environment, EnvironmentKind.neon);
      expect(s.ambient, 1.5);
      expect(s.showFloorGrid, isTrue);
      expect(s.planarFloorReflection, isTrue);
      expect(s.planarFloorRoughness, closeTo(.3, 1e-9));
      expect(s.fogDensity, closeTo(.4, 1e-9));
      expect(s.fogStart, 500);
      expect(s.tonemap, isFalse);
      expect(s.msaa, isTrue);
    });

    test('o fundo aceita cor E aceita voltar a nenhuma', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.setSceneBackground(b.id, const Color(0xFF102030));
      expect(_camada(b).scene.background, const Color(0xFF102030));

      // Nulo quer dizer "sem fundo proprio" — e um `copyWith` comum
      // nunca conseguiria dizer isso.
      b.e.setSceneBackground(b.id, null);
      expect(_camada(b).scene.background, isNull);
    });
  });

  group('material', () {
    test('os 12 materiais prontos eram codigo morto, e agora tem porta', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.sphere);
      final id = _no(b).id;

      b.e.applySceneNodeMaterialPreset(b.id, id, MaterialPreset3D.chrome);

      final m = _no(b).material;
      expect(m.metallic, greaterThan(.8));
      expect(m.roughness, lessThan(.2));
    });

    test('o material inteiro se escreve de uma vez', () {
      final b = _cena();
      addTearDown(b.c.dispose);
      b.e.addSceneNode(b.id, Element3DKind.cube);
      final id = _no(b).id;

      b.e.setSceneNodeMaterial(
        b.id,
        id,
        const Material3D(
          baseColor: Color(0xFFFF0000),
          metallic: .5,
          roughness: .25,
          kind: MaterialKind.transparent,
          opacity: .4,
        ),
      );

      final m = _no(b).material;
      expect(m.baseColor, const Color(0xFFFF0000));
      expect(m.metallic, .5);
      expect(m.kind, MaterialKind.transparent);
      expect(m.opacity, .4);
    });
  });
}
