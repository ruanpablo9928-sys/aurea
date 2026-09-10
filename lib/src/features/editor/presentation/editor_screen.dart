import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/am_colors.dart';
import '../application/editor_controller.dart';
import '../application/playback_controller.dart';
import '../application/video_layer_manager.dart';
import '../domain/video_project.dart';
import '../../export/presentation/export_video_screen.dart';
import '../../projects/application/projects_controller.dart';
import 'widgets/linha_do_tempo.dart';
import 'widgets/adicionar_conteudo.dart';
import 'widgets/editor_de_curva.dart';
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

  /// ESCREVE O QUE ESTA PENDENTE ANTES DE IR PARA O FUNDO.
  ///
  /// A gravacao e adiada em 900 ms de proposito — arrastar um numero
  /// manda dezenas de mutacoes por segundo, e gravar cada uma seria
  /// reescrever o projeto inteiro dezenas de vezes por segundo. Mas o
  /// sistema mata um app em segundo plano sem avisar, e esses 900 ms
  /// seriam exatamente os ultimos ajustes de quem saiu do app logo
  /// depois de mexer em alguma coisa. Ir para o fundo fecha a conta.
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onPause: _gravarAgora,
      onDetach: _gravarAgora,
    );
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
    // O OLHO VALE PARA O SOM TAMBEM. Ver `VideoLayerManager.soaAgora`.
    _videos.soaAgora = project.rendersInPreview;
    final master = _videos.sync(
      project.layers,
      _playback.time.value,
      _playback.playing.value,
      seekRevision: _playback.seekRevision,
    );
    if (master != null) _playback.anchorToMedia(master);
  }

  void _gravarAgora() {
    if (!mounted) return;
    ref.read(projectsControllerProvider.notifier).flush();
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _playback.dispose();
    _videos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // O EDITOR NAO ESTAVA GRAVANDO NADA.
    //
    // A ponte que levava cada mutacao para a lista de projetos — e dali,
    // com atraso, para o disco — morava na tela de edicao ANTIGA, e foi
    // apagada junto com ela. A tela nova nunca a refez: dava para
    // montar uma composicao inteira, sair do app e voltar para o
    // projeto exatamente como estava antes de comecar.
    //
    // Nao havia aviso, nem botao de salvar que tivesse sido esquecido:
    // este app nunca teve um, porque sempre salvou sozinho. O trabalho
    // simplesmente nao voltava.
    //
    // `projetoCompleto` e nao `state`: dentro de um grupo o estado E o
    // grupo, e gravar isso trocaria o projeto pelos filhos dele.
    ref.listen(editorControllerProvider, (antes, agora) {
      ref
          .read(projectsControllerProvider.notifier)
          .upsert(ref.read(editorControllerProvider.notifier).projetoCompleto);
    });
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final controlador = ref.read(editorControllerProvider.notifier);
    return PopScope(
      // O BOTAO DE VOLTAR DO SISTEMA TAMBEM SAI DO GRUPO PRIMEIRO.
      //
      // Sem isto, o gesto de voltar do Android fecharia o editor com um
      // grupo aberto — e as edicoes feitas la dentro so voltam para o
      // grupo em `exitGroup`. Seria perder o trabalho por um gesto que
      // todo mundo faz sem pensar.
      canPop: !controlador.dentroDeGrupo,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) controlador.exitGroup();
      },
      child: _corpo(project, selecionada),
    );
  }

  Widget _corpo(VideoProject project, String? selecionada) {
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
            // A PREVIA NAO ENCOLHE QUANDO UMA FERRAMENTA ABRE.
            //
            // Ela encolhia, e estava errado: no Alight a composicao fica
            // do MESMO tamanho com a aba de transformacao, de efeito ou
            // de curva aberta. Faz sentido — a previa e o que se olha
            // enquanto o dedo mexe no controle; muda-la de tamanho no
            // exato momento em que a atencao vai para ela e o pior
            // momento possivel.
            //
            // A conta que garante isso: a previa e limitada pelo espaco
            // que sobraria COM A FERRAMENTA ABERTA, sempre — aberta ou
            // nao. Assim ela ja nasce no tamanho em que vai ficar, e
            // abrir a ferramenta nao mexe num pixel dela.
            //
            // Quem cede e a LINHA DO TEMPO, que encolhe ate o chao dela
            // (transporte, regua e uma trilha) e volta a crescer quando
            // a ferramenta fecha. E o que a referencia faz: com uma aba
            // aberta, la aparece uma trilha so.
            final ferramenta = alturaDaFerramentaAberta(ref);
            final disponivel = util - _Cabecalho.altura;

            // O CHAO DA LINHA DO TEMPO COM FERRAMENTA ABERTA: transporte,
            // regua e uma trilha. Menos que isso e nao dava mais para ver
            // onde o cabecote esta enquanto se edita.
            final chaoComFerramenta =
                LinhaDoTempo.alturaDoTransporte +
                LinhaDoTempo.alturaDaRegua +
                VisaoGeralDasCamadas.alturaDaTrilha;

            final pedidaPelaComposicao = (limites.maxWidth - 24) / proporcao;
            // O TETO NAO DEPENDE DE A FERRAMENTA ESTAR ABERTA. E o que
            // faz a previa ficar parada.
            final tetoDoPreview =
                disponivel - PainelDaCamada.alturaMaxima - chaoComFerramenta;
            var preview = pedidaPelaComposicao < tetoDoPreview
                ? pedidaPelaComposicao
                : tetoDoPreview;
            if (preview < 140) preview = 140;

            var tempo = disponivel - preview - ferramenta;

            // O QUE A LINHA DO TEMPO PEDE vem depois: com a ferramenta
            // fechada ela usa o que sobrou; com a ferramenta aberta ela
            // desce ate o chao e nao abaixo.
            final pedidaPelaTimeline = LinhaDoTempo.alturaDoModo(
              ref.watch(modoDaLinhaDoTempoProvider),
              project.layers.length,
            );
            final chao = ferramenta > 0 ? chaoComFerramenta : pedidaPelaTimeline;
            if (tempo < chao) {
              tempo = chao;
              preview = disponivel - tempo - ferramenta;
              if (preview < 140) preview = 140;
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
                    // O ESPACO DA FERRAMENTA, ja descontado do preview
                    // acima. Reservado no arranjo para a linha do tempo
                    // ficar inteira e visivel por cima dela.
                    SizedBox(height: ferramenta),
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

/// A FAIXA DE CIMA, em dois estados.
///
/// EM REPOUSO: voltar, nome do projeto, trocar de vista, exportar. O
/// botao de exportar mudou de lugar uma vez e ficou: ele morava no
/// transporte, entre controles de tempo, e nao e um controle de tempo —
/// e a saida do trabalho. Na referencia ele e a unica coisa colorida do
/// cabecalho, na ponta oposta ao voltar. Aqui usa o lima da Aurea, e nao
/// o verde de la: a estrutura se copia, a identidade nao.
///
/// COM FERRAMENTA ABERTA: a barra e TOMADA pela ferramenta — `‹` e o
/// nome dela, centrado, e mais nada. E o que a referencia faz, e o
/// motivo aparece na conta de espaco: o painel tem 260 px para caber
/// campos, superficie de arrasto e dois rails; gastar 44 deles repetindo
/// "voce esta em Opacidade" seria tirar do que se usa para dizer onde se
/// esta. O cabecalho ja e o lugar onde o olho procura isso.
class _Cabecalho extends ConsumerWidget {
  const _Cabecalho({required this.nome, required this.aoExportar});

  final String nome;
  final VoidCallback aoExportar;

  static const altura = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A CURVA TOMA A BARRA IGUAL AS OUTRAS FERRAMENTAS, e antes delas:
    // ela abre POR DENTRO de uma, e quem esta na frente e quem nomeia.
    if (ref.watch(curvaEmEdicaoProvider) != null) {
      return const _CabecalhoDaFerramenta(titulo: 'Curva de gradacao');
    }
    final aberta = ref.watch(estadoDoPainelProvider) == EstadoDoPainel.categoria
        ? ref.watch(categoriaAbertaProvider)
        : null;
    if (aberta != null) {
      return _CabecalhoDaFerramenta(titulo: tituloDaFerramenta(aberta));
    }
    // DENTRO DE UM GRUPO, "VOLTAR" QUER DIZER SAIR DO GRUPO.
    //
    // Entrar num grupo troca a cena inteira pelos filhos dele. Se a
    // unica seta da barra continuasse fechando o editor, entrar seria
    // uma armadilha: quem entrasse sairia do projeto e as edicoes
    // feitas la dentro nunca seriam gravadas de volta no grupo — e
    // `exitGroup` e justamente quem faz essa gravacao.
    ref.watch(editorControllerProvider);
    final c = ref.read(editorControllerProvider.notifier);
    final dentro = c.dentroDeGrupo;
    return SizedBox(
      height: altura,
      child: Row(
        children: [
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: dentro ? 'Sair do grupo' : 'Voltar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => dentro
                  ? c.exitGroup()
                  : Navigator.of(context).maybePop(),
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
}

/// A BARRA TOMADA PELA FERRAMENTA: so o `‹` e o nome, centrado.
class _CabecalhoDaFerramenta extends ConsumerWidget {
  const _CabecalhoDaFerramenta({required this.titulo});

  final String titulo;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: _Cabecalho.altura,
    child: Row(
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Fechar a ferramenta',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => fecharFerramenta(ref),
            child: const SizedBox(
              width: 48,
              height: _Cabecalho.altura,
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
            titulo,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AmColors.text,
            ),
          ),
        ),
        // O MESMO ESPACO DA ESQUERDA, para o titulo cair no meio de
        // verdade. Centrar sem isto joga o texto para a direita.
        const SizedBox(width: 48),
      ],
    ),
  );
}
