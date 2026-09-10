// O Material tambem tem um `Easing`, e nao e o nosso: o nosso guarda os
// pontos de controle que o motor usa. Esconder o de la evita a duvida.
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/keyframe.dart';

/// QUAL CURVA ESTA ABERTA PARA EDICAO.
///
/// Nula quando o editor esta fechado. Guarda o suficiente para o editor
/// saber em quem escrever sem conhecer camada, efeito nem propriedade —
/// ele so devolve a [Easing] escolhida, e quem abriu aplica.
@immutable
class CurvaEmEdicao {
  const CurvaEmEdicao({
    required this.titulo,
    required this.atual,
    required this.aoAplicar,
    this.aoAplicarEmTodos,
  });

  /// O que aparece no cabecalho: "Opacidade", "Posicao"...
  final String titulo;
  final Easing atual;

  /// Aplica no trecho aberto.
  final void Function(Easing) aoAplicar;

  /// Aplica em TODOS os trechos daquela propriedade. Nulo quando so ha
  /// um trecho — e ai o botao seria a mesma coisa que o outro.
  final void Function(Easing)? aoAplicarEmTodos;
}

final curvaEmEdicaoProvider = StateProvider<CurvaEmEdicao?>((ref) => null);

/// OS PRESETS, na ordem em que a mao costuma procurar.
const presetsDeCurva = <(String, Easing)>[
  ('Linear', Easing.linear),
  ('Suave', Easing.easeInOut),
  ('Entra', Easing.easeIn),
  ('Sai', Easing.easeOut),
  ('Passa do ponto', Easing.overshoot),
  ('Quica', Easing.bounce),
  ('Elastico', Easing.elastic),
];

/// O EDITOR DE CURVA.
///
/// Um keyframe diz ONDE a propriedade chega; a curva diz COMO ela chega.
/// Sem ela, tudo que se anima no app se move em velocidade constante — e
/// velocidade constante e o que separa uma animacao de um deslizamento.
///
/// ELE E UM PAINEL DE FERRAMENTA, e nao um modal desfocado. Era um
/// modal, e estava errado: desfocar a previa esconde justamente o que se
/// esta ajustando. Na referencia a previa continua a vista enquanto a
/// curva muda, porque a curva so faz sentido olhando o movimento que ela
/// produz (`docs/painel-de-transformacao-alight.md`, "O editor de
/// curva").
///
/// O DESENHO E O CONTRATO: o quadro e o trecho entre duas marcas, o eixo
/// horizontal e o tempo e o vertical e o valor. A diagonal e a
/// velocidade constante; qualquer barriga para fora dela e aceleracao.
/// Os dois botoes brancos movem os MESMOS numeros que o motor usa
/// (`x1,y1,x2,y2`) — o desenho nao aproxima nada, ele chama
/// `Easing.transform`.
///
/// Os tipos que nao sao bezier (quica, elastico, mola) aparecem
/// desenhados mas SEM botao: os numeros deles nao sao pontos de
/// controle, e fingir que sao seria mentir sobre o que o dedo move.
class EditorDeCurva extends ConsumerStatefulWidget {
  const EditorDeCurva({super.key});

  @override
  ConsumerState<EditorDeCurva> createState() => _EditorDeCurvaState();
}

class _EditorDeCurvaState extends ConsumerState<EditorDeCurva> {
  /// A curva sob o dedo. Enquanto o gesto corre ela e a verdade; ao
  /// soltar, ja virou comando.
  Easing? _rascunho;

  @override
  Widget build(BuildContext context) {
    final aberta = ref.watch(curvaEmEdicaoProvider);
    if (aberta == null) return const SizedBox.shrink();
    final curva = _rascunho ?? aberta.atual;

    void aplicar(Easing e) {
      setState(() => _rascunho = e);
      aberta.aoAplicar(e);
    }

    void fechar() {
      _rascunho = null;
      ref.read(curvaEmEdicaoProvider.notifier).state = null;
    }

    final iPreset = presetsDeCurva.indexWhere((p) => p.$2 == curva);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RailDaCurva(
          aoVoltar: fechar,
          aoTodos: aberta.aoAplicarEmTodos == null
              ? null
              : () {
                  aberta.aoAplicarEmTodos!(curva);
                  fechar();
                },
        ),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 8, 2),
                  child: _Quadro(
                    curva: curva,
                    aoMover: aplicar,
                    aoComecar: () => ref
                        .read(editorControllerProvider.notifier)
                        .beginGesture(),
                    aoTerminar: () => ref
                        .read(editorControllerProvider.notifier)
                        .endGesture(),
                  ),
                ),
              ),
              _NomeDoPreset(
                indice: iPreset,
                aoTrocar: (d) {
                  final n = presetsDeCurva.length;
                  final base = iPreset < 0 ? 0 : iPreset;
                  aplicar(presetsDeCurva[(base + d + n) % n].$2);
                },
              ),
            ],
          ),
        ),
        _RailDePresets(escolhido: iPreset, aoEscolher: aplicar),
      ],
    );
  }
}

/// O rail esquerdo da curva: voltar e "vale para todos".
class _RailDaCurva extends StatelessWidget {
  const _RailDaCurva({required this.aoVoltar, required this.aoTodos});

  final VoidCallback aoVoltar;
  final VoidCallback? aoTodos;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _BotaoDaCurva(
          icone: Icons.chevron_left_rounded,
          rotulo: 'Fechar a curva',
          tamanho: 24,
          aoTocar: aoVoltar,
        ),
        _BotaoDaCurva(
          icone: Icons.repeat_rounded,
          rotulo: 'Aplicar em todos os trechos',
          aoTocar: aoTodos,
        ),
      ],
    ),
  );
}

class _BotaoDaCurva extends StatelessWidget {
  const _BotaoDaCurva({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.tamanho = 20,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: aoTocar != null,
    enabled: aoTocar != null,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 46,
        height: 48,
        child: Icon(
          icone,
          size: tamanho,
          color: aoTocar == null
              ? AmColors.muted.withValues(alpha: .28)
              : AmColors.text,
        ),
      ),
    ),
  );
}

/// O nome da curva entre setas, embaixo do quadro.
///
/// Trocar de preset sem tirar o dedo da regiao — e o que a referencia
/// faz. A lista inteira esta no rail da direita; estas setas sao para
/// quem quer experimentar em ordem, sem escolher.
class _NomeDoPreset extends StatelessWidget {
  const _NomeDoPreset({required this.indice, required this.aoTrocar});

  final int indice;
  final void Function(int) aoTrocar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 34,
    child: Row(
      children: [
        _Seta(
          icone: Icons.chevron_left_rounded,
          rotulo: 'Curva anterior',
          aoTocar: () => aoTrocar(-1),
        ),
        Expanded(
          child: Text(
            indice < 0 ? 'Bezier ajustada a mao' : presetsDeCurva[indice].$1,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AmColors.muted,
            ),
          ),
        ),
        _Seta(
          icone: Icons.chevron_right_rounded,
          rotulo: 'Proxima curva',
          aoTocar: () => aoTrocar(1),
        ),
      ],
    ),
  );
}

class _Seta extends StatelessWidget {
  const _Seta({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Icon(icone, size: 18, color: AmColors.muted),
      ),
    ),
  );
}

/// O rail direito: uma miniatura por preset, cada uma desenhando a
/// PROPRIA curva.
///
/// Nome nao serve aqui: "quica" e "elastico" sao a mesma palavra para
/// quem nunca viu os dois. O desenho e o rotulo.
class _RailDePresets extends StatelessWidget {
  const _RailDePresets({required this.escolhido, required this.aoEscolher});

  final int escolhido;
  final void Function(Easing) aoEscolher;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: presetsDeCurva.length,
      itemBuilder: (context, i) {
        final (nome, e) = presetsDeCurva[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: i == escolhido,
            label: nome,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoEscolher(e),
              child: Container(
                width: 44,
                height: 40,
                decoration: BoxDecoration(
                  color: AmColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i == escolhido ? AmColors.accent : AmColors.hairline,
                  ),
                ),
                child: CustomPaint(painter: _Miniatura(curva: e)),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _Miniatura extends CustomPainter {
  const _Miniatura({required this.curva});

  final Easing curva;

  @override
  void paint(Canvas canvas, Size size) {
    const folga = 8.0;
    final r = Rect.fromLTWH(
      folga,
      folga,
      size.width - folga * 2,
      size.height - folga * 2,
    );
    final caminho = Path();
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final v = curva.transform(t);
      final p = Offset(r.left + t * r.width, r.bottom - v * r.height);
      i == 0 ? caminho.moveTo(p.dx, p.dy) : caminho.lineTo(p.dx, p.dy);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      caminho,
      Paint()
        ..color = AmColors.text
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Miniatura o) => o.curva != curva;
}

/// O QUADRO com a curva e os dois botoes de controle.
///
/// O BOTAO PRESO MORA AQUI, e nao no pai. Morava la, e o defeito era
/// silencioso: `onPanStart` pegava o botao com `setState` e mexia nele na
/// linha seguinte — mas `setState` so chega no quadro SEGUINTE, entao o
/// primeiro movimento do dedo era sempre descartado. Num gesto curto, o
/// botao nao obedecia nunca.
class _Quadro extends StatefulWidget {
  const _Quadro({
    required this.curva,
    required this.aoMover,
    required this.aoComecar,
    required this.aoTerminar,
  });

  final Easing curva;
  final void Function(Easing) aoMover;

  /// Abrem e fecham o lote de desfazer. Sem eles, arrastar um botao da
  /// curva produzia dezenas de passos, e um toque em desfazer devolvia
  /// so a ultima fracao do movimento.
  final VoidCallback aoComecar;
  final VoidCallback aoTerminar;

  /// Onde o botao [i] cai dentro de um quadro de [tamanho].
  static Offset pontoDoBotao(Easing c, int i, Size tamanho) {
    final x = i == 0 ? c.x1 : c.x2;
    final y = i == 0 ? c.y1 : c.y2;
    return Offset(x * tamanho.width, (1 - y) * tamanho.height);
  }

  @override
  State<_Quadro> createState() => _QuadroState();
}

class _QuadroState extends State<_Quadro> {
  int? _preso;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final curva = widget.curva;
      final tamanho = Size(limites.maxWidth, limites.maxHeight);
      final bezier = curva.type == EasingType.cubicBezier;

      void mover(Offset p) {
        final i = _preso;
        if (i == null) return;
        final x = (p.dx / tamanho.width).clamp(0.0, 1.0);
        // O VALOR PASSA DE 0..1 DE PROPOSITO: e assim que se faz um
        // exagero, aquele passar do ponto e voltar. Meio quadro para
        // cada lado e o quanto cabe sem o desenho sair da moldura.
        final y = (1 - p.dy / tamanho.height).clamp(-0.5, 1.5);
        widget.aoMover(
          i == 0 ? curva.copyWith(x1: x, y1: y) : curva.copyWith(x2: x, y2: y),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          if (!bezier) return;
          // O BOTAO MAIS PERTO DO DEDO. Sem isso, pegar o de baixo num
          // canto onde os dois se encostam viraria loteria.
          final p = d.localPosition;
          final d0 = (_Quadro.pontoDoBotao(curva, 0, tamanho) - p).distance;
          final d1 = (_Quadro.pontoDoBotao(curva, 1, tamanho) - p).distance;
          _preso = d0 <= d1 ? 0 : 1;
          widget.aoComecar();
          mover(p);
        },
        onPanUpdate: (d) => mover(d.localPosition),
        onPanEnd: (_) {
          _preso = null;
          widget.aoTerminar();
        },
        onPanCancel: () {
          _preso = null;
          widget.aoTerminar();
        },
        child: CustomPaint(
          key: const ValueKey('quadro-da-curva'),
          painter: _PintorDaCurva(curva: curva, comBotoes: bezier),
          size: Size.infinite,
        ),
      );
    },
  );
}

class _PintorDaCurva extends CustomPainter {
  const _PintorDaCurva({required this.curva, required this.comBotoes});

  final Easing curva;
  final bool comBotoes;

  /// A GRADE E TRACEJADA, como na referencia — e nao continua.
  ///
  /// Linha cheia compete com a curva pelo olho; tracejada recua para o
  /// fundo e continua servindo de regua.
  void _tracejado(Canvas canvas, Offset a, Offset b, Paint tinta) {
    const traco = 4.0;
    const vao = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final passo = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final fim = (d + traco).clamp(0.0, total);
      canvas.drawLine(a + passo * d, a + passo * fim, tinta);
      d = fim + vao;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final grade = Paint()
      ..color = AmColors.muted.withValues(alpha: .25)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      _tracejado(canvas, Offset(x, 0), Offset(x, size.height), grade);
      _tracejado(canvas, Offset(0, y), Offset(size.width, y), grade);
    }

    // A CURVA SAI DO MOTOR, e nao de uma formula parecida desenhada
    // aqui. Se o desenho e a animacao discordarem, o desenho mente — e e
    // o desenho que a pessoa usa para decidir.
    final caminho = Path();
    for (var i = 0; i <= 96; i++) {
      final t = i / 96;
      final v = curva.transform(t);
      final p = Offset(t * size.width, (1 - v) * size.height);
      i == 0 ? caminho.moveTo(p.dx, p.dy) : caminho.lineTo(p.dx, p.dy);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      caminho,
      Paint()
        ..color = AmColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    final inicio = Offset(0, size.height);
    final fim = Offset(size.width, 0);
    // OS PONTOS DAS PONTAS SAO AS MARCAS: e onde a propriedade tem valor
    // cravado, e e isso que a curva liga.
    final verde = Paint()..color = AmColors.accent;
    canvas.drawCircle(inicio, 5, verde);
    canvas.drawCircle(fim, 5, verde);

    if (!comBotoes) return;
    for (var i = 0; i < 2; i++) {
      final p = _Quadro.pontoDoBotao(curva, i, size);
      canvas.drawLine(
        i == 0 ? inicio : fim,
        p,
        Paint()
          ..color = AmColors.text.withValues(alpha: .5)
          ..strokeWidth = 2,
      );
      // BOTOES GRANDES: dezoito de raio, medido na referencia. E um
      // gesto de precisao feito com o dedo, e o dedo cobre o proprio
      // alvo — um ponto pequeno seria mira as cegas.
      canvas.drawCircle(p, 18, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PintorDaCurva o) =>
      o.curva != curva || o.comBotoes != comBotoes;
}
