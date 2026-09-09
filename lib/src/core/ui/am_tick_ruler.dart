import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'am_colors.dart';

// A REGUA DE ARRASTO, com marcas.
//
// Veio de `am/am_widgets.dart`, que foi apagado com o resto da UI de
// edicao. Ela sobreviveu porque a Autoedicao a usa e nao tem nada a ver
// com a tela do editor: e um controle de VALOR, nao uma peca da linha
// do tempo.

/// Regua de ticks arrastavel (scrub fino de valor): os ticks deslizam com o
/// valor e o indicador central fica fixo.
///
/// O arrasto ACUMULA desde o inicio do gesto: valor = valor no toque -
/// deslocamento total x sensibilidade. Aplicar cada delta em cima de
/// [value] parece igual, mas [value] so muda quando o dono reconstroi —
/// e chegam dois ou tres eventos de movimento por quadro. Cada evento
/// a mais no mesmo quadro era descartado: um arrasto rapido de 300 px
/// virava o ultimo deltazinho de 3 px, e a superficie de arrasto
/// parecia "nao pegar".
class AmTickRuler extends StatelessWidget {
  const AmTickRuler({
    super.key,
    required this.value,
    required this.onChanged,
    this.unitsPerPixel = 0.5,
    this.height = 64,
    this.accentCenter = true,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
    this.arrastavel = true,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// Sensibilidade do arrasto.
  final double unitsPerPixel;
  final double height;
  final bool accentCenter;
  final double min;
  final double max;

  /// FALSO quando quem arrasta e a linha inteira, e nao so esta faixa.
  ///
  /// Dois detectores de arrasto horizontal encaixados brigam na arena de
  /// gestos, e quem ganha e o de dentro — que e justamente o mais
  /// estreito. Desligando este, o dedo pega a linha toda.
  final bool arrastavel;

  @override
  Widget build(BuildContext context) {
    final visual = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TickRulerPainter(
          value: value,
          unitsPerPixel: unitsPerPixel,
          accentCenter: accentCenter,
        ),
      ),
    );
    if (!arrastavel) return visual;
    return AmArrastoDeValor(
      value: value,
      min: min,
      max: max,
      unitsPerPixel: unitsPerPixel,
      onChanged: onChanged,
      child: visual,
    );
  }
}

class _TickRulerPainter extends CustomPainter {
  const _TickRulerPainter({
    required this.value,
    required this.unitsPerPixel,
    required this.accentCenter,
  });

  final double value;
  final double unitsPerPixel;
  final bool accentCenter;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 9.0;
    final tick = Paint()
      ..color = const Color(0xFF43516A)
      ..strokeWidth = 1.6;
    final center = size.width / 2;
    // Ticks deslizam conforme o valor.
    final phase = (value / unitsPerPixel) % spacing;
    final pad = size.height * 0.18;
    for (var x = -phase; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, pad), Offset(x, size.height - pad), tick);
    }
    final indicator = Paint()
      ..color = accentCenter ? AmColors.accent : Colors.white
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(center, pad * 0.4),
      Offset(center, size.height - pad * 0.4),
      indicator,
    );
  }

  @override
  bool shouldRepaint(_TickRulerPainter old) =>
      old.value != value || old.accentCenter != accentCenter;
}

/// A SUPERFICIE DE ARRASTO de um numero — o gesto, sem desenho nenhum.
///
/// Separada da regua porque a superficie precisa ser MAIOR do que ela.
/// Numa tela de 375 px, a faixa de riscos da linha "Largura" sobrava com
/// vinte e tres pixels depois do losango, do rotulo e do valor: o beta
/// relatou "nao da pra mexer no botao de largura, so no de altura", e
/// estava certo — nao havia onde pegar. Envolvendo a linha inteira, o
/// alvo passa a ser a linha, e o rotulo e o espaco vazio tambem puxam.
class AmArrastoDeValor extends StatefulWidget {
  const AmArrastoDeValor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.child,
    this.unitsPerPixel = 0.5,
    this.min = double.negativeInfinity,
    this.max = double.infinity,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Widget child;
  final double unitsPerPixel;
  final double min;
  final double max;

  @override
  State<AmArrastoDeValor> createState() => _AmArrastoDeValorState();
}

class _AmArrastoDeValorState extends State<AmArrastoDeValor> {
  double _inicio = 0;
  double _acumulado = 0;

  /// UMA ENTREGA POR QUADRO. Chegam dois ou tres eventos de movimento
  /// por quadro, e cada entrega reconstroi o projeto inteiro (preview,
  /// timeline, painel). Entregar todos e pagar a reconstrucao tres
  /// vezes para mostrar um quadro so — e o que se sentia como
  /// microtravamento ao arrastar. O primeiro evento do quadro sai na
  /// hora; os seguintes ficam guardados e o ultimo sai logo depois do
  /// quadro pintar. Nada se perde: o valor final e sempre entregue.
  double? _pendente;
  bool _agendado = false;

  void _entregar(double v) {
    widget.onChanged(v);
  }

  void _descarregar() {
    final p = _pendente;
    _pendente = null;
    if (p != null) _entregar(p);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _inicio = widget.value;
        _acumulado = 0;
      },
      onHorizontalDragUpdate: (d) {
        _acumulado += d.delta.dx;
        final v = (_inicio - _acumulado * widget.unitsPerPixel).clamp(
          widget.min,
          widget.max,
        );
        if (_agendado) {
          _pendente = v;
          return;
        }
        _agendado = true;
        _entregar(v);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _agendado = false;
          if (mounted) _descarregar();
        });
      },
      onHorizontalDragEnd: (_) => _descarregar(),
      onHorizontalDragCancel: _descarregar,
      child: widget.child,
    );
  }
}
