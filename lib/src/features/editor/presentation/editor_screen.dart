import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/am_colors.dart';
import '../application/editor_controller.dart';
import '../application/playback_controller.dart';
import '../application/video_layer_manager.dart';
import '../../export/presentation/export_video_screen.dart';
import 'widgets/linha_do_tempo.dart';
import 'widgets/adicionar_conteudo.dart';
import 'widgets/painel_da_camada.dart';
import 'widgets/palco_de_previa.dart';
import 'widgets/visao_geral_das_camadas.dart';

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
        child: LayoutBuilder(
          builder: (context, limites) {
            // A DIVISAO VERTICAL: A COMPOSICAO PEDE, A LINHA DO
            // TEMPO FICA COM TODO O RESTO.
            //
            // A conta responde as DUAS resolucoes ao mesmo tempo, que e
            // o que faz esta tela servir em qualquer aparelho:
            //
            //   - a do APARELHO entra como `limites`, a area que sobrou
            //     depois da barra de status e da de navegacao;
            //   - a do PROJETO entra como `proporcao`, que decide quanta
            //     ALTURA a composicao precisa para caber na largura
            //     disponivel.
            //
            // Um 9:16 num celular alto pede quase tudo e a linha do
            // tempo fica no chao dela; um 16:9 no mesmo celular pede um
            // terco, e os outros dois tercos viram area de trabalho.
            //
            // Tres contas erradas ja passaram por aqui, e cada uma
            // deixou um buraco:
            //
            //   - fatia FIXA para o preview: um 16:9 numa largura de 366
            //     px so precisa de 206, e reservar 40% da altura deixava
            //     quase trezentos pixels mortos sob a composicao;
            //   - teto de 50%: num projeto em pe ele cortava o preview
            //     em 369 px havendo 468 livres, e os 99 cortados iam
            //     morrer embaixo das trilhas;
            //   - dar o excedente ao preview: ele so cresce com tarja
            //     preta em volta da composicao.
            //
            // Entao: a composicao pede o que precisa, a linha do tempo
            // pede o chao dela, e o excedente e sempre da linha do
            // tempo — que sabe usa-lo, porque mais espaco e mais camada
            // a vista sem rolar.
            final util = limites.maxHeight;
            final proporcao = project.outputWidth / project.outputHeight;
            final disponivel = util - _Cabecalho.altura;

            final pedidaPelaComposicao = (limites.maxWidth - 24) / proporcao;
            var preview = pedidaPelaComposicao;
            var tempo = disponivel - preview;

            // O QUE A LINHA DO TEMPO PEDE vem antes do conforto do
            // preview. O pedido depende do modo e de quantas camadas ha:
            // sem transporte, regua e as trilhas que existem, ela deixa
            // de ser ferramenta e vira enfeite.
            final pedidaPelaTimeline = LinhaDoTempo.alturaDoModo(
              ref.watch(modoDaLinhaDoTempoProvider),
              project.layers.length,
            );
            if (tempo < pedidaPelaTimeline) {
              tempo = pedidaPelaTimeline;
              preview = disponivel - tempo;
            }
            // E o chao do preview vem antes de tudo: sem ele nao da para
            // ver o que se esta editando.
            if (preview < 140) {
              preview = 140;
              tempo = disponivel - preview;
            }

            return Stack(
              children: [
                Column(
                  children: [
                    _Cabecalho(
                      nome: project.name,
                      aoExportar: () {
                        _playback.pause();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ExportVideoScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      height: preview,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: proporcao,
                            child: DecoratedBox(
                              // OS LIMITES DA COMPOSICAO, visiveis. O
                              // quadro do projeto e o fundo do editor
                              // eram a mesma coisa preta. Este contorno e
                              // DECORACAO DA TELA: vive fora da arvore
                              // que a `CompositionView` desenha, entao
                              // nao vira camada e nao entra na
                              // exportacao.
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
                                    // A ESCALA E VISUAL, e so ela. As
                                    // coordenadas, a resolucao e a escala
                                    // das camadas continuam as do
                                    // projeto — e por isso um toque
                                    // continua caindo no mesmo objeto
                                    // depois de o preview mudar de
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
                    // TRANSPORTE, REGUA E TRILHAS SAO UM BLOCO SO. Eles
                    // encostam de proposito: sao a mesma ferramenta.
                    LinhaDoTempo(playback: _playback, altura: tempo),
                  ],
                ),
                // AS FERRAMENTAS DA CAMADA, sobrepostas ao rodape.
                //
                // A faixa fixa "Ferramentas da camada" foi REMOVIDA: ela
                // reservava 52 px de altura o tempo inteiro para
                // oferecer um caminho que o toque na propria camada ja
                // oferece. Esses 52 px sao da linha do tempo agora.
                PainelSobreposto(playback: _playback),
                // O PAINEL DO MEIO, com a tela desfocada atras. Fica por
                // cima de tudo porque enquanto ele esta aberto nao ha o
                // que fazer atras dele.
                PainelCentralDeAdicao(
                  instanteDeInsercao: ref.watch(instanteDeInsercaoProvider),
                  aoAdicionar: (_, _) {
                    fecharAdicao(ref);
                    ref.read(barraDeAdicaoAbertaProvider.notifier).state =
                        false;
                    // A camada nova ja nasce selecionada — o motor faz
                    // isso. Abrir as ferramentas dela na sequencia e o
                    // passo que a pessoa ia dar de qualquer jeito.
                    abrirFerramentasDaCamada(ref);
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A FAIXA DE CIMA: sair, saber em que projeto se esta, e EXPORTAR.
///
/// O botao de exportar mudou de lugar. Ele morava no transporte, entre
/// controles de tempo, e nao e um controle de tempo: e a saida do
/// trabalho. Na referencia ele e a unica coisa colorida do cabecalho, na
/// ponta oposta ao voltar — o comeco e o fim do caminho, um em cada
/// lado. Aqui ele usa o lima da Aurea, e nao o verde de la: a estrutura
/// se copia, a identidade nao.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.nome, required this.aoExportar});

  final String nome;
  final VoidCallback aoExportar;

  static const altura = 52.0;

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
                Icons.arrow_back_ios_new_rounded,
                size: 19,
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
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AmColors.text,
            ),
          ),
        ),
        // O ALTERNADOR DE VISTA ocupa o lugar que a referencia da a
        // engrenagem: ultimo antes do botao colorido.
        const AlternadorDeVista(altura: altura),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Exportar',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoExportar,
            child: Container(
              width: 38,
              height: 34,
              margin: const EdgeInsets.only(left: 8, right: 10),
              decoration: BoxDecoration(
                color: AmColors.action,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.ios_share_rounded,
                size: 19,
                color: AmColors.onAction,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
