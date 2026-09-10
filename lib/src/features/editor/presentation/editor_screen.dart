import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/am_colors.dart';
import '../application/editor_controller.dart';
import '../application/playback_controller.dart';
import '../application/video_layer_manager.dart';
import '../../export/presentation/export_video_screen.dart';
import 'widgets/linha_do_tempo.dart';
import 'widgets/painel_da_camada.dart';
import 'widgets/palco_de_previa.dart';

/// A TELA DE EDICAO, no osso.
///
/// A UI de edicao anterior — timeline, paineis, folhas, menus, barras,
/// edicao no palco — foi apagada por inteiro para ser refeita. O que
/// sobrou aqui e o minimo que ainda merece o nome de editor: a
/// composicao desenhada, e um cabecote para andar no tempo.
///
/// O MOTOR NAO FOI TOCADO. O projeto, as camadas, os efeitos, a cena 3D,
/// o desfazer, a gravacao e a exportacao continuam inteiros em
/// `domain/` e `application/`. O que saiu foi so a casca. Construir a
/// interface nova e ligar controles novos ao mesmo `EditorController`
/// que ja esta aqui.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _playback;
  final VideoLayerManager _videos = VideoLayerManager();

  @override
  void initState() {
    super.initState();
    _playback = PlaybackController(
      vsync: this,
      durationOf: () => ref.read(editorControllerProvider).duration,
    );
    _playback.time.addListener(_syncVideos);
    _playback.playing.addListener(_syncVideos);
    // ABRIR UM PROJETO precisa montar os tocadores AGORA: o relogio esta
    // parado no zero e o sync so aconteceria quando ele andasse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncVideos();
    });
  }

  void _syncVideos() {
    final project = ref.read(editorControllerProvider);
    final master = _videos.sync(
      project.layers,
      _playback.time.value,
      _playback.playing.value,
      seekRevision: _playback.seekRevision,
    );
    if (master != null) _playback.anchorToMedia(master);
  }

  @override
  void dispose() {
    _playback.dispose();
    _videos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    return Scaffold(
      backgroundColor: AmColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Cabecalho(nome: project.name),
            // O PREVIEW FICA COM O QUE SOBRA, e nao com uma altura fixa.
            //
            // A ordem de prioridade e: cabecalho e controles com espaco
            // reservado, timeline com altura minima util, preview no
            // resto. Ao contrario, um preview de altura fixa espremeria
            // a timeline ate ela nao servir para nada num aparelho baixo
            // — e e a timeline que diz ONDE se esta editando.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: project.outputWidth / project.outputHeight,
                    child: DecoratedBox(
                      // OS LIMITES DA COMPOSICAO, visiveis.
                      //
                      // O quadro do projeto e o fundo do editor eram a
                      // mesma coisa preta: nao dava para saber onde um
                      // acabava e o outro comecava, nem conferir a
                      // proporcao. Este contorno e DECORACAO DA TELA —
                      // vive fora da arvore que a `CompositionView`
                      // desenha, entao nao vira camada e nao aparece na
                      // exportacao, que renderiza a composicao e nao
                      // esta tela.
                      decoration: BoxDecoration(
                        border: Border.all(color: AmColors.hairline),
                        color: const Color(0xFF000000),
                      ),
                      child: ClipRect(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: project.outputWidth.toDouble(),
                            height: project.outputHeight.toDouble(),
                            // A ESCALA E VISUAL, e so ela. O `FittedBox`
                            // encolhe o que ja foi desenhado no tamanho
                            // do projeto: coordenadas, resolucao e escala
                            // das camadas continuam as do projeto, e por
                            // isso um toque continua caindo no mesmo
                            // objeto depois de o preview mudar de
                            // tamanho.
                            child: CompositionView(
                              time: _playback.time,
                              videos: _videos,
                              selectedId: selecionada,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            LinhaDoTempo(
              playback: _playback,
              aoExportar: () {
                _playback.pause();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ExportVideoScreen(),
                  ),
                );
              },
            ),
            // O PAINEL ENTRA ABAIXO DA LINHA DO TEMPO. Abrir reduz o
            // espaco do preview, mas NAO muda proporcao, resolucao nem
            // coordenadas: a composicao apenas encolhe no que resta.
            PainelDaCamada(playback: _playback),
          ],
        ),
      ),
    );
  }
}

/// A FAIXA DE CIMA: sair, e saber em que projeto se esta.
///
/// Compacta de proposito, e sem comandos de edicao. O transporte ja tem
/// os dele; mover controles entre as duas barras so confundiria quem ja
/// aprendeu onde eles ficam.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.nome});

  final String nome;

  static const altura = 44.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: altura,
    child: Row(
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Voltar',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const SizedBox(
              width: 48,
              height: altura,
              child: Icon(
                Icons.arrow_back_rounded,
                size: 21,
                color: AmColors.text,
              ),
            ),
          ),
        ),
        Expanded(
          child: Text(
            nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AmColors.text,
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
  );
}
