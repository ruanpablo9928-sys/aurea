import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
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

/// A LINHA DO TEMPO: UMA CAMADA POR VEZ.
///
/// A timeline anterior empilhava todas as camadas, e era o pedaço da
/// interface que mais dava problema — dez trilhas de quarenta pixels
/// numa tela de celular viram uma sopa onde nada e tocavel direito.
///
/// Esta segue o modelo do Alight Motion, que resolve isso ao contrario:
/// mostra a camada SELECIONADA, sozinha, ocupando a largura toda — e a
/// troca de camada e feita pelas setas nas pontas da propria trilha. O
/// dedo ganha uma faixa alta em vez de dez faixas finas.
///
/// O que a estrutura carrega:
///
///   - transporte em cima, com o play grande no meio;
///   - regua com marcas de tempo E os keyframes repetidos como riscos,
///     para eles continuarem visiveis mesmo com a trilha rolada;
///   - cabecote com o tempo numa capsula colada nele, que anda junto;
///   - trilha da camada com os keyframes em losango, e o losango sob o
///     cabecote destacado;
///   - coluna fixa a esquerda (olho e cor) que nao rola com a trilha.
class LinhaDoTempo extends ConsumerWidget {
  const LinhaDoTempo({super.key, required this.playback, this.aoExportar});

  final PlaybackController playback;

  /// Abrir a exportacao e NAVEGACAO, e navegacao e da tela — nao de um
  /// controle dentro dela. Por isso vem de fora.
  final VoidCallback? aoExportar;

  /// Altura do modo detalhado: transporte + regua + trilha.
  static const altura = 148.0;

  /// A altura que a linha do tempo ocupa, conforme o modo e quantas
  /// camadas ha para mostrar.
  static double alturaDoModo(ModoDaLinhaDoTempo modo, int camadas) =>
      modo == ModoDaLinhaDoTempo.detalhado
      ? altura
      : 48 + VisaoGeralDasCamadas.alturaPara(camadas);

  /// A largura da coluna fixa da esquerda (olho + cor da camada).
  static const larguraDaCabeca = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final modo = ref.watch(modoDaLinhaDoTempoProvider);
    final camadas = project.layers;
    final atual = camadas.where((l) => l.id == selecionada).firstOrNull;
    return SizedBox(
      height: alturaDoModo(modo, camadas.length),
      child: ColoredBox(
        color: AmColors.panel,
        child: Column(
          children: [
            _Transporte(
              playback: playback,
              duracao: project.duration,
              camadaSelecionada: selecionada,
              aoExportar: aoExportar,
              modo: modo,
            ),
            if (modo == ModoDaLinhaDoTempo.geral)
              Expanded(child: VisaoGeralDasCamadas(playback: playback))
            // A REFERENCIA TEMPORAL FICA, MESMO SEM CAMADAS.
            //
            // Regua e cabecote nao dependem de haver conteudo: dependem
            // de o projeto ter duracao. Some-los no projeto vazio tira a
            // unica pista de ONDE o conteudo novo vai entrar — e e
            // exatamente nesse momento que a pessoa precisa dela.
            //
            // Se a duracao nao for valida, dai sim nao ha regua que
            // desenhar, e a mensagem ocupa o lugar: inventar uma duracao
            // so para ter o que desenhar seria mentir sobre o projeto.
            else if (camadas.isEmpty && project.duration > Duration.zero)
              Expanded(
                child: _Faixa(
                  playback: playback,
                  duracao: project.duration,
                  camada: null,
                  escondida: false,
                  temAnterior: false,
                  temProxima: false,
                  aoMoverKeyframe: null,
                  aoApagarKeyframe: null,
                  aoTrocar: (_) {},
                  aoAlternarOlho: null,
                  aviso:
                      'Nenhuma camada ainda. O conteudo novo entra no '
                      'cabecote.',
                ),
              )
            else if (camadas.isEmpty)
              const Expanded(child: SemCamadasNaLinhaDoTempo())
            else if (atual == null)
              const Expanded(child: _SemSelecao())
            else
              Expanded(
                child: _Faixa(
                  playback: playback,
                  duracao: project.duration,
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
                  aoTrocar: (passo) {
                    final v = _vizinha(camadas, atual, passo);
                    if (v != null) {
                      ref.read(selectedLayerProvider.notifier).state = v.id;
                    }
                  },
                  aoAlternarOlho: () => ref
                      .read(editorControllerProvider.notifier)
                      .toggleHidden(atual.id),
                ),
              ),
          ],
        ),
      ),
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

/// A BARRA DE TRANSPORTE. O play e o maior alvo da barra, no meio, e os
/// saltos ficam do lado dele: e o gesto que a mao repete mais.
class _Transporte extends ConsumerWidget {
  const _Transporte({
    required this.playback,
    required this.duracao,
    required this.camadaSelecionada,
    required this.aoExportar,
    required this.modo,
  });

  final PlaybackController playback;
  final Duration duracao;
  final String? camadaSelecionada;
  final VoidCallback? aoExportar;
  final ModoDaLinhaDoTempo modo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(editorControllerProvider.notifier);
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            // O CAMINHO DE VOLTA ESTA SEMPRE AQUI. Trocar de vista e a
            // primeira pergunta — vem antes de qualquer acao sobre o
            // tempo —, e o mesmo botao leva e traz.
            _Botao(
              icone: modo == ModoDaLinhaDoTempo.geral
                  ? Icons.view_stream_rounded
                  : Icons.layers_rounded,
              destacado: modo == ModoDaLinhaDoTempo.geral,
              aoTocar: () =>
                  ref
                      .read(modoDaLinhaDoTempoProvider.notifier)
                      .state = modo == ModoDaLinhaDoTempo.geral
                  ? ModoDaLinhaDoTempo.detalhado
                  : ModoDaLinhaDoTempo.geral,
              rotulo: modo == ModoDaLinhaDoTempo.geral
                  ? 'Ver uma camada'
                  : 'Ver todas as camadas',
            ),
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
                tamanho: 34,
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
                  ref
                      .read(editorControllerProvider.notifier)
                      .duplicarCamada(id);
                }
              },
              rotulo: 'Duplicar camada',
            ),
            _Botao(
              icone: Icons.ios_share_rounded,
              ativo: aoExportar != null,
              aoTocar: () => aoExportar?.call(),
              rotulo: 'Exportar',
            ),
          ],
        ),
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
    this.tamanho = 24,
    this.destacado = false,
  });

  final IconData icone;
  final VoidCallback aoTocar;
  final String rotulo;
  final bool ativo;
  final double tamanho;

  /// Aceso: o controle diz que a vista dele e a que esta no ar.
  final bool destacado;

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
          height: 48,
          child: Icon(
            icone,
            size: tamanho,
            color: !ativo
                ? AmColors.muted.withValues(alpha: .4)
                : destacado
                ? AmColors.accent
                : AmColors.text,
          ),
        ),
      ),
    ),
  );
}

/// A REGUA E A TRILHA, que dividem a mesma largura e o mesmo mapa de
/// tempo — por isso vivem no mesmo widget.
class _Faixa extends StatefulWidget {
  const _Faixa({
    required this.playback,
    required this.duracao,
    required this.camada,
    required this.escondida,
    required this.temAnterior,
    required this.temProxima,
    required this.aoTrocar,
    required this.aoAlternarOlho,
    required this.aoMoverKeyframe,
    required this.aoApagarKeyframe,
    this.aviso,
  });

  final PlaybackController playback;
  final Duration duracao;
  final Layer? camada;
  final bool escondida;
  final bool temAnterior;
  final bool temProxima;
  final void Function(int passo) aoTrocar;
  final VoidCallback? aoAlternarOlho;
  final void Function(Duration de, Duration para)? aoMoverKeyframe;
  final void Function(Duration local)? aoApagarKeyframe;

  /// Texto no lugar da trilha, quando nao ha camada para desenhar. A
  /// regua e o cabecote continuam.
  final String? aviso;

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

  void _irPara(double dx, double largura) {
    if (largura <= 0) return;
    widget.playback.pause();
    widget.playback.seek(widget.duracao * (dx / largura).clamp(0.0, 1.0));
  }

  Duration _tempoEm(double dx, double largura) =>
      widget.duracao * (dx / largura).clamp(0.0, 1.0);

  /// O keyframe sob o dedo, em tempo LOCAL, ou nulo.
  ///
  /// A tolerancia e em PIXELS, e nao em tempo: o dedo tem o mesmo tamanho
  /// seja qual for a duracao da composicao. Dezoito pixels e o raio que
  /// deixa pegar o losango sem precisar de pontaria.
  Duration? _keyframeSobODedo(Offset ponto, double largura) {
    final l = widget.camada;
    if (l == null || largura <= 0) return null;
    if (ponto.dy < _PintorDaFaixa.topoDaTrilha - 8) return null;
    final us = widget.duracao.inMicroseconds;
    if (us <= 0) return null;
    Duration? melhor;
    var menorDistancia = double.infinity;
    for (final t in l.keyframeTimes) {
      final quando = l.startTime + t;
      if (quando < l.startTime || quando > l.endTime) continue;
      final px = largura * (quando.inMicroseconds / us).clamp(0.0, 1.0);
      final d = (px - ponto.dx).abs();
      if (d <= 18 && d < menorDistancia) {
        menorDistancia = d;
        melhor = t;
      }
    }
    return melhor;
  }

  /// O dedo pousou: so ESCOLHE, nao age. Se o toque acabar sendo das
  /// setas, nada aconteceu.
  void _pousar(Offset ponto, double largura) {
    _candidato = _keyframeSobODedo(ponto, largura);
  }

  /// TOCAR NUM KEYFRAME LEVA O CABECOTE ATE ELE. E o gesto que a mao faz
  /// sem pensar, e sem ele nao ha como cair exatamente em cima da marca
  /// para editar o valor dali.
  void _tocar(Offset ponto, double largura) {
    final l = widget.camada;
    final k = _candidato;
    if (k == null || l == null) {
      _irPara(ponto.dx, largura);
      return;
    }
    widget.playback.pause();
    widget.playback.seek(l.startTime + k);
  }

  /// O arrasto comecou: quem manda e a marca escolhida no pouso.
  void _comecarArrasto(Offset ponto, double largura) {
    final l = widget.camada;
    final k = _candidato;
    if (k == null || l == null || !l.podeArrastarKeyframeEm(k)) {
      _pego = null;
      _irPara(ponto.dx, largura);
      return;
    }
    _pego = k;
  }

  void _mover(Offset ponto, double largura) {
    final l = widget.camada;
    final pego = _pego;
    if (pego == null || l == null) {
      _irPara(ponto.dx, largura);
      return;
    }
    var destino = _tempoEm(ponto.dx, largura) - l.startTime;
    // A marca nao sai da propria camada.
    if (destino < Duration.zero) destino = Duration.zero;
    if (destino > l.duration) destino = l.duration;
    if (destino == pego) return;
    widget.aoMoverKeyframe?.call(pego, destino);
    _pego = destino;
    widget.playback.seek(l.startTime + destino);
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: LinhaDoTempo.larguraDaCabeca,
        child: _Cabeca(
          camada: widget.camada,
          escondida: widget.escondida,
          aoAlternarOlho: widget.aoAlternarOlho,
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, limites) {
            final largura = limites.maxWidth;
            return Listener(
              onPointerDown: (e) => _pousar(e.localPosition, largura),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _tocar(d.localPosition, largura),
                onHorizontalDragStart: (d) =>
                    _comecarArrasto(d.localPosition, largura),
                onHorizontalDragUpdate: (d) => _mover(d.localPosition, largura),
                onHorizontalDragEnd: (_) => _pego = null,
                onHorizontalDragCancel: () => _pego = null,
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
                            tempo: t,
                            duracao: widget.duracao,
                            camada: widget.camada,
                            escondida: widget.escondida,
                          ),
                        ),
                      ),
                      // O AVISO OCUPA A FAIXA DA TRILHA, e nao a regua.
                      // A referencia temporal continua inteira: o que
                      // falta e conteudo, e nao tempo.
                      if (widget.aviso != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _PintorDaFaixa.topoDaTrilha,
                          height: _PintorDaFaixa.alturaDaTrilha,
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
                      if (widget.temAnterior)
                        _Seta(
                          esquerda: true,
                          aoTocar: () => widget.aoTrocar(-1),
                        ),
                      if (widget.temProxima)
                        _Seta(
                          esquerda: false,
                          aoTocar: () => widget.aoTrocar(1),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

/// A SETA que troca de camada, na ponta da trilha. E o unico caminho
/// para mudar de camada aqui — como no Alight, a trilha e uma so.
class _Seta extends StatelessWidget {
  const _Seta({required this.esquerda, required this.aoTocar});

  final bool esquerda;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Positioned(
    left: esquerda ? 0 : null,
    right: esquerda ? null : 0,
    top: _PintorDaFaixa.topoDaTrilha,
    height: _PintorDaFaixa.alturaDaTrilha,
    child: Semantics(
      button: true,
      label: esquerda ? 'Camada anterior' : 'Proxima camada',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aoTocar,
        child: Container(
          width: 30,
          alignment: Alignment.center,
          color: AmColors.panel.withValues(alpha: .92),
          child: Icon(
            esquerda ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 20,
            color: AmColors.text,
          ),
        ),
      ),
    ),
  );
}

/// A COLUNA FIXA: olho e cor. Nao rola com a trilha, porque saber se a
/// camada esta visivel nao pode depender de onde a trilha parou.
class _Cabeca extends StatelessWidget {
  const _Cabeca({
    required this.camada,
    required this.escondida,
    required this.aoAlternarOlho,
  });

  final Layer? camada;
  final bool escondida;
  final VoidCallback? aoAlternarOlho;

  @override
  Widget build(BuildContext context) {
    if (camada == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: escondida ? 'Mostrar camada' : 'Esconder camada',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: aoAlternarOlho,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    escondida
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 19,
                    color: escondida ? AmColors.muted : AmColors.text,
                  ),
                ),
              ),
            ),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _PintorDaFaixa.corDe(camada!),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PintorDaFaixa extends CustomPainter {
  const _PintorDaFaixa({
    required this.tempo,
    required this.duracao,
    required this.camada,
    required this.escondida,
  });

  final Duration tempo;
  final Duration duracao;
  final Layer? camada;
  final bool escondida;

  static const topoDaTrilha = 46.0;
  static const alturaDaTrilha = 38.0;
  static const _baseDaRegua = 30.0;

  static Color corDe(Layer camada) => corDaCamada(camada);

  @override
  void paint(Canvas canvas, Size size) {
    final us = duracao.inMicroseconds;
    if (us <= 0 || size.width <= 0) return;
    double x(Duration t) =>
        size.width * (t.inMicroseconds / us).clamp(0.0, 1.0);

    _pintarRegua(canvas, size);
    final l = camada;
    if (l != null) _pintarTrilha(canvas, size, l, x);
    _pintarCabecote(canvas, size, x(tempo));
  }

  void _pintarRegua(Canvas canvas, Size size) {
    final segundos = duracao.inSeconds;
    if (segundos <= 0) return;
    // Nunca mais de uma marca a cada tres pixels: numa composicao longa
    // as marcas viram mancha e custam caro.
    var passo = ((segundos * 3) / size.width).ceil();
    if (passo < 1) passo = 1;
    final fino = Paint()..color = AmColors.muted.withValues(alpha: .35);
    final grosso = Paint()..color = AmColors.muted.withValues(alpha: .75);
    for (var s = 0; s <= segundos; s += passo) {
      final px = size.width * (s / segundos);
      final alta = s % (passo * 5) == 0;
      canvas.drawRect(
        Rect.fromLTWH(px, alta ? 14 : 20, 1, alta ? 12 : 6),
        alta ? grosso : fino,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, _baseDaRegua, size.width, 1),
      Paint()..color = AmColors.hairline,
    );
  }

  void _pintarTrilha(
    Canvas canvas,
    Size size,
    Layer l,
    double Function(Duration) x,
  ) {
    final inicio = x(l.startTime);
    final fim = x(l.endTime);
    final barra = Rect.fromLTRB(
      inicio,
      topoDaTrilha,
      fim <= inicio + 6 ? inicio + 6 : fim,
      topoDaTrilha + alturaDaTrilha,
    );
    final cor = corDe(l);
    final rr = RRect.fromRectAndRadius(barra, const Radius.circular(8));
    canvas.drawRRect(
      rr,
      Paint()..color = escondida ? cor.withValues(alpha: .28) : cor,
    );

    // O NOME dentro da barra, como no Alight: a barra ja e o rotulo.
    final nome = TextPainter(
      text: TextSpan(
        text: l.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: escondida
              ? AmColors.text.withValues(alpha: .5)
              : const Color(0xFF0B0E12),
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

    _pintarKeyframes(canvas, size, l, x, barra);
  }

  /// OS KEYFRAMES APARECEM DUAS VEZES: losango na trilha, e risco na
  /// regua. O risco existe porque a trilha de uma camada curta ocupa um
  /// pedaco pequeno da largura — sem ele, os keyframes sumiriam de vista
  /// junto com a barra.
  void _pintarKeyframes(
    Canvas canvas,
    Size size,
    Layer l,
    double Function(Duration) x,
    Rect barra,
  ) {
    final tempos = l.keyframeTimes;
    if (tempos.isEmpty) return;
    final naRegua = Paint()..color = AmColors.pink;
    final losango = Paint()..color = Colors.white;
    final sob = Paint()..color = AmColors.accent;
    final contorno = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    // Perto o bastante do cabecote para contar como "o keyframe atual".
    final tolerancia = duracao.inMicroseconds / size.width * 6;

    for (final t in tempos) {
      final quando = l.startTime + t;
      // FORA DA CAMADA NAO SE DESENHA. Um keyframe pode cair antes do
      // inicio ou depois do fim (a camada foi aparada, ou a marca nasceu
      // com o cabecote fora dela). Desenhado assim mesmo, ele aparece
      // solto no vazio, longe da barra a que pertence — parece sujeira,
      // e nao da para tocar nele.
      if (quando < l.startTime || quando > l.endTime) continue;
      final px = x(quando);
      canvas.drawRect(Rect.fromLTWH(px, 8, 1.4, 18), naRegua);

      final atual =
          (quando.inMicroseconds - tempo.inMicroseconds).abs() <= tolerancia;
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

  /// O CABECOTE LEVA O TEMPO JUNTO, numa capsula. Ler o tempo num canto
  /// fixo obriga o olho a ir e voltar; colado nele, a informacao esta
  /// onde a atencao ja esta.
  void _pintarCabecote(Canvas canvas, Size size, double px) {
    final texto = TextPainter(
      text: TextSpan(
        text: _relogio(tempo),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AmColors.text,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final larguraCapsula = texto.width + 14;
    var esquerda = px - larguraCapsula / 2;
    if (esquerda < 0) esquerda = 0;
    if (esquerda + larguraCapsula > size.width) {
      esquerda = size.width - larguraCapsula;
    }
    final capsula = RRect.fromRectAndRadius(
      Rect.fromLTWH(esquerda, 30, larguraCapsula, 17),
      const Radius.circular(5),
    );
    // A LINHA PRIMEIRO, a capsula por cima: senao o traco corta o
    // numero ao meio justamente quando ele importa.
    canvas.drawRect(
      Rect.fromLTWH(px - 1, 6, 2, size.height - 6),
      Paint()..color = AmColors.pink,
    );
    canvas.drawRRect(capsula, Paint()..color = AmColors.chip);
    texto.paint(canvas, Offset(esquerda + 7, 33));
  }

  static String _relogio(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final c = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(
      2,
      '0',
    );
    return '$m:$s:$c';
  }

  @override
  bool shouldRepaint(_PintorDaFaixa o) =>
      o.tempo != tempo ||
      o.duracao != duracao ||
      o.escondida != escondida ||
      !identical(o.camada, camada);
}

/// ESTADO VAZIO do modo detalhado: ha camadas, mas nenhuma escolhida.
///
/// A trilha vazia sozinha parece defeito. Dizer o que falta — e que a
/// visao geral resolve — custa duas linhas.
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
