import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/media_preview_service.dart';
import '../../application/playback_controller.dart';
import '../../domain/peak_pyramid.dart';
import '../../domain/layer.dart';
import 'linha_do_tempo.dart';
import 'mapa_do_tempo.dart';
import 'painel_da_camada.dart';

/// COMO A LINHA DO TEMPO ESTA SENDO MOSTRADA.
///
/// Os dois modos respondem a perguntas diferentes, e por isso os dois
/// existem:
///
///   - GERAL: "como as camadas se arrumam no tempo?" Todas empilhadas,
///     baixas, do jeito que a referencia mostra.
///   - DETALHADO: "o que esta acontecendo NESTA camada?" Uma trilha
///     alta, com os keyframes grandes o bastante para o dedo pegar.
///
/// O detalhado e nosso; a referencia so tem a pilha. Por isso o botao
/// que troca de vista mora no cabecalho, e nao no transporte: o
/// transporte tem exatamente os sete alvos da referencia.
enum ModoDaLinhaDoTempo { detalhado, geral }

/// O modo vigente. Vive so na sessao — guardar em disco seria migracao
/// de dados, e migracao esta fora deste pacote.
///
/// ABRE NA PILHA. A primeira pergunta de quem entra num projeto e "o que
/// tem aqui?", e quem responde e a pilha. O detalhado e o passo
/// seguinte: escolher uma camada e mexer nela.
final modoDaLinhaDoTempoProvider = StateProvider<ModoDaLinhaDoTempo>(
  (ref) => ModoDaLinhaDoTempo.geral,
);

/// O BOTAO QUE TROCA DE VISTA.
///
/// Mora no cabecalho, no lugar que a referencia da a engrenagem: ultimo
/// antes do botao colorido. Ele saiu do transporte porque la era o
/// oitavo alvo — e com um numero par de alvos dividindo a largura, o
/// play deixava de cair no centro exato da tela.
///
/// E um widget proprio, e nao um pedaco do cabecalho, porque o modo e
/// desta camada de codigo: quem mostra as camadas e quem sabe dizer que
/// vistas existem.
class AlternadorDeVista extends ConsumerWidget {
  const AlternadorDeVista({super.key, this.altura = 52});

  final double altura;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modo = ref.watch(modoDaLinhaDoTempoProvider);
    final naPilha = modo == ModoDaLinhaDoTempo.geral;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: naPilha ? 'Ver uma camada' : 'Ver todas as camadas',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            ref.read(modoDaLinhaDoTempoProvider.notifier).state = naPilha
            ? ModoDaLinhaDoTempo.detalhado
            : ModoDaLinhaDoTempo.geral,
        child: SizedBox(
          width: 44,
          height: altura,
          child: Icon(
            naPilha ? Icons.view_stream_rounded : Icons.layers_rounded,
            size: 20,
            color: naPilha ? AmColors.accent : AmColors.text,
          ),
        ),
      ),
    );
  }
}

/// A VISTA DE TODAS AS CAMADAS.
///
/// Reaproveita tudo que o modo detalhado ja usa: o mesmo projeto, o
/// mesmo relogio, a mesma selecao, os mesmos comandos — e o mesmo
/// [MapaDoTempo], entao o cabecote da regua cai exatamente sobre o
/// keyframe da trilha. Nada aqui e estado proprio, tirando o arrasto em
/// curso da alca de reordenar.
///
/// CONTRATO DE GESTOS (o mesmo escrito em
/// `docs/linha-do-tempo-gestos.md`):
///
///   - toque numa trilha ............. seleciona aquela camada
///   - toque na trilha JA escolhida .. abre ela no modo detalhado
///   - toque na pilula (olho) ........ esconde ou mostra aquela camada
///   - arrasto horizontal ............ navega no tempo
///   - arrasto NO CLIPE ESCOLHIDO .... move a camada no tempo
///   - arrasto NA PONTA do escolhido . apara aquele lado
///   - arrasto vertical .............. rola a lista de camadas
///   - arrasto na alca da direita .... muda a camada de lugar na pilha
///
/// MOVER E APARAR SO VALEM NO CLIPE JA ESCOLHIDO, e essa e a regra que
/// faz os dois gestos caberem na mesma superficie. Se qualquer clipe
/// respondesse ao arrasto, navegar no tempo viraria sorte: quase toda a
/// largura da pilha tem clipe em cima. Escolher primeiro custa um
/// toque e devolve a navegacao inteira.
///
/// O que NAO ha, de proposito: dividir e mexer em keyframe. Dividir tem
/// botao proprio nas ferramentas da camada; keyframe e do detalhado.
class VisaoGeralDasCamadas extends ConsumerStatefulWidget {
  const VisaoGeralDasCamadas({
    super.key,
    required this.playback,
    required this.mapa,
  });

  final PlaybackController playback;

  /// A conta de tempo para pixel, vinda da linha do tempo. E a MESMA que
  /// a regua usa: se cada vista fizesse a sua, o cabecote desenhado em
  /// cima nao cairia sobre o clipe desenhado embaixo.
  final MapaDoTempo Function(Duration) mapa;

  /// A ALTURA DE CADA TRILHA, medida na referencia: 30 px de passo, com
  /// o clipe ocupando 26 e 4 de respiro.
  ///
  /// Baixa de proposito, e FIXA. Ja tentei estica-las para preencher o
  /// espaco e o resultado foi pior: com poucas camadas viravam blocos
  /// enormes, e o tamanho de uma trilha passava a depender de quantas
  /// existem — a mesma camada mudava de cara so porque outra foi criada.
  static const alturaDaTrilha = 30.0;
  static const alturaDoClipe = 26.0;

  /// A COLUNA DAS ALCAS, presa na direita.
  static const larguraDaAlca = 26.0;

  /// Quantas trilhas cabem antes de a lista comecar a rolar. E o piso do
  /// calculo: com mais espaco, a tela manda uma altura maior e mais
  /// trilhas aparecem sem rolar.
  static const trilhasVisiveis = 6;

  /// A altura que a pilha pede. So as trilhas — a regua nao e mais dela,
  /// e sim da linha do tempo, que a divide com o modo detalhado.
  static double alturaPara(int camadas) =>
      camadas.clamp(1, trilhasVisiveis) * alturaDaTrilha;

  @override
  ConsumerState<VisaoGeralDasCamadas> createState() =>
      _VisaoGeralDasCamadasState();
}

/// O QUE O ARRASTO HORIZONTAL VAI FAZER, decidido no POUSO do dedo.
///
/// A decisao nao pode esperar o `onHorizontalDragStart`: ele so chega
/// depois de uns dezoito pixels, e ja com a posicao nova — a essa altura
/// nao da mais para saber se o dedo pousou na ponta do clipe ou no meio
/// dele. Um `Listener` recebe o pouso cru e guarda a resposta aqui.
enum _Arrasto { navegar, mover, apararInicio, apararFim }

class _VisaoGeralDasCamadasState extends ConsumerState<VisaoGeralDasCamadas> {
  Duration _tempoAoComecar = Duration.zero;
  double _xAoComecar = 0;

  /// A LARGURA DA ALCA DE APARAR, em pixels.
  ///
  /// Doze e o que cabe num clipe curto sem as duas pontas se
  /// encostarem, e o bastante para o dedo achar. Abaixo disso aparar
  /// vira pontaria; acima, um clipe de trinta pixels nao teria meio.
  static const _alca = 12.0;

  _Arrasto _oQueFazer = _Arrasto.navegar;
  String? _clipe;
  Duration _inicioAoComecar = Duration.zero;
  Duration _fimAoComecar = Duration.zero;

  /// O dedo pousou: so ESCOLHE o que o arrasto vai fazer. Se o gesto
  /// acabar sendo um toque, nada aconteceu.
  void _pousar(Offset ponto, List<Layer> camadas, String? selecionada) {
    _oQueFazer = _Arrasto.navegar;
    _clipe = null;
    if (selecionada == null) return;
    final i = ponto.dy ~/ VisaoGeralDasCamadas.alturaDaTrilha;
    if (i < 0 || i >= camadas.length) return;
    final l = camadas[i];
    if (l.id != selecionada) return;
    // CAMADA TRAVADA NAO SE MOVE NEM SE APARA.
    //
    // A trava existia so como um bit no arquivo: dava para ligar e o
    // editor continuava deixando arrastar. Uma trava que nao trava e
    // pior que trava nenhuma — ela promete e falha justamente quando
    // alguem confiou nela para nao estragar o trabalho.
    if (ref.read(editorControllerProvider).metaOf(l.id).locked) return;

    final mapa = widget.mapa(widget.playback.time.value);
    final inicio = mapa.xDe(l.startTime);
    final fim = mapa.xDe(l.endTime);
    if (ponto.dx < inicio - _alca || ponto.dx > fim + _alca) return;

    _clipe = l.id;
    _inicioAoComecar = l.startTime;
    _fimAoComecar = l.endTime;
    // A PONTA GANHA DO MEIO. Num clipe estreito as duas alcas ocupam
    // ele inteiro, e ai aparar e o unico gesto possivel — mover um
    // clipe de doze pixels e pedir demais do dedo de qualquer forma.
    if ((ponto.dx - inicio).abs() <= _alca) {
      _oQueFazer = _Arrasto.apararInicio;
    } else if ((ponto.dx - fim).abs() <= _alca) {
      _oQueFazer = _Arrasto.apararFim;
    } else {
      _oQueFazer = _Arrasto.mover;
    }
  }

  /// A camada que a alca esta segurando, e quanto o dedo ja subiu ou
  /// desceu. Nulo quando ninguem esta reordenando.
  String? _segurando;
  double _dy = 0;

  /// QUANTOS DEGRAUS O DEDO JA PEDIU.
  int get _degraus => (_dy / VisaoGeralDasCamadas.alturaDaTrilha).round();

  void _soltarAlca(String id) {
    final passos = _degraus;
    setState(() {
      _segurando = null;
      _dy = 0;
    });
    if (passos == 0) return;
    // UMA MUTACAO SO, no fim.
    //
    // Chamar `reorderLayer` a cada degrau daria retorno imediato, mas
    // cada degrau viraria um lance de desfazer: arrastar cinco linhas
    // custaria cinco toques para voltar. O retorno durante o arrasto e
    // a linha de destino, desenhada; o projeto so muda quando o dedo
    // solta.
    ref.read(editorControllerProvider.notifier).reorderLayer(id, passos);
  }

  void _fecharArrasto() {
    if (_oQueFazer != _Arrasto.navegar) {
      ref.read(editorControllerProvider.notifier).endGesture();
    }
    _oQueFazer = _Arrasto.navegar;
    _clipe = null;
  }

  @override
  void initState() {
    super.initState();
    MediaPreviewService.instance.revision.addListener(_ondaPronta);
  }

  @override
  void dispose() {
    MediaPreviewService.instance.revision.removeListener(_ondaPronta);
    super.dispose();
  }

  /// A analise de um arquivo terminou: redesenhar.
  void _ondaPronta() {
    if (mounted) setState(() {});
  }

  /// AS ONDAS DAS CAMADAS QUE TEM SOM.
  ///
  /// A piramide ja existia inteira — seis niveis de detalhe, cache em
  /// disco, escolha de nivel por pixel (`peak_pyramid.dart`) — e nunca
  /// foi desenhada em lugar nenhum. Uma faixa de audio na linha do
  /// tempo era um retangulo liso: dava para ver ONDE o som esta, nunca
  /// O QUE ele e, que e o que faz alguem cortar no lugar certo.
  Map<String, PeakPyramid> _ondas(List<Layer> camadas) {
    final servico = MediaPreviewService.instance;
    final saida = <String, PeakPyramid>{};
    for (final l in camadas) {
      final caminho = switch (l) {
        AudioLayer a => a.sourcePath,
        VideoLayer v => v.sourcePath,
        _ => null,
      };
      if (caminho == null) continue;
      final p = servico.pyramidOf(caminho);
      if (p == null) {
        // PEDIR E BARATO E A RESPOSTA E GUARDADA: o servico devolve na
        // hora o que ja calculou e ignora o pedido repetido.
        servico.ensureWaveform(caminho);
        continue;
      }
      if (!p.isEmpty) saida[l.id] = p;
    }
    return saida;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final camadas = project.layers;
    if (camadas.isEmpty) return const SemCamadasNaLinhaDoTempo();

    final altura = camadas.length * VisaoGeralDasCamadas.alturaDaTrilha;
    final ondas = _ondas(camadas);
    final multi = ref.watch(multiSelectProvider);
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      // ARRASTAR NA PILHA NAVEGA NO TEMPO. O cabecote esta parado no
      // meio; quem anda e o conteudo, no mesmo sentido do dedo.
      //
      // O arrasto VERTICAL nao passa por aqui: ele desce para a lista,
      // que rola, ou para a alca, que reordena. Quem separa e a arena
      // de gestos, pela direcao do primeiro movimento.
      onHorizontalDragStart: (d) {
        widget.playback.pause();
        _tempoAoComecar = widget.playback.time.value;
        _xAoComecar = d.localPosition.dx;
        // UM ARRASTO, UM DESFAZER. Mover um clipe manda dezenas de
        // posicoes entre o toque e o solte; sem o grupo, desfazer
        // devolveria so o ultimo passo do movimento.
        if (_oQueFazer != _Arrasto.navegar) {
          ref.read(editorControllerProvider.notifier).beginGesture();
        }
      },
      onHorizontalDragUpdate: (d) {
        final mapa = widget.mapa(_tempoAoComecar);
        final andou = mapa.tempoDe(d.localPosition.dx - _xAoComecar);
        final id = _clipe;
        final c = ref.read(editorControllerProvider.notifier);
        switch (_oQueFazer) {
          case _Arrasto.navegar:
            widget.playback.seek(_tempoAoComecar - andou);
          case _Arrasto.mover:
            if (id != null) c.moveLayer(id, _inicioAoComecar + andou);
          case _Arrasto.apararInicio:
            if (id != null) c.trimLayerStart(id, _inicioAoComecar + andou);
          case _Arrasto.apararFim:
            if (id != null) c.trimLayerEnd(id, _fimAoComecar + andou);
        }
      },
      onHorizontalDragEnd: (_) => _fecharArrasto(),
      onHorizontalDragCancel: _fecharArrasto,
      child: SingleChildScrollView(
        child: SizedBox(
          height: altura,
          child: Listener(
            // O POUSO CRU, em coordenadas do CONTEUDO. Ele nao entra na
            // arena de gestos, entao nao rouba o toque de ninguem — so
            // anota onde o dedo caiu.
            onPointerDown: (e) =>
                _pousar(e.localPosition, camadas, selecionada),
            child: Stack(
            children: [
              // OS CLIPES SAO UM DESENHO SO.
              //
              // Antes cada trilha era um widget com o proprio pintor,
              // numa `ListView`. Com o cabecote parado e o conteudo
              // deslizando, TODAS as trilhas mudam a cada quadro — e
              // reconstruir vinte widgets por quadro para desenhar vinte
              // retangulos e pagar caro por nada.
              Positioned.fill(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: widget.playback.time,
                  builder: (context, t, _) => CustomPaint(
                    painter: _PintorDasTrilhas(
                      camadas: camadas,
                      mapa: widget.mapa(t),
                      selecionada: selecionada,
                      escondidas: {
                        for (final l in camadas)
                          if (project.metaOf(l.id).hidden) l.id,
                      },
                      travadas: {
                        for (final l in camadas)
                          if (project.metaOf(l.id).locked) l.id,
                      },
                      segurando: _segurando,
                      degraus: _segurando == null ? 0 : _degraus,
                      familia: familiaDoApp(context),
                      ondas: ondas,
                      juntas: multi,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
              // OS ALVOS DE SELECAO, uma faixa por camada. Ficam ENTRE o
              // desenho e as pilulas: o olho tem de ganhar do toque de
              // selecao, senao esconder uma camada tambem a selecionaria.
              Column(
                children: [
                  for (final l in camadas)
                    SizedBox(
                      // A CHAVE E O ENDERECO DA TRILHA.
                      //
                      // O nome da camada aparece em tres lugares na
                      // mesma linha — o desenho do clipe, a pilula e
                      // este alvo — e procurar por nome acha os tres.
                      key: ValueKey('trilha-${l.id}'),
                      height: VisaoGeralDasCamadas.alturaDaTrilha,
                      child: Semantics(
                        button: true,
                        selected:
                            l.id == selecionada || multi.contains(l.id),
                        label: l.name,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // TOQUE LONGO JUNTA CAMADAS.
                          //
                          // `multiSelectProvider` existia desde sempre e
                          // era so LIMPO, nunca preenchido: nao havia
                          // gesto que pusesse duas camadas no conjunto,
                          // e por isso agrupar varias, alinhar,
                          // distribuir, escalonar e as acoes em lote
                          // ficavam todas sem porta.
                          //
                          // O toque longo e o gesto que sobrava aqui: o
                          // simples ja escolhe e abre, e o arrasto ja
                          // navega no tempo.
                          onLongPress: () {
                            final atual = {
                              ...ref.read(multiSelectProvider),
                            };
                            // A PRIMEIRA JUNCAO LEVA A SELECIONADA
                            // JUNTO. Sem isso, segurar a segunda camada
                            // deixaria o conjunto com uma so — e a
                            // pessoa veria "1 camada" depois de mandar
                            // juntar duas.
                            if (atual.isEmpty && selecionada != null) {
                              atual.add(selecionada);
                            }
                            if (!atual.add(l.id)) atual.remove(l.id);
                            ref.read(multiSelectProvider.notifier).state =
                                atual.length < 2 ? const {} : atual;
                            if (atual.length >= 2) {
                              abrirAcoesDaSelecao(ref);
                            }
                          },
                          // TOQUE DUPLO SAIU DAQUI DE PROPOSITO.
                          //
                          // Um `onDoubleTap` obriga o Flutter a segurar
                          // TODO toque simples por uns trezentos
                          // milissegundos, esperando o segundo — e o
                          // toque simples e o gesto mais comum desta
                          // vista.
                          //
                          // O PRIMEIRO TOQUE ESCOLHE, O SEGUNDO ABRE AS
                          // FERRAMENTAS daquela camada. Antes o segundo
                          // toque levava ao modo detalhado, mas o modo
                          // ja tem botao proprio no cabecalho — e o que
                          // some com a faixa do rodape e o caminho para
                          // as ferramentas, entao e ele que herda o
                          // gesto. E o mesmo do Alight: tocar na camada
                          // mostra o que da para fazer com ela.
                          onTap: () {
                            if (l.id == selecionada) {
                              abrirFerramentasDaCamada(ref);
                              return;
                            }
                            ref.read(selectedLayerProvider.notifier).state =
                                l.id;
                          },
                        ),
                      ),
                    ),
                ],
              ),
              // AS PILULAS FLUTUAM POR CIMA, presas a esquerda. Elas nao
              // rolam no tempo: saber se a camada esta visivel nao pode
              // depender de onde o conteudo dela parou.
              Column(
                children: [
                  for (final l in camadas)
                    SizedBox(
                      height: VisaoGeralDasCamadas.alturaDaTrilha,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: PilulaDaCamada(
                          camada: l,
                          escondida: project.metaOf(l.id).hidden,
                          aoAlternarOlho: () => ref
                              .read(editorControllerProvider.notifier)
                              .toggleHidden(l.id),
                        ),
                      ),
                    ),
                ],
              ),
              // AS ALCAS, presas na direita. Elas ficam por ULTIMO para
              // ganhar do alvo de selecao que esta embaixo.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: VisaoGeralDasCamadas.larguraDaAlca,
                child: Column(
                  children: [
                    for (final l in camadas)
                      _AlcaDeOrdem(
                        nome: l.name,
                        segurando: _segurando == l.id,
                        aoPegar: () => setState(() {
                          _segurando = l.id;
                          _dy = 0;
                        }),
                        aoMover: (dy) => setState(() => _dy += dy),
                        aoSoltar: () => _soltarAlca(l.id),
                      ),
                  ],
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A ALCA DE ORDEM, na ponta direita de cada trilha.
///
/// Tres riscos, do tamanho exato da referencia. Ela so escuta arrasto
/// VERTICAL: o horizontal atravessa para quem esta atras e continua
/// navegando no tempo, como em qualquer outro ponto da pilha.
class _AlcaDeOrdem extends StatelessWidget {
  const _AlcaDeOrdem({
    required this.nome,
    required this.segurando,
    required this.aoPegar,
    required this.aoMover,
    required this.aoSoltar,
  });

  final String nome;
  final bool segurando;
  final VoidCallback aoPegar;
  final void Function(double dy) aoMover;
  final VoidCallback aoSoltar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: VisaoGeralDasCamadas.alturaDaTrilha,
    child: Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Mudar $nome de lugar',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => aoPegar(),
        onVerticalDragUpdate: (d) => aoMover(d.delta.dy),
        onVerticalDragEnd: (_) => aoSoltar(),
        onVerticalDragCancel: aoSoltar,
        child: Center(
          child: SizedBox(
            width: 14,
            height: 12,
            child: CustomPaint(painter: _PintorDaAlca(aceso: segurando)),
          ),
        ),
      ),
    ),
  );
}

class _PintorDaAlca extends CustomPainter {
  const _PintorDaAlca({required this.aceso});

  final bool aceso;

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()
      ..color = aceso
          ? AmColors.text
          : AmColors.muted.withValues(alpha: .45);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, i * 5.0, size.width, 1.6),
          const Radius.circular(1),
        ),
        tinta,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorDaAlca o) => o.aceso != aceso;
}

/// TODAS AS TRILHAS NUM PINTOR SO.
class _PintorDasTrilhas extends CustomPainter {
  const _PintorDasTrilhas({
    required this.camadas,
    required this.mapa,
    required this.selecionada,
    required this.escondidas,
    required this.travadas,
    required this.segurando,
    required this.degraus,
    required this.familia,
    required this.ondas,
    required this.juntas,
  });

  final List<Layer> camadas;
  final MapaDoTempo mapa;
  final String? selecionada;
  final Set<String> escondidas;

  /// Quem esta travada. O clipe leva um cadeado e o gesto nao pega.
  final Set<String> travadas;

  /// A camada presa pela alca, e quantos degraus ela vai andar se o dedo
  /// soltar agora.
  final String? segurando;
  final int degraus;

  /// A fonte do app — `TextPainter` nao herda nada sozinho.
  final TextStyle familia;

  /// A forma de onda por camada, quando ja analisada.
  final Map<String, PeakPyramid> ondas;

  /// As camadas juntadas por toque longo.
  final Set<String> juntas;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    const passo = VisaoGeralDasCamadas.alturaDaTrilha;
    const alto = VisaoGeralDasCamadas.alturaDoClipe;
    for (var i = 0; i < camadas.length; i++) {
      final l = camadas[i];
      final topo = i * passo + (passo - alto) / 2;
      final escondida = escondidas.contains(l.id);
      final inicio = mapa.xDe(l.startTime);
      final fim = mapa.xDe(l.endTime);
      final direita = fim <= inicio + 6 ? inicio + 6 : fim;
      // FORA DA VISTA NAO SE DESENHA.
      if (direita < 0 || inicio > size.width) continue;

      final barra = Rect.fromLTRB(inicio, topo, direita, topo + alto);
      final cor = corDaCamada(l);
      final rr = RRect.fromRectAndRadius(barra, const Radius.circular(5));
      canvas.drawRRect(
        rr,
        Paint()..color = escondida ? cor.withValues(alpha: .25) : cor,
      );

      canvas.save();
      canvas.clipRRect(rr);
      final onda = ondas[l.id];
      if (onda != null) _pintarOnda(canvas, l, barra, onda, escondida);
      _pintarNome(canvas, l, barra, cor, escondida);
      _pintarKeyframes(canvas, l, barra, cor);
      canvas.restore();

      if (travadas.contains(l.id)) _pintarCadeado(canvas, barra);
      // O ANEL VERDE DIZ "ESTA VAI JUNTO".
      //
      // Cor diferente da selecionada de propósito: a branca e a que as
      // ferramentas abrem, a verde e a que a acao em lote pega. As duas
      // podem valer ao mesmo tempo na mesma camada.
      if (juntas.contains(l.id)) {
        canvas.drawRRect(
          rr.inflate(1.5),
          Paint()
            ..color = AmColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (l.id == selecionada) {
        canvas.drawRRect(
          rr.inflate(1.5),
          Paint()
            ..color = AmColors.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        _pintarAlcasDeAparar(canvas, barra);
      }
    }
    _pintarDestinoDaOrdem(canvas, size);
  }

  /// A FORMA DE ONDA dentro do clipe.
  ///
  /// Duas camadas de desenho, e as duas sao necessarias:
  ///
  ///   - o CONTORNO (min..max) mostra o transiente, a batida seca que
  ///     uma media achataria;
  ///   - o CORPO (RMS) mostra o quao ALTO esta, que e o que o ouvido
  ///     percebe.
  ///
  /// So o contorno da uma mancha cheia; so o RMS, uma forma sem ataque.
  ///
  /// O tempo do desenho e o do ARQUIVO, e nao o do clipe: aparar o
  /// comeco tem de revelar outro pedaco da onda, e nao esticar a mesma.
  /// E por isso que `sourceOffset` e `speed` entram na conta.
  void _pintarOnda(
    Canvas canvas,
    Layer l,
    Rect barra,
    PeakPyramid onda,
    bool escondida,
  ) {
    final recuo = switch (l) {
      AudioLayer a => a.sourceOffset,
      VideoLayer v => v.sourceOffset,
      _ => Duration.zero,
    };
    final ritmo = switch (l) {
      AudioLayer a => a.speed,
      VideoLayer v => v.speed,
      _ => 1.0,
    };
    final segundosPorPixel = 1 / mapa.pxPorSegundo * (ritmo <= 0 ? 1 : ritmo);
    final nivel = onda.levelFor(segundosPorPixel);
    if (nivel.length == 0) return;

    final meio = barra.center.dy;
    final metade = barra.height / 2 - 2;
    final contorno = Paint()
      ..color = const Color(0xFF0B0E12).withValues(alpha: escondida ? .2 : .38);
    final corpo = Paint()
      ..color = const Color(0xFF0B0E12).withValues(alpha: escondida ? .3 : .62);

    final de = barra.left < 0 ? 0.0 : barra.left;
    final ate = barra.right;
    for (var x = de; x < ate; x += 1) {
      final noClipe = mapa.tempoEm(x) - l.startTime;
      if (noClipe < Duration.zero) continue;
      final noArquivo =
          recuo + Duration(microseconds: (noClipe.inMicroseconds * ritmo).round());
      final i = nivel.bucketAt(noArquivo);
      if (i < 0 || i >= nivel.length) continue;
      final alto = nivel.max[i].abs();
      final baixo = nivel.min[i].abs();
      final pico = (alto > baixo ? alto : baixo).clamp(0.0, 1.0) * metade;
      final rms = nivel.rms[i].clamp(0.0, 1.0) * metade;
      canvas.drawRect(Rect.fromLTRB(x, meio - pico, x + 1, meio + pico), contorno);
      if (rms > .5) {
        canvas.drawRect(Rect.fromLTRB(x, meio - rms, x + 1, meio + rms), corpo);
      }
    }
  }

  /// O CADEADO no canto do clipe travado.
  ///
  /// Pequeno e no canto: ele nao e um controle, e um aviso. Quem quiser
  /// destravar vai as ferramentas da camada, onde a linha inteira e
  /// alvo.
  void _pintarCadeado(Canvas canvas, Rect barra) {
    final centro = Offset(barra.right - 9, barra.center.dy);
    final tinta = Paint()..color = const Color(0xCC0B0E12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: centro, width: 7, height: 6),
        const Radius.circular(1.5),
      ),
      tinta,
    );
    canvas.drawArc(
      Rect.fromCenter(center: centro.translate(0, -4), width: 6, height: 7),
      3.14159,
      3.14159,
      false,
      Paint()
        ..color = const Color(0xCC0B0E12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  /// AS ALCAS DE APARAR, nas duas pontas do clipe escolhido.
  ///
  /// Elas so aparecem no escolhido porque so nele o arrasto apara — e um
  /// desenho de alca num clipe que nao responde seria uma promessa
  /// falsa. Sao dois tracinhos claros, do tamanho do alvo que o dedo
  /// tem de acertar.
  void _pintarAlcasDeAparar(Canvas canvas, Rect barra) {
    final tinta = Paint()..color = AmColors.text;
    for (final x in [barra.left + 4, barra.right - 4]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, barra.center.dy),
            width: 2.5,
            height: barra.height - 10,
          ),
          const Radius.circular(2),
        ),
        tinta,
      );
    }
  }

  /// A LINHA DE DESTINO do arrasto de ordem.
  ///
  /// E o unico retorno que o arrasto da enquanto o dedo esta na tela; a
  /// pilha so se reorganiza quando ele solta, para um degrau nao virar
  /// um lance de desfazer.
  void _pintarDestinoDaOrdem(Canvas canvas, Size size) {
    final id = segurando;
    if (id == null || degraus == 0) return;
    final de = camadas.indexWhere((l) => l.id == id);
    if (de < 0) return;
    final para = (de + degraus).clamp(0, camadas.length - 1);
    if (para == de) return;
    // A linha marca a BORDA para onde a camada vai: a de cima quando
    // sobe, a de baixo quando desce.
    final y =
        (degraus < 0 ? para : para + 1) * VisaoGeralDasCamadas.alturaDaTrilha;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 1.5, size.width, 3),
        const Radius.circular(2),
      ),
      Paint()..color = AmColors.action,
    );
  }

  /// OS KEYFRAMES SAO LOSANGOS DENTRO DO CLIPE, como na referencia.
  ///
  /// Eram riscos, e risco colado em risco vira barra listrada: visto no
  /// aparelho, uma cena 3D com dezenas de marcas ficava ilegivel e o
  /// nome da camada sumia debaixo delas. O espacamento minimo continua —
  /// a partir de certa densidade o que a marca diz e "ha muita animacao
  /// aqui", e para isso bastam algumas.
  void _pintarKeyframes(Canvas canvas, Layer l, Rect barra, Color cor) {
    final tinta = Paint()..color = sobreACorDaCamada(cor);
    var ultimoX = double.negativeInfinity;
    final raio = (barra.height / 2 - 6).clamp(3.0, 5.0);
    for (final t in l.keyframeTimes) {
      final quando = l.startTime + t;
      if (quando < l.startTime || quando > l.endTime) continue;
      final px = mapa.xDe(quando);
      if (px < barra.left - 2 || px > barra.right + 2) continue;
      if (px - ultimoX < raio * 2 + 2) continue;
      ultimoX = px;
      final cy = barra.center.dy;
      canvas.drawPath(
        Path()
          ..moveTo(px, cy - raio)
          ..lineTo(px + raio, cy)
          ..lineTo(px, cy + raio)
          ..lineTo(px - raio, cy)
          ..close(),
        tinta,
      );
    }
  }

  /// O NOME MORA DENTRO DO CLIPE, e some por baixo da pilula quando o
  /// clipe desliza para fora pela esquerda. E o que a referencia faz, e
  /// e honesto: o rotulo pertence a barra, e nao a tela.
  void _pintarNome(
    Canvas canvas,
    Layer l,
    Rect barra,
    Color cor,
    bool escondida,
  ) {
    if (barra.width < 22) return;
    final nome = TextPainter(
      text: TextSpan(
        text: l.name,
        style: familia.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: escondida ? sobreACorDaCamada(cor).withValues(alpha: .45) : sobreACorDaCamada(cor),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (barra.width - 12).clamp(0.0, double.infinity));
    nome.paint(
      canvas,
      Offset(barra.left + 6, barra.center.dy - nome.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PintorDasTrilhas o) =>
      o.familia != familia ||
      o.mapa.tempo != mapa.tempo ||
      o.mapa.pxPorSegundo != mapa.pxPorSegundo ||
      o.mapa.largura != mapa.largura ||
      o.selecionada != selecionada ||
      o.segurando != segurando ||
      o.degraus != degraus ||
      !identical(o.camadas, camadas) ||
      o.escondidas.length != escondidas.length ||
      o.travadas.length != travadas.length ||
      o.ondas.length != ondas.length ||
      o.juntas.length != juntas.length;
}

/// ESTADO VAZIO: projeto sem camada nenhuma.
///
/// Uma pilha vazia sem explicacao parece defeito. Dizer o que falta, e
/// onde, custa uma linha e evita a duvida.
class SemCamadasNaLinhaDoTempo extends StatelessWidget {
  const SemCamadasNaLinhaDoTempo({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        'Nenhuma camada neste projeto ainda.',
        key: const ValueKey('visao-geral-vazia'),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AmColors.muted, height: 1.4),
      ),
    ),
  );
}
