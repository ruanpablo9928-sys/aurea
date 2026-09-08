import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

import '../../domain/effect.dart';
import 'fx_lote2.dart';

const essentialWarpTypes = [
  EffectType.twirl,
  EffectType.fisheye,
  EffectType.kaleidoscope,
  EffectType.venetianBlinds,
  EffectType.blockDissolve,
  EffectType.offset,
  EffectType.invert,
  EffectType.waveWarp,
];

/// Shared single-pass shader. Each layer owns its shader uniforms; program code
/// is cached. Impeller filters sample live textures without CPU readback.
class EssentialWarpPass extends StatefulWidget {
  const EssentialWarpPass({
    super.key,
    required this.effect,
    required this.time,
    required this.child,
  });
  final EffectInstance effect;
  final Duration time;
  final Widget child;
  @override
  State<EssentialWarpPass> createState() => _EssentialWarpState();
}

class _EssentialWarpState extends State<EssentialWarpPass> {
  static Future<ui.FragmentProgram>? _program;
  static ui.FragmentProgram? _ready;
  ui.FragmentShader? _shader;
  @override
  void initState() {
    super.initState();
    if (_ready != null) {
      _shader = _ready!.fragmentShader();
      return;
    }
    (_program ??= ui.FragmentProgram.fromAsset('shaders/essential_warp.frag'))
        .then((program) {
          _ready = program;
          if (mounted) setState(() => _shader = program.fragmentShader());
        })
        .catchError((Object error) {
          debugPrint('Essential warp shader: $error');
        });
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) return widget.child;
    double p(String key, double fallback) =>
        widget.effect.spec.params.containsKey(key)
        ? widget.effect.paramAt(key, widget.time)
        : fallback;
    final filter = ui.ImageFilter.isShaderFilterSupported;
    shader
      ..setFloat(2, essentialWarpTypes.indexOf(widget.effect.type).toDouble())
      ..setFloat(3, p('amount', 1))
      ..setFloat(4, p('angle', 0) * 3.141592653589793 / 180)
      ..setFloat(5, p('radius', .5))
      ..setFloat(6, p('center_x', .5))
      ..setFloat(7, p('center_y', .5))
      ..setFloat(8, p('count', 8))
      ..setFloat(9, p('seed', 0))
      ..setFloat(10, filter ? 1 : 0);
    return filter
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.shader(shader),
            child: widget.child,
          )
        : FxSnapshot(painter: _WarpSnapshot(shader), child: widget.child);
  }
}

class _WarpSnapshot extends SnapshotPainter {
  _WarpSnapshot(this.shader);
  final ui.FragmentShader shader;
  @override
  bool shouldRepaint(_WarpSnapshot old) => true;
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
