// QA 1.0 — CAMPANHA 1: NADA SE PERDE AO SALVAR E REABRIR.
//
// Esta e a checagem de severidade mais alta que existe: perder trabalho.
// Em vez de conferir "um projeto completo" (que o project_store_test ja
// faz), esta campanha varre os CATALOGOS — todos os 56 efeitos, todos os
// 36 presets de animacao de texto, todos os tipos de forma e de objeto
// 3D — e prova, um por um, que cada um sobrevive a gravacao e a
// releitura com os parametros que tinha.
//
// Um catalogo cresce; um teste escrito a mao envelhece. Varrendo o
// catalogo, o efeito novo de amanha entra na conta sozinho.
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/scene3d.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/text_anim.dart';
import 'package:aurea/src/features/editor/domain/text_animator.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

VideoProject _projetoCom(List<Layer> camadas) => VideoProject(
  name: 'qa',
  createdAt: DateTime(2026, 9, 8),
  layers: camadas,
);

VideoProject _idaEVolta(VideoProject p) => projectFromJson(projectToJson(p));

void main() {
  group('todos os efeitos do catalogo', () {
    test('cada efeito sobrevive a ida e volta, com os parametros', () {
      final falhas = <String>[];
      for (final tipo in EffectType.values) {
        final efeito = EffectInstance(type: tipo);
        final camada = ShapeLayer(
          id: 'forma',
          name: 'Forma',
          startTime: Duration.zero,
          duration: const Duration(seconds: 5),
          effects: [efeito],
        );
        try {
          final volta = _idaEVolta(_projetoCom([camada]));
          final lida = volta.layers.single;
          if (lida.effects.length != 1) {
            falhas.add('${tipo.name}: sumiu na volta');
            continue;
          }
          final e = lida.effects.single;
          if (e.type != tipo) {
            falhas.add('${tipo.name}: voltou como ${e.type.name}');
            continue;
          }
          // Os parametros que o efeito tem de nascenca precisam voltar
          // com o MESMO valor — um efeito que volta no padrao errado
          // muda a cena de quem salvou.
          for (final chave in efeito.params.keys) {
            final antes = efeito.params[chave]!.valueAt(Duration.zero);
            final depois = e.params[chave]?.valueAt(Duration.zero);
            if (depois == null) {
              falhas.add('${tipo.name}: perdeu o parametro $chave');
            } else if ((antes - depois).abs() > 1e-6) {
              falhas.add('${tipo.name}.$chave: $antes -> $depois');
            }
          }
          if (e.enabled != efeito.enabled) {
            falhas.add('${tipo.name}: ligado/desligado mudou');
          }
        } catch (erro) {
          falhas.add('${tipo.name}: EXPLODIU ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('efeito com parametro ANIMADO mantem os keyframes', () {
      final falhas = <String>[];
      for (final tipo in EffectType.values) {
        final base = EffectInstance(type: tipo);
        if (base.params.isEmpty) continue;
        final chave = base.params.keys.first;
        final animado = EffectInstance(
          type: tipo,
          params: {
            ...base.params,
            chave: AnimatedDouble(base.params[chave]!.valueAt(Duration.zero))
                .withKeyframe(Duration.zero, 1)
                .withKeyframe(const Duration(seconds: 2), 9),
          },
        );
        final volta = _idaEVolta(
          _projetoCom([
            ShapeLayer(
              id: 'f',
              name: 'F',
              startTime: Duration.zero,
              duration: const Duration(seconds: 5),
              effects: [animado],
            ),
          ]),
        );
        final p = volta.layers.single.effects.single.params[chave];
        if (p == null) {
          falhas.add('${tipo.name}: parametro animado sumiu');
          continue;
        }
        if (!p.isAnimated) {
          falhas.add('${tipo.name}: perdeu a animacao');
        } else if ((p.valueAt(const Duration(seconds: 2)) - 9).abs() > 1e-6) {
          falhas.add(
            '${tipo.name}: valor em 2s virou ${p.valueAt(const Duration(seconds: 2))}',
          );
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('todas as animacoes de texto do catalogo', () {
    test('cada preset volta igual: unidade, ordem, curva, mola e tempos', () {
      final falhas = <String>[];
      for (final spec in textAnimCatalog) {
        for (final slot in spec.slots) {
          final anim = TextAnim(
            specId: spec.id,
            slot: slot,
            unit: TextAnimUnit.word,
            ease: TextAnimEase.mola,
            amplitude: 1.7,
            frequency: 3.3,
            decay: 6.5,
            duration: const Duration(milliseconds: 1234),
            stagger: const Duration(milliseconds: 77),
            start: const Duration(milliseconds: 250),
          );
          final camada = TextLayer(
            id: 'txt',
            name: 'Texto',
            text: 'AUREA',
            startTime: Duration.zero,
            duration: const Duration(seconds: 6),
            anims: [anim],
          );
          try {
            final volta = _idaEVolta(_projetoCom([camada]));
            final lida = (volta.layers.single as TextLayer).anims;
            if (lida.length != 1) {
              falhas.add('${spec.id}/${slot.name}: sumiu');
              continue;
            }
            final a = lida.single;
            if (a.specId != spec.id) falhas.add('${spec.id}: virou ${a.specId}');
            if (a.slot != slot) falhas.add('${spec.id}: slot mudou');
            if (a.unit != TextAnimUnit.word) {
              falhas.add('${spec.id}: unidade mudou para ${a.unit.name}');
            }
            if (a.ease != TextAnimEase.mola) {
              falhas.add('${spec.id}: curva mudou para ${a.ease.name}');
            }
            if ((a.amplitude - 1.7).abs() > 1e-6 ||
                (a.frequency - 3.3).abs() > 1e-6 ||
                (a.decay - 6.5).abs() > 1e-6) {
              falhas.add(
                '${spec.id}: mola virou ${a.amplitude}/${a.frequency}/${a.decay}',
              );
            }
            if (a.duration.inMilliseconds != 1234 ||
                a.stagger.inMilliseconds != 77 ||
                a.start.inMilliseconds != 250) {
              falhas.add('${spec.id}: tempos mudaram');
            }
          } catch (erro) {
            falhas.add('${spec.id}/${slot.name}: EXPLODIU ($erro)');
          }
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('todas as formas e todos os objetos 3D', () {
    test('cada primitiva de forma volta igual', () {
      final falhas = <String>[];
      for (final prim in ShapePrimitive.values) {
        final camada = ShapeLayer(
          id: 's',
          name: 'S',
          startTime: Duration.zero,
          duration: const Duration(seconds: 4),
          contents: [
            ShapePath(primitive: prim, points: 7, innerRadiusRatio: .4),
            ShapeFill(color: const Color(0xFF3366FF)),
            ShapeStroke(
              color: const Color(0xFFFFFFFF),
              width: AnimatedDouble(3),
            ),
          ],
        );
        try {
          final volta = _idaEVolta(_projetoCom([camada]));
          final lida = volta.layers.single as ShapeLayer;
          final caminho = lida.contents.whereType<ShapePath>().firstOrNull;
          if (caminho == null) {
            falhas.add('${prim.name}: caminho sumiu');
          } else if (caminho.primitive != prim) {
            falhas.add('${prim.name}: virou ${caminho.primitive.name}');
          }
          if (lida.contents.whereType<ShapeFill>().isEmpty) {
            falhas.add('${prim.name}: preenchimento sumiu');
          }
          if (lida.contents.whereType<ShapeStroke>().isEmpty) {
            falhas.add('${prim.name}: contorno sumiu');
          }
        } catch (erro) {
          falhas.add('${prim.name}: EXPLODIU ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('cada tipo de objeto 3D volta igual, com material e animacao', () {
      final falhas = <String>[];
      for (final kind in Element3DKind.values) {
        final cena = Scene3D(
          nodes: [
            SceneNode(
              id: 'n',
              name: 'No',
              kind: kind,
              size: 137,
              material: const Material3D(
                baseColor: Color(0xFF00FF88),
                metallic: .7,
                roughness: .2,
              ),
              rotY: AnimatedDouble(0)
                  .withKeyframe(Duration.zero, 0)
                  .withKeyframe(const Duration(seconds: 2), 90),
            ),
          ],
          lights: Scene3D.tresPontos,
        );
        final camada = Scene3DLayer(
          id: 'c3d',
          name: 'Cena',
          startTime: Duration.zero,
          duration: const Duration(seconds: 5),
          scene: cena,
        );
        try {
          final volta = _idaEVolta(_projetoCom([camada]));
          final lida = volta.layers.single as Scene3DLayer;
          final no = lida.scene.nodes.single;
          if (no.kind != kind) falhas.add('${kind.name}: virou ${no.kind.name}');
          if (no.size != 137) falhas.add('${kind.name}: tamanho mudou');
          if (no.material.metallic != .7 || no.material.roughness != .2) {
            falhas.add('${kind.name}: material mudou');
          }
          if ((no.rotY.valueAt(const Duration(seconds: 2)) - 90).abs() > 1e-6) {
            falhas.add('${kind.name}: a animacao nao voltou');
          }
          if (lida.scene.lights.length != Scene3D.tresPontos.length) {
            falhas.add('${kind.name}: perdeu luz');
          }
        } catch (erro) {
          falhas.add('${kind.name}: EXPLODIU ($erro)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('o easing de cada keyframe', () {
    test('todas as curvas voltam iguais', () {
      final falhas = <String>[];
      for (final tipo in EasingType.values) {
        final valor = AnimatedDouble(0)
            .withKeyframe(Duration.zero, 0, Easing(type: tipo))
            .withKeyframe(const Duration(seconds: 1), 100, Easing(type: tipo));
        final volta = _idaEVolta(
          _projetoCom([
            ShapeLayer(
              id: 'f',
              name: 'F',
              startTime: Duration.zero,
              duration: const Duration(seconds: 3),
              rotation: valor,
            ),
          ]),
        );
        final lida = volta.layers.single.rotation;
        if (lida.keyframes.first.ease.type != tipo) {
          falhas.add(
            '${tipo.name}: virou ${lida.keyframes.first.ease.type.name}',
          );
        }
        // E o valor no meio tem de bater — a curva muda o desenho.
        final antes = valor.valueAt(const Duration(milliseconds: 500));
        final depois = lida.valueAt(const Duration(milliseconds: 500));
        if ((antes - depois).abs() > 1e-6) {
          falhas.add('${tipo.name}: meio do caminho $antes -> $depois');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });
}
