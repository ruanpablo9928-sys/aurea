import 'dart:ui' as ui;

// O Material tambem tem um `Easing`, e nao e o nosso: o nosso guarda os
// pontos de controle que o motor usa. Esconder o de la evita a duvida.
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
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
const _presets = <(String, Easing)>[
  ('Linear', Easing.linear),
  ('Suave', Easing.easeInOut),
  ('Entra', Easing.easeIn),
  ('Sai', Easing.easeOut),
  ('Passa', Easing.overshoot),
  ('Quica', Easing.bounce),
  ('Elastico', Easing.elastic),
];

/// O EDITOR DE CURVA.
///
/// Um keyframe diz ONDE a propriedade chega; a curva diz COMO ela chega.
/// Sem ela, tudo que se anima no app se move em velocidade constante — e
/// velocidade constante e o que separa uma animacao de um deslizamento.
///
/// O DESENHO E O CONTRATO: o quadrado e o trecho entre duas marcas, o
/// eixo horizontal e o tempo e o vertical e o valor. A diagonal e a
/// velocidade constante; qualquer barriga para fora dela e aceleracao.
/// Duas alcas movem os pontos de controle da bezier, e sao os MESMOS
/// numeros que o motor usa (`x1,y1,x2,y2`) — o desenho nao aproxima
/// nada.
///
/// Os tipos que nao sao bezier (quica, elastico, mola) aparecem
/// desenhados mas SEM alca: os numeros deles nao sao pontos de controle,
/// e fingir que sao seria mentir sobre o que o dedo esta movendo.
class EditorDeCurva extends ConsumerStatefulWidget {
  const EditorDeCurva({super.key});

  @override
  ConsumerState<EditorDeCurva> createState() => _EditorDeCurvaState();
}

class _EditorDeCurvaState extends ConsumerState<EditorDeCurva> {
  /// A curva sob o dedo. Enquanto o gesto corre ela e a verdade; ao
  /// soltar, vira comando.
  Easing? _rascunho;

  @override
  Widget build(BuildContext context) {
    final aberta = ref.watch(curvaEmEdicaoProvider);
    if (aberta == null) return const SizedBox.shrink();
    final curva = _rascunho ?? aberta.atual;

    void fechar() {
      _rascunho = null;
      ref.read(curvaEmEdicaoProvider.notifier).state = null;
    }

    void aplicar(Easing e) {
      setState(() => _rascunho = e);
      aberta.aoAplicar(e);
    }

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Fechar',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: fechar,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: ColoredBox(color: Colors.black.withValues(alpha: .45)),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AmColors.panelHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AmColors.hairline),
                  ),
                  // QUEM ENCOLHE E O QUADRO, e nao a caixa toda.
                  //
                  // Numa tela baixa — celular deitado, janela pequena —
                  // o quadro mais os presets passam da altura. Rolar
                  // resolveria o desenho e quebraria o gesto: a rolagem
                  // vertical brigaria com o arrasto da alca, e a alca
                  // perderia. Entao o quadro cede altura e o resto fica.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Cabecalho(titulo: aberta.titulo, aoFechar: fechar),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: AspectRatio(
                            aspectRatio: 1.35,
                              child: _Quadro(curva: curva, aoMover: aplicar),
                          ),
                        ),
                      ),
                      _Presets(atual: curva, aoEscolher: aplicar),
                      if (aberta.aoAplicarEmTodos != null)
                        _Rodape(
                          aoTodos: () {
                            aberta.aoAplicarEmTodos!(curva);
                            fechar();
                          },
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.titulo, required this.aoFechar});

  final String titulo;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Curva · $titulo',
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
          label: 'Fechar a curva',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoFechar,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.close_rounded, size: 20, color: AmColors.muted),
            ),
          ),
        ),
      ],
    ),
  );
}

/// O QUADRO com a curva e as duas alcas.
///
/// A ALCA PRESA MORA AQUI, e nao no pai. Ela morava la, e o defeito era
/// silencioso: `onPanStart` pegava a alca com `setState` e mexia nela na
/// linha seguinte — mas o `setState` so chega no quadro SEGUINTE, entao o
/// primeiro movimento do dedo era sempre descartado. No aparelho isso
/// virava uma alca que so obedece depois de um tranco; num gesto curto,
/// uma alca que nao obedece nunca.
class _Quadro extends StatefulWidget {
  const _Quadro({required this.curva, required this.aoMover});

  final Easing curva;
  final void Function(Easing) aoMover;

  /// Onde a alca [i] cai dentro de um quadro de [tamanho].
  static Offset pontoDaAlca(Easing c, int i, Size tamanho) {
    final x = i == 0 ? c.x1 : c.x2;
    final y = i == 0 ? c.y1 : c.y2;
    return Offset(x * tamanho.width, (1 - y) * tamanho.height);
  }

  @override
  State<_Quadro> createState() => _QuadroState();
}

class _QuadroState extends State<_Quadro> {
  int? _presa;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final curva = widget.curva;
      final tamanho = Size(limites.maxWidth, limites.maxHeight);
      final bezier = curva.type == EasingType.cubicBezier;

      void mover(Offset p) {
        final i = _presa;
        if (i == null) return;
        final x = (p.dx / tamanho.width).clamp(0.0, 1.0);
        // O VALOR PASSA DE 0..1 DE PROPOSITO: e assim que se faz um
        // exagero, aquele passar do ponto e voltar. Meio quadro para
        // cada lado e o quanto cabe sem o desenho sair da moldura.
        final y = (1 - p.dy / tamanho.height).clamp(-0.5, 1.5);
        widget.aoMover(
          i == 0
              ? curva.copyWith(x1: x, y1: y)
              : curva.copyWith(x2: x, y2: y),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          if (!bezier) return;
          // A ALCA MAIS PERTO DO DEDO. Sem isso, pegar a de baixo num
          // canto onde as duas se encostam viraria loteria.
          final p = d.localPosition;
          final d0 = (_Quadro.pontoDaAlca(curva, 0, tamanho) - p).distance;
          final d1 = (_Quadro.pontoDaAlca(curva, 1, tamanho) - p).distance;
          _presa = d0 <= d1 ? 0 : 1;
          mover(p);
        },
        onPanUpdate: (d) => mover(d.localPosition),
        onPanEnd: (_) => _presa = null,
        onPanCancel: () => _presa = null,
        child: CustomPaint(
          key: const ValueKey('quadro-da-curva'),
          painter: _PintorDaCurva(curva: curva, comAlcas: bezier),
          size: Size.infinite,
        ),
      );
    },
  );
}

class _PintorDaCurva extends CustomPainter {
  const _PintorDaCurva({required this.curva, required this.comAlcas});

  final Easing curva;
  final bool comAlcas;

  @override
  void paint(Canvas canvas, Size size) {
    final fundo = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    canvas.drawRRect(fundo, Paint()..color = AmColors.bg);

    // A GRADE: quatro linhas, so para o olho medir. Mais que isso vira
    // papel milimetrado e some com a curva.
    final grade = Paint()..color = AmColors.hairline;
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      final y = size.height * i / 4;
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), grade);
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), grade);
    }

    // A DIAGONAL e a velocidade constante — a referencia contra a qual
    // toda curva e lida.
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, 0),
      Paint()
        ..color = AmColors.muted.withValues(alpha: .35)
        ..strokeWidth = 1,
    );

    // A CURVA SAI DO MOTOR, e nao de uma formula parecida desenhada
    // aqui. Se o desenho e a animacao discordarem, o desenho mente — e
    // e o desenho que a pessoa usa para decidir.
    final caminho = Path();
    for (var i = 0; i <= 96; i++) {
      final t = i / 96;
      final v = curva.transform(t);
      final p = Offset(t * size.width, (1 - v) * size.height);
      i == 0 ? caminho.moveTo(p.dx, p.dy) : caminho.lineTo(p.dx, p.dy);
    }
    canvas.save();
    canvas.clipRRect(fundo);
    canvas.drawPath(
      caminho,
      Paint()
        ..color = AmColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    if (!comAlcas) return;
    final inicio = Offset(0, size.height);
    final fim = Offset(size.width, 0);
    for (var i = 0; i < 2; i++) {
      final p = _Quadro.pontoDaAlca(curva, i, size);
      canvas.drawLine(
        i == 0 ? inicio : fim,
        p,
        Paint()
          ..color = AmColors.text.withValues(alpha: .35)
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(p, 8, Paint()..color = AmColors.text);
      canvas.drawCircle(p, 4, Paint()..color = AmColors.panelHigh);
    }
  }

  @override
  bool shouldRepaint(_PintorDaCurva o) =>
      o.curva != curva || o.comAlcas != comAlcas;
}

class _Presets extends StatelessWidget {
  const _Presets({required this.atual, required this.aoEscolher});

  final Easing atual;
  final void Function(Easing) aoEscolher;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        for (final (nome, e) in _presets)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              selected: e == atual,
              label: nome,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => aoEscolher(e),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: e == atual ? AmColors.accentDim : AmColors.chip,
                    borderRadius: BorderRadius.circular(9),
                    border: e == atual
                        ? Border.all(color: AmColors.accent)
                        : null,
                  ),
                  child: Text(
                    nome,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: e == atual ? AmColors.accent : AmColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Rodape extends StatelessWidget {
  const _Rodape({required this.aoTodos});

  final VoidCallback aoTodos;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: 'Aplicar em todos os trechos',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aoTodos,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AmColors.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'Aplicar em todos os trechos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AmColors.text,
            ),
          ),
        ),
      ),
    ),
  );
}
