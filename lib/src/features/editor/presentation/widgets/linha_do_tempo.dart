import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import '../../domain/video_project.dart';
import 'adicionar_conteudo.dart';
import 'mapa_do_tempo.dart';
import 'painel_da_camada.dart';
import 'pilula_de_navegacao.dart';
import 'visao_geral_das_camadas.dart';

/// A COR DIZ O TIPO DA CAMADA.
///
/// Sem miniatura: a maior parte das camadas do Aurea (texto, forma, cena
/// 3D) nao tem quadro para miniaturar, e gerar miniatura de video custa
/// caro no aparelho. A cor responde a mesma pergunta — "o que e isto?" —
/// por quase nada, e vale nos DOIS modos: uma camada nao pode trocar de
/// cor so por mudar de vista.
Color corDaCamada(Layer camada) => switch (camada) {
  TextLayer() => AmColors.selection,
  Scene3DLayer() => AmColors.accent,
  ShapeLayer() => AmColors.tealBright,
  _ => AmColors.teal,
};

/// A FONTE DO APP, para quem pinta texto no canvas.
///
/// `TextPainter` nao herda nada: sem isto ele cai na fonte padrao da
/// plataforma enquanto o resto da tela usa a do tema. Enquanto as duas
/// coincidem ninguem nota — no dia em que a Aurea adotar uma fonte
/// propria, nome de camada e relogio seriam os unicos textos fora dela.
TextStyle familiaDoApp(BuildContext context) {
  final base = DefaultTextStyle.of(context).style;
  return TextStyle(
    fontFamily: base.fontFamily,
    fontFamilyFallback: base.fontFamilyFallback,
  );
}

/// A COR DO QUE VAI EM CIMA DE UM CLIPE.
///
/// Preto fixo funcionava enquanto todas as barras eram claras. Quem
/// decide e a luminancia da propria cor, e nao uma tabela por tipo: uma
/// cor nova nao pode nascer ilegivel.
Color sobreACorDaCamada(Color cor) => cor.computeLuminance() > .45
    ? const Color(0xFF0B0E12)
    : const Color(0xFFFFFFFF);

/// A LINHA DO TEMPO.
///
/// A estrutura e as medidas saem de uma gravacao do Alight Motion em uso,
/// medida quadro a quadro (`docs/linha-do-tempo-alight.md`). Tres blocos
/// colados, sem respiro entre eles porque sao a mesma ferramenta:
///
///   TRANSPORTE  48 px .. desfazer, refazer, inicio, play, fim, duplicar
///   REGUA       44 px .. barra de rolagem, marcas de tempo, capsula
///   TRILHAS     o resto
///
/// O CABECOTE NAO ANDA: ele fica preso no meio da largura e o conteudo
/// desliza por baixo. Ver [MapaDoTempo] para o porque — em resumo, e o
/// que permite ter escala constante e zoom, e sem isso um projeto longo
/// vira uma fileira de riscos de quatro pixels.
class LinhaDoTempo extends ConsumerWidget {
  const LinhaDoTempo({super.key, required this.playback, this.altura});

  final PlaybackController playback;

  /// A altura que a tela reservou. Nula = o chao.
  final double? altura;

  /// O TRANSPORTE E MAIS ALTO QUE O DA REFERENCIA, e de proposito.
  ///
  /// La ele mede 32 px. Aqui mede 48, que e o piso de alvo tocavel — e
  /// ha um teste que cobra isso. Copiar 32 economizaria dezesseis
  /// pixels numa tela de setecentos e cobraria o preco em toques
  /// errados no controle que a mao mais repete.
  static const alturaDoTransporte = 48.0;

  /// A REGUA, medida na referencia: 44 px. Dentro dela, de cima para
  /// baixo — barra de rolagem (4), marcas (24), capsula do tempo (16,
  /// sobreposta as marcas).
  static const alturaDaRegua = 44.0;

  /// O CHAO DA LINHA DO TEMPO.
  ///
  /// Abaixo disto ela deixa de ser util: a trilha fica fina demais para
  /// o dedo pegar keyframe e a regua perde a escala. Nenhum calculo de
  /// layout pode passar por baixo deste numero.
  static const alturaMinima = alturaDoTransporte + alturaDaRegua + 96;

  /// A altura que a linha do tempo pede, conforme o modo e quantas
  /// camadas ha para mostrar. O chao vale para os dois modos: sem isso a
  /// pilha com poucas camadas ficava MENOR que a trilha unica, e trocar
  /// de vista encolhia a area de trabalho.
  static double alturaDoModo(ModoDaLinhaDoTempo modo, int camadas) {
    if (modo == ModoDaLinhaDoTempo.detalhado) return alturaMinima;
    final pedida =
        alturaDoTransporte +
        alturaDaRegua +
        VisaoGeralDasCamadas.alturaPara(camadas);
    return pedida < alturaMinima ? alturaMinima : pedida;
  }

  /// A LARGURA DA PILULA da camada — o olho e a cor.
  ///
  /// Ela FLUTUA sobre a trilha em vez de ocupar uma coluna propria. Foi
  /// assim que a referencia resolveu, e o motivo aparece na conta: numa
  /// tela de 360 px, uma coluna fixa de 64 come 18% da area onde o
  /// tempo e desenhado, para sempre, em todas as camadas. Flutuando, ela
  /// so tapa o comeco da faixa — e o comeco da faixa e passado, que e a
  /// parte que menos se edita.
  static const larguraDaPilula = 62.0;

  /// A escala vigente para esta largura: a escolhida, ou a que faz a
  /// composicao caber.
  static double zoomPara(double? escolhido, double largura, Duration duracao) =>
      escolhido ?? MapaDoTempo.zoomQueCabe(largura, duracao);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final modo = ref.watch(modoDaLinhaDoTempoProvider);
    final camadas = project.layers;
    final atual = camadas.where((l) => l.id == selecionada).firstOrNull;
    // QUEM MANDA NA ALTURA E A TELA.
    //
    // Aqui era `max(altura, pedida)`, e isso estourava o Column da tela
    // por 84 px assim que o projeto passava de quatro camadas: a tela
    // dividia o espaco por uma conta e a linha do tempo devolvia outra.
    // Duas contas para a mesma altura sempre acabam discordando. A tela
    // ja garante o chao; se o que ela mandar for menos que as trilhas
    // ocupam, a pilha rola.
    final a = altura ?? alturaDoModo(modo, camadas.length);
    return SizedBox(
      height: a,
      child: ColoredBox(
        color: AmColors.panel,
        child: LayoutBuilder(
          builder: (context, limites) {
            final largura = limites.maxWidth;
            final zoom = zoomPara(
              ref.watch(zoomDaLinhaDoTempoProvider),
              largura,
              project.duration,
            );
            MapaDoTempo mapa(Duration t) => MapaDoTempo(
              largura: largura,
              pxPorSegundo: zoom,
              tempo: t,
            );

            return Stack(
              children: [
                Column(
                  children: [
                    _Transporte(
                      playback: playback,
                      duracao: project.duration,
                      camadaSelecionada: selecionada,
                      // ENQUADRAR MEXE NO ZOOM **E** NO CABECOTE.
                      //
                      // So o zoom nao enquadra nada: com o cabecote
                      // preso no meio, a composicao inteira so cabe na
                      // tela quando ele esta no MEIO DELA. Estando no
                      // zero, metade da regua vira tempo negativo e a
                      // segunda metade do projeto fica de fora — o botao
                      // dizia "enquadrar" e mostrava metade.
                      aoEnquadrar: () {
                        ref.read(zoomDaLinhaDoTempoProvider.notifier).state =
                            MapaDoTempo.zoomQueCabe(largura, project.duration);
                        playback.pause();
                        playback.seek(project.duration * .5);
                      },
                    ),
                    // A REGUA E UMA SO, e serve os dois modos.
                    //
                    // Ela ficava duplicada — uma no detalhado, outra na
                    // pilha — e as duas desenhavam marcas diferentes com
                    // codigo diferente. Uma so significa que trocar de
                    // vista nao mexe na escala nem na posicao do
                    // cabecote: o que muda e o que esta EMBAIXO dela.
                    _Regua(
                      playback: playback,
                      duracao: project.duration,
                      fps: project.fps,
                      mapa: mapa,
                      marcadores: project.markers,
                      batidas: project.beats,
                      aoAlternarMarcador: () => ref
                          .read(editorControllerProvider.notifier)
                          .toggleMarker(playback.time.value),
                      aoAmpliar: (fator) {
                        final n = ref.read(zoomDaLinhaDoTempoProvider) ?? zoom;
                        ref.read(zoomDaLinhaDoTempoProvider.notifier).state =
                            MapaDoTempo.prender(n * fator);
                      },
                    ),
                    Expanded(child: _conteudo(ref, modo, camadas, atual, mapa)),
                  ],
                ),
                // O CABECOTE E UMA LINHA PARADA.
                //
                // Ele nao se move, entao nao precisa repintar: e um
                // widget de 2 px centrado, por cima de tudo, que ignora
                // o toque. Antes era pintado a cada quadro junto com a
                // regua inteira.
                Positioned(
                  top: alturaDoTransporte,
                  bottom: 0,
                  left: largura * MapaDoTempo.fracaoDoCabecote - 1,
                  width: 2,
                  child: const IgnorePointer(
                    child: ColoredBox(
                      key: ValueKey('cabecote'),
                      color: AmColors.cabecote,
                    ),
                  ),
                ),
                // O `+` REDONDO, flutuando no canto de baixo a direita.
                //
                // E o unico controle da referencia que nao esta numa
                // barra, e o lugar dele nao e capricho: e o canto que o
                // polegar alcanca sem a mao sair de posicao, e a acao
                // mais repetida de quem monta uma composicao e
                // acrescentar mais uma camada.
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _BotaoRedondoDeAdicao(playback: playback),
                ),
                // A BARRA DE FAMILIAS abre EM CIMA do `+`, e nao no
                // rodape da tela: ela pertence ao botao que a chamou, e
                // o dedo que acabou de tocar nele ja esta ali.
                if (ref.watch(barraDeAdicaoAbertaProvider))
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12 + _BotaoRedondoDeAdicao.diametro + 10,
                    child: BarraDeCategoriasDeAdicao(
                      aoEscolher: (id) =>
                          ref.read(categoriaDeAdicaoProvider.notifier).state =
                              id,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _conteudo(
    WidgetRef ref,
    ModoDaLinhaDoTempo modo,
    List<Layer> camadas,
    Layer? atual,
    MapaDoTempo Function(Duration) mapa,
  ) {
    final project = ref.watch(editorControllerProvider);
    if (modo == ModoDaLinhaDoTempo.geral) {
      return VisaoGeralDasCamadas(playback: playback, mapa: mapa);
    }
    // A REFERENCIA TEMPORAL FICA, MESMO SEM CAMADAS. Regua e cabecote
    // nao dependem de haver conteudo — eles ja estao desenhados acima.
    // O que falta aqui e so o aviso de que o conteudo novo entra no
    // cabecote, que e onde a pessoa esta olhando.
    if (camadas.isEmpty) {
      return project.duration > Duration.zero
          ? _Faixa(
              playback: playback,
              mapa: mapa,
              camada: null,
              escondida: false,
              temAnterior: false,
              temProxima: false,
              aoMoverKeyframe: null,
              aoApagarKeyframe: null,
              aoComecarLote: () {},
              aoTerminarLote: () {},
              aoTrocar: (_) {},
              aoAlternarOlho: null,
              aviso: 'Nenhuma camada ainda. O conteudo novo entra no cabecote.',
            )
          : const SemCamadasNaLinhaDoTempo();
    }
    if (atual == null) return const _SemSelecao();
    return _Faixa(
      playback: playback,
      mapa: mapa,
      camada: atual,
      escondida: project.metaOf(atual.id).hidden,
      temAnterior: _vizinha(camadas, atual, -1) != null,
      temProxima: _vizinha(camadas, atual, 1) != null,
      aoMoverKeyframe: (de, para) => ref
          .read(editorControllerProvider.notifier)
          .moverKeyframeDeTransformacao(atual.id, de, para),
      aoApagarKeyframe: (local) => ref
          .read(editorControllerProvider.notifier)
          .apagarKeyframeDeTransformacao(atual.id, local),
      aoComecarLote: () =>
          ref.read(editorControllerProvider.notifier).beginGesture(),
      aoTerminarLote: () =>
          ref.read(editorControllerProvider.notifier).endGesture(),
      aoTrocar: (passo) {
        final v = _vizinha(camadas, atual, passo);
        if (v != null) {
          ref.read(selectedLayerProvider.notifier).state = v.id;
        }
      },
      aoAlternarOlho: () =>
          ref.read(editorControllerProvider.notifier).toggleHidden(atual.id),
    );
  }

  /// A camada [passo] posicoes adiante na pilha, ou nula na ponta.
  static Layer? _vizinha(List<Layer> camadas, Layer? atual, int passo) {
    if (camadas.isEmpty) return null;
    if (atual == null) return passo > 0 ? camadas.first : camadas.last;
    final i = camadas.indexWhere((l) => l.id == atual.id);
    if (i < 0) return camadas.first;
    final destino = i + passo;
    if (destino < 0 || destino >= camadas.length) return null;
    return camadas[destino];
  }
}

/// A BARRA DE TRANSPORTE: SETE ALVOS, com o play no meio EXATO.
///
/// Sete, e nao oito, porque sete e o que a referencia tem — e o numero
/// nao e decoracao: com um numero PAR de alvos dividindo a largura, o
/// play deixa de cair no centro da tela, e ele e o controle que a mao
/// procura sem olhar.
///
/// Na ordem da referencia: desfazer, refazer, inicio, PLAY, fim,
/// duplicar, enquadrar. O botao de trocar de vista, que a referencia nao
/// tem porque la so existe a pilha, foi para o cabecalho — ocupa la o
/// lugar da engrenagem.
class _Transporte extends ConsumerWidget {
  const _Transporte({
    required this.playback,
    required this.duracao,
    required this.camadaSelecionada,
    required this.aoEnquadrar,
  });

  final PlaybackController playback;
  final Duration duracao;
  final String? camadaSelecionada;
  final VoidCallback aoEnquadrar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O BOTAO DESFAZER PRECISA DO ESTADO, e nao so do notifier.
    //
    // `ref.watch(...notifier)` nao avisa quando a pilha de desfazer
    // muda: o notifier e sempre o mesmo objeto. O botao so parecia certo
    // porque o pai reconstruia por outro motivo — e quando nao
    // reconstruia, ele ficava apagado com desfazer disponivel. Observar
    // o ESTADO amarra a atualizacao a cada mutacao do projeto, que e
    // exatamente quando `canUndo` pode ter mudado.
    ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    return SizedBox(
      height: LinhaDoTempo.alturaDoTransporte,
      child: Row(
        children: [
          _Botao(
            icone: Icons.undo_rounded,
            ativo: controller.canUndo,
            aoTocar: controller.undo,
            rotulo: 'Desfazer',
          ),
          _Botao(
            icone: Icons.redo_rounded,
            ativo: controller.canRedo,
            aoTocar: controller.redo,
            rotulo: 'Refazer',
          ),
          _Botao(
            icone: Icons.first_page_rounded,
            aoTocar: () {
              playback.pause();
              playback.seek(Duration.zero);
            },
            rotulo: 'Inicio',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: playback.playing,
            builder: (context, tocando, _) => _Botao(
              icone: tocando ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tamanho: 30,
              aoTocar: playback.toggle,
              rotulo: tocando ? 'Pausar' : 'Reproduzir',
            ),
          ),
          _Botao(
            icone: Icons.last_page_rounded,
            aoTocar: () {
              playback.pause();
              playback.seek(duracao);
            },
            rotulo: 'Fim',
          ),
          _Botao(
            icone: Icons.copy_all_rounded,
            ativo: camadaSelecionada != null,
            aoTocar: () {
              final id = camadaSelecionada;
              if (id != null) {
                ref.read(editorControllerProvider.notifier).duplicarCamada(id);
              }
            },
            rotulo: 'Duplicar camada',
          ),
          // ENQUADRAR toma o lugar que a referencia da ao "caber na
          // tela". La ele enquadra a PREVIA; aqui enquadra o TEMPO, que
          // e o que pode sair de vista nesta tela — a previa ja se
          // ajusta sozinha.
          _Botao(
            icone: Icons.fit_screen_rounded,
            aoTocar: aoEnquadrar,
            rotulo: 'Enquadrar',
          ),
        ],
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.icone,
    required this.aoTocar,
    required this.rotulo,
    this.ativo = true,
    this.tamanho = 21,
  });

  final IconData icone;
  final VoidCallback aoTocar;
  final String rotulo;
  final bool ativo;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Expanded(
    // O ALVO DIVIDE A LARGURA, e nao a soma.
    //
    // Com largura fixa de 48 px, oito botoes pedem 384 px e estouram uma
    // tela de 390 — e o estouro nao e cosmetico: o ultimo controle sai
    // da area tocavel. Dividindo, cada um fica com a maior fatia que a
    // tela permite, seja qual for o aparelho e o numero de botoes.
    child: Semantics(
      button: true,
      label: rotulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ativo ? aoTocar : null,
        child: SizedBox(
          height: LinhaDoTempo.alturaDoTransporte,
          child: Icon(
            icone,
            size: tamanho,
            color: ativo
                ? AmColors.text
                : AmColors.muted.withValues(alpha: .4),
          ),
        ),
      ),
    ),
  );
}

/// A REGUA: escala, posicao e navegacao.
///
/// Ela e a superficie de NAVEGACAO da linha do tempo. Arrastar aqui
/// desliza o tempo; beliscar aproxima e afasta. As trilhas embaixo
/// tambem deslizam com o dedo, mas o belisco fica so aqui: nas trilhas
/// ele brigaria com a rolagem vertical da lista de camadas, e o que
/// perderia seria a rolagem.
class _Regua extends StatefulWidget {
  const _Regua({
    required this.playback,
    required this.duracao,
    required this.fps,
    required this.mapa,
    required this.aoAmpliar,
    required this.marcadores,
    required this.batidas,
    required this.aoAlternarMarcador,
  });

  final PlaybackController playback;
  final Duration duracao;
  final int fps;
  final MapaDoTempo Function(Duration) mapa;
  final void Function(double fator) aoAmpliar;

  /// OS MARCADORES DO PROJETO, desenhados na regua.
  ///
  /// O motor cria, renomeia, move, corta por eles e os SALVA no arquivo
  /// — e os modelos prontos ja vinham com marcador dentro. A regua nunca
  /// mostrou nenhum: o app guardava uma decisao que ninguem conseguia
  /// ver.
  final List<Marker> marcadores;

  /// O PULSO DA MUSICA, quando alguem mandou procurar.
  ///
  /// O detector existia inteiro — banda, envelope, estimativa de BPM,
  /// grade por compasso — e o resultado ia para `state.beats`, que
  /// NINGUEM desenhava. Achar as batidas era uma acao sem resposta na
  /// tela: os cortes saiam no ritmo e nao havia como conferir a grade
  /// antes de cortar.
  final List<Duration> batidas;

  /// Toque longo na regua crava ou tira um marcador no cabecote.
  final VoidCallback aoAlternarMarcador;

  @override
  State<_Regua> createState() => _ReguaState();
}

class _ReguaState extends State<_Regua> {
  Duration _tempoAoComecar = Duration.zero;
  Offset _focoAoComecar = Offset.zero;
  double _escalaAplicada = 1;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: LinhaDoTempo.alturaDaRegua,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      // UM RECONHECEDOR SO PARA ARRASTO E BELISCO.
      //
      // `onScale*` e `onHorizontalDrag*` no mesmo detector e erro em
      // tempo de execucao no Flutter. O `onScale` cobre os dois casos:
      // com um dedo ele e arrasto, com dois e belisco. A conta de qual
      // e sai de `pointerCount`.
      onScaleStart: (d) {
        widget.playback.pause();
        _tempoAoComecar = widget.playback.time.value;
        _focoAoComecar = d.localFocalPoint;
        _escalaAplicada = 1;
      },
      onScaleUpdate: (d) {
        if (d.pointerCount >= 2) {
          // O BELISCO E RELATIVO AO ULTIMO PASSO, e nao ao inicio: o
          // provider ja guarda o acumulado, e multiplicar duas vezes
          // pelo mesmo fator dispara o zoom.
          final passo = d.scale / _escalaAplicada;
          _escalaAplicada = d.scale;
          if (passo.isFinite && passo > 0) widget.aoAmpliar(passo);
          return;
        }
        final mapa = widget.mapa(_tempoAoComecar);
        final andou = d.localFocalPoint.dx - _focoAoComecar.dx;
        // ARRASTAR PARA A ESQUERDA AVANCA. O dedo empurra o conteudo, e
        // o conteudo passa por baixo do cabecote — o mesmo sentido de
        // rolar uma lista.
        _levar(_tempoAoComecar - mapa.tempoDe(andou));
      },
      onTapUp: (d) {
        final mapa = widget.mapa(widget.playback.time.value);
        widget.playback.pause();
        _levar(mapa.tempoEm(d.localPosition.dx));
      },
      // TOQUE LONGO NA REGUA CRAVA UM MARCADOR no cabecote, e tira se ja
      // houver um perto. E o gesto que sobra: o toque leva o cabecote e
      // o arrasto desliza o tempo, e marcador e coisa da regua — nao da
      // trilha, que pertence a uma camada so.
      onLongPress: widget.aoAlternarMarcador,
      child: ValueListenableBuilder<Duration>(
        valueListenable: widget.playback.time,
        builder: (context, t, _) => CustomPaint(
          painter: _PintorDaRegua(
            mapa: widget.mapa(t),
            duracao: widget.duracao,
            fps: widget.fps,
            familia: familiaDoApp(context),
            marcadores: widget.marcadores,
            batidas: widget.batidas,
          ),
          size: Size.infinite,
        ),
      ),
    ),
  );

  /// O CABECOTE NAO SAI DA COMPOSICAO — quem garante isso e o proprio
  /// `seek`, que ja prende nas duas pontas. Repetir a conta aqui so
  /// criaria um segundo lugar para ela ficar errada.
  void _levar(Duration t) => widget.playback.seek(t);
}

class _PintorDaRegua extends CustomPainter {
  const _PintorDaRegua({
    required this.mapa,
    required this.duracao,
    required this.fps,
    required this.familia,
    required this.marcadores,
    required this.batidas,
  });

  final MapaDoTempo mapa;
  final Duration duracao;
  final int fps;
  final TextStyle familia;
  final List<Marker> marcadores;
  final List<Duration> batidas;

  /// A barra de rolagem no topo, as marcas embaixo dela, e a capsula
  /// sobreposta ao pe das marcas. Medidas da referencia.
  static const _topoDaBarra = 2.0;
  static const _alturaDaBarra = 4.0;
  static const _topoDasMarcas = 10.0;
  static const _marcaCurta = 5.0;
  static const _marcaLonga = 9.0;
  static const _topoDaCapsula = 21.0;
  static const _alturaDaCapsula = 16.0;

  /// A ESCADA DE PASSOS. So estes valores aparecem como marca, para o
  /// espacamento nunca virar um numero quebrado que nao ajuda ninguem a
  /// contar ("uma marca a cada 0,37 s" nao e escala, e ruido).
  static const _passos = <double>[
    .1, .25, .5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    _pintarMarcas(canvas, size);
    _pintarBarra(canvas, size);
    _pintarBatidas(canvas, size);
    _pintarMarcadores(canvas, size);
    _pintarCapsula(canvas, size);
  }

  /// AS BATIDAS: risquinhos no pe da regua.
  ///
  /// Baixos e finos de proposito. Sao muitos — uma musica de tres
  /// minutos a 120 BPM tem 360 — e desenha-los com o peso de um
  /// marcador viraria uma cerca que esconde a propria regua. O que se
  /// quer deles e o RITMO visto de longe, para conferir se a grade
  /// bateu com a musica antes de mandar cortar.
  void _pintarBatidas(Canvas canvas, Size size) {
    if (batidas.isEmpty) return;
    final tinta = Paint()..color = AmColors.accent.withValues(alpha: .5);
    for (final t in batidas) {
      final x = mapa.xDe(t);
      if (x < 0 || x > size.width) continue;
      canvas.drawRect(
        Rect.fromLTWH(x - .5, size.height - 7, 1, 7),
        tinta,
      );
    }
  }

  /// OS MARCADORES: um triangulinho pendurado no alto da regua.
  ///
  /// Na cor que o proprio marcador guarda, porque a cor e como se
  /// separa "aqui vira a cena" de "aqui entra a legenda" sem caber
  /// texto nenhum numa regua de 44 px.
  void _pintarMarcadores(Canvas canvas, Size size) {
    for (final m in marcadores) {
      final x = mapa.xDe(m.time);
      if (x < -8 || x > size.width + 8) continue;
      final tinta = Paint()..color = m.color;
      canvas.drawPath(
        Path()
          ..moveTo(x - 5, _topoDasMarcas - 2)
          ..lineTo(x + 5, _topoDasMarcas - 2)
          ..lineTo(x, _topoDasMarcas + 7)
          ..close(),
        tinta,
      );
      // O RISCO DESCE ATE O PE DA REGUA, senao o triangulo sozinho nao
      // diz em que instante exato ele esta.
      canvas.drawRect(
        Rect.fromLTWH(x - .5, _topoDasMarcas, 1, size.height - _topoDasMarcas),
        Paint()..color = m.color.withValues(alpha: .45),
      );
    }
  }

  /// AS MARCAS SAO A ESCALA. Elas nao levam numero: a referencia nao
  /// tem, e a capsula ja diz o instante exato. Numero em toda marca so
  /// enche a faixa de digitos pequenos que ninguem le.
  void _pintarMarcas(Canvas canvas, Size size) {
    // Nunca menos de treze pixels entre uma marca grande e a seguinte:
    // mais denso que isso vira mancha cinza e custa caro de pintar.
    var passo = _passos.last;
    for (final p in _passos) {
      if (p * mapa.pxPorSegundo >= 13) {
        passo = p;
        break;
      }
    }
    final curta = Paint()..color = AmColors.muted.withValues(alpha: .30);
    final longa = Paint()..color = AmColors.muted.withValues(alpha: .55);

    final inicio = mapa.inicioVisivel.inMicroseconds / 1000000;
    final fim = mapa.fimVisivel.inMicroseconds / 1000000;
    // MEIO PASSO, porque a referencia alterna: marca grande no passo,
    // marca pequena no meio dele.
    final meio = passo / 2;
    var n = (inicio / meio).floor();
    final ultimo = (fim / meio).ceil();
    while (n <= ultimo) {
      final s = n * meio;
      n++;
      // AS MARCAS COBREM A LARGURA INTEIRA, inclusive antes do zero.
      //
      // Cortar a regua no comeco da composicao foi tentado e esta
      // errado: no instante zero — que e onde todo projeto abre — a
      // metade esquerda ficava lisa, e uma regua pela metade parece
      // defeito. A referencia desenha a grade toda; quem diz onde a
      // composicao comeca e a barra do topo.
      final x =
          mapa.ancora +
          (s - mapa.tempo.inMicroseconds / 1000000) * mapa.pxPorSegundo;
      if (x < -2 || x > size.width + 2) continue;
      final grande = (s / passo - (s / passo).roundToDouble()).abs() < .001;
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          _topoDasMarcas,
          1,
          grande ? _marcaLonga : _marcaCurta,
        ),
        grande ? longa : curta,
      );
    }
  }

  /// A BARRA DO TOPO: que pedaco da composicao esta a vista.
  ///
  /// Com o cabecote preso no meio, a regua coberta de marcas iguais e a
  /// escala livre, nada mais na tela diz "voce esta perto do fim" nem
  /// "isto aqui e um terco do projeto". Esta barra e a unica pista de
  /// proporcao — e por isso ela e a unica coisa colorida da regua, como
  /// na referencia.
  void _pintarBarra(Canvas canvas, Size size) {
    final total = duracao.inMicroseconds;
    if (total <= 0) return;
    double frac(Duration t) => (t.inMicroseconds / total).clamp(0.0, 1.0);
    final de = frac(mapa.inicioVisivel);
    final ate = frac(mapa.fimVisivel);
    if (ate <= de) return;
    final trilho = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, _topoDaBarra, size.width, _alturaDaBarra),
      const Radius.circular(2),
    );
    canvas.drawRRect(
      trilho,
      Paint()..color = AmColors.muted.withValues(alpha: .10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          de * size.width,
          _topoDaBarra,
          (ate - de) * size.width,
          _alturaDaBarra,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = AmColors.accent,
    );
  }

  /// O TEMPO ANDA COM O CABECOTE, numa capsula colada nele. Ler o tempo
  /// num canto fixo obriga o olho a ir e voltar; colado, a informacao
  /// esta onde a atencao ja esta.
  void _pintarCapsula(Canvas canvas, Size size) {
    final texto = TextPainter(
      text: TextSpan(
        text: relogioDeQuadros(mapa.tempo, fps),
        style: familia.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AmColors.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final largura = texto.width + 16;
    var esquerda = mapa.ancora - largura / 2;
    if (esquerda < 2) esquerda = 2;
    if (esquerda + largura > size.width - 2) {
      esquerda = size.width - 2 - largura;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(esquerda, _topoDaCapsula, largura, _alturaDaCapsula),
        const Radius.circular(5),
      ),
      Paint()..color = AmColors.chip,
    );
    texto.paint(
      canvas,
      Offset(
        esquerda + 8,
        _topoDaCapsula + (_alturaDaCapsula - texto.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_PintorDaRegua o) =>
      o.familia != familia ||
      o.marcadores.length != marcadores.length ||
      o.batidas.length != batidas.length ||
      o.mapa.tempo != mapa.tempo ||
      o.mapa.pxPorSegundo != mapa.pxPorSegundo ||
      o.mapa.largura != mapa.largura ||
      o.duracao != duracao ||
      o.fps != fps;
}

/// O RELOGIO DA REFERENCIA: minuto, segundo e QUADRO.
///
/// Quadro, e nao centesimo, porque quadro e a unidade em que o video
/// existe — nao ha meio quadro para o cabecote parar em cima. Um projeto
/// a 30 fps conta ate 29 e vira o segundo.
String relogioDeQuadros(Duration d, int fps) {
  final taxa = fps > 0 ? fps : 30;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  final q = ((d.inMicroseconds.remainder(1000000) / 1000000) * taxa)
      .floor()
      .toString()
      .padLeft(2, '0');
  // A HORA SO APARECE QUANDO EXISTE.
  //
  // Sem ela, um projeto de uma hora e um minuto mostrava `01:xx` — o
  // mesmo que um de um minuto. Mostrar `00:` sempre gastaria tres
  // caracteres da capsula em todo projeto curto, que e a maioria; a
  // hora entra so quando ha hora para contar.
  if (d.inHours <= 0) return '$m:$s:$q';
  return '${d.inHours.toString().padLeft(2, '0')}:$m:$s:$q';
}

/// A TRILHA DA CAMADA SELECIONADA, no modo detalhado.
class _Faixa extends StatefulWidget {
  const _Faixa({
    required this.playback,
    required this.mapa,
    required this.camada,
    required this.escondida,
    required this.temAnterior,
    required this.temProxima,
    required this.aoTrocar,
    required this.aoAlternarOlho,
    required this.aoMoverKeyframe,
    required this.aoApagarKeyframe,
    required this.aoComecarLote,
    required this.aoTerminarLote,
    this.aviso,
  });

  final PlaybackController playback;
  final MapaDoTempo Function(Duration) mapa;
  final Layer? camada;
  final bool escondida;
  final bool temAnterior;
  final bool temProxima;
  final void Function(int passo) aoTrocar;
  final VoidCallback? aoAlternarOlho;
  final void Function(Duration de, Duration para)? aoMoverKeyframe;
  final void Function(Duration local)? aoApagarKeyframe;

  /// ABREM E FECHAM O LOTE DE DESFAZER do arrasto de marca.
  ///
  /// Vem de fora porque esta faixa e um `State` comum, sem `ref` — e
  /// inventar um `ConsumerState` so para chamar `beginGesture` seria
  /// trocar o problema de lugar.
  final VoidCallback aoComecarLote;
  final VoidCallback aoTerminarLote;

  /// Texto no lugar da trilha, quando nao ha camada para desenhar.
  final String? aviso;

  /// A TRILHA E MAIS ALTA QUE AS DA PILHA, de proposito. Na pilha o que
  /// importa e ver muitas; aqui o que importa e PEGAR — o losango do
  /// keyframe precisa de alvo, e alvo e altura.
  static const alturaDaTrilha = 56.0;

  static double topoDaTrilhaEm(double altura) {
    final t = (altura - alturaDaTrilha) / 2;
    return t < 0 ? 0 : t;
  }

  @override
  State<_Faixa> createState() => _FaixaState();
}

class _FaixaState extends State<_Faixa> {
  /// O keyframe que o dedo pegou, em tempo LOCAL da camada. Nulo quando
  /// o arrasto e do cabecote e nao de uma marca.
  Duration? _pego;

  /// O KEYFRAME SOB O DEDO NO MOMENTO DO POUSO.
  ///
  /// Escolher a marca depende de saber onde o dedo POUSOU, e nenhum
  /// retorno de gesto entrega isso a tempo:
  ///
  ///   - `onTapDown` nao dispara quando o dedo sai andando logo, porque
  ///     o toque e rejeitado antes do prazo dele;
  ///   - `onHorizontalDragStart` so chega depois de uns dezoito pixels,
  ///     e ja com a posicao NOVA.
  ///
  /// Um `Listener` recebe o `onPointerDown` cru, no instante do pouso, e
  /// sem entrar na arena de gestos — entao ele nao rouba o toque das
  /// setas de trocar de camada, que ficam por cima.
  Duration? _candidato;

  /// De onde o arrasto de navegacao partiu.
  Duration _tempoAoComecar = Duration.zero;
  double _xAoComecar = 0;

  MapaDoTempo get _mapaAgora => widget.mapa(widget.playback.time.value);

  /// O keyframe sob o dedo, em tempo LOCAL, ou nulo.
  ///
  /// A tolerancia e em PIXELS, e nao em tempo: o dedo tem o mesmo
  /// tamanho seja qual for a escala. Dezoito pixels e o raio que deixa
  /// pegar o losango sem precisar de pontaria.
  Duration? _keyframeSobODedo(Offset ponto, double altura) {
    final l = widget.camada;
    if (l == null) return null;
    // O LOSANGO SO E PEGAVEL NA FAIXA DA TRILHA.
    final topo = _Faixa.topoDaTrilhaEm(altura);
    if (ponto.dy < topo - 8) return null;
    final mapa = _mapaAgora;
    Duration? melhor;
    var menorDistancia = double.infinity;
    for (final t in l.keyframeTimes) {
      final quando = l.startTime + t;
      if (quando < l.startTime || quando > l.endTime) continue;
      final d = (mapa.xDe(quando) - ponto.dx).abs();
      if (d <= 18 && d < menorDistancia) {
        menorDistancia = d;
        melhor = t;
      }
    }
    return melhor;
  }

  /// O dedo pousou: so ESCOLHE, nao age. Se o toque acabar sendo das
  /// setas, nada aconteceu.
  void _pousar(Offset ponto, double altura) {
    _candidato = _keyframeSobODedo(ponto, altura);
  }

  /// TOCAR NUM KEYFRAME LEVA O CABECOTE ATE ELE. E o gesto que a mao faz
  /// sem pensar, e sem ele nao ha como cair exatamente em cima da marca
  /// para editar o valor dali.
  void _tocar(Offset ponto) {
    final l = widget.camada;
    final k = _candidato;
    widget.playback.pause();
    if (k == null || l == null) {
      widget.playback.seek(_mapaAgora.tempoEm(ponto.dx));
      return;
    }
    widget.playback.seek(l.startTime + k);
  }

  /// O arrasto comecou: quem manda e a marca escolhida no pouso.
  void _comecarArrasto(Offset ponto) {
    final l = widget.camada;
    final k = _candidato;
    _tempoAoComecar = widget.playback.time.value;
    _xAoComecar = ponto.dx;
    if (k == null || l == null || !l.podeArrastarKeyframeEm(k)) {
      _pego = null;
      widget.playback.pause();
      return;
    }
    _pego = k;
    // UM ARRASTO, UM DESFAZER. Sem o lote, mover uma marca produzia
    // dezenas de passos e um toque em desfazer devolvia so o ultimo
    // pedacinho do movimento — o resto ficava preso na pilha.
    _lote = true;
    widget.aoComecarLote();
  }

  /// O lote de desfazer do arrasto de marca esta aberto?
  bool _lote = false;

  void _fecharLote() {
    if (!_lote) return;
    _lote = false;
    widget.aoTerminarLote();
  }

  void _mover(Offset ponto) {
    final l = widget.camada;
    final pego = _pego;
    final mapa = widget.mapa(_tempoAoComecar);
    if (pego == null || l == null) {
      // NAVEGAR: o conteudo desliza sob o cabecote parado.
      widget.playback.seek(
        _tempoAoComecar - mapa.tempoDe(ponto.dx - _xAoComecar),
      );
      return;
    }
    var destino = mapa.tempoEm(ponto.dx) - l.startTime;
    // A marca nao sai da propria camada.
    if (destino < Duration.zero) destino = Duration.zero;
    if (destino > l.duration) destino = l.duration;
    if (destino == pego) return;
    widget.aoMoverKeyframe?.call(pego, destino);
    _pego = destino;
    // O CABECOTE FICA PARADO ATE O DEDO SOLTAR.
    //
    // Antes ele seguia a marca a cada passo, para a previa mostrar o
    // instante sendo editado. Com o cabecote preso no meio, seguir a
    // marca significa ROLAR O CONTEUDO — e a marca fugiria do dedo,
    // saltando para o centro a cada quadro. Parada, ela anda um por um
    // com o dedo; a previa alcanca quando o dedo solta.
  }

  void _soltar() {
    final l = widget.camada;
    final pego = _pego;
    _pego = null;
    _fecharLote();
    if (l == null || pego == null) return;
    widget.playback.seek(l.startTime + pego);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final altura = limites.maxHeight;
      return Listener(
        onPointerDown: (e) => _pousar(e.localPosition, altura),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tocar(d.localPosition),
          onHorizontalDragStart: (d) => _comecarArrasto(d.localPosition),
          onHorizontalDragUpdate: (d) => _mover(d.localPosition),
          onHorizontalDragEnd: (_) => _soltar(),
          onHorizontalDragCancel: () {
            _pego = null;
            _fecharLote();
          },
          onLongPressStart: (_) {
            final k = _candidato;
            final l = widget.camada;
            if (k == null || l == null) return;
            if (!l.podeArrastarKeyframeEm(k)) return;
            widget.aoApagarKeyframe?.call(k);
            _candidato = null;
          },
          child: ValueListenableBuilder<Duration>(
            valueListenable: widget.playback.time,
            builder: (context, t, _) => Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PintorDaFaixa(
                      mapa: widget.mapa(t),
                      camada: widget.camada,
                      escondida: widget.escondida,
                      familia: familiaDoApp(context),
                    ),
                  ),
                ),
                // O AVISO OCUPA A FAIXA DA TRILHA. A referencia temporal
                // continua inteira acima: o que falta e conteudo, e nao
                // tempo.
                if (widget.aviso != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _Faixa.topoDaTrilhaEm(altura),
                    height: _Faixa.alturaDaTrilha,
                    child: IgnorePointer(
                      child: Center(
                        child: Text(
                          widget.aviso!,
                          key: const ValueKey('timeline-aviso'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AmColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (widget.camada != null)
                  Positioned(
                    left: 0,
                    top: _Faixa.topoDaTrilhaEm(altura),
                    height: _Faixa.alturaDaTrilha,
                    width: LinhaDoTempo.larguraDaPilula,
                    child: Center(
                      child: PilulaDaCamada(
                        camada: widget.camada!,
                        escondida: widget.escondida,
                        aoAlternarOlho: widget.aoAlternarOlho,
                      ),
                    ),
                  ),
                // O NAVEGADOR DE CAMADA: uma pilula BRANCA por cima
                // da trilha, com o nome no meio e as setas nas pontas.
                //
                // Eram duas setas cinzas nas bordas da faixa, e elas
                // brigavam com tudo: com o `+` redondo, com a pilula do
                // olho, com o proprio clipe. A referencia resolve
                // juntando as tres coisas numa peca so, no meio, onde
                // nada mais mora — e de quebra o nome da camada aberta
                // fica visivel, que era o que faltava para saber onde se
                // esta sem olhar o cabecalho.
                if (widget.camada != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _Faixa.topoDaTrilhaEm(altura) - 40,
                    child: Center(
                      child: PilulaDeNavegacao(
                        nome: widget.camada!.name,
                        cor: corDaCamada(widget.camada!),
                        aoAnterior: widget.temAnterior
                            ? () => widget.aoTrocar(-1)
                            : null,
                        aoProxima: widget.temProxima
                            ? () => widget.aoTrocar(1)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}


/// A PILULA: o olho e a cor da camada, flutuando sobre a trilha.
///
/// Medida na referencia: capsula de cantos redondos, 62 px, com o olho a
/// esquerda e a identidade da camada a direita. Ela FICA POR CIMA da
/// faixa em vez de ocupar coluna propria — ver
/// [LinhaDoTempo.larguraDaPilula] para a conta.
class PilulaDaCamada extends StatelessWidget {
  const PilulaDaCamada({
    super.key,
    required this.camada,
    required this.escondida,
    this.aoAlternarOlho,
    this.altura = 24,
  });

  final Layer camada;
  final bool escondida;
  final VoidCallback? aoAlternarOlho;
  final double altura;

  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: escondida ? 'Mostrar ${camada.name}' : 'Esconder ${camada.name}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aoAlternarOlho,
        child: Container(
          width: LinhaDoTempo.larguraDaPilula,
          height: altura,
          decoration: BoxDecoration(
            color: AmColors.pilula,
            borderRadius: BorderRadius.circular(altura / 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Icon(
                escondida
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 15,
                color: escondida ? AmColors.muted : AmColors.text,
              ),
              Container(
                width: 13,
                height: 15,
                decoration: BoxDecoration(
                  color: escondida
                      ? corDaCamada(camada).withValues(alpha: .3)
                      : corDaCamada(camada),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
  );
}

class _PintorDaFaixa extends CustomPainter {
  const _PintorDaFaixa({
    required this.mapa,
    required this.camada,
    required this.escondida,
    required this.familia,
  });

  final MapaDoTempo mapa;
  final Layer? camada;
  final bool escondida;
  final TextStyle familia;

  @override
  void paint(Canvas canvas, Size size) {
    final l = camada;
    if (l == null || size.width <= 0) return;
    final topo = _Faixa.topoDaTrilhaEm(size.height);
    final inicio = mapa.xDe(l.startTime);
    final fim = mapa.xDe(l.endTime);
    final barra = Rect.fromLTRB(
      inicio,
      topo,
      fim <= inicio + 8 ? inicio + 8 : fim,
      topo + _Faixa.alturaDaTrilha,
    );
    // NADA A VISTA: a camada esta fora do trecho visivel.
    if (barra.right < 0 || barra.left > size.width) return;

    final cor = corDaCamada(l);
    final rr = RRect.fromRectAndRadius(barra, const Radius.circular(8));
    canvas.drawRRect(
      rr,
      Paint()..color = escondida ? cor.withValues(alpha: .28) : cor,
    );

    final nome = TextPainter(
      text: TextSpan(
        text: l.name,
        style: familia.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: escondida
              ? sobreACorDaCamada(cor).withValues(alpha: .5)
              : sobreACorDaCamada(cor),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (barra.width - 20).clamp(0.0, double.infinity));
    canvas.save();
    canvas.clipRRect(rr);
    nome.paint(canvas, Offset(barra.left + 10, barra.center.dy - 8));
    canvas.restore();

    _pintarKeyframes(canvas, size, l, barra);
  }

  void _pintarKeyframes(Canvas canvas, Size size, Layer l, Rect barra) {
    final tempos = l.keyframeTimes;
    if (tempos.isEmpty) return;
    final losango = Paint()..color = Colors.white;
    final sob = Paint()..color = AmColors.accent;
    final contorno = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    // Perto o bastante do cabecote para contar como "o keyframe atual".
    final tolerancia = mapa.tempoDe(6);

    for (final t in tempos) {
      final quando = l.startTime + t;
      // FORA DA CAMADA NAO SE DESENHA. Um keyframe pode cair antes do
      // inicio ou depois do fim (a camada foi aparada, ou a marca nasceu
      // com o cabecote fora dela). Desenhado assim mesmo, ele aparece
      // solto no vazio, longe da barra a que pertence.
      if (quando < l.startTime || quando > l.endTime) continue;
      final px = mapa.xDe(quando);
      if (px < -10 || px > size.width + 10) continue;

      final atual =
          (quando - mapa.tempo).abs() <= tolerancia;
      final centro = Offset(px, barra.center.dy);
      final caminho = Path()
        ..moveTo(centro.dx, centro.dy - 7)
        ..lineTo(centro.dx + 6, centro.dy)
        ..lineTo(centro.dx, centro.dy + 7)
        ..lineTo(centro.dx - 6, centro.dy)
        ..close();
      canvas.drawPath(caminho, atual ? sob : losango);
      if (atual) canvas.drawPath(caminho, contorno);
    }
  }

  @override
  bool shouldRepaint(_PintorDaFaixa o) =>
      o.familia != familia ||
      o.mapa.tempo != mapa.tempo ||
      o.mapa.pxPorSegundo != mapa.pxPorSegundo ||
      o.mapa.largura != mapa.largura ||
      o.escondida != escondida ||
      !identical(o.camada, camada);
}

/// ESTADO VAZIO do modo detalhado: ha camadas, mas nenhuma escolhida.
class _SemSelecao extends StatelessWidget {
  const _SemSelecao();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Nenhuma camada selecionada. Abra a visao geral para escolher '
        'uma.',
        key: const ValueKey('detalhado-sem-selecao'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AmColors.muted, height: 1.4),
      ),
    ),
  );
}

/// O `+` REDONDO que flutua sobre a linha do tempo.
///
/// Aberto, ele vira um `x`: o mesmo alvo que chamou a barra a dispensa,
/// e o dedo nao precisa procurar outro lugar para desistir.
class _BotaoRedondoDeAdicao extends ConsumerWidget {
  const _BotaoRedondoDeAdicao({required this.playback});

  final PlaybackController playback;

  static const diametro = 46.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(painelDaCamadaLigadoProvider)) {
      return const SizedBox.shrink();
    }
    final aberta = ref.watch(barraDeAdicaoAbertaProvider);
    // NO PROJETO VAZIO ELE FICA — e o unico caminho para comecar.
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: aberta ? 'Fechar o menu' : 'Adicionar conteudo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (aberta) {
            fecharAdicao(ref);
            ref.read(barraDeAdicaoAbertaProvider.notifier).state = false;
            return;
          }
          abrirAdicaoDeConteudo(ref, playback);
        },
        child: Container(
          width: diametro,
          height: diametro,
          decoration: const BoxDecoration(
            color: AmColors.action,
            shape: BoxShape.circle,
          ),
          child: Icon(
            aberta ? Icons.close_rounded : Icons.add_rounded,
            size: 26,
            color: AmColors.onAction,
          ),
        ),
      ),
    );
  }
}
