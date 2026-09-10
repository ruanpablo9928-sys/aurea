import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'linha_do_tempo.dart';

/// COMO A LINHA DO TEMPO ESTA SENDO MOSTRADA.
///
/// Os dois modos respondem a perguntas diferentes, e por isso os dois
/// existem:
///
///   - DETALHADO: "o que esta acontecendo NESTA camada?" Uma trilha
///     alta, com os keyframes grandes o bastante para o dedo pegar.
///   - GERAL: "como as camadas se arrumam no tempo?" Todas empilhadas,
///     baixas, sem manipulacao.
///
/// O geral e uma VISTA, e nao um editor: nele nao se arrasta keyframe,
/// nao se apara, nao se reordena. Quem quiser mexer volta ao detalhado,
/// e o caminho de volta esta sempre a um toque.
enum ModoDaLinhaDoTempo { detalhado, geral }

/// O modo vigente. Vive so na sessao — guardar em disco seria migracao
/// de dados, e migracao esta fora deste pacote.
///
/// ABRE NO GERAL. A primeira pergunta de quem entra num projeto e "o que
/// tem aqui?", e quem responde e a pilha. O detalhado e o passo
/// seguinte: escolher uma camada e mexer nela.
final modoDaLinhaDoTempoProvider = StateProvider<ModoDaLinhaDoTempo>(
  (ref) => ModoDaLinhaDoTempo.geral,
);

/// A VISTA DE TODAS AS CAMADAS.
///
/// Reaproveita tudo que o modo detalhado ja usa: o mesmo projeto, o
/// mesmo relogio, a mesma selecao e os mesmos comandos. Nada aqui e
/// estado proprio — o que ela desenha e o que o editor ja sabe.
///
/// CONTRATO DE GESTOS (o mesmo escrito em
/// `docs/linha-do-tempo-gestos.md`):
///
///   - toque numa trilha ............. seleciona aquela camada
///   - toque na trilha JA escolhida .. abre ela no modo detalhado
///   - toque no olho ................. esconde ou mostra aquela camada
///   - toque na regua ................ leva o cabecote
///   - arrasto na regua .............. leva o cabecote
///
/// O que NAO ha, de proposito: arrastar barra, aparar ponta, reordenar,
/// mexer em keyframe. Tocar e arrastar sao os unicos gestos, e nenhum
/// deles muda o projeto sem passar pela selecao.
class VisaoGeralDasCamadas extends ConsumerStatefulWidget {
  const VisaoGeralDasCamadas({super.key, required this.playback});

  final PlaybackController playback;

  /// A altura de cada trilha na pilha. Baixa de proposito: aqui o que
  /// importa e ver MUITAS de uma vez.
  static const alturaDaTrilha = 40.0;

  /// Quantas trilhas cabem antes de a lista comecar a rolar. E o piso
  /// do calculo: com mais espaco, a tela manda uma altura maior e mais
  /// trilhas aparecem sem rolar.
  static const trilhasVisiveis = 4;

  static const alturaDaRegua = 28.0;

  /// A altura que a linha do tempo pede neste modo.
  static double alturaPara(int camadas) {
    final n = camadas.clamp(1, trilhasVisiveis);
    return alturaDaRegua + n * alturaDaTrilha;
  }

  @override
  ConsumerState<VisaoGeralDasCamadas> createState() =>
      _VisaoGeralDasCamadasState();
}

class _VisaoGeralDasCamadasState extends ConsumerState<VisaoGeralDasCamadas> {
  void _irPara(double dx, double largura, Duration duracao) {
    if (largura <= 0) return;
    widget.playback.pause();
    widget.playback.seek(duracao * (dx / largura).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selecionada = ref.watch(selectedLayerProvider);
    final camadas = project.layers;
    if (camadas.isEmpty) return const SemCamadasNaLinhaDoTempo();

    return LayoutBuilder(
      builder: (context, limites) {
        // UMA LISTA SO, com o olho DENTRO de cada linha.
        //
        // A primeira versao tinha duas listas lado a lado — olhos numa,
        // trilhas noutra — presas ao mesmo `ScrollController`. O Flutter
        // nao permite dois `ScrollView` no mesmo controlador, e o
        // resultado foi silencioso e pior que um erro: o alinhamento saiu
        // do lugar e os toques caiam na linha errada.
        final largura = limites.maxWidth - LinhaDoTempo.larguraDaCabeca;
        return Stack(
          children: [
            Column(
              children: [
                // A REGUA E A UNICA PARTE QUE LEVA O CABECOTE AO TOQUE.
                // Nas trilhas o toque seleciona; se as duas coisas
                // dividissem a area, uma roubaria a outra — e a que
                // perderia seria a selecao, que e o motivo desta vista.
                SizedBox(
                  height: VisaoGeralDasCamadas.alturaDaRegua,
                  child: Row(
                    children: [
                      const SizedBox(width: LinhaDoTempo.larguraDaCabeca),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _irPara(
                            d.localPosition.dx,
                            largura,
                            project.duration,
                          ),
                          onHorizontalDragStart: (d) => _irPara(
                            d.localPosition.dx,
                            largura,
                            project.duration,
                          ),
                          onHorizontalDragUpdate: (d) => _irPara(
                            d.localPosition.dx,
                            largura,
                            project.duration,
                          ),
                          child: CustomPaint(
                            painter: _PintorDaRegua(duracao: project.duration),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: camadas.length,
                    // ALTURA FIXA. Ja tentei estica-las para preencher
                    // o espaco e o resultado foi pior: com poucas
                    // camadas elas viravam blocos enormes, e o tamanho
                    // de uma trilha passava a depender de quantas
                    // existem — a mesma camada mudava de cara so porque
                    // outra foi criada.
                    //
                    // O espaco que sobra embaixo nao e desperdicio: e
                    // onde as proximas camadas entram.
                    itemExtent: VisaoGeralDasCamadas.alturaDaTrilha,
                    itemBuilder: (context, i) {
                      final l = camadas[i];
                      final escondida = project.metaOf(l.id).hidden;
                      return Row(
                        children: [
                          SizedBox(
                            width: LinhaDoTempo.larguraDaCabeca,
                            child: Semantics(
                              button: true,
                              label: escondida
                                  ? 'Mostrar ${l.name}'
                                  : 'Esconder ${l.name}',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => ref
                                    .read(editorControllerProvider.notifier)
                                    .toggleHidden(l.id),
                                child: Icon(
                                  escondida
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 17,
                                  color: escondida
                                      ? AmColors.muted
                                      : AmColors.text,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _TrilhaRasa(
                              camada: l,
                              duracao: project.duration,
                              selecionada: l.id == selecionada,
                              escondida: escondida,
                              aoSelecionar: () =>
                                  ref
                                          .read(selectedLayerProvider.notifier)
                                          .state =
                                      l.id,
                              aoAbrir: () {
                                ref.read(selectedLayerProvider.notifier).state =
                                    l.id;
                                ref
                                    .read(modoDaLinhaDoTempoProvider.notifier)
                                    .state = ModoDaLinhaDoTempo
                                    .detalhado;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            // O CABECOTE ATRAVESSA A PILHA INTEIRA: e o que deixa
            // comparar, num olhar, o que acontece em todas as camadas no
            // mesmo instante.
            Positioned(
              left: LinhaDoTempo.larguraDaCabeca,
              top: 0,
              bottom: 0,
              width: largura,
              child: IgnorePointer(
                child: ValueListenableBuilder<Duration>(
                  valueListenable: widget.playback.time,
                  builder: (context, t, _) => CustomPaint(
                    painter: _PintorDoCabecote(
                      tempo: t,
                      duracao: project.duration,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Uma camada na pilha: barra fina no tempo, com os keyframes como
/// riscos. Losango aqui nao caberia — e nao ha o que pegar de qualquer
/// forma, porque manipular keyframe e do modo detalhado.
class _TrilhaRasa extends StatelessWidget {
  const _TrilhaRasa({
    required this.camada,
    required this.duracao,
    required this.selecionada,
    required this.escondida,
    required this.aoSelecionar,
    required this.aoAbrir,
  });

  final Layer camada;
  final Duration duracao;
  final bool selecionada;
  final bool escondida;
  final VoidCallback aoSelecionar;
  final VoidCallback aoAbrir;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selecionada,
    label: camada.name,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      // TOQUE DUPLO SAIU DAQUI DE PROPOSITO.
      //
      // Um `onDoubleTap` obriga o Flutter a segurar TODO toque simples
      // por uns trezentos milissegundos, esperando o segundo — e o toque
      // simples e o gesto mais comum desta vista. Trocar trezentos
      // milissegundos de atraso em cada selecao por um atalho e um mau
      // negocio.
      //
      // Tocar na camada que JA esta selecionada abre ela no detalhado: o
      // primeiro toque escolhe, o segundo entra. Mesma economia de
      // gesto, sem atraso nenhum.
      onTap: selecionada ? aoAbrir : aoSelecionar,
      child: CustomPaint(
        painter: _PintorDaTrilhaRasa(
          camada: camada,
          duracao: duracao,
          selecionada: selecionada,
          escondida: escondida,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

class _PintorDaTrilhaRasa extends CustomPainter {
  const _PintorDaTrilhaRasa({
    required this.camada,
    required this.duracao,
    required this.selecionada,
    required this.escondida,
  });

  final Layer camada;
  final Duration duracao;
  final bool selecionada;
  final bool escondida;

  @override
  void paint(Canvas canvas, Size size) {
    final us = duracao.inMicroseconds;
    if (us <= 0 || size.width <= 0) return;
    double x(Duration t) =>
        size.width * (t.inMicroseconds / us).clamp(0.0, 1.0);

    final inicio = x(camada.startTime);
    final fim = x(camada.endTime);
    final barra = Rect.fromLTRB(
      inicio,
      5,
      fim <= inicio + 4 ? inicio + 4 : fim,
      size.height - 5,
    );
    final cor = corDaCamada(camada);
    final rr = RRect.fromRectAndRadius(barra, const Radius.circular(5));
    canvas.drawRRect(
      rr,
      Paint()..color = escondida ? cor.withValues(alpha: .25) : cor,
    );

    // OS RISCOS VEM ANTES DO NOME, e com espacamento minimo.
    //
    // Visto no aparelho: uma cena 3D com dezenas de keyframes virava uma
    // barra listrada, ilegivel, com o nome da camada coberto. Risco
    // colado em risco nao informa nada — a partir de certa densidade, o
    // que ele diz e "ha muita animacao aqui", e para isso bastam alguns.
    final risco = Paint()..color = Colors.white.withValues(alpha: .8);
    var ultimoX = double.negativeInfinity;
    for (final t in camada.keyframeTimes) {
      final quando = camada.startTime + t;
      if (quando < camada.startTime || quando > camada.endTime) continue;
      final px = x(quando);
      // Menos de quatro pixels do anterior: nao cabe, e nao acrescenta.
      if (px - ultimoX < 4) continue;
      ultimoX = px;
      canvas.drawRect(
        Rect.fromLTWH(px - .8, barra.top + 3, 1.6, barra.height - 6),
        risco,
      );
    }

    final nome = TextPainter(
      text: TextSpan(
        text: camada.name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: escondida
              ? AmColors.text.withValues(alpha: .45)
              : const Color(0xFF0B0E12),
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: (barra.width - 12).clamp(0.0, double.infinity));
    canvas.save();
    canvas.clipRRect(rr);
    nome.paint(canvas, Offset(barra.left + 6, barra.center.dy - 7));
    canvas.restore();

    if (selecionada) {
      canvas.drawRRect(
        rr.inflate(1.5),
        Paint()
          ..color = AmColors.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorDaTrilhaRasa o) =>
      !identical(o.camada, camada) ||
      o.duracao != duracao ||
      o.selecionada != selecionada ||
      o.escondida != escondida;
}

class _PintorDaRegua extends CustomPainter {
  const _PintorDaRegua({required this.duracao});

  final Duration duracao;

  @override
  void paint(Canvas canvas, Size size) {
    final segundos = duracao.inSeconds;
    if (segundos <= 0 || size.width <= 0) return;
    var passo = ((segundos * 3) / size.width).ceil();
    if (passo < 1) passo = 1;
    final fino = Paint()..color = AmColors.muted.withValues(alpha: .3);
    final grosso = Paint()..color = AmColors.muted.withValues(alpha: .7);
    for (var s = 0; s <= segundos; s += passo) {
      final px = size.width * (s / segundos);
      final alta = s % (passo * 5) == 0;
      canvas.drawRect(
        Rect.fromLTWH(px, alta ? 8 : 13, 1, alta ? 11 : 6),
        alta ? grosso : fino,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 1, size.width, 1),
      Paint()..color = AmColors.hairline,
    );
  }

  @override
  bool shouldRepaint(_PintorDaRegua o) => o.duracao != duracao;
}

class _PintorDoCabecote extends CustomPainter {
  const _PintorDoCabecote({required this.tempo, required this.duracao});

  final Duration tempo;
  final Duration duracao;

  @override
  void paint(Canvas canvas, Size size) {
    final us = duracao.inMicroseconds;
    if (us <= 0) return;
    final px = size.width * (tempo.inMicroseconds / us).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(px - 1, 0, 2, size.height),
      Paint()..color = AmColors.pink,
    );
  }

  @override
  bool shouldRepaint(_PintorDoCabecote o) =>
      o.tempo != tempo || o.duracao != duracao;
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
