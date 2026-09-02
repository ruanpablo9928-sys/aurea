import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/mask.dart';
import '../../domain/shape.dart';
import '../../domain/shape_library.dart';
import '../am/am_colors.dart';

/// Ligado pelo "Desenho livre" do menu de adicionar: o proximo rabisco
/// no preview vira uma camada de forma (caminho aberto, so traco).
final freehandRequestProvider = StateProvider<bool>((ref) => false);

/// DESENHO LIVRE: cobre a composicao enquanto o pedido esta ligado,
/// acompanha o dedo com uma linha, e ao soltar simplifica o rabisco em
/// vertices suaves e cria a camada centrada no desenho.
class FreehandOverlay extends ConsumerStatefulWidget {
  const FreehandOverlay({super.key, required this.playback});

  final PlaybackController playback;

  @override
  ConsumerState<FreehandOverlay> createState() => _FreehandOverlayState();
}

class _FreehandOverlayState extends ConsumerState<FreehandOverlay> {
  final List<Offset> _pontos = [];

  void _fim() {
    final pts = List<Offset>.of(_pontos);
    _pontos.clear();
    ref.read(freehandRequestProvider.notifier).state = false;
    if (pts.length < 2) {
      setState(() {});
      return;
    }
    // Centro do desenho vira a posicao da camada; os vertices ficam
    // relativos a ele (e assim que toda forma vive na Aurea).
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final centro = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final caminho = freehandToPath([for (final p in pts) p - centro]);
    if (caminho.vertices.length < 2) {
      setState(() {});
      return;
    }
    final controller = ref.read(editorControllerProvider.notifier);
    final antes = {
      for (final l in ref.read(editorControllerProvider).layers) l.id
    };
    controller.addShapeLayer(
      widget.playback.time.value,
      contents: [
        ShapeBezier(path: AnimatedPath(caminho)),
        ShapeStroke(color: const Color(0xFFFFFFFF), width: 12),
      ],
      name: 'Desenho livre',
    );
    for (final l in ref.read(editorControllerProvider).layers) {
      if (!antes.contains(l.id)) {
        controller.editPosition(l.id, widget.playback.time.value, centro);
        break;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ligado = ref.watch(freehandRequestProvider);
    if (!ligado) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => setState(() => _pontos
        ..clear()
        ..add(d.localPosition)),
      onPanUpdate: (d) => setState(() => _pontos.add(d.localPosition)),
      onPanEnd: (_) => _fim(),
      onPanCancel: _fim,
      child: CustomPaint(
        painter: _RabiscoPainter(_pontos),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RabiscoPainter extends CustomPainter {
  const _RabiscoPainter(this.pontos);

  final List<Offset> pontos;

  @override
  void paint(Canvas canvas, Size size) {
    // Um veu leve avisa que o preview esta em modo de desenho.
    canvas.drawRect(Offset.zero & size,
        Paint()..color = AmColors.accent.withValues(alpha: 0.06));
    if (pontos.length < 2) return;
    final path = Path()..moveTo(pontos.first.dx, pontos.first.dy);
    for (final p in pontos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_RabiscoPainter old) => true;
}
