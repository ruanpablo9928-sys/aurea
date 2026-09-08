import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../domain/scene3d.dart';

/// A VISTA DE FRENTE, DE TOPO E DE LADO, DESENHADAS PELA GPU.
///
/// O motor so trazia lente em perspectiva. As vistas fixas do Estudio
/// (Frente, Tras, Esquerda, Direita, Topo, Baixo) sao ORTOGRAFICAS — e,
/// sem lente ortografica no motor, elas caiam inteiras no pintor de
/// processador. A bancada mediu o que isso custa: de 6 ms (um objeto)
/// a 44 ms por quadro (cinquenta objetos) so para desenhar, sem contar
/// o resto do aplicativo. Era a travada, e ela nao tinha nada a ver com
/// qualidade: bastava trocar de vista.
///
/// A lente ortografica e uma matriz — o motor aceita qualquer
/// [fs.CameraProjection], entao ela entra sem tocar no resto.
class LenteOrtografica extends fs.CameraProjection {
  LenteOrtografica({
    required this.altura,
    required this.near,
    required this.far,
  });

  /// A ALTURA do mundo que cabe na tela, em unidades da cena. A largura
  /// sai da proporcao do alvo — assim a vista nao estica quando o
  /// aparelho vira.
  final double altura;
  final double near;
  final double far;

  @override
  vm.Matrix4 getProjectionMatrix(double aspectRatio) {
    final h = math.max(1e-6, altura);
    final w = h * (aspectRatio <= 0 ? 1 : aspectRatio);
    // Ortografica com profundidade em 0..1 (a mesma faixa que a
    // perspectiva do motor usa), e o Y para cima como no resto da cena.
    final m = vm.Matrix4.zero();
    m.setEntry(0, 0, 2 / w);
    m.setEntry(1, 1, 2 / h);
    m.setEntry(2, 2, 1 / (near - far));
    m.setEntry(2, 3, near / (near - far));
    m.setEntry(3, 3, 1);
    return m;
  }
}

/// A camera das vistas fixas: mesma posicao e alvo da camera do
/// dominio, com a lente ortografica no lugar da perspectiva.
class CameraOrtografica extends fs.Camera {
  CameraOrtografica({
    required this.position,
    required this.target,
    required this.up,
    required this.projection,
  });

  @override
  final vm.Vector3 position;
  final vm.Vector3 target;

  @override
  final vm.Vector3 up;

  @override
  final fs.CameraProjection projection;

  @override
  vm.Vector3 get forward => (target - position).normalized();

  @override
  vm.Matrix4 getViewMatrix() => vm.makeViewMatrix(position, target, up);
}

/// A camera do motor para uma [cam] ortografica do dominio, numa area de
/// [tamanho] pixels.
///
/// A altura do enquadramento e a mesma conta do pintor de processador
/// ([RenderCamera.orthoScale] em pixels por unidade), para a vista de
/// topo mostrar exatamente o mesmo pedaco de mundo nos dois caminhos —
/// quem troca de vista nao pode ver a cena "pular de tamanho".
fs.Camera cameraOrtograficaDoMotor(RenderCamera cam, double alturaEmPixels) {
  final escala = cam.orthoScale <= 0 ? 1.0 : cam.orthoScale;
  return CameraOrtografica(
    position: vm.Vector3(cam.position.x, cam.position.y, cam.position.z),
    target: vm.Vector3(cam.target.x, cam.target.y, cam.target.z),
    up: vm.Vector3(cam.up.x, cam.up.y, cam.up.z),
    projection: LenteOrtografica(
      altura: math.max(1e-3, alturaEmPixels / escala),
      near: math.max(0.01, cam.near),
      far: math.min(cam.far, 120000),
    ),
  );
}
