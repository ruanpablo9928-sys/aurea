// QA 1.0 — CAMPANHA 3: DESFAZER, REFAZER E O CICLO COMPLETO.
//
// Duas coisas que, se falharem, o usuario perde trabalho sem entender
// por que:
//
//   1. DESFAZER/REFAZER depois de dezenas de operacoes de tipos
//      diferentes. O estado tem de voltar EXATAMENTE ao que era — nao
//      "parecido".
//   2. O CICLO: criar, editar de tudo, salvar, fechar, reabrir. O que
//      volta tem de ser o que se viu antes de fechar, propriedade por
//      propriedade, no mesmo instante da linha do tempo.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/element3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/text_anim.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma foto do projeto que da para comparar: se dois projetos tem a
/// mesma foto, eles sao iguais para quem edita.
String _foto(VideoProject p) {
  final b = StringBuffer()
    ..writeln('nome=${p.name} fps=${p.fps} aspecto=${p.aspectRatio}');
  for (final l in p.layers) {
    b
      ..write('${l.runtimeType} ${l.id} "${l.name}" ')
      ..write('t=${l.startTime.inMicroseconds}+${l.duration.inMicroseconds} ')
      ..write('pos=${l.position.valueAt(const Duration(milliseconds: 500))} ')
      ..write('rot=${l.rotation.valueAt(const Duration(milliseconds: 500))} ')
      ..write('op=${l.opacity.valueAt(const Duration(milliseconds: 500))} ')
      ..write('efeitos=${l.effects.map((e) => e.type.name).join(",")} ');
    if (l is TextLayer) {
      b.write('texto="${l.text}" anims=${l.anims.map((a) => a.specId).join(",")} ');
    }
    if (l is Scene3DLayer) {
      b.write('nos=${l.scene.nodes.map((n) => "${n.id}:${n.kind.name}").join(",")} ');
    }
    b.writeln();
  }
  return b.toString();
}

void main() {
  late ProviderContainer container;
  EditorController ctrl() =>
      container.read(editorControllerProvider.notifier);
  VideoProject projeto() => container.read(editorControllerProvider);

  setUp(() {
    container = ProviderContainer();
    ctrl().openProject(
      VideoProject(name: 'qa', createdAt: DateTime(2026, 9, 8), layers: const []),
    );
  });
  tearDown(() => container.dispose());

  test('cada acao ESTRUTURAL e um passo de desfazer, e a volta e exata', () {
    // Adicionar, duplicar, remover e reordenar sao acoes deliberadas: uma
    // de cada vez no desfazer, mesmo feitas depressa. (Ajuste de valor e
    // outra coisa — ver o teste seguinte.)
    final inicial = _foto(projeto());
    final fotos = <String>[inicial];
    void passo(void Function() operacao) {
      operacao();
      fotos.add(_foto(projeto()));
    }

    passo(() => ctrl().addTextLayer(Duration.zero, text: 'Um'));
    passo(() => ctrl().addShapeLayer(Duration.zero, name: 'Forma A'));
    passo(() => ctrl().addShapeLayer(Duration.zero, name: 'Forma B'));
    passo(() => ctrl().addScene3DLayer(Duration.zero));
    passo(() => ctrl().duplicateLayer(projeto().layers.first.id));
    passo(() => ctrl().duplicateLayer(projeto().layers.last.id));
    passo(() => ctrl().removeLayer(projeto().layers.first.id));
    passo(() => ctrl().reorderLayer(projeto().layers.last.id, -1));
    passo(() => ctrl().removeLayer(projeto().layers.last.id));

    for (var i = fotos.length - 1; i > 0; i--) {
      expect(_foto(projeto()), fotos[i], reason: 'estado errado no passo $i');
      ctrl().undo();
    }
    expect(
      _foto(projeto()),
      inicial,
      reason: 'depois de desfazer tudo, o projeto tem de estar como comecou',
    );
    for (var i = 1; i < fotos.length; i++) {
      ctrl().redo();
      expect(_foto(projeto()), fotos[i], reason: 'refazer o passo $i');
    }
  });

  test('ajustar o MESMO numero varias vezes seguidas e um passo so', () {
    // Arrastar um valor manda dezenas de mudancas por segundo. Se cada
    // uma virasse um passo, desfazer um arrasto exigiria trinta toques.
    ctrl().addShapeLayer(Duration.zero, name: 'F');
    final id = projeto().layers.first.id;
    final antes = projeto().layers.first.opacity.valueAt(Duration.zero);
    for (var i = 1; i <= 30; i++) {
      ctrl().editOpacity(id, Duration.zero, i / 30);
    }
    ctrl().undo();
    expect(
      projeto().layers.first.opacity.valueAt(Duration.zero),
      closeTo(antes, 1e-9),
      reason: 'um desfazer tem de voltar o arrasto inteiro',
    );
    expect(projeto().layers, hasLength(1), reason: 'a camada continua la');
  });

  test('desfazer alem do inicio e refazer alem do fim nao quebram', () {
    for (var i = 0; i < 50; i++) {
      ctrl().undo();
    }
    expect(projeto().layers, isEmpty);
    for (var i = 0; i < 50; i++) {
      ctrl().redo();
    }
    expect(projeto().layers, isEmpty);
    // E o editor continua funcionando depois disso.
    ctrl().addShapeLayer(Duration.zero);
    expect(projeto().layers, hasLength(1));
  });

  test('uma operacao NOVA depois de desfazer corta o refazer', () {
    ctrl().addShapeLayer(Duration.zero, name: 'A');
    ctrl().addShapeLayer(Duration.zero, name: 'B');
    ctrl().undo();
    expect(projeto().layers, hasLength(1));
    ctrl().addTextLayer(Duration.zero, text: 'C');
    // O 'B' desfeito nao pode voltar por cima do 'C' — o refazer morreu
    // quando a historia mudou de rumo.
    ctrl().redo();
    final nomes = projeto().layers.map((l) => l.name).toList();
    expect(nomes.where((n) => n == 'B'), isEmpty);
    expect(projeto().layers, hasLength(2));
  });

  test('o ciclo completo: editar de tudo, salvar, fechar, reabrir', () {
    // 1. Um projeto com um pouco de cada coisa.
    final e = ctrl();
    e.addTextLayer(Duration.zero, text: 'AUREA');
    final texto = projeto().layers.whereType<TextLayer>().single;
    e.setTextAnim(texto.id, TextAnimSlot.entrada, 'bounceLetter');
    e.editTextLayer(texto.id, fontSize: 96, color: const Color(0xFFB8FF3D));
    e.addShapeLayer(Duration.zero, name: 'Fundo');
    final forma = projeto().layers.firstWhere(
      (l) => l.name.startsWith('Fundo'),
    );
    e.addEffect(forma.id, EffectType.lightGlow);
    e.addEffect(forma.id, EffectType.tint);
    e.editOpacity(forma.id, Duration.zero, 0.66);
    e.addScene3DLayer(Duration.zero);
    final cena = projeto().layers.whereType<Scene3DLayer>().single;
    e.addSceneNode(cena.id, Element3DKind.sphere);
    e.addScene3DCamera(cena.id);
    // Um keyframe de posicao no texto, no meio do tempo.
    e.editPosition(texto.id, Duration.zero, const Offset(100, 200));
    e.toggleKeyframe(texto.id, const Duration(seconds: 1), LayerProp.position);

    final antes = _foto(projeto());
    final noDisco = projectToJson(projeto());

    // 2. Fecha (abre outro projeto) e reabre o que foi salvo.
    e.openProject(
      VideoProject(name: 'outro', createdAt: DateTime(2026), layers: const []),
    );
    expect(projeto().layers, isEmpty);
    e.openProject(projectFromJson(noDisco));

    // 3. O que voltou tem de ser o que se viu.
    expect(_foto(projeto()), antes, reason: 'o projeto reaberto nao e o mesmo');

    // E o detalhe que a foto nao cobre: a animacao do texto e a cena 3D.
    final textoVolta = projeto().layers.whereType<TextLayer>().single;
    expect(textoVolta.anims.single.specId, 'bounceLetter');
    expect(textoVolta.fontSize, 96);
    expect(textoVolta.color, const Color(0xFFB8FF3D));
    final cenaVolta = projeto().layers.whereType<Scene3DLayer>().single;
    expect(cenaVolta.scene.nodes, hasLength(1));
    expect(cenaVolta.allCameras.length, 2);
    final formaVolta = projeto().layers.firstWhere(
      (l) => l.name.startsWith('Fundo'),
    );
    expect(formaVolta.effects.map((x) => x.type), [
      EffectType.lightGlow,
      EffectType.tint,
    ]);
    expect(formaVolta.opacity.valueAt(Duration.zero), closeTo(0.66, 1e-9));
  });

  test('reabrir cem vezes seguidas nao muda o projeto (nem incha)', () {
    ctrl().addTextLayer(Duration.zero, text: 'AUREA');
    ctrl().addShapeLayer(Duration.zero);
    var json = projectToJson(projeto());
    final primeira = _foto(projectFromJson(json));
    var tamanho = json.toString().length;
    for (var i = 0; i < 100; i++) {
      final p = projectFromJson(json);
      json = projectToJson(p);
      // O arquivo nao pode crescer a cada ida e volta (campo duplicado,
      // lista que se acumula): num projeto aberto e salvo todo dia, isso
      // vira um arquivo de megabytes.
      final agora = json.toString().length;
      expect(
        agora,
        lessThanOrEqualTo(tamanho + 64),
        reason: 'o arquivo cresceu na volta $i ($tamanho -> $agora)',
      );
      tamanho = agora;
    }
    expect(_foto(projectFromJson(json)), primeira);
  });
}
