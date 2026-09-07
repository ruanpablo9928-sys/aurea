import 'dart:math' as math;
import 'dart:ui';

import 'algebra_numerica.dart';
import 'camera3d.dart';
import 'camera_solver3d.dart';
import 'element3d.dart';
import 'keyframe.dart';
import 'layer.dart';
import 'scene3d.dart';

/// DO RASTREIO PARA A CENA — o passo que transforma numeros em algo que
/// se edita.
///
/// O solver devolve poses e uma nuvem de pontos. Isso ainda nao serve
/// para ninguem: o que a pessoa quer e pousar um texto no chao do video
/// e ver ele ficar la. A ponte e uma CAMADA DE CENA 3D por cima do
/// clipe, com fundo transparente e uma camera que anda exatamente como a
/// camera de verdade andou. Dai em diante, tudo que entrar nessa cena
/// gruda no plano sem mais nenhum ajuste — que e o ponto do rastreio.
///
/// A parte delicada e a ORIENTACAO. O motor monta a base da camera a
/// partir do alvo e de um "cima" fixo, e deixa a inclinacao para o
/// parametro de giro. O rastreio, ao contrario, sabe exatamente para
/// onde o topo da imagem apontava. Traduzir um no outro e o que evita o
/// erro classico de camera rastreada: o enquadramento certo, a cena
/// inteira tombada.

/// A distancia focal em milimetros equivalente ao que o solver achou em
/// pixels. A largura do filme e a mesma que o resto do app usa (36 mm),
/// entao o numero sai comparavel com uma lente de verdade.
double focalEmMilimetros(SolucaoCamera3D s, {double larguraDoFilme = 36}) =>
    larguraDoFilme * s.focalPx / math.max(1, s.largura);

/// O GIRO DA CAMERA, em graus.
///
/// O motor calcula o "cima" da camera assim: pega a frente, cruza com o
/// eixo Y do mundo e volta. Isso da uma camera sempre nivelada. O giro e
/// o quanto o topo REAL da imagem se afasta desse nivelado — e sem ele
/// uma camera inclinada devolve a cena torta na direcao contraria.
double giroDaPose(PoseCamera pose, Vec3 posicao, Vec3 alvo) {
  final base = cameraBasis(RenderCamera(position: posicao, target: alvo));
  final cima = pose.cima;
  final c = Vec3(cima[0], cima[1], cima[2]);
  return math.atan2(c.dot(base.right), c.dot(base.up)) * 180 / math.pi;
}

Duration _tempoDoQuadro(int quadro, int fps) =>
    Duration(microseconds: (quadro * 1000000 / math.max(1, fps)).round());

/// A CAMERA DO RASTREIO, com um keyframe por quadro analisado.
Camera3D cameraDoRastreio(
  SolucaoCamera3D s, {
  String id = 'rastreio_camera',
  String nome = 'Câmera rastreada',
}) {
  // A distancia do alvo e so uma convencao (o alvo define direcao, nao
  // profundidade). Usar a profundidade tipica da cena mantem os numeros
  // do painel na mesma ordem de grandeza do resto.
  final profundidades = <double>[];
  for (final p in s.poses) {
    final pos = p.posicao;
    for (final x in s.nuvem.values) {
      profundidades.add(
        norma([x[0] - pos[0], x[1] - pos[1], x[2] - pos[2]]),
      );
    }
    if (profundidades.length > 400) break;
  }
  final distancia = profundidades.isEmpty ? 800.0 : mediana(profundidades);

  final px = <Keyframe<double>>[];
  final py = <Keyframe<double>>[];
  final pz = <Keyframe<double>>[];
  final ax = <Keyframe<double>>[];
  final ay = <Keyframe<double>>[];
  final az = <Keyframe<double>>[];
  final giro = <Keyframe<double>>[];

  for (final pose in s.poses) {
    final t = _tempoDoQuadro(pose.quadro, s.fps);
    final pos = pose.posicao;
    final frente = pose.frente;
    final alvo = [
      pos[0] + frente[0] * distancia,
      pos[1] + frente[1] * distancia,
      pos[2] + frente[2] * distancia,
    ];
    px.add(Keyframe(time: t, value: pos[0]));
    py.add(Keyframe(time: t, value: pos[1]));
    pz.add(Keyframe(time: t, value: pos[2]));
    ax.add(Keyframe(time: t, value: alvo[0]));
    ay.add(Keyframe(time: t, value: alvo[1]));
    az.add(Keyframe(time: t, value: alvo[2]));
    giro.add(
      Keyframe(
        time: t,
        value: giroDaPose(
          pose,
          Vec3(pos[0], pos[1], pos[2]),
          Vec3(alvo[0], alvo[1], alvo[2]),
        ),
      ),
    );
  }

  return Camera3D(
    id: id,
    name: nome,
    posX: AnimatedDouble(px.first.value, px),
    posY: AnimatedDouble(py.first.value, py),
    posZ: AnimatedDouble(pz.first.value, pz),
    poiX: AnimatedDouble(ax.first.value, ax),
    poiY: AnimatedDouble(ay.first.value, ay),
    poiZ: AnimatedDouble(az.first.value, az),
    rotZ: AnimatedDouble(giro.first.value, giro),
    focalLength: AnimatedDouble(focalEmMilimetros(s)),
  );
}

/// A NUVEM DE PONTOS como um objeto so.
///
/// Um no por ponto seriam cem chamadas de desenho por quadro para
/// mostrar confetes. Como instancias de um unico no, e uma chamada — e a
/// nuvem serve para o que precisa servir: ver se o rastreio pegou o que
/// interessa, e escolher onde pousar as coisas.
SceneNode nuvemDoRastreio(
  SolucaoCamera3D s, {
  String id = 'rastreio_nuvem',
  String nome = 'Pontos do rastreio',
}) => SceneNode(
  id: id,
  name: nome,
  kind: Element3DKind.octahedron,
  size: 4,
  material: const Material3D(
    baseColor: Color(0xFF6FE3B0),
    kind: MaterialKind.unlit,
  ),
  instances: [
    for (final v in s.nuvem.values) Vec3(v[0], v[1], v[2]),
  ],
);

/// UM NULO NO PONTO ESCOLHIDO — o "criar nulo e camera" do After
/// Effects, na versao que faz sentido aqui.
///
/// Nulo e nao cubo porque o que se quer nao e um objeto: e um lugar. A
/// pessoa põe o texto como filho dele e o texto passa a viver naquele
/// canto do mundo real.
SceneNode? noNoPonto(
  SolucaoCamera3D s,
  int idDoPonto, {
  String? nome,
  bool comoNulo = true,
}) {
  final v = s.nuvem[idDoPonto];
  if (v == null) return null;
  return SceneNode(
    name: nome ?? 'Ponto $idDoPonto',
    kind: Element3DKind.cube,
    isNull: comoNulo,
    size: 30,
    x: AnimatedDouble(v[0]),
    y: AnimatedDouble(v[1]),
    z: AnimatedDouble(v[2]),
  );
}

/// A CAMADA PRONTA: cena 3D com fundo transparente, camera rastreada e a
/// nuvem de pontos, para entrar em cima do clipe.
Scene3DLayer camadaDoRastreio(
  SolucaoCamera3D s, {
  required Duration startTime,
  required Duration duration,
  required Offset position,
  String nome = 'Rastreio 3D',
  bool comNuvem = true,
}) => Scene3DLayer(
  name: nome,
  startTime: startTime,
  duration: duration,
  position: AnimatedOffset(position),
  camera: cameraDoRastreio(s),
  // Os ajudantes ficam LIGADOS: sem ver a nuvem e o horizonte, nao ha
  // como saber se o rastreio pegou o chao ou a parede — e descobrir isso
  // depois de montar a cena inteira e caro.
  showHelpers: comNuvem,
  scene: Scene3D(
    // Fundo transparente: o video e que aparece atras.
    showFloorGrid: false,
    lights: Scene3D.tresPontos,
    nodes: [if (comNuvem) nuvemDoRastreio(s)],
  ),
);
