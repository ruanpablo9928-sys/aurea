import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/layer.dart';
import '../../domain/text_animator.dart';

/// Render por unidade (PR-T2): segmenta em grapheme clusters, mede o
/// avanco pela LINHA INTEIRA (getBoxesForRange no layout completo) e pinta
/// cada unidade com o transform acumulado dos animadores.
///
/// Caminho rapido: sem animador ativo, o chamador usa o Text normal.
class AnimatedTextView extends StatelessWidget {
  const AnimatedTextView({
    super.key,
    required this.layer,
    required this.localTime,
  });

  final TextLayer layer;
  final Duration localTime;

  static TextStyle styleFor(TextLayer l, {bool animated = false}) => TextStyle(
        color: l.color,
        fontSize: l.fontSize,
        fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
        letterSpacing: -l.fontSize * 0.02,
        height: 1.1,
        // Com animacao por caractere, ligaduras partiriam glifos (§3.2).
        fontFeatures: animated
            ? const [
                FontFeature.disable('liga'),
                FontFeature.disable('clig'),
                FontFeature.disable('dlig'),
              ]
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final style = styleFor(layer, animated: true);
    final full = TextPainter(
      text: TextSpan(text: layer.text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final units = TextUnits.of(layer.text);

    return CustomPaint(
      size: full.size,
      painter: _AnimatedTextPainter(
        layer: layer,
        style: style,
        full: full,
        units: units,
        localTime: localTime,
      ),
    );
  }
}

class _AnimatedTextPainter extends CustomPainter {
  _AnimatedTextPainter({
    required this.layer,
    required this.style,
    required this.full,
    required this.units,
    required this.localTime,
  });

  final TextLayer layer;
  final TextStyle style;
  final TextPainter full;
  final TextUnits units;
  final Duration localTime;

  @override
  void paint(Canvas canvas, Size size) {
    final t = localTime;
    final animators = [
      for (final a in layer.effectiveAnimators(units.length))
        if (a.enabled && a.properties.isNotEmpty) a,
    ];

    var runningTracking = 0.0;

    for (var i = 0; i < units.length; i++) {
      final cluster = units.clusters[i];
      final trackingShift = runningTracking;

      // Acumula o transform desta unidade pelos animadores em pilha.
      var dx = 0.0, dy = 0.0, rotation = 0.0, tracking = 0.0;
      var blur = 0.0, skew = 0.0, hue = 0.0;
      var scaleP = 100.0, opacityP = 100.0;
      var scaleXP = 100.0, scaleYP = 100.0;
      var satP = 100.0, brightP = 100.0;
      for (final a in animators) {
        final c = units.coverageFor(a.selectors, i, t,
            allowOvershoot: a.allowOvershoot);
        for (final p in a.properties) {
          switch (p.type) {
            case TextAnimProp.positionX:
              dx = p.apply(dx, t, c);
            case TextAnimProp.positionY:
              dy = p.apply(dy, t, c);
            case TextAnimProp.rotation:
              rotation = p.apply(rotation, t, c);
            case TextAnimProp.tracking:
              tracking = p.apply(tracking, t, c);
            case TextAnimProp.scale:
              scaleP = p.apply(scaleP, t, c);
            case TextAnimProp.opacity:
              opacityP = p.apply(opacityP, t, c);
            case TextAnimProp.scaleX:
              scaleXP = p.apply(scaleXP, t, c);
            case TextAnimProp.scaleY:
              scaleYP = p.apply(scaleYP, t, c);
            case TextAnimProp.blur:
              blur = p.apply(blur, t, c);
            case TextAnimProp.skew:
              skew = p.apply(skew, t, c);
            case TextAnimProp.hue:
              hue = p.apply(hue, t, c);
            case TextAnimProp.saturation:
              satP = p.apply(satP, t, c);
            case TextAnimProp.brightness:
              brightP = p.apply(brightP, t, c);
          }
        }
      }
      runningTracking += tracking;

      if (units.isWhitespace[i]) continue;

      // Avanco SEMPRE da medicao da linha completa (§3.4).
      final boxes = full.getBoxesForSelection(
        TextSelection(
          baseOffset: units.codeUnitStart[i],
          extentOffset: units.codeUnitEnd[i],
        ),
        boxHeightStyle: BoxHeightStyle.tight,
      );
      if (boxes.isEmpty) continue;
      var rect = boxes.first.toRect();
      for (final b in boxes.skip(1)) {
        rect = rect.expandToInclude(b.toRect());
      }

      final opacity = (opacityP / 100).clamp(0.0, 1.0);
      if (opacity <= 0.001) continue;
      final sx = math.max(0.0, (scaleP / 100) * (scaleXP / 100));
      final sy = math.max(0.0, (scaleP / 100) * (scaleYP / 100));
      if (sx <= 0.001 || sy <= 0.001) continue;

      final unitColor = _shiftColor(style.color!, hue, satP, brightP)
          .withValues(alpha: style.color!.a * opacity);

      final unitPainter = TextPainter(
        text: TextSpan(text: cluster, style: style.copyWith(color: unitColor)),
        textDirection: TextDirection.ltr,
      )..layout();

      final center = rect.center;
      canvas.save();
      // DESFOQUE POR UNIDADE: e o que faz "aparecer em desfoque" existir.
      // Sem isto so da para borrar a camada inteira, que e outra coisa.
      final blurring = blur > 0.05;
      if (blurring) {
        final pad = blur * 3 + rect.longestSide;
        canvas.saveLayer(
          Rect.fromCenter(center: center, width: pad * 2, height: pad * 2),
          Paint()
            ..imageFilter =
                ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        );
      }
      canvas.translate(center.dx + dx + trackingShift, center.dy + dy);
      if (rotation != 0) canvas.rotate(rotation * math.pi / 180);
      if (skew != 0) {
        canvas.transform(Float64List.fromList(<double>[
          1, 0, 0, 0, //
          math.tan(-skew * math.pi / 180), 1, 0, 0, //
          0, 0, 1, 0, //
          0, 0, 0, 1,
        ]));
      }
      if (sx != 1 || sy != 1) canvas.scale(sx, sy);
      unitPainter.paint(
        canvas,
        Offset(-unitPainter.width / 2, -unitPainter.height / 2),
      );
      canvas.restore();
      if (blurring) canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AnimatedTextPainter old) => true;
}

/// Deslocamento de MATIZ, SATURACAO e BRILHO por unidade — e o que
/// permite varrer cor letra a letra sem trocar a cor da camada.
Color _shiftColor(Color base, double hueDeg, double satPct, double brightPct) {
  if (hueDeg == 0 && satPct == 100 && brightPct == 100) return base;
  final hsl = HSLColor.fromColor(base);
  final h = (hsl.hue + hueDeg) % 360;
  return hsl
      .withHue(h < 0 ? h + 360 : h)
      .withSaturation((hsl.saturation * satPct / 100).clamp(0.0, 1.0))
      .withLightness((hsl.lightness * brightPct / 100).clamp(0.0, 1.0))
      .toColor();
}
