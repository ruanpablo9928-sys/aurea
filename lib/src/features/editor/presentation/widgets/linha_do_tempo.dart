import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';

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
  const LinhaDoTempo({super.key, required this.playback});

  final PlaybackController playback;

  /// Altura total: transporte + regua + trilha.
  static const altura = 148.0;

  /// A largura da coluna fixa da esquerda (olho + cor da camada).
  static const larguraDaCabeca = 64.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final camadas = project.layers;
    final atual = camadas.where((l) => l.id == selecionada).firstOrNull;
    return SizedBox(
      height: altura,
      child: ColoredBox(
        color: AmColors.panel,
        child: Column(
          children: [
            _Transporte(playback: playback, duracao: project.duration),
            Expanded(
              child: _Faixa(
                playback: playback,
                duracao: project.duration,
                camada: atual,
                escondida:
                    atual != null && project.metaOf(atual.id).hidden,
                temAnterior: _vizinha(camadas, atual, -1) != null,
                temProxima: _vizinha(camadas, atual, 1) != null,
                aoTrocar: (passo) {
                  final v = _vizinha(camadas, atual, passo);
                  if (v != null) {
                    ref.read(selectedLayerProvider.notifier).state = v.id;
                  }
                },
                aoAlternarOlho: atual == null
                    ? null
                    : () => ref
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
  const _Transporte({required this.playback, required this.duracao});

  final PlaybackController playback;
  final Duration duracao;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(editorControllerProvider.notifier);
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
              icone: tocando
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
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
    this.tamanho = 24,
  });

  final IconData icone;
  final VoidCallback aoTocar;
  final String rotulo;
  final bool ativo;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: ativo ? aoTocar : null,
      child: SizedBox(
        // O ALVO TEM 48 px MESMO COM O ICONE MENOR. Botao de transporte
        // e apertado com o polegar, muitas vezes seguidas.
        width: 48,
        height: 48,
        child: Icon(
          icone,
          size: tamanho,
          color: ativo ? AmColors.text : AmColors.muted.withValues(alpha: .4),
        ),
      ),
    ),
  );
}

/// A REGUA E A TRILHA, que dividem a mesma largura e o mesmo mapa de
/// tempo — por isso vivem no mesmo widget.
class _Faixa extends StatelessWidget {
  const _Faixa({
    required this.playback,
    required this.duracao,
    required this.camada,
    required this.escondida,
    required this.temAnterior,
    required this.temProxima,
    required this.aoTrocar,
    required this.aoAlternarOlho,
  });

  final PlaybackController playback;
  final Duration duracao;
  final Layer? camada;
  final bool escondida;
  final bool temAnterior;
  final bool temProxima;
  final void Function(int passo) aoTrocar;
  final VoidCallback? aoAlternarOlho;

  void _irPara(double dx, double largura) {
    if (largura <= 0) return;
    playback.pause();
    playback.seek(duracao * (dx / largura).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: LinhaDoTempo.larguraDaCabeca,
        child: _Cabeca(
          camada: camada,
          escondida: escondida,
          aoAlternarOlho: aoAlternarOlho,
        ),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (context, limites) {
            final largura = limites.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _irPara(d.localPosition.dx, largura),
              onHorizontalDragStart: (d) =>
                  _irPara(d.localPosition.dx, largura),
              onHorizontalDragUpdate: (d) =>
                  _irPara(d.localPosition.dx, largura),
              child: ValueListenableBuilder<Duration>(
                valueListenable: playback.time,
                builder: (context, t, _) => Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _PintorDaFaixa(
                          tempo: t,
                          duracao: duracao,
                          camada: camada,
                          escondida: escondida,
                        ),
                      ),
                    ),
                    if (temAnterior)
                      _Seta(
                        esquerda: true,
                        aoTocar: () => aoTrocar(-1),
                      ),
                    if (temProxima)
                      _Seta(
                        esquerda: false,
                        aoTocar: () => aoTrocar(1),
                      ),
                  ],
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
            esquerda
                ? Icons.chevron_left_rounded
                : Icons.chevron_right_rounded,
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

  /// A COR DIZ O TIPO. Sem miniatura — a maior parte das camadas do
  /// Aurea (texto, forma, cena 3D) nao tem quadro para miniaturar, e
  /// gerar miniatura de video custa caro no aparelho.
  static Color corDe(Layer camada) => switch (camada) {
    TextLayer() => AmColors.selection,
    Scene3DLayer() => AmColors.accent,
    ShapeLayer() => AmColors.tealBright,
    _ => AmColors.teal,
  };

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
    final c = (d.inMilliseconds.remainder(1000) ~/ 10)
        .toString()
        .padLeft(2, '0');
    return '$m:$s:$c';
  }

  @override
  bool shouldRepaint(_PintorDaFaixa o) =>
      o.tempo != tempo ||
      o.duracao != duracao ||
      o.escondida != escondida ||
      !identical(o.camada, camada);
}
