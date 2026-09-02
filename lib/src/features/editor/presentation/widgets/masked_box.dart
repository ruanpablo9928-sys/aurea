import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../domain/mask.dart';

/// Uma mascara ja avaliada no tempo local (caminho construido).
/// Coordenadas do caminho: origem no CENTRO do conteudo da camada.
class MaskSpec {
  const MaskSpec({
    required this.path,
    required this.mode,
    required this.inverted,
    required this.opacity,
    required this.feather,
    required this.expansion,
    this.featherY,
  });


  final Path path;
  final MaskMode mode;
  final bool inverted;
  final double opacity;
  final double feather;
  final double expansion;

  /// Suavidade vertical; nulo = igual a horizontal.
  final double? featherY;

  double get featherVertical => featherY ?? feather;
}

/// Aplica a pilha de mascaras ao alfa do filho (PR-M2):
/// - o conteudo e pintado num saveLayer;
/// - a COBERTURA das mascaras e composta numa camada dstIn: cada mascara
///   pinta sua geometria (branca) numa subcamada propria e composita com
///   o blend do seu modo — a primeira contra o alfa da camada, as
///   seguintes contra as de cima;
/// - feather = blur gaussiano montado sobre a borda; expansao = stroke
///   que alarga (positiva) ou apaga a borda (negativa), sem mexer nos
///   vertices; inverted troca dentro/fora daquela mascara.
class MaskedBox extends SingleChildRenderObjectWidget {
  const MaskedBox({super.key, required this.specs, super.child});

  final List<MaskSpec> specs;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMaskedBox(
      specs, MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMaskedBox)
      ..specs = specs
      ..pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
  }
}

class _RenderMaskedBox extends RenderProxyBox {
  _RenderMaskedBox(this._specs, this._pixelRatio);

  List<MaskSpec> _specs;
  set specs(List<MaskSpec> v) {
    _specs = v;
    markNeedsPaint();
  }

  double _pixelRatio;
  set pixelRatio(double v) {
    if (v == _pixelRatio) return;
    _pixelRatio = v;
    markNeedsPaint();
  }

  static bool _temTextura(RenderObject r) {
    if (r is TextureBox) return true;
    var achou = false;
    r.visitChildren((c) {
      if (!achou && _temTextura(c)) achou = true;
    });
    return achou;
  }

  /// PINTA O FILHO DENTRO DO saveLayer — de verdade.
  ///
  /// Um filho com camadas proprias do motor (video, Opacity, efeito com
  /// ImageFiltered, grupo) escapa do saveLayer: o conteudo dele sai
  /// numa camada separada, pintada DEPOIS do restore, e a mascara nao
  /// o alcanca. Era "a mascara nao funciona em toda camada". Esses
  /// filhos sao fotografados (com folga para halo de efeito) e a foto
  /// entra no saveLayer, onde a cobertura da mascara os corta.
  void _pintarFilho(PaintingContext context, Offset offset, double folga) {
    final filho = child!;
    if (!filho.needsCompositing || _temTextura(filho)) {
      context.paintChild(filho, offset);
      return;
    }
    final limites = Rect.fromLTWH(
        -folga, -folga, size.width + 2 * folga, size.height + 2 * folga);
    final camada = OffsetLayer();
    final ctx = PaintingContext(camada, limites);
    ctx.paintChild(filho, Offset.zero);
    // ignore: invalid_use_of_protected_member
    ctx.stopRecordingIfNeeded();
    final foto = camada.toImageSync(limites, pixelRatio: _pixelRatio);
    camada.dispose();
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx - folga, offset.dy - folga);
    canvas.scale(1 / _pixelRatio);
    canvas.drawImage(foto, Offset.zero,
        Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
    foto.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final active = [
      for (final s in _specs)
        if (s.mode != MaskMode.none) s,
    ];
    if (active.isEmpty) {
      context.paintChild(child!, offset);
      return;
    }

    final canvas = context.canvas;
    // O conteudo da camada pode desenhar alem do size; folga generosa.
    final rect = (offset & size).inflate(1400);
    canvas.saveLayer(rect, Paint());
    // Folga da foto: o halo de um glow e a expansao da mascara cabem.
    var folga = 160.0;
    for (final s in active) {
      final alcance = s.feather * 3 + s.featherVertical * 3 + s.expansion.abs();
      if (alcance + 40 > folga) folga = alcance + 40;
    }
    _pintarFilho(context, offset, folga.clamp(160.0, 720.0));

    // Cobertura das mascaras multiplica o alfa do conteudo.
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);

    // Primeira mascara em modo que "corta de" precisa de base cheia.
    final firstMode = active.first.mode;
    if (firstMode == MaskMode.subtract ||
        firstMode == MaskMode.darken ||
        firstMode == MaskMode.difference) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFFFFFFFF));
    }

    final center = offset + Offset(size.width / 2, size.height / 2);
    var first = true;
    for (final s in active) {
      final blend = first ? _firstBlend(s.mode) : _blendFor(s.mode);
      first = false;
      canvas.saveLayer(
        rect,
        Paint()
          ..blendMode = blend
          ..color = const Color(0xFFFFFFFF)
              .withValues(alpha: s.opacity.clamp(0.0, 1.0)),
      );

      var g = s.path.shift(center);
      if (s.inverted) {
        g = Path.combine(
            PathOperation.difference, Path()..addRect(rect), g);
      }

      // Feather por EIXO: o blur vai numa camada propria porque
      // MaskFilter e redondo por definicao — nao ha como pedir 40 px em
      // cima e 0 dos lados com ele. ImageFilter aceita os dois sigmas, e
      // e o que permite o degrade de horizonte.
      final borrar = s.feather > 0.5 || s.featherVertical > 0.5;
      if (borrar) {
        canvas.saveLayer(
          rect,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(
              // 25 ~ 12,5 px por lado, como antes.
              sigmaX: s.feather > 0.5 ? s.feather / 4 : 0.0001,
              sigmaY: s.featherVertical > 0.5 ? s.featherVertical / 4 : 0.0001,
            ),
        );
      }

      canvas.drawPath(g, Paint()..color = const Color(0xFFFFFFFF));

      // Expansao: alarga ou contrai o alcance sem alterar o caminho.
      if (s.expansion.abs() > 0.5) {
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.expansion.abs() * 2
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFFFFFFFF);
        if (s.expansion > 0) {
          canvas.drawPath(g, stroke);
        } else {
          stroke.blendMode = BlendMode.clear;
          canvas.drawPath(g, stroke);
        }
      }

      if (borrar) canvas.restore();
      canvas.restore();
    }

    canvas.restore();
    canvas.restore();
  }

  /// A primeira mascara interage com o alfa da camada: modos que cortam
  /// operam sobre a base cheia; os aditivos comecam do vazio.
  BlendMode _firstBlend(MaskMode mode) => switch (mode) {
        MaskMode.subtract => BlendMode.dstOut,
        MaskMode.darken => BlendMode.darken,
        MaskMode.difference => BlendMode.xor,
        _ => BlendMode.srcOver,
      };

  /// Mascaras seguintes interagem com as de cima na pilha.
  BlendMode _blendFor(MaskMode mode) => switch (mode) {
        MaskMode.add => BlendMode.srcOver,
        MaskMode.subtract => BlendMode.dstOut,
        MaskMode.intersect => BlendMode.dstIn,
        MaskMode.lighten => BlendMode.lighten,
        MaskMode.darken => BlendMode.darken,
        MaskMode.difference => BlendMode.xor,
        MaskMode.none => BlendMode.srcOver,
      };
}
