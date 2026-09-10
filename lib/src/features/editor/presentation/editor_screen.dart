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
            // A DIVISAO VERTICAL, e a razao de cada conta.
            //
            // A composicao PEDE a altura que a proporcao dela exige na
            // largura disponivel — e nao uma fatia fixa da tela. Foi essa
            // a origem do vazio: reservar 40% da altura para um 16:9 que
            // so precisa de 206 px deixa quase trezentos pixels mortos
            // entre o cabecalho e a barra de transporte.
            //
            // O QUE SOBRA VAI PARA A LINHA DO TEMPO. Ela e area de
            // trabalho, e nao rodape: num projeto deitado ela fica
            // grande; num vertical, o preview e que ocupa a tela e ela
            // recua ate o chao dela, nunca abaixo.
            // A DIVISAO VERTICAL: CADA UM PEDE O QUE PRECISA, e o
            // que sobra vai para o preview.
            //
            // Duas contas erradas ja foram tentadas aqui, e as duas
            // deixaram buraco na tela:
            //
            //   - fatia FIXA para o preview: um 16:9 numa largura de 366
            //     px so precisa de 206, e reservar 40% da altura deixava
            //     quase trezentos pixels mortos sob a composicao;
            //   - dar TODO o resto para a linha do tempo: com quatro
            //     trilhas ela pedia 190 e recebia 600, e o vazio so
            //     mudava de lugar.
            //
            // Entao os dois pedem: a composicao pede a altura que a
            // proporcao dela exige, a linha do tempo pede o que as
            // trilhas ocupam. O excedente e do preview, ate um teto —
            // ele e quem sabe crescer sem inventar conteudo.
            final util = limites.maxHeight;
            final proporcao = project.outputWidth / project.outputHeight;

            final painel = alturaDoPainel(ref);
            final disponivel = util - _Cabecalho.altura - painel;

            final pedidaPelaTimeline = LinhaDoTempo.alturaDoModo(
              ref.watch(modoDaLinhaDoTempoProvider),
              project.layers.length,
            );

            // A LINHA DO TEMPO PEDE O QUE AS TRILHAS OCUPAM. O que
            // sobra e do preview.
            //
            // Ja tentei o contrario — esticar as trilhas para preencher
            // — e foi pior: com poucas camadas elas viravam blocos
            // enormes, e o tamanho de uma trilha passava a depender de
            // quantas existem. Trilha tem altura fixa; o espaco livre
            // embaixo dela e onde as proximas camadas entram.
            var tempo = pedidaPelaTimeline;
            var preview = disponivel - tempo;

            // O PREVIEW NAO PASSA DO QUE A COMPOSICAO PRECISA.
            //
            // Antes havia um teto de 50% da altura, e ele estava
            // errado nos dois sentidos:
            //
            //   - num projeto EM PE ele cortava o preview em 369 px
            //     quando havia 468 livres, e os 97 px cortados iam
            //     morrer embaixo das trilhas, onde nao ha o que
            //     desenhar;
            //   - num projeto DEITADO ele deixava passar mais altura do
            //     que a composicao ocupa, e sobrava tarja preta.
            //
            // A conta certa nao e uma fracao: e quanto a composicao
            // ocupa nesta largura. Acima disso o preview so cresceria
            // vazio.
            final pedidaPelaComposicao = (limites.maxWidth - 24) / proporcao;
            if (preview > pedidaPelaComposicao) {
              preview = pedidaPelaComposicao;
              tempo = disponivel - preview;
            }
            if (preview < 140) {
              preview = 140;
              tempo = disponivel - preview;
            }
            if (tempo < LinhaDoTempo.alturaMinima) {
              tempo = LinhaDoTempo.alturaMinima;
              preview = disponivel - tempo;
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
                    // O ESPACO DO PAINEL, ja descontado do preview acima.
                    SizedBox(height: painel),
                  ],
                ),
                // A FAIXA no rodape, e o painel POR CIMA dela quando
                // aberto. A linha do tempo fica sempre inteira e visivel
                // — nada do painel passa por cima dela.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FaixaDoPainel(playback: _playback),
                ),
                PainelSobreposto(playback: _playback),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A ALTURA QUE O PAINEL OCUPA AGORA, para a tela descontar do preview.
///
/// Fica fora da tela de proposito: o teste monta as mesmas pecas e
/// precisa da mesma conta, senao testa um arranjo que nao existe.
double alturaDoPainel(WidgetRef ref) {
  if (!ref.watch(painelDaCamadaLigadoProvider)) return 0;
  final estado = ref.watch(estadoDoPainelProvider);
  if (estado == EstadoDoPainel.recolhido) return FaixaDoPainel.altura;

  final project = ref.watch(editorControllerProvider);
  final id = ref.watch(selectedLayerProvider);
  final camada = project.layers.where((l) => l.id == id).firstOrNull;
  if (camada == null && estado != EstadoDoPainel.adicionar) {
    return FaixaDoPainel.altura;
  }
  if (estado == EstadoDoPainel.categoria) return PainelDaCamada.alturaMaxima;
  final itens = estado == EstadoDoPainel.adicionar
      ? tiposDeConteudo.length
      : categoriasDaCamada(camada!).length;
  return PainelDaCamada.alturaAberta(itens);
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
