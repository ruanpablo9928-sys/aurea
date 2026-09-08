import 'package:aurea/src/features/editor/application/camera_ortografica.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A LENTE ORTOGRAFICA DAS VISTAS FIXAS.
///
/// Ela existe por um motivo medido: sem lente ortografica no motor, as
/// vistas Frente/Topo/Lado do Estudio desenhavam a cena inteira no
/// processador — de 6 a 44 ms por quadro na bancada. O que este teste
/// segura e o enquadramento: a vista pela GPU tem de mostrar o MESMO
/// pedaco de mundo que o pintor mostrava, senao trocar de vista faz a
/// cena "pular de tamanho" na cara de quem edita.
void main() {
  /// Onde um ponto do mundo cai na tela, pela camera do motor.
  ({double x, double y}) naTela(
    vm.Matrix4 vp,
    vm.Vector3 mundo,
    double largura,
    double altura,
  ) {
    final clip = vp.transform(
      vm.Vector4(mundo.x, mundo.y, mundo.z, 1),
    );
    final w = clip.w == 0 ? 1 : clip.w;
    return (
      x: (clip.x / w + 1) / 2 * largura,
      y: (1 - clip.y / w) / 2 * altura,
    );
  }

  test('o mesmo enquadramento do pintor: orthoScale e pixel por unidade', () {
    // A vista de topo do Estudio: camera em cima, olhando para baixo.
    const cam = RenderCamera(
      position: Vec3(0, 500, 0),
      target: Vec3.zero,
      up: Vec3(0, 0, -1),
      orthographic: true,
      orthoScale: 2, // dois pixels por unidade de mundo
    );
    const largura = 390.0, altura = 700.0;
    final camera = cameraOrtograficaDoMotor(cam, altura);
    final vp = camera.projection
        .getProjectionMatrix(largura / altura)
        .multiplied(camera.getViewMatrix());

    // O centro do mundo cai no centro da tela.
    final centro = naTela(vp, vm.Vector3.zero(), largura, altura);
    expect(centro.x, closeTo(largura / 2, 0.01));
    expect(centro.y, closeTo(altura / 2, 0.01));

    // E o ponto a 50 unidades de distancia cai a 50 * orthoScale pixels
    // do centro — a mesma conta do pintor (`halfW + x * orthoScale`).
    final direita = naTela(vp, vm.Vector3(50, 0, 0), largura, altura);
    expect(direita.x, closeTo(largura / 2 + 50 * 2, 0.5));
    expect(direita.y, closeTo(altura / 2, 0.5));
  });

  test('sem perspectiva: a distancia da camera nao muda o tamanho', () {
    const cam = RenderCamera(
      position: Vec3(0, 0, 800),
      target: Vec3.zero,
      orthographic: true,
      orthoScale: 3,
    );
    const largura = 400.0, altura = 800.0;
    final camera = cameraOrtograficaDoMotor(cam, altura);
    final vp = camera.projection
        .getProjectionMatrix(largura / altura)
        .multiplied(camera.getViewMatrix());

    // Dois pontos do mesmo tamanho, um perto e um longe: na ortografica
    // eles ocupam exatamente a mesma largura na tela.
    final pertoA = naTela(vp, vm.Vector3(-20, 0, 200), largura, altura);
    final pertoB = naTela(vp, vm.Vector3(20, 0, 200), largura, altura);
    final longeA = naTela(vp, vm.Vector3(-20, 0, -200), largura, altura);
    final longeB = naTela(vp, vm.Vector3(20, 0, -200), largura, altura);
    expect(pertoB.x - pertoA.x, closeTo(longeB.x - longeA.x, 0.01));
    expect(pertoB.x - pertoA.x, closeTo(40 * 3, 0.5));
  });

  test('a profundidade continua ordenando: perto na frente de longe', () {
    const cam = RenderCamera(
      position: Vec3(0, 0, 800),
      target: Vec3.zero,
      orthographic: true,
      orthoScale: 2,
      near: 1,
      far: 4000,
    );
    final camera = cameraOrtograficaDoMotor(cam, 700);
    final vp = camera.projection
        .getProjectionMatrix(0.6)
        .multiplied(camera.getViewMatrix());
    double z(double mundoZ) {
      final c = vp.transform(vm.Vector4(0, 0, mundoZ, 1));
      return c.z / (c.w == 0 ? 1 : c.w);
    }

    // Mais perto da camera (z maior, porque ela olha de +Z) = menor
    // profundidade no recorte.
    expect(z(400), lessThan(z(-400)));
    // E tudo o que esta entre os planos cabe na faixa 0..1.
    expect(z(400), inInclusiveRange(0, 1));
    expect(z(-400), inInclusiveRange(0, 1));
  });
}
