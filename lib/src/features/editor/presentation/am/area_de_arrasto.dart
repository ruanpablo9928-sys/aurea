import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// AREA DE ARRASTO QUE GANHA DA ROLAGEM.
///
/// O dial de girar, o pad de mover e o de pivo vivem dentro de um painel
/// que rola. Um arrasto para cima e para baixo dentro deles era
/// entregue a ROLAGEM: quem reconhece arrasto vertical aceita o gesto
/// com 18 px de folga, e o arrasto livre (pan) so com 36 — a rolagem
/// chegava primeiro, sempre. O dial recebia so o comeco do movimento e
/// parava; na pratica, "nao gira".
///
/// Aqui o reconhecedor DECLARA VITORIA no toque: encostou dentro da
/// area, o gesto e dela, e a rolagem nem entra na disputa. Como isso
/// tira o toque simples e o duplo do caminho (a arena so tem um
/// vencedor), os dois voltam medidos aqui dentro: sem movimento e toque;
/// dois toques secos em menos de 300 ms e toque duplo.
class AreaDeArrasto extends StatefulWidget {
  const AreaDeArrasto({
    super.key,
    required this.child,
    this.onStart,
    this.onUpdate,
    this.onEnd,
    this.onTap,
    this.onDoubleTap,
    this.folgaDoToque = 8,
  });

  final Widget child;

  /// Posicao local em que o dedo pousou.
  final void Function(Offset local)? onStart;

  /// Posicao local agora, e quanto andou desde o quadro anterior.
  final void Function(Offset local, Offset delta)? onUpdate;
  final VoidCallback? onEnd;

  /// Toque seco (sem passar de [folgaDoToque]).
  final void Function(Offset local)? onTap;
  final VoidCallback? onDoubleTap;
  final double folgaDoToque;

  @override
  State<AreaDeArrasto> createState() => _AreaDeArrastoState();
}

class _AreaDeArrastoState extends State<AreaDeArrasto> {
  Offset _inicio = Offset.zero;
  Offset _ultimo = Offset.zero;
  double _andou = 0;
  DateTime? _toqueAnterior;

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _PanImediato: GestureRecognizerFactoryWithHandlers<_PanImediato>(
          _PanImediato.new,
          (r) {
            r
              ..onDown = (d) {
                _inicio = d.localPosition;
                _ultimo = d.localPosition;
                _andou = 0;
                widget.onStart?.call(d.localPosition);
              }
              ..onUpdate = (d) {
                _andou += d.delta.distance;
                _ultimo = d.localPosition;
                widget.onUpdate?.call(d.localPosition, d.delta);
              }
              ..onEnd = (_) {
                _solta();
              }
              ..onCancel = () {
                _solta();
              };
          },
        ),
      },
      child: widget.child,
    );
  }

  void _solta() {
    widget.onEnd?.call();
    if (_andou > widget.folgaDoToque) return;
    final agora = DateTime.now();
    final anterior = _toqueAnterior;
    _toqueAnterior = agora;
    if (widget.onDoubleTap != null &&
        anterior != null &&
        agora.difference(anterior) < const Duration(milliseconds: 320)) {
      _toqueAnterior = null;
      widget.onDoubleTap!.call();
      return;
    }
    widget.onTap?.call(_ultimo == Offset.zero ? _inicio : _ultimo);
  }
}

/// Aceita o ponteiro assim que ele encosta: quem esta por fora (a
/// rolagem do painel) perde a arena antes de comecar.
class _PanImediato extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
