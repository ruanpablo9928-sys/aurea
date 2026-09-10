import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
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
///   - arrasto vertical .............. rola a lista de camadas
///   - arrasto na alca da direita .... muda a camada de lugar na pilha
///
/// O que NAO ha, de proposito: aparar ponta, mover clipe no tempo,
/// dividir, mexer em keyframe. Isso e do detalhado, ou de entregas que
/// ainda nao vieram.
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

class _VisaoGeralDasCamadasState extends ConsumerState<VisaoGeralDasCamadas> {
  Duration _tempoAoComecar = Duration.zero;
  double _xAoComecar = 0;

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

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final camadas = project.layers;
    if (camadas.isEmpty) return const SemCamadasNaLinhaDoTempo();

    final altura = camadas.length * VisaoGeralDasCamadas.alturaDaTrilha;
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
      },
      onHorizontalDragUpdate: (d) {
        final mapa = widget.mapa(_tempoAoComecar);
        widget.playback.seek(
          _tempoAoComecar - mapa.tempoDe(d.localPosition.dx - _xAoComecar),
        );
      },
      child: SingleChildScrollView(
        child: SizedBox(
          height: altura,
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
                      segurando: _segurando,
                      degraus: _segurando == null ? 0 : _degraus,
                      familia: familiaDoApp(context),
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
                      height: VisaoGeralDasCamadas.alturaDaTrilha,
                      child: Semantics(
                        button: true,
                        selected: l.id == selecionada,
                        label: l.name,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
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
    required this.segurando,
    required this.degraus,
    required this.familia,
  });

  final List<Layer> camadas;
  final MapaDoTempo mapa;
  final String? selecionada;
  final Set<String> escondidas;

  /// A camada presa pela alca, e quantos degraus ela vai andar se o dedo
  /// soltar agora.
  final String? segurando;
  final int degraus;

  /// A fonte do app — `TextPainter` nao herda nada sozinho.
  final TextStyle familia;

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
      _pintarNome(canvas, l, barra, cor, escondida);
      _pintarKeyframes(canvas, l, barra, cor);
      canvas.restore();

      if (l.id == selecionada) {
        canvas.drawRRect(
          rr.inflate(1.5),
          Paint()
            ..color = AmColors.text
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
    _pintarDestinoDaOrdem(canvas, size);
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
      o.escondidas.length != escondidas.length;
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
