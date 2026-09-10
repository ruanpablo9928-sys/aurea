import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/freehand_session.dart';
import '../../application/playback_controller.dart';
import '../../domain/keyframe.dart';
import '../../domain/mask.dart';
import '../../domain/shape.dart';

export '../../application/freehand_session.dart' show desenhoVetorialProvider;

/// A CANETA VETORIAL: um toque, um vertice.
///
/// `ensureShapeBezierGeometry` existia no motor com ZERO chamadores — a
/// forma vazia sabia nascer com um caminho e nao havia como pousar um
/// ponto nele. Esta camada e a porta.
///
/// Irma do desenho a mao livre e diferente dele: o traco livre segue o
/// dedo e depois e simplificado; a caneta coloca CANTOS exatos, um toque
/// por vertice, e quem decide quando fechar a forma e a pessoa. Sao as
/// duas entradas que a referencia poe lado a lado no seletor de
/// insercao — uma na faixa de cima, outra no trilho da direita.
///
/// Vive DENTRO do espaco de coordenadas da composicao, ao lado da
/// `CompositionView` e nunca dentro dela: o que se desenha aqui e ajuda
/// de tela, e ajuda de tela nao pode vazar para a exportacao.
class CanetaVetorialOverlay extends ConsumerStatefulWidget {
  const CanetaVetorialOverlay({super.key, required this.playback});

  final PlaybackController playback;

  @override
  ConsumerState<CanetaVetorialOverlay> createState() =>
      _CanetaVetorialOverlayState();
}

class _CanetaVetorialOverlayState extends ConsumerState<CanetaVetorialOverlay> {
  final List<Offset> _pontos = [];
  String? _projectId;
  Duration _startTime = Duration.zero;

  /// Fechar no primeiro ponto e o gesto que todo editor vetorial tem;
  /// este e o raio, em pixels da composicao, que conta como "no ponto".
  static const double _imaDoPrimeiro = 18;

  void _cancelar() {
    _projectId = null;
    if (mounted) setState(_pontos.clear);
    ref.read(desenhoVetorialProvider.notifier).state = false;
  }

  void _tocar(Offset p) {
    if (_pontos.isEmpty) {
      widget.playback.pause();
      _projectId = ref.read(editorControllerProvider).id;
      _startTime = widget.playback.time.value;
      setState(() => _pontos.add(p));
      return;
    }
    if (_pontos.length >= 3 && (p - _pontos.first).distance <= _imaDoPrimeiro) {
      _concluir(fechada: true);
      return;
    }
    setState(() => _pontos.add(p));
  }

  void _concluir({required bool fechada}) {
    // Um gesto interrompido pela troca de projeto nao pode gravar no
    // proximo.
    if (_projectId != ref.read(editorControllerProvider).id) {
      _cancelar();
      return;
    }
    final pts = List<Offset>.of(_pontos);
    _pontos.clear();
    _projectId = null;
    ref.read(desenhoVetorialProvider.notifier).state = false;
    if (pts.length < 2) {
      setState(() {});
      return;
    }
    // O centro do desenho vira a posicao da camada; os vertices ficam
    // relativos a ele, que e como toda forma vive na Aurea.
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final centro = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    // CANTOS DE VERDADE: tangentes zeradas. Uma caneta que arredondasse
    // sozinha nao seria uma caneta.
    final caminho = BezierPath(
      vertices: [
        for (final p in pts)
          PathVertex(p: p - centro, inT: Offset.zero, outT: Offset.zero),
      ],
      closed: fechada,
    );
    final c = ref.read(editorControllerProvider.notifier);
    final antes = {
      for (final l in ref.read(editorControllerProvider).layers) l.id,
    };
    c.addShapeLayer(
      _startTime,
      contents: [
        ShapeBezier(path: AnimatedPath(caminho)),
        if (fechada)
          ShapeFill(color: const Color(0xFFFFFFFF))
        else
          ShapeStroke(color: const Color(0xFFFFFFFF), width: AnimatedDouble(8)),
      ],
      name: 'Desenho vetorial',
    );
    for (final l in ref.read(editorControllerProvider).layers) {
      if (!antes.contains(l.id)) {
        c.editPosition(l.id, _startTime, centro);
        break;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(desenhoVetorialProvider, (_, ligado) {
      if (!ligado && _pontos.isNotEmpty) {
        _pontos.clear();
        _projectId = null;
      }
    });
    if (!ref.watch(desenhoVetorialProvider)) return const SizedBox.shrink();
    return Stack(
      children: [
        GestureDetector(
          key: const ValueKey('caneta-vetorial'),
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _tocar(d.localPosition),
          child: CustomPaint(
            painter: _CanetaPainter(_pontos),
            child: const SizedBox.expand(),
          ),
        ),
        // AS SAIDAS FICAM NA PROPRIA CAMADA DE DESENHO: sair sem gravar,
        // e gravar o que ja tem. Sem elas, um traco aberto de dois
        // pontos nao teria como virar camada.
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _BotaoDaCaneta(
                rotulo: 'Cancelar o desenho vetorial',
                texto: 'Cancelar',
                aoTocar: _cancelar,
              ),
              const SizedBox(width: 10),
              _BotaoDaCaneta(
                rotulo: 'Concluir o desenho vetorial',
                texto: 'Concluir',
                forte: true,
                aoTocar: _pontos.length >= 2
                    ? () => _concluir(fechada: false)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BotaoDaCaneta extends StatelessWidget {
  const _BotaoDaCaneta({
    required this.rotulo,
    required this.texto,
    required this.aoTocar,
    this.forte = false,
  });

  final String rotulo;
  final String texto;
  final VoidCallback? aoTocar;
  final bool forte;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: aoTocar != null,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: forte ? AmColors.action : AmColors.panelHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: FittedBox(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: forte
                  ? AmColors.onAction
                  : (aoTocar == null ? AmColors.muted : AmColors.text),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CanetaPainter extends CustomPainter {
  const _CanetaPainter(this.pontos);

  final List<Offset> pontos;

  @override
  void paint(Canvas canvas, Size size) {
    if (pontos.isEmpty) return;
    if (pontos.length >= 2) {
      final path = Path()..moveTo(pontos.first.dx, pontos.first.dy);
      for (final p in pontos.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final ponto = Paint()..color = AmColors.action;
    for (final p in pontos) {
      canvas.drawCircle(p, 9, ponto);
    }
  }

  @override
  bool shouldRepaint(_CanetaPainter old) => true;
}
