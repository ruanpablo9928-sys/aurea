// A EDICAO PENDENTE: o valor que ja esta na tela e ainda nao esta gravado.
//
// E o unico caso do pedido que nao se resolve com "cria" ou "nao cria":
// propriedade ANIMADA, cabecote FORA de uma marca, e a pessoa mexe no
// numero. Gravar inventaria um keyframe que ninguem pediu; ignorar
// deixaria o controle morto na mao.
//
// A decisao do dono do produto foi a terceira porta: a previa mostra, a
// linha do tempo nao muda, e o losango crava
// (`docs/keyframe-explicito.md`).
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const t0 = Duration.zero;
const t1 = Duration(seconds: 1);
const t2 = Duration(seconds: 2);

/// Uma camada com a opacidade JA ANIMADA: marca em 0 s e marca em 2 s.
({ProviderContainer c, String id}) _animada() {
  final container = ProviderContainer();
  final c = container.read(editorControllerProvider.notifier);
  c.addShapeLayer(t0);
  final id = container.read(editorControllerProvider).layers.single.id;
  c.toggleKeyframe(id, t0, LayerProp.opacity);
  c.editOpacity(id, t0, 1);
  c.toggleKeyframe(id, t2, LayerProp.opacity);
  c.editOpacity(id, t2, 0);
  return (c: container, id: id);
}

Layer _real(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layerById(id)!;
Layer _visivel(ProviderContainer c, String id) =>
    c.read(projetoVisivelProvider).layerById(id)!;

void main() {
  test('editar fora da marca NAO mexe na linha do tempo', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final antes = _real(m.c, m.id).opacity;

    m.c.read(editorControllerProvider.notifier).editOpacity(m.id, t1, .75);

    final depois = _real(m.c, m.id).opacity;
    expect(depois.keyframes, hasLength(2), reason: 'nenhuma marca nasceu');
    expect(depois.keyframes.map((k) => k.time), antes.keyframes.map((k) => k.time));
    expect(depois.valueAt(t1), antes.valueAt(t1), reason: 'o gravado nao mudou');
  });

  test('mas a PREVIA ja mostra o valor novo', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    m.c.read(editorControllerProvider.notifier).editOpacity(m.id, t1, .75);

    expect(m.c.read(edicaoPendenteProvider), isNotNull);
    expect(_visivel(m.c, m.id).opacity.valueAt(t1), closeTo(.75, 1e-9));
    // E so naquele instante: os extremos gravados continuam de pe.
    expect(_visivel(m.c, m.id).opacity.valueAt(t0), 1);
    expect(_visivel(m.c, m.id).opacity.valueAt(t2), 0);
  });

  test('o losango crava o que esta na tela, e nao o interpolado', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    // Interpolado em 1 s seria 0.5; o que a pessoa esta vendo e 0.75.
    expect(_real(m.c, m.id).opacity.valueAt(t1), closeTo(.5, 1e-9));
    c.editOpacity(m.id, t1, .75);

    c.toggleKeyframe(m.id, t1, LayerProp.opacity);

    final o = _real(m.c, m.id).opacity;
    expect(o.keyframes, hasLength(3));
    expect(o.valueAt(t1), closeTo(.75, 1e-9));
    expect(m.c.read(edicaoPendenteProvider), isNull, reason: 'a pendencia morreu');
  });

  test('o cabecote andou: a pendencia morre sem deixar marca', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.editOpacity(m.id, t1, .75);

    c.descartarPendencia();

    expect(m.c.read(edicaoPendenteProvider), isNull);
    expect(_real(m.c, m.id).opacity.keyframes, hasLength(2));
    expect(_visivel(m.c, m.id).opacity.valueAt(t1), closeTo(.5, 1e-9));
  });

  test('qualquer edicao de VERDADE descarta a pendencia', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.editOpacity(m.id, t1, .75);

    // Mexer numa propriedade estatica e uma edicao de verdade: a
    // pendencia vira retrato de um projeto que nao existe mais.
    c.editScaleUniform(m.id, t1, 2);

    expect(m.c.read(edicaoPendenteProvider), isNull);
    expect(_real(m.c, m.id).scaleX.valueAt(t1), 2);
    expect(_real(m.c, m.id).opacity.keyframes, hasLength(2));
  });

  test('a pendencia nao chega a quem escuta o projeto — nem ao disco', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    var avisos = 0;
    final sub = m.c.listen(editorControllerProvider, (_, _) => avisos++);
    addTearDown(sub.close);

    m.c.read(editorControllerProvider.notifier).editOpacity(m.id, t1, .75);

    // A ponte de gravacao (`ref.listen(editorControllerProvider)` na
    // tela do editor) e o que leva o projeto ao disco. Se ela acordasse
    // aqui, o arquivo salvo teria um keyframe que a pessoa nao gravou.
    expect(avisos, 0);
  });

  test('a pendencia nao entra no desfazer', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.editOpacity(m.id, t1, .75);
    c.toggleKeyframe(m.id, t1, LayerProp.opacity);
    expect(_real(m.c, m.id).opacity.keyframes, hasLength(3));

    // UM toque em desfazer volta o passo inteiro — e nao meio passo,
    // com a marca la e o valor errado dentro dela.
    c.undo();
    expect(_real(m.c, m.id).opacity.keyframes, hasLength(2));
    expect(_real(m.c, m.id).opacity.valueAt(t1), closeTo(.5, 1e-9));
  });

  test('editar de novo TROCA a pendencia, nao empilha', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.editOpacity(m.id, t1, .75);
    c.editOpacity(m.id, t1, .25);

    c.toggleKeyframe(m.id, t1, LayerProp.opacity);
    final o = _real(m.c, m.id).opacity;
    expect(o.keyframes, hasLength(3));
    expect(o.valueAt(t1), closeTo(.25, 1e-9));
  });

  test('o losango de OUTRA camada nao crava a pendencia — descarta', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.addShapeLayer(t0);
    final outra = m.c
        .read(editorControllerProvider)
        .layers
        .firstWhere((l) => l.id != m.id);
    c.editOpacity(m.id, t1, .75);

    c.toggleKeyframe(outra.id, t1, LayerProp.opacity);

    // O losango da outra camada fez o que sempre faz: cravou a marca
    // DELA — e nada da pendencia foi parar la. Cravar e uma edicao de
    // verdade, e edicao de verdade descarta a pendencia: ela era o
    // retrato de um projeto que acabou de mudar.
    expect(_real(m.c, outra.id).opacity.hasKeyframeAt(t1), isTrue);
    expect(_real(m.c, m.id).opacity.keyframes, hasLength(2));
    expect(_real(m.c, m.id).opacity.valueAt(t1), closeTo(.5, 1e-9));
    expect(m.c.read(edicaoPendenteProvider), isNull);
  });

  test('o losango NOUTRO instante nao crava a pendencia', () {
    final m = _animada();
    addTearDown(m.c.dispose);
    final c = m.c.read(editorControllerProvider.notifier);
    c.editOpacity(m.id, t1, .75);

    c.toggleKeyframe(m.id, const Duration(milliseconds: 1500), LayerProp.opacity);

    final o = _real(m.c, m.id).opacity;
    expect(o.hasKeyframeAt(const Duration(milliseconds: 1500)), isTrue);
    expect(
      o.valueAt(t1),
      closeTo(.5, 1e-9),
      reason: 'em 1 s continua o interpolado: nada foi cravado ali',
    );
  });

  test('propriedade ESTATICA nunca fica pendente: muda a base e pronto', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(editorControllerProvider.notifier);
    c.addShapeLayer(t0);
    final id = container.read(editorControllerProvider).layers.single.id;

    c.editOpacity(id, t1, .3);

    expect(container.read(edicaoPendenteProvider), isNull);
    expect(container.read(editorControllerProvider).layerById(id)!.opacity.base, .3);
  });
}
