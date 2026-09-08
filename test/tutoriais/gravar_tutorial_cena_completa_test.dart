// O GRAVADOR DO TUTORIAL "CENA 3D COMPLETA".
//
// O segundo tutorial: nao mais um cubo, e sim os MODELOS que vem com o
// app (o astronauta e a arvore do Monolito) numa cena montada do zero —
// importar, posicionar, luz e ambiente, animar por keyframe, uma segunda
// camera, o corte entre as duas no tempo e o "olhar para" que faz a
// camera seguir o personagem.
//
// Como o primeiro: e uma gravacao de tela feita pelo proprio app (os
// mesmos widgets, a mesma cena, o mesmo pintor), quadro a quadro. O
// importador de modelo abre o seletor de arquivos do sistema; aqui ele e
// trocado por um que devolve os assets do proprio app ja no disco — que
// e exatamente o que a pessoa escolheria.
//
// Rodar (so quando se quer regravar; a suite normal pula):
//   AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_cena_completa_test.dart
// Depois:  python test/tutoriais/montar_tutorial_cena3d.py cena-completa
import 'dart:io';

import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/core/theme/app_theme.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/estudio_preferencia.dart';
import 'package:aurea/src/features/editor/domain/camera3d.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/am/scene3d_studio.dart';
import 'package:aurea/src/features/editor/presentation/widgets/preview_stage.dart';
import 'package:aurea/src/features/editor/presentation/widgets/scene3d_painter.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:aurea/src/features/projects/presentation/home_shell.dart';
import 'package:aurea/src/features/projects/presentation/release_notice.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gravador.dart';

const _saida = 'build/tutorial/cena-completa';

/// O seletor de arquivos do sistema, trocado por um que ja sabe o que
/// vai ser escolhido: os arquivos do modelo, no disco.
class _SeletorFixo extends FilePicker {
  _SeletorFixo(this.caminhos);

  List<String> caminhos;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    for (final c in caminhos)
      PlatformFile(name: c.split('/').last, size: 0, path: c),
  ]);
}

/// Os modelos que vem no app viram arquivos de verdade, como os que a
/// pessoa escolheria na galeria dela.
Future<String> _modelosNoDisco(WidgetTester tester) async {
  final pasta = Directory.systemTemp.createTempSync('aurea_modelos');
  addTearDown(() => pasta.deleteSync(recursive: true));
  for (final nome in const [
    'astronauta.obj',
    'astronauta.mtl',
    'Astronaut_BaseColornew.jpeg',
    'arvore.obj',
    'arvore.mtl',
    'arvore.jpg',
  ]) {
    final dados = await rootBundle.load('assets/models/monolito/$nome');
    File('${pasta.path}/$nome').writeAsBytesSync(dados.buffer.asUint8List());
  }
  return pasta.path;
}

void main() {
  final gravar = Platform.environment['AUREA_GRAVAR_TUTORIAL'] == '1';

  testWidgets('grava o tutorial da cena 3D completa', (tester) async {
    if (!gravar) return;

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await carregarFontes();

    final modelos = await _modelosNoDisco(tester);
    final seletor = _SeletorFixo([
      '$modelos/astronauta.obj',
      '$modelos/astronauta.mtl',
      '$modelos/Astronaut_BaseColornew.jpeg',
    ]);
    // O seletor so tem um valor depois que alguem poe um: ler antes de
    // escrever estoura (LateInitializationError). Aqui ele nasce com o
    // nosso, e no fim volta a nao ter dono.
    FilePicker.platform = seletor;

    SharedPreferences.setMockInitialValues({
      releaseNoticeSeenKey: releaseNoticeRevision,
      EstudioPreferencia.kDicasVistas: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        projectsControllerProvider.overrideWith(ProjetosNaMemoria.new),
        projectRepositoryProvider.overrideWithValue(RepositorioNulo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: chaveDaGravacao,
          child: MaterialApp(
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            home: const HomeShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final g = Gravador(tester, saida: _saida);
    await g.preparar();
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

    // 1. Projeto de cinema.
    g.cena('Novo projeto, formato 16:9 — o de cinema.');
    await g.segurar(1.4);
    await g.tocar(find.byKey(const ValueKey('novo-projeto')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(const ValueKey('formato-16:9')));
    await g.assentar(quadros: 4);
    await g.tocar(find.byKey(const ValueKey('criar-projeto')));
    await g.assentar(quadros: 8);

    // 2. A cena 3D e o Estudio.
    g.cena('Aba Objeto → Cena 3D, e o menu da camada abre o Estúdio.');
    await g.segurar(1.0);
    if (find.byKey(const ValueKey('add-tab-objeto')).evaluate().isEmpty) {
      await g.tocar(find.byKey(const ValueKey('estado-vazio-cta')));
      await g.assentar(quadros: 5);
    }
    await g.tocar(find.byKey(const ValueKey('add-tab-objeto')));
    await g.assentar(quadros: 6);
    await g.tocar(find.text('Cena 3D'));
    await g.assentar(quadros: 8);
    if (container.read(selectedLayerProvider) == null) {
      await g.tocar(find.byType(PreviewStage));
      await g.assentar(quadros: 4);
    }
    await g.tocar(find.text('Cena 3D'));
    await g.assentar(quadros: 8);
    expect(find.byType(Scene3DStudio), findsOneWidget);

    // 3. O primeiro modelo.
    g.cena('Em + → Objeto 3D está o importador: GLB, glTF, OBJ ou FBX. Escolha o modelo e, junto, o .mtl e a textura.');
    await g.segurar(1.4);
    await g.tocar(find.byKey(const ValueKey('estudio-adicionar')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-objeto')));
    await g.assentar(quadros: 6);
    await g.rolarAte(find.textContaining('Importar GLB'));
    await g.tocar(find.textContaining('Importar GLB'));
    // Ler o OBJ e trabalho de verdade: alguns quadros ate ele aparecer.
    await g.assentar(quadros: 14, ms: 140);
    await g.segurar(1.0);
    expect(
      cena().scene.nodes.length,
      1,
      reason: 'o astronauta entrou na cena',
    );
    final astronauta = cena().scene.nodes.single.id;

    g.cena('O modelo entra com a textura dele. Focar enquadra o que está selecionado.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('estudio-focar')));
    await g.assentar(quadros: 8);
    await g.segurar(1.4);

    // 4. O segundo modelo, deslocado.
    g.cena('Agora a árvore, pelo mesmo caminho: uma cena tem quantos modelos você quiser.');
    await g.segurar(1.0);
    seletor.caminhos = [
      '$modelos/arvore.obj',
      '$modelos/arvore.mtl',
      '$modelos/arvore.jpg',
    ];
    await g.tocar(find.byKey(const ValueKey('estudio-adicionar')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-objeto')));
    await g.assentar(quadros: 6);
    await g.rolarAte(find.textContaining('Importar GLB'));
    await g.tocar(find.textContaining('Importar GLB'));
    await g.assentar(quadros: 16, ms: 140);
    expect(cena().scene.nodes.length, 2, reason: 'a arvore entrou');
    await g.segurar(1.0);

    g.cena('Com Mover, o X afasta a árvore do personagem — o valor entra digitado, sem depender da mira.');
    await g.segurar(.8);
    await g.tocar(find.text('Mover'));
    await g.assentar(quadros: 3);
    await g.valorDoEixo(0, '260');
    await g.segurar(1.0);

    // 5. Luz.
    g.cena('Uma luz de ponto: + → Luz. A barra de baixo passa a ser a da luz — intensidade e sombras.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('estudio-adicionar')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-luz')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('adicionar-luz-point')));
    await g.assentar(quadros: 8);
    expect(cena().scene.lights, isNotEmpty);
    await g.segurar(1.2);

    // 6. Animar o astronauta.
    g.cena('Animar: selecione o astronauta na lista da cena (menu ⋮ → Cena).');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('estudio-mais')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('mais-cena')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(ValueKey('cena-item-$astronauta')));
    await g.assentar(quadros: 6);
    if (find.byKey(const ValueKey('estudio-focar')).evaluate().isEmpty) {
      await g.fecharFolha();
    }
    await g.segurar(.8);

    g.cena('Com Auto-key ligado, o tempo em 3 s e o giro Y em 180: o keyframe nasce sozinho, e o início fica guardado.');
    await g.segurar(1.0);
    await g.tempoDoEstudio(0, 3);
    await g.tocar(find.text('Girar'));
    await g.assentar(quadros: 3);
    await g.valorDoEixo(1, '180');
    expect(
      cena().scene.nodeById(astronauta)!.rotY.valueAt(const Duration(seconds: 3)),
      180,
    );
    expect(
      cena().scene.nodeById(astronauta)!.rotY.valueAt(Duration.zero),
      0,
      reason: 'o Auto-key guardou a pose do inicio',
    );
    await g.segurar(1.0);

    g.cena('Arraste o tempo: o personagem gira entre os dois keyframes.');
    await g.tempoDoEstudio(3, 0, passos: 10);
    await g.tempoDoEstudio(0, 3, passos: 10);
    await g.segurar(.8);

    // 7. A segunda camera.
    g.cena('Câmera → Nova câmera. Ela nasce olhando para onde a vista está agora.');
    await g.segurar(.8);
    final principal = cena().camera.id;
    await g.tocar(find.byKey(const ValueKey('estudio-camera')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(const ValueKey('camera-nova')));
    await g.assentar(quadros: 8);
    expect(cena().allCameras.length, 2);
    final segunda = cena().extraCameras.single.id;
    await g.segurar(1.0);

    g.cena('Arraste no palco para escolher o enquadramento dela.');
    await g.segurar(.6);
    await g.arrastar(viewport, const Offset(70, -30), passos: 8);
    await g.segurar(.8);

    g.cena('A barra de baixo é sempre a do que está selecionado. Escolha a câmera na lista da cena para ver a barra dela.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('estudio-mais')));
    await g.assentar(quadros: 5);
    await g.tocar(find.byKey(const ValueKey('mais-cena')));
    await g.assentar(quadros: 6);
    await g.rolarAte(find.byKey(ValueKey('cena-item-$segunda')));
    await g.tocar(find.byKey(ValueKey('cena-item-$segunda')));
    await g.assentar(quadros: 6);
    if (find.byKey(const ValueKey('contexto-olhar')).evaluate().isEmpty) {
      await g.fecharFolha();
    }
    await g.segurar(1.0);

    g.cena('Olhar para → o astronauta: a câmera passa a seguir o personagem, mesmo que ele se mexa.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('contexto-olhar')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(ValueKey('olhar-$astronauta')));
    await g.assentar(quadros: 8);
    expect(
      cena().allCameras.firstWhere((c) => c.id == segunda).lookAtNodeId,
      astronauta,
      reason: 'a camera no ar passou a seguir o personagem',
    );
    await g.segurar(1.2);

    // 8. Os cortes.
    g.cena('Trocar de câmera é um corte no instante em que você toca: em 1,5 s, a primeira câmera.');
    await g.segurar(1.0);
    await g.tempoDoEstudio(3, 1.5, passos: 6);
    await g.tocar(find.byKey(ValueKey('faixa-camera-$principal')));
    await g.assentar(quadros: 8);
    await g.segurar(1.0);

    g.cena('Em 3 s, de volta para a segunda: dois cortes, uma cena que respira.');
    await g.segurar(.8);
    await g.tempoDoEstudio(1.5, 3, passos: 6);
    await g.tocar(find.byKey(ValueKey('faixa-camera-$segunda')));
    await g.assentar(quadros: 8);
    expect(
      cena().shots.length,
      greaterThanOrEqualTo(2),
      reason: 'os cortes ficaram gravados no tempo',
    );
    await g.segurar(1.2);

    g.cena('Arraste o tempo do começo ao fim: o corte acontece sozinho, na hora marcada.');
    await g.tempoDoEstudio(3, 0, passos: 12);
    await g.tempoDoEstudio(0, 4, passos: 14);
    await g.segurar(1.0);

    // 9. Voltar e tocar.
    g.cena('← volta para o editor. A cena 3D é uma camada como as outras: dê o play.');
    await g.segurar(.8);
    await g.tocar(find.byKey(const ValueKey('estudio-voltar')));
    await g.assentar(quadros: 8);
    await g.tocar(find.byKey(const ValueKey('transport-play')));
    for (var i = 0; i < 36; i++) {
      await tester.pump(const Duration(milliseconds: 66));
      await g.quadro(dur: .066);
    }
    await g.tocar(find.byKey(const ValueKey('transport-play')));

    g.cena('Daqui em diante é edição normal: texto, música, efeitos — e exportar.');
    await g.segurar(2.5);

    await g.salvar();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
