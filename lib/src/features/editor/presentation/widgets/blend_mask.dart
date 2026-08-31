import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Aplica um BlendMode ao filho contra o que ja foi pintado por baixo
/// (saveLayer com Paint.blendMode).
class BlendMask extends SingleChildRenderObjectWidget {
  const BlendMask({
    super.key,
    required this.blendMode,
    super.child,
  });

  final BlendMode blendMode;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBlendMask(blendMode);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderBlendMask).blendMode = blendMode;
  }
}

class _RenderBlendMask extends RenderProxyBox {
  _RenderBlendMask(this._blendMode);

  BlendMode _blendMode;

  BlendMode get blendMode => _blendMode;
  set blendMode(BlendMode value) {
    if (_blendMode == value) return;
    _blendMode = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = _blendMode,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}
