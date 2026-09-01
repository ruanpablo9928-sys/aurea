import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'fx_lote2.dart' show FxSnapshot;

/// DITHERING DE SAIDA — o que tira a faixa do gradiente escuro.
///
/// Um degrade de `#000` a `#0A1E3C` em tela cheia nao tem degraus
/// suficientes em 8 bits por canal: o olho ve listras, e listra em
/// gradiente e o defeito que denuncia motion amador na hora.
///
/// A correcao e ruido de meio degrau antes de quantizar. Custa quase
/// nada e resolve sozinho.
class DitherLayer extends StatefulWidget {
  const DitherLayer({
    super.key,
    required this.child,
    this.strength = 0.75,
    this.enabled = true,
    this.time = Duration.zero,
  });

  final Widget child;

  /// Em degraus de 8 bits. 0,75 e o ponto em que a faixa some sem que o
  /// granulado apareca.
  final double strength;

  final bool enabled;

  /// O ruido muda com o tempo — ruido parado vira textura fixa e chama
  /// mais atencao que a faixa que ele veio consertar.
  final Duration time;

  /// O programa e carregado uma vez e compartilhado.
  static ui.FragmentProgram? _program;
  static bool _tried = false;

  static Future<void> warmUp() async {
    if (_tried) return;
    _tried = true;
    try {
      _program =
          await ui.FragmentProgram.fromAsset('shaders/dither.frag');
    } catch (_) {
      // Aparelho sem suporte: segue sem dithering, nao quebra.
      _program = null;
    }
  }

  static bool get ready => _program != null;

  @override
  State<DitherLayer> createState() => _DitherLayerState();
}

class _DitherLayerState extends State<DitherLayer> {
  @override
  void initState() {
    super.initState();
    if (!DitherLayer._tried) {
      DitherLayer.warmUp().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final program = DitherLayer._program;
    if (!widget.enabled || program == null || widget.strength <= 0.01) {
      return widget.child;
    }
    return FxSnapshot(
      painter: _DitherPainter(
        shader: program.fragmentShader(),
        strength: widget.strength,
        seed: (widget.time.inMilliseconds % 4096).toDouble(),
      ),
      child: widget.child,
    );
  }
}

class _DitherPainter extends SnapshotPainter {
  _DitherPainter({
    required this.shader,
    required this.strength,
    required this.seed,
  });

  final ui.FragmentShader shader;
  final double strength;
  final double seed;

  @override
  void paint(PaintingContext context, Offset offset, Size size,
      PaintingContextCallback painter) {
    painter(context, offset);
  }

  @override
  void paintSnapshot(PaintingContext context, Offset offset, Size size,
      ui.Image image, Size sourceSize, double pixelRatio) {
    if (size.isEmpty) return;
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, strength)
      ..setFloat(3, seed)
      ..setImageSampler(0, image);

    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    context.canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
    context.canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DitherPainter old) =>
      old.strength != strength || old.seed != seed;
}
