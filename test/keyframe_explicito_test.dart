// COM AUTOKEY DESLIGADO, O KEYFRAME E EXPLICITO.
//
// Este arquivo se chamava assim porque testava o keyframe AUTOMATICO —
// e era ele que guardava o defeito: as afirmacoes de antes exigiam que
// editar um valor cravasse marca sozinho, em dois eixos e em dois
// instantes.
//
// A regra do produto mudou (`docs/keyframe-explicito.md`): editar valor
// nunca cria keyframe. O que sobrou de valioso das afirmacoes antigas —
// tempo LOCAL da camada, os tres eixos de giro andando juntos, o
// desfazer devolvendo a pose — continua aqui, agora medido contra a
// regra certa.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma forma que comeca em 3 s e dura 5 s — o tempo LOCAL dela e o
/// global menos 3 s, e e sobre o local que os keyframes moram.
ProviderContainer _comFormaAtrasada() {
  final ref = ProviderContainer();
  ref.read(autoKeyframeProvider.notifier).state = false;
  final editor = ref.read(editorControllerProvider.notifier);
  editor.openProject(
    ref
        .read(editorControllerProvider)
        .copyWith(
          layers: [
            ShapeLayer(
              id: 'shape',
              name: 'Motion',
              startTime: const Duration(seconds: 3),
              duration: const Duration(seconds: 5),
              position: AnimatedOffset(const Offset(10, 20)),
            ),
          ],
        ),
  );
  return ref;
}

Layer _camada(ProviderContainer ref) =>
    ref.read(editorControllerProvider).layerById('shape')!;

void main() {
  test('mover sem tocar no losango nao cria keyframe nenhum', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    editor.editPosition(
      'shape',
      const Duration(seconds: 5),
      const Offset(50, 60),
    );

    final l = _camada(ref);
    expect(l.position.isAnimated, isFalse);
    expect(l.position.keyframes, isEmpty);
    expect(
      l.position.base,
      const Offset(50, 60),
      reason: 'estatica: editar muda a base, e so',
    );
  });

  test('o losango crava no tempo LOCAL da camada', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    // Cabecote em 5 s da linha do tempo = 2 s dentro da camada.
    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 5),
      LayerProp.position,
    );
    final l = _camada(ref);
    expect(l.position.keyframes, hasLength(1));
    expect(l.position.keyframes.single.time, const Duration(seconds: 2));
    expect(
      l.position.keyframes.single.value,
      const Offset(10, 20),
      reason: 'a marca guarda o valor que estava valendo',
    );
  });

  test('depois do losango, o valor entra NAQUELA marca', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 5),
      LayerProp.position,
    );
    editor.editPosition(
      'shape',
      const Duration(seconds: 5),
      const Offset(50, 60),
    );

    final l = _camada(ref);
    expect(l.position.keyframes, hasLength(1), reason: 'nao duplica');
    expect(l.position.keyframes.single.value, const Offset(50, 60));
  });

  test('animada, FORA da marca, editar nao mexe na trilha', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 3),
      LayerProp.position,
    );
    final antes = _camada(ref).position;

    editor.editPosition(
      'shape',
      const Duration(seconds: 6),
      const Offset(99, 99),
    );

    final depois = _camada(ref).position;
    expect(depois.keyframes, hasLength(1));
    expect(depois.keyframes.single.time, antes.keyframes.single.time);
    expect(depois.keyframes.single.value, antes.keyframes.single.value);
  });

  test('o desfazer devolve a pose', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 5),
      LayerProp.position,
    );
    expect(_camada(ref).position.isAnimated, isTrue);

    editor.undo();
    expect(_camada(ref).position.isAnimated, isFalse);
    expect(_camada(ref).position.base, const Offset(10, 20));
  });

  test('o losango do giro marca os TRES eixos, e a escala fica de fora', () {
    final ref = ProviderContainer();
    ref.read(autoKeyframeProvider.notifier).state = false;
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);
    editor.addShapeLayer(Duration.zero);
    final id = ref.read(editorControllerProvider).layers.first.id;
    const t = Duration(seconds: 1);

    editor.toggleKeyframe(id, t, LayerProp.rotation);
    editor.editRotation(id, t, 90);

    final l = ref.read(editorControllerProvider).layerById(id)!;
    // No motor a rotacao e UMA propriedade de tres eixos.
    expect(l.rotation.hasKeyframeAt(t), isTrue);
    expect(l.rotationX.hasKeyframeAt(t), isTrue);
    expect(l.rotationY.hasKeyframeAt(t), isTrue);
    expect(l.rotation.valueAt(t), 90);
    // E a escala nao foi arrastada junto.
    expect(l.scaleX.isAnimated, isFalse);
    expect(l.scaleX.valueAt(t), 1);
  });

  test('a escala sem losango continua estatica nos dois eixos', () {
    final ref = ProviderContainer();
    ref.read(autoKeyframeProvider.notifier).state = false;
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);
    editor.addShapeLayer(Duration.zero);
    final id = ref.read(editorControllerProvider).layers.first.id;

    editor.editScaleUniform(id, const Duration(seconds: 1), 2);

    final l = ref.read(editorControllerProvider).layerById(id)!;
    expect(l.scaleX.isAnimated, isFalse);
    expect(l.scaleY.isAnimated, isFalse);
    expect(l.scaleX.valueAt(Duration.zero), 2);
  });

  test('projetoVisivelProvider reflete edicao pendente fora de keyframe e toggleKeyframe crava', () {
    final ref = _comFormaAtrasada();
    addTearDown(ref.dispose);
    final editor = ref.read(editorControllerProvider.notifier);

    // Marca em 3s (tempo local 0s)
    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 3),
      LayerProp.position,
    );

    // Edita em 5s (tempo local 2s, fora da marca)
    editor.editPosition(
      'shape',
      const Duration(seconds: 5),
      const Offset(88, 99),
    );

    // O projeto real continua intacto (sem keyframe fantasma)
    final real = ref.read(editorControllerProvider).layerById('shape')!;
    expect(real.position.keyframes, hasLength(1));
    expect(real.position.keyframes.single.value, const Offset(10, 20));

    // O projeto visivel (o que a previa e o painel mostram) reflete o valor novo em tempo real
    final visivel = ref.read(projetoVisivelProvider).layerById('shape')!;
    expect(
      visivel.position.valueAt(const Duration(seconds: 2)),
      const Offset(88, 99),
    );

    // Ao tocar no losango do rail, a pendencia e gravada no projeto de verdade
    editor.toggleKeyframe(
      'shape',
      const Duration(seconds: 5),
      LayerProp.position,
    );
    final gravado = ref.read(editorControllerProvider).layerById('shape')!;
    expect(gravado.position.keyframes, hasLength(2));
    expect(gravado.position.keyframes.last.value, const Offset(88, 99));
    expect(gravado.position.keyframes.last.time, const Duration(seconds: 2));
  });

  test(
    'com autoKeyframe ativo, edicao fora de marca grava direto no projeto real',
    () {
      final ref = _comFormaAtrasada();
      addTearDown(ref.dispose);
      final editor = ref.read(editorControllerProvider.notifier);

      // Liga autoKeyframe
      ref.read(autoKeyframeProvider.notifier).state = true;

      // Marca inicial em 3s
      editor.toggleKeyframe(
        'shape',
        const Duration(seconds: 3),
        LayerProp.position,
      );

      // Edita em 5s com autoKeyframe ligado
      editor.editPosition(
        'shape',
        const Duration(seconds: 5),
        const Offset(123, 456),
      );

      // Grava imediatamente sem ficar pendente
      final real = ref.read(editorControllerProvider).layerById('shape')!;
      expect(real.position.keyframes, hasLength(2));
      expect(real.position.keyframes.last.value, const Offset(123, 456));
    },
  );
}
