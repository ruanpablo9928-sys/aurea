import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'element3d.dart';
import 'keyframe.dart';

/// CENA 3D (spec AUREA-cena-3d): um CONTEINER que, por fora, e UMA
/// camada do compositor e, por dentro, tem seu proprio renderizador.
///
/// A camada 3D atual (planos no espaco) continua existindo para 2.5D —
/// esta e a outra coisa: malhas, luzes, e ordenacao que resolve
/// INTERPENETRACAO, que o algoritmo do pintor por camada nao resolve.
///
/// Restricao honesta desta implementacao: o Canvas do Flutter nao expoe
/// buffer de profundidade nem instancing de GPU. O equivalente possivel
/// — e que passa o teste que a spec define como aprovacao — e ordenar
/// POR TRIANGULO em vez de por objeto, que resolve interpenetracao, e
/// bater todas as instancias numa unica chamada de desenho.

enum MaterialKind { pbr, unlit, transparent }

class Material3D {
  const Material3D({
    this.name = 'Material',
    this.baseColor = const Color(0xFFB8C4D0),
    this.metallic = 0.0,
    this.roughness = 0.6,
    this.emissive = 0.0,
    this.opacity = 1.0,
    this.kind = MaterialKind.pbr,
    this.textureLayerId,
  });

  final String name;
  final Color baseColor;
  final double metallic;
  final double roughness;
  final double emissive;
  final double opacity;
  final MaterialKind kind;

  /// TEXTURA VINDA DE CAMADA DA CENA (§6): uma precomp animada vira a
  /// tela de um celular 3D ou o rotulo de uma embalagem. E o recurso
  /// que mais rende num app de motion.
  final String? textureLayerId;

  bool get isTransparent =>
      kind == MaterialKind.transparent || opacity < 0.999;

  Material3D copyWith({
    String? name,
    Color? baseColor,
    double? metallic,
    double? roughness,
    double? emissive,
    double? opacity,
    MaterialKind? kind,
    String? textureLayerId,
  }) =>
      Material3D(
        name: name ?? this.name,
        baseColor: baseColor ?? this.baseColor,
        metallic: metallic ?? this.metallic,
        roughness: roughness ?? this.roughness,
        emissive: emissive ?? this.emissive,
        opacity: opacity ?? this.opacity,
        kind: kind ?? this.kind,
        textureLayerId: textureLayerId ?? this.textureLayerId,
      );
}

enum Light3DKind { directional, point, ambient }

class Light3D {
  Light3D({
    String? id,
    this.kind = Light3DKind.directional,
    this.color = const Color(0xFFFFFFFF),
    AnimatedDouble? intensity,
    this.direction = const Vec3(-0.4, -0.8, -0.45),
    this.position = const Vec3(0, 300, 300),
    this.range = 1200,
    this.castsShadow = false,
  })  : id = id ?? const Uuid().v4(),
        intensity = intensity ?? AnimatedDouble(1);

  final String id;
  final Light3DKind kind;
  final Color color;
  final AnimatedDouble intensity;
  final Vec3 direction;
  final Vec3 position;

  /// Alcance: usado no CULLING DE LUZ POR OBJETO — uma malha so recebe
  /// as luzes que a alcancam.
  final double range;
  final bool castsShadow;

  Light3D copyWith({
    Light3DKind? kind,
    Color? color,
    AnimatedDouble? intensity,
    Vec3? direction,
    Vec3? position,
    double? range,
    bool? castsShadow,
  }) =>
      Light3D(
        id: id,
        kind: kind ?? this.kind,
        color: color ?? this.color,
        intensity: intensity ?? this.intensity,
        direction: direction ?? this.direction,
        position: position ?? this.position,
        range: range ?? this.range,
        castsShadow: castsShadow ?? this.castsShadow,
      );
}

/// Vetor 3D minimo (evita puxar vector_math para o modelo).
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalized {
    final l = length;
    return l < 1e-9 ? zero : Vec3(x / l, y / l, z / l);
  }

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

/// Volume envolvente — base do culling hierarquico.
class Bounds3D {
  const Bounds3D(this.center, this.radius);

  final Vec3 center;
  final double radius;

  static const empty = Bounds3D(Vec3.zero, 0);
}

/// Um NO do grafo de cena.
class SceneNode {
  SceneNode({
    String? id,
    this.name = 'Objeto',
    this.kind = Element3DKind.cube,
    this.material = const Material3D(),
    AnimatedDouble? x,
    AnimatedDouble? y,
    AnimatedDouble? z,
    AnimatedDouble? rotX,
    AnimatedDouble? rotY,
    AnimatedDouble? rotZ,
    AnimatedDouble? scale,
    this.size = 100,
    this.visible = true,
    this.instances = const [],
    this.mesh,
    this.outline,
    this.extrudeDepth = 40,
    this.parentId,
    this.isNull = false,
  })  : id = id ?? const Uuid().v4(),
        x = x ?? AnimatedDouble(0),
        y = y ?? AnimatedDouble(0),
        z = z ?? AnimatedDouble(0),
        rotX = rotX ?? AnimatedDouble(0),
        rotY = rotY ?? AnimatedDouble(0),
        rotZ = rotZ ?? AnimatedDouble(0),
        scale = scale ?? AnimatedDouble(1);

  final String id;
  final String name;
  final Element3DKind kind;
  final Material3D material;
  final AnimatedDouble x;
  final AnimatedDouble y;
  final AnimatedDouble z;
  final AnimatedDouble rotX;
  final AnimatedDouble rotY;
  final AnimatedDouble rotZ;
  final AnimatedDouble scale;
  final double size;
  final bool visible;

  /// INSTANCIACAO (§4.1): copias da MESMA malha desenhadas numa unica
  /// chamada. Vazio = so o proprio no.
  final List<Vec3> instances;

  /// MALHA PROPRIA (forma extrudada). Quando existe, manda no lugar da
  /// malha do [kind] — e como um logo vira volume sem virar um dos
  /// solidos prontos.
  final Element3DMesh? mesh;

  /// O contorno 2D que gerou a malha, guardado para poder mudar a
  /// espessura depois sem pedir a forma de novo.
  final List<Offset>? outline;

  final double extrudeDepth;

  /// PAI DENTRO DA CENA. Sem isto nao ha rigging la dentro: nao da para
  /// girar um conjunto de objetos junto, nem orbitar a camera interna.
  final String? parentId;

  /// NULO 3D: so transforma, nao desenha. E o pivo dos rigs.
  final bool isNull;

  Vec3 positionAt(Duration t) =>
      Vec3(x.valueAt(t), y.valueAt(t), z.valueAt(t));

  SceneNode copyWith({
    String? name,
    Element3DKind? kind,
    Material3D? material,
    AnimatedDouble? x,
    AnimatedDouble? y,
    AnimatedDouble? z,
    AnimatedDouble? rotX,
    AnimatedDouble? rotY,
    AnimatedDouble? rotZ,
    AnimatedDouble? scale,
    double? size,
    bool? visible,
    List<Vec3>? instances,
    Element3DMesh? mesh,
    List<Offset>? outline,
    double? extrudeDepth,
    String? parentId,
    bool clearParent = false,
    bool? isNull,
  }) =>
      SceneNode(
        id: id,
        name: name ?? this.name,
        kind: kind ?? this.kind,
        material: material ?? this.material,
        x: x ?? this.x,
        y: y ?? this.y,
        z: z ?? this.z,
        rotX: rotX ?? this.rotX,
        rotY: rotY ?? this.rotY,
        rotZ: rotZ ?? this.rotZ,
        scale: scale ?? this.scale,
        size: size ?? this.size,
        visible: visible ?? this.visible,
        instances: instances ?? this.instances,
        mesh: mesh ?? this.mesh,
        outline: outline ?? this.outline,
        extrudeDepth: extrudeDepth ?? this.extrudeDepth,
        parentId: clearParent ? null : (parentId ?? this.parentId),
        isNull: isNull ?? this.isNull,
      );
}

/// CAMERA SALVA (cena §9 / camera §6): guardar um enquadramento e
/// voltar nele com um toque.
class SavedView {
  const SavedView({
    required this.name,
    required this.position,
    required this.target,
  });

  final String name;
  final Vec3 position;
  final Vec3 target;
}

/// A CENA: grafo de nos, luzes e orcamento.
class Scene3D {
  const Scene3D({
    this.nodes = const [],
    this.lights = const [],
    this.savedViews = const [],
    this.ambient = 0.28,
    this.background,
    this.showFloorGrid = true,
    this.msaa = true,
    this.draftMode = false,
    this.cameraParentId,
  });

  final List<SceneNode> nodes;

  /// De qual NO da cena a camera interna e filha. Nulo = solta.
  ///
  /// E o que permite orbitar a camera de dentro: um nulo girando em Y
  /// com a camera deslocada em Z.
  final String? cameraParentId;

  /// O no de [id], ou null.
  SceneNode? nodeById(String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  final List<Light3D> lights;
  final List<SavedView> savedViews;
  final double ambient;
  final Color? background;
  final bool showFloorGrid;

  /// Em GPU de blocos MSAA e barato; aqui vira suavizacao de borda no
  /// desenho dos triangulos.
  final bool msaa;

  /// MODO RASCUNHO (camera §8): desliga sombra, DOF e ambiente por
  /// imagem SO no preview — a diferenca entre navegar e sofrer.
  final bool draftMode;

  Scene3D copyWith({
    List<SceneNode>? nodes,
    List<Light3D>? lights,
    List<SavedView>? savedViews,
    double? ambient,
    Color? background,
    bool? showFloorGrid,
    bool? msaa,
    bool? draftMode,
    String? cameraParentId,
    bool clearCameraParent = false,
  }) =>
      Scene3D(
        nodes: nodes ?? this.nodes,
        lights: lights ?? this.lights,
        savedViews: savedViews ?? this.savedViews,
        ambient: ambient ?? this.ambient,
        background: background ?? this.background,
        showFloorGrid: showFloorGrid ?? this.showFloorGrid,
        msaa: msaa ?? this.msaa,
        draftMode: draftMode ?? this.draftMode,
        cameraParentId: clearCameraParent
            ? null
            : (cameraParentId ?? this.cameraParentId),
      );

  static Scene3D get demo => Scene3D(
        nodes: [
          SceneNode(
            name: 'Cubo',
            kind: Element3DKind.cube,
            size: 90,
            x: AnimatedDouble(-70),
            material: const Material3D(baseColor: Color(0xFF7C62FF)),
          ),
          SceneNode(
            name: 'Esfera',
            kind: Element3DKind.sphere,
            size: 80,
            x: AnimatedDouble(80),
            material: const Material3D(
                baseColor: Color(0xFFB8FF3D), roughness: 0.35),
          ),
        ],
        lights: [Light3D()],
      );
}

// ---------------------------------------------------------- pipeline

/// Um triangulo pronto para desenhar, ja no espaco de tela, com a
/// profundidade que decide a ordem.
class RenderTri {
  const RenderTri({
    required this.a,
    required this.b,
    required this.c,
    required this.depth,
    required this.color,
    required this.transparent,
    this.nodeId = '',
  });

  final Offset a;
  final Offset b;
  final Offset c;

  /// Z medio em espaco de camera (maior = mais longe).
  final double depth;
  final Color color;
  final bool transparent;

  /// De qual no da cena este triangulo saiu — e o que permite tocar no
  /// preview e selecionar o objeto certo.
  final String nodeId;
}

/// Resultado de um passe: os triangulos e as METRICAS do orcamento.
typedef SceneFrame = ({
  List<RenderTri> opaque,
  List<RenderTri> transparent,
  int drawCalls,
  int triangles,
  int culled,
});

/// Parametros de camera que o renderizador precisa.
class RenderCamera {
  const RenderCamera({
    this.position = const Vec3(0, 0, 800),
    this.target = Vec3.zero,
    this.up = const Vec3(0, 1, 0),
    this.focalLength = 50,
    this.filmWidth = 36,
    this.orthographic = false,
    this.orthoScale = 1,
    this.near = 1,
    this.far = 100000,
  });

  final Vec3 position;
  final Vec3 target;
  final Vec3 up;

  /// Distancia focal em mm e largura do filme em mm — a mesma grandeza
  /// do angulo de visao, so que vista de outro jeito.
  final double focalLength;
  final double filmWidth;

  final bool orthographic;
  final double orthoScale;
  final double near;
  final double far;

  /// ANGULO DE VISAO: 2*atan(filme / (2*focal)). E a mesma coisa que a
  /// distancia focal — mexer num muda o outro.
  double get fovRadians =>
      2 * math.atan(filmWidth / (2 * math.max(1e-6, focalLength)));

  double get fovDegrees => fovRadians * 180 / math.pi;
}

/// Distancia focal a partir do angulo de visao (a volta da conta).
double focalFromFov(double fovDegrees, {double filmWidth = 36}) {
  final rad = fovDegrees * math.pi / 180;
  return filmWidth / (2 * math.tan(rad / 2));
}

/// ZOOM (px) do AE: a distancia em que uma camada do tamanho da
/// composicao preenche o quadro.
double zoomFromFocal(double focalLength, double compWidth,
        {double filmWidth = 36}) =>
    compWidth * focalLength / filmWidth;

double focalFromZoom(double zoom, double compWidth,
        {double filmWidth = 36}) =>
    zoom * filmWidth / math.max(1e-6, compWidth);

/// Base ortonormal da camera (olhar, direita, cima).
({Vec3 forward, Vec3 right, Vec3 up}) cameraBasis(RenderCamera cam) {
  final forward = (cam.target - cam.position).normalized;
  var right = forward.cross(cam.up).normalized;
  if (right.length < 1e-6) {
    right = forward.cross(const Vec3(0, 0, 1)).normalized;
  }
  final up = right.cross(forward).normalized;
  return (forward: forward, right: right, up: up);
}

/// Rotaciona um ponto local pelos angulos do no (X, depois Y, depois Z
/// — a mesma ordem do resto do app).
Vec3 _rotate(Vec3 v, double rx, double ry, double rz) {
  final cx = math.cos(rx), sx = math.sin(rx);
  final y1 = v.y * cx - v.z * sx;
  final z1 = v.y * sx + v.z * cx;
  final cy = math.cos(ry), sy = math.sin(ry);
  final x2 = v.x * cy + z1 * sy;
  final z2 = -v.x * sy + z1 * cy;
  final cz = math.cos(rz), sz = math.sin(rz);
  return Vec3(x2 * cz - y1 * sz, x2 * sz + y1 * cz, z2);
}

/// RENDERIZA a cena para triangulos de tela.
///
/// Pipeline (§3), na medida do que o Canvas permite:
///   1. cull pelo volume envolvente contra o frustum
///   2. transforma vertices para espaco de camera
///   3. separa OPACOS e TRANSPARENTES
///   4. ordena POR TRIANGULO (nao por objeto) — e o que resolve
///      interpenetracao, que o algoritmo do pintor por camada nao faz
///   5. transparentes depois, do mais distante ao mais proximo, e
///      nunca "escrevem profundidade" (nao entram na ordenacao opaca)
/// Transform EFETIVO de um no, com a cadeia de pais ja resolvida.
class NodeTransform {
  const NodeTransform({
    this.position = Vec3.zero,
    this.rotX = 0,
    this.rotY = 0,
    this.rotZ = 0,
    this.scale = 1,
  });

  /// Em GRAUS, como no resto do aplicativo.
  final Vec3 position;
  final double rotX;
  final double rotY;
  final double rotZ;
  final double scale;

  static const identity = NodeTransform();
}

/// Resolve a cadeia de pais de [node].
///
/// A posicao do filho e GIRADA pelo pai antes de somar — e isso que faz
/// o rig de orbita funcionar: um nulo girando em Y com o objeto deslocado
/// em Z faz o objeto dar a volta, em vez de girar no proprio eixo.
///
/// A profundidade e limitada: um ciclo de parentesco (A pai de B, B pai
/// de A) travaria o quadro em vez de desenhar errado.
NodeTransform resolveNodeTransform(
  Scene3D scene,
  SceneNode node,
  Duration t, {
  NodeTransform external = NodeTransform.identity,
  int depth = 0,
}) {
  final local = NodeTransform(
    position: node.positionAt(t),
    rotX: node.rotX.valueAt(t),
    rotY: node.rotY.valueAt(t),
    rotZ: node.rotZ.valueAt(t),
    scale: node.scale.valueAt(t),
  );

  final pid = node.parentId;
  NodeTransform pai;
  if (pid == null || depth >= 16) {
    pai = external;
  } else {
    final parent = scene.nodeById(pid);
    if (parent == null) {
      pai = external;
    } else {
      pai = resolveNodeTransform(scene, parent, t,
          external: external, depth: depth + 1);
    }
  }

  return composeTransforms(pai, local);
}

/// Pai depois filho: a posicao do filho gira e escala com o pai.
NodeTransform composeTransforms(NodeTransform pai, NodeTransform filho) {
  final escalada = filho.position * pai.scale;
  final girada = _rotate(
      escalada,
      pai.rotX * math.pi / 180,
      pai.rotY * math.pi / 180,
      pai.rotZ * math.pi / 180);
  return NodeTransform(
    position: pai.position + girada,
    rotX: pai.rotX + filho.rotX,
    rotY: pai.rotY + filho.rotY,
    rotZ: pai.rotZ + filho.rotZ,
    scale: pai.scale * filho.scale,
  );
}

/// Aplica um transform de pai a uma camera.
///
/// A camera herda posicao, rotacao e orientacao — mas NAO herda escala.
/// Camera nao tem escala, e herdar do pai e justamente o bug que faz o
/// enquadramento explodir quando alguem escala o nulo.
RenderCamera applyParentToCamera(RenderCamera cam, NodeTransform pai) {
  Vec3 mover(Vec3 p) =>
      pai.position +
      _rotate(p, pai.rotX * math.pi / 180, pai.rotY * math.pi / 180,
          pai.rotZ * math.pi / 180);
  return RenderCamera(
    position: mover(cam.position),
    target: mover(cam.target),
    up: _rotate(cam.up, pai.rotX * math.pi / 180,
        pai.rotY * math.pi / 180, pai.rotZ * math.pi / 180),
    focalLength: cam.focalLength,
    filmWidth: cam.filmWidth,
    orthographic: cam.orthographic,
    orthoScale: cam.orthoScale,
    near: cam.near,
    far: cam.far,
  );
}

SceneFrame renderScene(
  Scene3D scene,
  RenderCamera cam,
  Size viewport,
  Duration t,
) {
  final basis = cameraBasis(cam);
  final opaque = <RenderTri>[];
  final transparent = <RenderTri>[];
  var drawCalls = 0;
  var triangles = 0;
  var culled = 0;

  final halfW = viewport.width / 2;
  final halfH = viewport.height / 2;
  // Escala de projecao a partir do angulo de visao.
  final focalPx = halfW / math.tan(cam.fovRadians / 2);

  for (final node in scene.nodes) {
    if (!node.visible) continue;
    // NULO 3D so transforma os filhos; nao desenha nada.
    if (node.isNull) continue;
    // Malha propria (forma extrudada) manda; sem ela, o solido do tipo.
    final mesh = node.mesh ?? element3DMesh(node.kind);
    if (mesh.verts.isEmpty) continue;

    final xf = resolveNodeTransform(scene, node, t);
    final s = node.size * xf.scale;
    final base = xf.position;
    final rx = xf.rotX * math.pi / 180;
    final ry = xf.rotY * math.pi / 180;
    final rz = xf.rotZ * math.pi / 180;

    // Uma "chamada de desenho" por NO — as instancias entram na mesma,
    // que e o equivalente possivel de instanciacao aqui.
    final offsets = node.instances.isEmpty
        ? const [Vec3.zero]
        : node.instances;
    var nodeEmitted = false;

    for (final inst in offsets) {
      final origin = base + inst;

      // CULLING pelo volume envolvente: fora do frustum, descarta o
      // objeto inteiro com um teste so.
      final toCam = origin - cam.position;
      final zCam = toCam.dot(basis.forward);
      final radius = s * 1.9;
      if (zCam + radius < cam.near || zCam - radius > cam.far) {
        culled++;
        continue;
      }
      if (zCam > 0) {
        final xCam = toCam.dot(basis.right).abs();
        final yCam = toCam.dot(basis.up).abs();
        final limitX = zCam * halfW / focalPx + radius;
        final limitY = zCam * halfH / focalPx + radius;
        if (xCam > limitX * 1.4 || yCam > limitY * 1.4) {
          culled++;
          continue;
        }
      }

      // Transforma os vertices uma vez por instancia.
      final n = mesh.verts.length;
      final cx = Float64List(n);
      final cy = Float64List(n);
      final cz = Float64List(n);
      final wx = Float64List(n);
      final wy = Float64List(n);
      final wz = Float64List(n);
      for (var i = 0; i < n; i++) {
        final v = mesh.verts[i];
        final r = _rotate(Vec3(v[0] * s, v[1] * s, v[2] * s), rx, ry, rz);
        final world = origin + r;
        wx[i] = world.x;
        wy[i] = world.y;
        wz[i] = world.z;
        final rel = world - cam.position;
        cx[i] = rel.dot(basis.right);
        cy[i] = rel.dot(basis.up);
        cz[i] = rel.dot(basis.forward);
      }

      final isTransparent = node.material.isTransparent;

      for (final face in mesh.faces) {
        // Normal em espaco de MUNDO (Newell), para a iluminacao.
        var nx = 0.0, ny = 0.0, nz = 0.0;
        var fcx = 0.0, fcy = 0.0, fcz = 0.0;
        for (var i = 0; i < face.length; i++) {
          final a = face[i];
          final b = face[(i + 1) % face.length];
          nx += (wy[a] - wy[b]) * (wz[a] + wz[b]);
          ny += (wz[a] - wz[b]) * (wx[a] + wx[b]);
          nz += (wx[a] - wx[b]) * (wy[a] + wy[b]);
          fcx += wx[a];
          fcy += wy[a];
          fcz += wz[a];
        }
        final inv = 1.0 / face.length;
        final faceCenter = Vec3(fcx * inv, fcy * inv, fcz * inv);

        // NORMAL PARA FORA, independente do sentido em que a face foi
        // escrita na malha. Sem isto, uma face com sentido invertido
        // recebe luz pelo lado errado — e escapa do descarte de costas,
        // que e onde mora metade do custo.
        var normal = Vec3(nx, ny, nz).normalized;
        final outward = faceCenter - origin;
        if (normal.dot(outward) < 0) {
          normal = Vec3(-normal.x, -normal.y, -normal.z);
        }

        // DESCARTE DE COSTAS: num solido fechado, a face virada para o
        // outro lado esta sempre escondida por outra. Deixar de emitir
        // corta perto da metade dos triangulos — some do emit, da
        // ordenacao e do desenho de uma vez.
        //
        // Material transparente NAO entra: ali se ve o fundo por dentro.
        if (!isTransparent) {
          final toFace = faceCenter - cam.position;
          if (normal.dot(toFace) >= 0) continue;
        }

        final color = shadeFace(
          scene: scene,
          material: node.material,
          normal: normal,
          point: faceCenter,
          t: t,
        );

        // Leque de triangulos: o poligono vira triangulos, e cada um
        // entra na ordenacao com a SUA profundidade.
        for (var i = 1; i < face.length - 1; i++) {
          final ia = face[0], ib = face[i], ic = face[i + 1];
          // Descarta o que esta atras da camera.
          if (cz[ia] <= cam.near ||
              cz[ib] <= cam.near ||
              cz[ic] <= cam.near) {
            continue;
          }

          final Offset pa, pb, pc;
          if (cam.orthographic) {
            final k = cam.orthoScale;
            pa = Offset(halfW + cx[ia] * k, halfH - cy[ia] * k);
            pb = Offset(halfW + cx[ib] * k, halfH - cy[ib] * k);
            pc = Offset(halfW + cx[ic] * k, halfH - cy[ic] * k);
          } else {
            final ka = focalPx / cz[ia];
            final kb = focalPx / cz[ib];
            final kc = focalPx / cz[ic];
            pa = Offset(halfW + cx[ia] * ka, halfH - cy[ia] * ka);
            pb = Offset(halfW + cx[ib] * kb, halfH - cy[ib] * kb);
            pc = Offset(halfW + cx[ic] * kc, halfH - cy[ic] * kc);
          }

          // FORA DA TELA: um triangulo inteiramente para la da borda nao
          // pinta nada, mas pagaria ordenacao e chamada de desenho.
          final minX = pa.dx < pb.dx
              ? (pa.dx < pc.dx ? pa.dx : pc.dx)
              : (pb.dx < pc.dx ? pb.dx : pc.dx);
          if (minX > viewport.width) continue;
          final maxX = pa.dx > pb.dx
              ? (pa.dx > pc.dx ? pa.dx : pc.dx)
              : (pb.dx > pc.dx ? pb.dx : pc.dx);
          if (maxX < 0) continue;
          final minY = pa.dy < pb.dy
              ? (pa.dy < pc.dy ? pa.dy : pc.dy)
              : (pb.dy < pc.dy ? pb.dy : pc.dy);
          if (minY > viewport.height) continue;
          final maxY = pa.dy > pb.dy
              ? (pa.dy > pc.dy ? pa.dy : pc.dy)
              : (pb.dy > pc.dy ? pb.dy : pc.dy);
          if (maxY < 0) continue;

          final tri = RenderTri(
            a: pa,
            b: pb,
            c: pc,
            depth: (cz[ia] + cz[ib] + cz[ic]) / 3,
            color: color,
            transparent: isTransparent,
            nodeId: node.id,
          );
          if (isTransparent) {
            transparent.add(tri);
          } else {
            opaque.add(tri);
          }
          triangles++;
          nodeEmitted = true;
        }
      }
    }
    if (nodeEmitted) drawCalls++;
  }

  // Sem Z-buffer, a ordem correta e a do pintor: do mais distante ao
  // mais proximo, POR TRIANGULO. E a ordenacao por triangulo (nao por
  // objeto) que resolve interpenetracao.
  //
  // Ordenar por comparacao custa n log n com uma chamada de funcao por
  // comparacao — com dezenas de milhares de triangulos vira o gargalo.
  // [depthSort] faz numa passada por balde.
  depthSort(opaque);
  depthSort(transparent);

  return (
    opaque: opaque,
    transparent: transparent,
    drawCalls: drawCalls,
    triangles: triangles,
    culled: culled,
  );
}

/// ORDENACAO POR BALDE, do mais distante ao mais proximo.
///
/// Ordenar por comparacao custa n log n e uma chamada de funcao por
/// comparacao — em Dart isso pesa. Aqui a profundidade e um numero num
/// intervalo conhecido, entao da para jogar cada triangulo direto no
/// balde dele e concatenar: uma passada so.
///
/// A resolucao dos baldes acompanha a quantidade de triangulos, entao
/// dois triangulos so caem no mesmo balde quando estao mais perto um do
/// outro do que o olho distingue naquela cena.
void depthSort(List<RenderTri> tris) {
  final n = tris.length;
  if (n < 64) {
    tris.sort((a, b) => b.depth.compareTo(a.depth));
    return;
  }

  var lo = double.infinity, hi = -double.infinity;
  for (var i = 0; i < n; i++) {
    final d = tris[i].depth;
    if (d < lo) lo = d;
    if (d > hi) hi = d;
  }
  final span = hi - lo;
  if (!span.isFinite || span <= 1e-9) return;

  final buckets = (n * 4).clamp(256, 65536);
  final scale = (buckets - 1) / span;

  // Contagem por balde, deslocamento, distribuicao — o "counting sort",
  // que e o que torna isto linear.
  final count = Int32List(buckets);
  final slot = Int32List(n);
  for (var i = 0; i < n; i++) {
    // Invertido: o balde 0 recebe o MAIS DISTANTE.
    final b = buckets - 1 - ((tris[i].depth - lo) * scale).floor();
    final bb = b < 0 ? 0 : (b >= buckets ? buckets - 1 : b);
    slot[i] = bb;
    count[bb]++;
  }
  var running = 0;
  for (var b = 0; b < buckets; b++) {
    final c = count[b];
    count[b] = running;
    running += c;
  }
  final out = List<RenderTri>.filled(n, tris[0]);
  for (var i = 0; i < n; i++) {
    out[count[slot[i]]++] = tris[i];
  }
  tris.setAll(0, out);
}

/// ILUMINACAO DIRETA com poucas luzes (§5) — nada de diferida, que
/// consome banda, e banda e o gargalo. Inclui CULLING DE LUZ POR
/// OBJETO: a luz so entra na conta se alcanca o ponto.
Color shadeFace({
  required Scene3D scene,
  required Material3D material,
  required Vec3 normal,
  required Vec3 point,
  required Duration t,
}) {
  if (material.kind == MaterialKind.unlit) return material.baseColor;

  var r = 0.0, g = 0.0, b = 0.0;
  final baseR = material.baseColor.r;
  final baseG = material.baseColor.g;
  final baseB = material.baseColor.b;

  // Ambiente.
  r += baseR * scene.ambient;
  g += baseG * scene.ambient;
  b += baseB * scene.ambient;

  for (final light in scene.lights) {
    final intensity = light.intensity.valueAt(t);
    if (intensity <= 0) continue;
    Vec3 dir;
    var atten = 1.0;
    switch (light.kind) {
      case Light3DKind.ambient:
        r += baseR * light.color.r * intensity;
        g += baseG * light.color.g * intensity;
        b += baseB * light.color.b * intensity;
        continue;
      case Light3DKind.directional:
        dir = (light.direction * -1).normalized;
      case Light3DKind.point:
        final delta = light.position - point;
        final d = delta.length;
        // CULLING DE LUZ POR OBJETO: fora do alcance, nem entra.
        if (d > light.range) continue;
        atten = 1 - (d / light.range);
        atten *= atten;
        dir = delta.normalized;
    }
    final lambert = math.max(0.0, normal.dot(dir));
    if (lambert <= 0) continue;
    final k = lambert * intensity * atten;
    r += baseR * light.color.r * k;
    g += baseG * light.color.g * k;
    b += baseB * light.color.b * k;

    // Especular simples (rugosidade menor = realce mais concentrado).
    final shininess = (1 - material.roughness).clamp(0.0, 1.0);
    if (shininess > 0.05) {
      final spec = math.pow(lambert, 8 + shininess * 60).toDouble() *
          shininess *
          intensity *
          atten;
      final metalTint = material.metallic;
      r += (baseR * metalTint + (1 - metalTint)) * spec;
      g += (baseG * metalTint + (1 - metalTint)) * spec;
      b += (baseB * metalTint + (1 - metalTint)) * spec;
    }
  }

  if (material.emissive > 0) {
    r += baseR * material.emissive;
    g += baseG * material.emissive;
    b += baseB * material.emissive;
  }

  return Color.from(
    alpha: material.opacity.clamp(0.0, 1.0),
    red: r.clamp(0.0, 1.0),
    green: g.clamp(0.0, 1.0),
    blue: b.clamp(0.0, 1.0),
  );
}

/// PROFUNDIDADE EXPORTADA (§8): a profundidade de cada triangulo,
/// normalizada em 0..1 (0 = perto). E o que permite ao compositor pôr
/// uma camada 2D ENTRE dois objetos 3D, com oclusao correta.
typedef DepthSample = ({double near, double far});

DepthSample sceneDepthRange(SceneFrame frame) {
  var near = double.infinity;
  var far = 0.0;
  for (final tri in [...frame.opaque, ...frame.transparent]) {
    if (tri.depth < near) near = tri.depth;
    if (tri.depth > far) far = tri.depth;
  }
  if (near == double.infinity) return (near: 0, far: 1);
  return (near: near, far: far <= near ? near + 1 : far);
}

/// Profundidade da cena no ponto de tela [p] (a do triangulo mais
/// PROXIMO que cobre o ponto), ou null se nada cobre. E a consulta que
/// decide se uma camada 2D fica na frente ou atras.
double? depthAtPoint(SceneFrame frame, Offset p) {
  double? best;
  for (final tri in [...frame.opaque, ...frame.transparent]) {
    if (_pointInTriangle(p, tri.a, tri.b, tri.c)) {
      if (best == null || tri.depth < best) best = tri.depth;
    }
  }
  return best;
}

/// Qual OBJETO esta sob o dedo: o no do triangulo mais proximo que
/// cobre o ponto. Sem isso, tocar na cena selecionaria a camada inteira
/// em vez do solido tocado.
String? pickNodeAt(SceneFrame frame, Offset p) {
  String? best;
  var bestDepth = double.infinity;
  for (final tri in [...frame.opaque, ...frame.transparent]) {
    if (tri.depth < bestDepth && _pointInTriangle(p, tri.a, tri.b, tri.c)) {
      bestDepth = tri.depth;
      best = tri.nodeId;
    }
  }
  return best;
}

bool _pointInTriangle(Offset p, Offset a, Offset b, Offset c) {
  double sign(Offset p1, Offset p2, Offset p3) =>
      (p1.dx - p3.dx) * (p2.dy - p3.dy) -
      (p2.dx - p3.dx) * (p1.dy - p3.dy);
  final d1 = sign(p, a, b);
  final d2 = sign(p, b, c);
  final d3 = sign(p, c, a);
  final hasNeg = d1 < 0 || d2 < 0 || d3 < 0;
  final hasPos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(hasNeg && hasPos);
}

/// ORCAMENTO (§10) e DEGRADACAO automatica.
typedef SceneBudget = ({
  int maxDrawCalls,
  int maxTriangles,
  int maxLights,
  int maxShadowLights,
});

const lowProfileBudget = (
  maxDrawCalls: 80,
  maxTriangles: 150000,
  maxLights: 4,
  maxShadowLights: 1,
);

/// Passos de degradacao, na ordem da spec. Devolve a cena rebaixada.
Scene3D degradeScene(Scene3D scene, int step) {
  var out = scene;
  if (step >= 2) {
    // Desliga sombra da segunda luz em diante.
    var shadowed = 0;
    out = out.copyWith(lights: [
      for (final l in out.lights)
        if (l.castsShadow && shadowed++ >= 1)
          l.copyWith(castsShadow: false)
        else
          l,
    ]);
  }
  if (step >= 4) out = out.copyWith(msaa: false);
  if (step >= 5) out = out.copyWith(ambient: out.ambient * 0.8);
  return out;
}
