import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../../domain/effect.dart';
import 'fx_lote2.dart';

/// Enlarges the actual filter input, so output beyond the original layer is
/// retained. A shader samples repeated tiles in one pass, including live video
/// on Impeller, without thousands of widget copies or CPU pixel readback.
class MotionTilePass extends StatefulWidget {
  const MotionTilePass({
    super.key,
    required this.effect,
    required this.time,
    required this.child,
  });
  final EffectInstance effect;
  final Duration time;
  final Widget child;
  @override
  State<MotionTilePass> createState() => _MotionTilePassState();
}

class _MotionTilePassState extends State<MotionTilePass> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? shader;
  Size? sourceSize;
  void measure(Size size) {
    if (size == sourceSize || size.isEmpty || !size.isFinite) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sourceSize != size) setState(() => sourceSize = size);
    });
  }

  @override
  void initState() {
    super.initState();
    (_program ??= ui.FragmentProgram.fromAsset('shaders/motion_tile.frag'))
        .then((p) {
          if (mounted) setState(() => shader = p.fragmentShader());
        })
        .catchError((Object e) {
          debugPrint('Motion Tile shader: $e');
        });
  }

  @override
  void dispose() {
    shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (shader == null || sourceSize == null) {
        return _Measure(onSize: measure, child: widget.child);
      }
      double p(String key) => widget.effect.paramAt(key, widget.time);
      final ow = (p('output_width') / 100).clamp(0.01, 6.0),
          oh = (p('output_height') / 100).clamp(0.01, 6.0);
      // Input must include the complete source, even for cropped (<100%) output.
      final ew = ow < 1 ? 1.0 : ow, eh = oh < 1 ? 1.0 : oh;
      final size = sourceSize!;
      final filter = ui.ImageFilter.isShaderFilterSupported;
      shader!
        ..setFloat(2, ew)
        ..setFloat(3, eh)
        ..setFloat(4, (p('tile_width') / 100).clamp(0.01, 3.0))
        ..setFloat(5, (p('tile_height') / 100).clamp(0.01, 3.0))
        ..setFloat(6, p('tile_center'))
        ..setFloat(7, p('tile_center_y'))
        ..setFloat(8, p('mirror_edges'))
        ..setFloat(9, p('phase') / 360)
        ..setFloat(10, p('horizontal_phase_shift'))
        ..setFloat(11, filter ? 1 : 0);
      final source = SizedBox(
        width: size.width * ew,
        height: size.height * eh,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BoundsPainter())),
            Center(
              child: UnconstrainedBox(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      );
      final rendered = filter
          ? ImageFiltered(
              imageFilter: ui.ImageFilter.shader(shader!),
              child: source,
            )
          : FxSnapshot(painter: _TileSnapshot(shader!), child: source);
      return SizedBox(
        width: size.width,
        height: size.height,
        child: OverflowBox(
          minWidth: size.width * ow,
          maxWidth: size.width * ow,
          minHeight: size.height * oh,
          maxHeight: size.height * oh,
          child: ClipRect(
            child: OverflowBox(
              minWidth: size.width * ew,
              maxWidth: size.width * ew,
              minHeight: size.height * eh,
              maxHeight: size.height * eh,
              child: rendered,
            ),
          ),
        ),
      );
    },
  );
}

class _BoundsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0x00000000),
    );
  }

  @override
  bool shouldRepaint(_BoundsPainter old) => false;
}

class _TileSnapshot extends SnapshotPainter {
  _TileSnapshot(this.shader);
  final ui.FragmentShader shader;
  @override
  bool shouldRepaint(_TileSnapshot old) => true;
  @override
  void paint(
    PaintingContext context,
    Offset offset,
    Size size,
    PaintingContextCallback painter,
  ) => painter(context, offset);
  @override
  void paintSnapshot(
    PaintingContext context,
    Offset offset,
    Size size,
    ui.Image image,
    Size sourceSize,
    double pixelRatio,
  ) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setImageSampler(0, image);
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    context.canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    context.canvas.restore();
  }
}

class _Measure extends SingleChildRenderObjectWidget {
  const _Measure({required this.onSize, required super.child});
  final ValueChanged<Size> onSize;
  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureBox(onSize);
  @override
  void updateRenderObject(BuildContext context, _MeasureBox renderObject) {
    renderObject.onSize = onSize;
  }
}

class _MeasureBox extends RenderProxyBox {
  _MeasureBox(this.onSize);
  ValueChanged<Size> onSize;
  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
