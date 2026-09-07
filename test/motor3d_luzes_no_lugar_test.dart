import 'dart:io';

import 'package:aurea/src/features/editor/application/scene3d_gpu.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/orcamento_render.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:flutter_test/flutter_test.dart';

/// UMA INTENSIDADE ANIMADA NAO RECRIA A LUZ.
///
/// A ponte antiga refazia todas as luzes do motor a cada quadro em que
/// alguma intensidade mudava — e uma luz nova e um cache de sombra novo,
/// ou seja, um atlas de sombra refeito por quadro. Agora a estrutura das
/// luzes tem assinatura; a intensidade muda no objeto que ja existe.
///
/// A cena aqui nao tem nos (geometria pede GPU, e o teste roda em Skia):
/// so luzes, que sao objetos Dart do motor. Se o motor nao deixar nem
/// isso ser construido fora da GPU, o teste se marca como pulado — e
/// nao passa calado.
void main() {
  Duration t(num s) => Duration(microseconds: (s * 1000000).round());

  Scene3D cenaComLuzAnimada() => Scene3D(
    lights: [
      Light3D(
        kind: Light3DKind.directional,
        intensity: AnimatedDouble(0, [
          Keyframe(time: Duration.zero, value: 0),
          Keyframe(time: t(1), value: 1),
        ]),
        direction: const Vec3(-0.4, 0.7, 0.5),
        castsShadow: true,
      ),
      Light3D(
        kind: Light3DKind.point,
        intensity: AnimatedDouble(1),
        position: const Vec3(100, 0, 0),
        range: 800,
      ),
    ],
  );

  Scene3DGpu? motor() {
    try {
      return Scene3DGpu();
    } catch (e) {
      // ignore: avoid_print
      print('pulado: o motor nao constroi fora da GPU ($e)');
      return null;
    }
  }

  test('a mesma luz do motor, com a intensidade nova', () {
    final gpu = motor();
    if (gpu == null) return;
    final cena = cenaComLuzAnimada();
    gpu.sincronizar(cena, Duration.zero, receita: ReceitaDeQualidade.alta);
    final antes = gpu.luzesDoMotor;
    expect(antes, hasLength(2));
    expect(antes[0], isA<fs.DirectionalLight>());
    expect((antes[0] as fs.DirectionalLight).castsShadow, isFalse,
        reason: 'apagada (intensidade 0) nao projeta sombra');

    gpu.sincronizar(cena, t(.5), receita: ReceitaDeQualidade.alta);
    final depois = gpu.luzesDoMotor;
    expect(identical(antes[0], depois[0]), isTrue, reason: 'a luz foi recriada');
    expect(identical(antes[1], depois[1]), isTrue);
    final d = depois[0] as fs.DirectionalLight;
    expect(d.intensity, closeTo(.5 * 2.6, 1e-9));
    expect(d.castsShadow, isTrue, reason: 'acesa, volta a projetar sombra');
  });

  test('a receita muda a sombra: resolucao, cascatas e o teto de spots', () {
    final gpu = motor();
    if (gpu == null) return;
    final cena = Scene3D(
      lights: [
        Light3D(
          kind: Light3DKind.directional,
          intensity: AnimatedDouble(1),
          castsShadow: true,
        ),
        for (var i = 0; i < 6; i++)
          Light3D(
            kind: Light3DKind.spot,
            intensity: AnimatedDouble(1),
            position: Vec3(i * 50.0, 0, 0),
            castsShadow: true,
          ),
      ],
    );
    gpu.sincronizar(cena, Duration.zero, receita: ReceitaDeQualidade.alta);
    var luzes = gpu.luzesDoMotor;
    var d = luzes[0] as fs.DirectionalLight;
    expect(d.shadowMapResolution, 1024);
    expect(d.shadowCascadeCount, 2);
    int spotsComSombra() =>
        luzes.whereType<fs.SpotLight>().where((s) => s.castsShadow).length;
    expect(spotsComSombra(), 2, reason: 'alta deixa dois spots com sombra');

    gpu.sincronizar(cena, Duration.zero, receita: ReceitaDeQualidade.baixa);
    luzes = gpu.luzesDoMotor;
    d = luzes[0] as fs.DirectionalLight;
    expect(d.shadowMapResolution, 512);
    expect(d.shadowCascadeCount, 1);
    expect(spotsComSombra(), 0);

    gpu.sincronizar(cena, Duration.zero, receita: ReceitaDeQualidade.emergencia);
    luzes = gpu.luzesDoMotor;
    expect((luzes[0] as fs.DirectionalLight).castsShadow, isFalse,
        reason: 'emergencia: sem sombra nenhuma');
  });

  test('o codigo nativo responde memoria e termico no mesmo canal', () {
    final swift = File('ios/Runner/VideoEncoderPlugin.swift').readAsStringSync();
    final kotlin = File('android/app/src/main/kotlin/com/aurea/aurea/MainActivity.kt')
        .readAsStringSync();
    for (final fonte in [swift, kotlin]) {
      expect(fonte, contains('"memoria"'));
      expect(fonte, contains('"termico"'));
    }
    expect(swift, contains('os_proc_available_memory'),
        reason: 'no iOS o que importa e quanto o processo ainda pode alocar');
    expect(swift, contains('thermalState'));
    expect(kotlin, contains('getMemoryInfo'));
    expect(kotlin, contains('currentThermalStatus'));
  });
}
