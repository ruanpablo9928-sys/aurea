// O GRAVADOR DO TUTORIAL DA CENA 3D.
//
// Nao e um teste de verdade: e uma "gravacao de tela" feita pelo proprio
// renderizador do app. Ele abre a Inicio, cria um projeto, adiciona uma
// Cena 3D, entra no Estudio, poe um cubo, anima, cria uma camera, corta
// entre as duas, manda a camera olhar para o cubo, volta e da o play —
// tirando um PNG a cada passo e anotando onde o dedo tocou e qual legenda
// vale em cada quadro. O `test/tutoriais/montar_tutorial_cena3d.py` junta tudo num MP4
// com a faixa de legenda embaixo.
//
// Por que assim, e nao gravando um celular: nao se abre o emulador aqui,
// e o desenho e o mesmo — sao os mesmos widgets, a mesma cena, o mesmo
// pintor. O que falta e so a barra de status do sistema.
//
// Rodar (so quando se quer regravar; a suite normal pula):
//   AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_cena3d_test.dart
// Saida: build/tutorial/cena3d/{quadros/*.png, quadros.json, cenas.json}
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/core/theme/app_theme.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/estudio_preferencia.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/editor/presentation/am/scene3d_studio.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/application/project_repository.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:aurea/src/features/projects/presentation/home_shell.dart';
import 'package:aurea/src/features/projects/presentation/release_notice.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _saida = 'build/tutorial/cena3d';
const _chaveGravacao = ValueKey('gravacao');

class _MemoryProjects extends ProjectsController {
  @override
  List<VideoProject> build() => [];
}

/// Sem disco: o repositorio de verdade grava por isolate, que nao anda
/// no relogio de mentira do testWidgets.
class _RepoNulo extends ProjectRepository {
  _RepoNulo()
    : super(directory: Directory.systemTemp, installBundledExamples: false);

  @override
  Future<List<VideoProject>> loadAll() async => const [];

  @override
  Future<void> save(VideoProject project) async {}

  @override
  Future<void> delete(String id) async {}
}

/// As fontes de verdade, sob todos os nomes que o app usa: sem isto o
/// texto sai como caixinhas.
Future<void> _carregarFontes() async {
  for (final family in [
    'Aurea Motion Sans',
    'Roboto',
    'CupertinoSystemText',
    'CupertinoSystemDisplay',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
    '.AppleSystemUIFont',
  ]) {
    await (FontLoader(family)..addFont(
          rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
        ))
        .load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
  await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      ))
      .load();
}

class _Gravador {
  _Gravador(this.tester);

  final WidgetTester tester;
  final quadros = <Map<String, Object?>>[];
  final cenas = <Map<String, Object?>>[];
  Offset? dedo;
  double tempo = 0;
  int _n = 0;

  /// A FILA DE IMAGENS AINDA NAO GRAVADAS.
  ///
  /// Gravar o PNG exige `runAsync`, e `runAsync` no meio de um gesto
  /// mata o gesto: o arrasto que gira o cubo nunca chegava ao painel.
  /// Entao o quadro e capturado de forma sincrona (`toImageSync`) e o
  /// disco espera o dedo levantar.
  final _fila = <(String, ui.Image)>[];

  /// Um quadro: repinta tudo, guarda a imagem e anota dedo, cena e duracao.
  Future<void> quadro({double dur = 1 / 12}) async {
    void repintar(RenderObject o) {
      o.markNeedsPaint();
      o.visitChildren(repintar);
    }

    repintar(tester.renderObject(find.byKey(_chaveGravacao)));
    await tester.pump();
    final nome = '${_n.toString().padLeft(4, '0')}.png';
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_chaveGravacao),
    );
    _fila.add((nome, boundary.toImageSync(pixelRatio: 2)));
    quadros.add({
      'arquivo': nome,
      'dur': dur,
      'dedo': dedo == null ? null : [dedo!.dx, dedo!.dy],
      'cena': cenas.length,
    });
    tempo += dur;
    _n++;
    // Fora de gesto, escoa a fila: cada quadro guardado sao ~5 MB.
    if (dedo == null && _fila.length >= 8) await descarregar();
  }

  /// Grava no disco o que estiver na fila.
  Future<void> descarregar() async {
    if (_fila.isEmpty) return;
    final lote = [..._fila];
    _fila.clear();
    await tester.runAsync(() async {
      for (final (nome, imagem) in lote) {
        final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
        await File('$_saida/quadros/$nome').writeAsBytes(
          bytes!.buffer.asUint8List(),
        );
        imagem.dispose();
      }
    });
  }

  Future<void> segurar(double segundos) => quadro(dur: segundos);

  /// Alguns quadros seguidos, para uma transicao (folha subindo, rota).
  Future<void> assentar({int quadros = 5, int ms = 90}) async {
    for (var i = 0; i < quadros; i++) {
      await tester.pump(Duration(milliseconds: ms));
      await quadro(dur: ms / 1000);
    }
  }

  void cena(String texto) {
    cenas.add({'n': cenas.length + 1, 'texto': texto, 'inicio': tempo});
  }

  /// Toque com o dedo a vista: aparece, toca, some.
  Future<void> tocar(Finder f) async {
    await tester.ensureVisible(f);
    await tester.pump();
    dedo = tester.getCenter(f);
    await quadro(dur: .3);
    await tester.tap(f, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
    await quadro(dur: .12);
    dedo = null;
  }

  /// ARRASTO EM PASSOS, cada passo um gesto INTEIRO (desce, anda, sobe).
  ///
  /// Um gesto unico com pausas entre os movimentos nao chegava ao palco
  /// do Estudio: o reconhecedor que ganha a arena depende do ritmo, e o
  /// arrasto do gravador (com um quadro gravado a cada passo) e lento
  /// demais. Gestos inteiros sempre valem — e como o efeito e cumulativo
  /// (girar soma graus, a regua soma passos), o resultado na tela e o
  /// mesmo de um arrasto continuo.
  Future<void> arrastar(Finder f, Offset delta, {int passos = 8}) async {
    final inicio = tester.getCenter(f);
    final pedaco = delta / passos.toDouble();
    for (var i = 1; i <= passos; i++) {
      dedo = inicio + delta * (i / passos);
      await tester.drag(f, pedaco, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 40));
      await quadro(dur: .08);
    }
    dedo = null;
    await tester.pump(const Duration(milliseconds: 60));
    await quadro(dur: .35);
    await descarregar();
  }

  /// A regua do tempo do Estudio, com o dedo andando junto do valor.
  Future<void> tempoDoEstudio(double de, double ate, {int passos = 8}) async {
    final regua = find.byKey(const ValueKey('scene-motion-time'));
    final r = tester.getRect(regua);
    final widget = tester.widget<AmTickRuler>(regua);
    for (var i = 1; i <= passos; i++) {
      final v = de + (ate - de) * i / passos;
      widget.onChanged(v);
      dedo = Offset(r.left + r.width * (i / passos), r.center.dy);
      await tester.pump(const Duration(milliseconds: 40));
      await quadro(dur: .09);
    }
    dedo = null;
    await tester.pump();
    await quadro(dur: .3);
  }

  Future<void> salvar() async {
    await descarregar();
    File('$_saida/quadros.json').writeAsStringSync(jsonEncode(quadros));
    File('$_saida/cenas.json').writeAsStringSync(jsonEncode(cenas));
  }
}

void main() {
  final gravar = Platform.environment['AUREA_GRAVAR_TUTORIAL'] == '1';

  testWidgets('grava o tutorial da cena 3D, quadro a quadro', (tester) async {
    if (!gravar) return;
    Directory('$_saida/quadros').createSync(recursive: true);
    for (final f in Directory('$_saida/quadros').listSync()) {
      f.deleteSync();
    }

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _carregarFontes();

    SharedPreferences.setMockInitialValues({
      releaseNoticeSeenKey: releaseNoticeRevision,
      EstudioPreferencia.kDicasVistas: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        projectsControllerProvider.overrideWith(_MemoryProjects.new),
        projectRepositoryProvider.overrideWithValue(_RepoNulo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: _chaveGravacao,
          child: MaterialApp(
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            home: const HomeShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final g = _Gravador(tester);
    Scene3DLayer cena() => container
        .read(editorControllerProvider)
        .layers
        .whereType<Scene3DLayer>()
        .single;
    final viewport = find.byWidgetPredicate(
      (w) =>
          w is CustomPaint &&
          w.painter is Scene3DPainter &&
          (w.painter as Scene3DPainter).view == SceneView.camera,
    );

    // 1. Inicio -> Novo projeto.
    g.cena('Na Início, toque em Novo projeto.');
    await g.segurar(1.6);
    await g.tocar(find.byKey(const ValueKey('novo-projeto')));
    await g.assentar(quadros: 6);

    g.cena('Escolha o formato — 9:16 para Reels — e toque em Criar projeto.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('formato-9:16')));
    await g.assentar(quadros: 4);
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('criar-projeto')));
    await g.assentar(quadros: 8);

    // 2. Adicionar a cena 3D. O projeto novo ja abre com o menu de
    //    adicionar na frente — e so trocar para a aba Objeto.
    g.cena('O projeto novo abre com o menu de adicionar. Vá na aba Objeto.');
    await g.segurar(1.4);
    if (find.byKey(const ValueKey('add-tab-objeto')).evaluate().isEmpty) {
      await g.tocar(find.byKey(const ValueKey('estado-vazio-cta')));
      await g.assentar(quadros: 5);
    }
    await g.tocar(find.byKey(const ValueKey('add-tab-objeto')));
    await g.assentar(quadros: 6);

    g.cena('Toque em Cena 3D: um ambiente 3D com objetos, luzes e câmera.');
    await g.segurar(1.0);
    await g.tocar(find.text('Cena 3D'));
    await g.assentar(quadros: 8);
    if (container.read(selectedLayerProvider) == null) {
      await g.tocar(find.byType(PreviewStage));
      await g.assentar(quadros: 4);
    }

    // 3. Abrir o Estudio.
    g.cena('A cena entra na timeline. No menu da camada, toque em Cena 3D para abrir o Estúdio.');
    await g.segurar(1.2);
    await g.tocar(find.text('Cena 3D'));
    await g.assentar(quadros: 8);
    expect(find.byType(Scene3DStudio), findsOneWidget);

    // 4. O tour.
    g.cena('O Estúdio: em cima, Cena, Câmera e o menu ⋮. Embaixo, a linha do tempo e as ferramentas Selecionar, Mover, Girar e Escalar.');
    await g.segurar(3.5);

    // 5. Um cubo.
    g.cena('Toque em + e escolha Objeto → Cubo. Ele já nasce selecionado, com a barra de contexto dele.');
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('estudio-adicionar')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-objeto')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-cube')));
    await g.assentar(quadros: 8);
    await g.segurar(1.0);
    final cubo = cena().scene.nodes.single.id;

    // 6. Material.
    g.cena('Na barra de contexto, Material: arraste a régua Metálico para mudar o acabamento — sem sair da tela.');
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('contexto-material')));
    await g.assentar(quadros: 5);
    final regua = find.descendant(
      of: find.byKey(const ValueKey('material-metalico')),
      matching: find.byType(AmTickRuler),
    );
    await g.arrastar(regua, const Offset(-220, 0));
    await g.segurar(.8);
    // O material e uma folha: fecha para a barra de contexto voltar.
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await g.assentar(quadros: 5);

    // 7. Enquadrar e animar com Auto-key.
    g.cena('Toque em Focar: a câmera enquadra o objeto selecionado.');
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('estudio-focar')));
    await g.assentar(quadros: 6);
    await g.segurar(.8);

    g.cena('Arraste no palco para orbitar a câmera e ver a cena de outro ângulo.');
    await g.segurar(.6);
    await g.arrastar(viewport, const Offset(90, 0), passos: 9);
    await g.segurar(.8);

    g.cena('Selecione o cubo, leve o tempo para 2 s e escolha a ferramenta Girar.');
    await g.segurar(.6);
    await g.tocar(viewport);
    await g.assentar(quadros: 3);
    await g.tempoDoEstudio(0, 2);
    await g.tocar(find.text('Girar'));
    await g.assentar(quadros: 3);

    g.cena('Toque no Y do giro e digite 45. Com o Auto-key ligado, o keyframe nasce em 2 s — e o cubo passa a girar de 0 até 45 graus.');
    await g.segurar(.8);
    // O NUMERO, e nao o arrasto: no arrasto quem decide e onde o dedo
    // encosta (fora do objeto, o palco orbita). O campo e o caminho que
    // sempre funciona — e o que se ensina.
    await g.tocar(find.byKey(const ValueKey('scene-transform-1')));
    await g.assentar(quadros: 5);
    await tester.enterText(find.byKey(const ValueKey('valor-campo')), '45');
    await g.assentar(quadros: 3);
    tester.view.resetViewInsets();
    await g.assentar(quadros: 3);
    await g.tocar(find.text('OK'));
    await g.assentar(quadros: 6);
    expect(
      cena().scene.nodeById(cubo)!.rotY.valueAt(const Duration(seconds: 2)),
      45,
      reason: 'o valor entrou em 2 s',
    );
    expect(
      cena().scene.nodeById(cubo)!.rotY.valueAt(Duration.zero),
      0,
      reason: 'o Auto-key guardou a pose do inicio',
    );
    await g.segurar(1.2);

    // 8. Ver a animacao.
    g.cena('Arraste o tempo de volta e veja o cubo girar entre os dois keyframes.');
    await g.tempoDoEstudio(2, 0, passos: 12);
    await g.tempoDoEstudio(0, 2, passos: 12);
    await g.segurar(.8);

    // 9. Nova camera.
    g.cena('Câmera → Nova câmera: ela entra no ar na hora. Com Mover, arraste para reposicioná-la.');
    await g.segurar(.6);
    final principal = cena().camera.id;
    await g.tocar(find.byKey(const ValueKey('estudio-camera')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(const ValueKey('camera-nova')));
    await g.assentar(quadros: 8);
    await g.tocar(find.text('Mover'));
    await g.assentar(quadros: 3);
    await g.arrastar(viewport, const Offset(0, -50), passos: 8);
    await g.segurar(1.0);

    // 10. Cortar de volta.
    g.cena('Com duas câmeras aparece a faixa de troca. Leve o tempo para 3 s e toque na primeira câmera: o corte acontece nesse instante.');
    await g.segurar(.6);
    await g.tempoDoEstudio(2, 3, passos: 6);
    await g.tocar(find.byKey(ValueKey('faixa-camera-$principal')));
    await g.assentar(quadros: 8);
    await g.segurar(1.0);

    // 11. Olhar para.
    g.cena('Menu ⋮ → Cena: toque na câmera na lista, depois em Olhar para e escolha o cubo. A câmera passa a seguir o objeto.');
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('estudio-mais')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('mais-cena')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(ValueKey('cena-item-$principal')));
    await g.assentar(quadros: 6);
    if (find.byKey(const ValueKey('contexto-olhar')).evaluate().isEmpty) {
      // A lista e uma folha: fecha para a barra de contexto aparecer.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.pop();
      await g.assentar(quadros: 5);
    }
    await g.tocar(find.byKey(const ValueKey('contexto-olhar')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(ValueKey('olhar-$cubo')));
    await g.assentar(quadros: 8);
    expect(cena().camera.lookAtNodeId, cubo);
    await g.segurar(1.2);

    // 12. Voltar e tocar.
    g.cena('Toque em ← para voltar ao editor e dê o play: a cena 3D toca na timeline como qualquer camada.');
    await g.segurar(.6);
    await g.tocar(find.byKey(const ValueKey('estudio-voltar')));
    await g.assentar(quadros: 8);
    await g.tocar(find.byKey(const ValueKey('transport-play')));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 66));
      await g.quadro(dur: .066);
    }
    await g.tocar(find.byKey(const ValueKey('transport-play')));

    g.cena('Pronto. Exporte pelo botão de compartilhar, como qualquer projeto.');
    await g.segurar(2.5);

    await g.salvar();
    // Desmonta tudo antes de terminar: o aviso ao vivo e o relogio do
    // player tem timers proprios.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
