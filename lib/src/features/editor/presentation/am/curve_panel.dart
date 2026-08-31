import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/grid_rig.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

/// Painel "Curva de gradacao": grafico tempo->tempo com grade, alcas
/// grandes, thumbnails de preset a direita e navegacao entre segmentos.
class CurvePanel extends ConsumerStatefulWidget {
  const CurvePanel({
    super.key,
    required this.playback,
    required this.prop,
    required this.onBack,
  });

  final PlaybackController playback;
  final LayerProp prop;
  final VoidCallback onBack;

  @override
  ConsumerState<CurvePanel> createState() => _CurvePanelState();
}

class _CurvePanelState extends ConsumerState<CurvePanel> {
  bool _overshoot = false;

  @override
  void initState() {
    super.initState();
    // Segue o playhead: o segmento mostrado acompanha o scrub na timeline.
    widget.playback.time.addListener(_onClock);
  }

  @override
  void dispose() {
    widget.playback.time.removeListener(_onClock);
    super.dispose();
  }

  void _onClock() {
    if (!mounted) return;
    // O proprio build pode dar seek (auto-pulo para o primeiro segmento);
    // nesse caso adia o setState para depois do frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  List<Duration> _kfTimes(Layer layer) {
    final track = switch (widget.prop) {
      LayerProp.position => layer.position.keyframes.map((k) => k.time),
      LayerProp.scale => layer.scaleX.keyframes.map((k) => k.time),
      LayerProp.rotation => layer.rotation.keyframes.map((k) => k.time),
      LayerProp.opacity => layer.opacity.keyframes.map((k) => k.time),
      LayerProp.skew => layer.skewX.keyframes.map((k) => k.time),
      LayerProp.pivot => layer.pivot.keyframes.map((k) => k.time),
      LayerProp.parent => const Iterable<Duration>.empty(),
    };
    return track.toList();
  }

  Easing _easeOf(Layer layer, Duration segStart) => switch (widget.prop) {
        LayerProp.position => layer.position.easeAt(segStart),
        LayerProp.scale => layer.scaleX.easeAt(segStart),
        LayerProp.rotation => layer.rotation.easeAt(segStart),
        LayerProp.opacity => layer.opacity.easeAt(segStart),
        LayerProp.skew => layer.skewX.easeAt(segStart),
        LayerProp.pivot => layer.pivot.easeAt(segStart),
        LayerProp.parent => Easing.linear,
      };

  (Duration, Duration)? _segmentAt(Layer layer, Duration local) {
    final times = _kfTimes(layer);
    for (var i = 0; i < times.length - 1; i++) {
      if (local >= times[i] && local < times[i + 1]) {
        return (times[i], times[i + 1]);
      }
    }
    return null;
  }

  void _jumpSegment(Layer layer, int dir) {
    final times = _kfTimes(layer);
    if (times.length < 2) return;
    final local = layer.localTime(widget.playback.time.value);
    final mids = [
      for (var i = 0; i < times.length - 1; i++)
        times[i] + (times[i + 1] - times[i]) ~/ 2,
    ];
    var idx = 0;
    for (var i = 0; i < mids.length; i++) {
      if (local >= times[i]) idx = i;
    }
    final target = (idx + dir).clamp(0, mids.length - 1);
    widget.playback.seek(layer.startTime + mids[target]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer == null || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }

    final controller = ref.read(editorControllerProvider.notifier);
    final local = layer.localTime(widget.playback.time.value);
    var segment = _segmentAt(layer, local);
    // Sem segmento sob o playhead: tenta pular para o primeiro.
    if (segment == null && _kfTimes(layer).length >= 2) {
      final times = _kfTimes(layer);
      widget.playback.seek(
          layer.startTime + times[0] + (times[1] - times[0]) ~/ 2);
      segment = _segmentAt(layer, layer.localTime(widget.playback.time.value));
    }
    final ease = segment == null ? null : _easeOf(layer, segment.$1);

    return ColoredBox(
      color: AmColors.panel,
      child: segment == null || ease == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Crie pelo menos 2 keyframes\npara editar a curva.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AmColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: widget.onBack,
                    child: const Text('Voltar',
                        style: TextStyle(color: AmColors.accent)),
                  ),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Trilho esquerdo: voltar / inverter / menu.
                Column(
                  children: [
                    AmRailButton(
                      onTap: widget.onBack,
                      child: const Icon(CupertinoIcons.chevron_back,
                          size: 24, color: AmColors.text),
                    ),
                    const Spacer(),
                    AmRailButton(
                      onTap: () {
                        // Inverte a curva (espelha as alcas).
                        controller.setSegmentEase(
                          id,
                          widget.prop,
                          segment!.$1,
                          ease.copyWith(
                            x1: (1 - ease.x2).clamp(0.0, 1.0),
                            y1: 1 - ease.y2,
                            x2: (1 - ease.x1).clamp(0.0, 1.0),
                            y2: 1 - ease.y1,
                          ),
                        );
                      },
                      child: const Icon(CupertinoIcons.arrow_2_squarepath,
                          size: 22, color: AmColors.text),
                    ),
                    AmRailButton(
                      onTap: () => _showMenu(context, id, ease),
                      child: const Icon(CupertinoIcons.ellipsis,
                          size: 20, color: AmColors.text),
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
                // Grafico + navegacao.
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Expanded(
                        child: _CurveGraph(
                          ease: ease,
                          overshootEnabled: _overshoot,
                          onBezierChanged: (e) => controller.setSegmentEase(
                              id, widget.prop, segment!.$1, e),
                        ),
                      ),
                      SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              onPressed: () => _jumpSegment(layer, -1),
                              child: const Icon(CupertinoIcons.chevron_left,
                                  size: 18, color: AmColors.muted),
                            ),
                            Expanded(
                              child: Text(
                                'Efeito Ease de ${ease.label}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, color: AmColors.muted),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.all(8),
                              onPressed: () => _jumpSegment(layer, 1),
                              child: const Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 18,
                                  color: AmColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Thumbnails de preset a direita.
                SizedBox(
                  width: 78,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
                    children: [
                      for (final preset in _presets)
                        _PresetTile(
                          ease: preset,
                          selected: _samePreset(ease, preset),
                          onTap: () => controller.setSegmentEase(
                              id, widget.prop, segment!.$1, preset),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  static const _presets = [
    Easing.linear,
    Easing.easeIn,
    Easing.easeOut,
    Easing.easeInOut,
    Easing.overshoot,
    Easing.bounce,
    Easing.elastic,
    Easing(type: EasingType.steps),
    Easing(type: EasingType.cyclic),
  ];

  static bool _samePreset(Easing a, Easing b) {
    if (a.type != b.type) return false;
    if (a.type != EasingType.cubicBezier) return true;
    return (a.x1 - b.x1).abs() < 0.01 &&
        (a.y1 - b.y1).abs() < 0.01 &&
        (a.x2 - b.x2).abs() < 0.01 &&
        (a.y2 - b.y2).abs() < 0.01;
  }

  Future<void> _showMenu(
      BuildContext context, String layerId, Easing ease) async {
    final controller = ref.read(editorControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Ativar overshoot',
                  style: TextStyle(color: AmColors.text, fontSize: 15)),
              activeTrackColor: AmColors.accent,
              value: _overshoot,
              onChanged: (v) {
                setState(() => _overshoot = v);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              title: const Text('Aplicar curva a todos os keyframes',
                  style: TextStyle(color: AmColors.text, fontSize: 15)),
              onTap: () {
                controller.applyEaseToAllSegments(
                    layerId, widget.prop, ease);
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Curve editor de uma trilha do MODULO GRADE (inclui 'transition', o
/// morph): sheet persistente — o preview continua visivel, o transporte
/// escolhe o segmento e as alcas/presets editam a curva daquele trecho.
Future<void> showGridCurveSheet(
  BuildContext context,
  WidgetRef ref,
  PlaybackController playback,
  String nullId,
  String paramKey,
  String label, {
  VoidCallback? onClosed,
}) {
  final controller = ref.read(editorControllerProvider.notifier);
  return showTrackCurveSheet(
    context,
    ref,
    playback,
    label: label,
    layerId: nullId,
    trackOf: (layer) => layer is NullLayer && layer.grid != null
        ? gridTrackOf(layer.grid!, paramKey)
        : null,
    onSetEase: (segStart, ease) =>
        controller.setGridSegmentEase(nullId, paramKey, segStart, ease),
    onSetEaseAll: (ease) =>
        controller.applyEaseToAllGridSegments(nullId, paramKey, ease),
    onClosed: onClosed,
  );
}

/// Curve editor GENERICO de qualquer trilha animavel (grade, parametros
/// de forma...): quem chama diz como achar a trilha e como gravar o
/// easing; o sheet cuida de segmento, alcas e presets.
Future<void> showTrackCurveSheet(
  BuildContext context,
  WidgetRef ref,
  PlaybackController playback, {
  required String label,
  required String layerId,
  required AnimatedDouble? Function(Layer layer) trackOf,
  required void Function(Duration segStartLocal, Easing ease) onSetEase,
  required void Function(Easing ease) onSetEaseAll,
  VoidCallback? onClosed,
}) async {
  final myGen = paramSheetGeneration + 1;
  await showParamSheet(
    context,
    heightFactor: 0.5,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) =>
          ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (sheetContext, t, _) {
          final project = ref.read(editorControllerProvider);
          final layer = project.layerById(layerId);
          if (layer == null) return const SizedBox.shrink();
          final track = trackOf(layer);
          if (track == null) return const SizedBox.shrink();
          final local = layer.localTime(t);
          final times = [for (final k in track.keyframes) k.time];

          (Duration, Duration)? seg;
          for (var i = 0; i < times.length - 1; i++) {
            if (local >= times[i] && local < times[i + 1]) {
              seg = (times[i], times[i + 1]);
              break;
            }
          }

          void jump(int dir) {
            if (times.length < 2) return;
            final mids = [
              for (var i = 0; i < times.length - 1; i++)
                times[i] + (times[i + 1] - times[i]) ~/ 2,
            ];
            var idx = 0;
            for (var i = 0; i < mids.length; i++) {
              if (local >= times[i]) idx = i;
            }
            final target = (idx + dir).clamp(0, mids.length - 1);
            playback.seek(layer.startTime + mids[target]);
          }

          final ease = seg == null ? null : track.easeAt(seg.$1);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Curva — $label',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AmColors.text)),
                  SheetTransport(
                    playback: playback,
                    duration: project.duration,
                    fps: project.fps,
                  ),
                  const SizedBox(height: 6),
                  if (seg == null || ease == null)
                    Container(
                      height: 150,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Crie 2+ keyframes neste parametro e leve o\n'
                            'playhead para DENTRO do trecho entre eles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AmColors.muted, fontSize: 13),
                          ),
                          if (times.length >= 2)
                            CupertinoButton(
                              onPressed: () {
                                playback.seek(layer.startTime +
                                    times[0] +
                                    (times[1] - times[0]) ~/ 2);
                              },
                              child: const Text('Ir ao primeiro trecho',
                                  style: TextStyle(
                                      color: AmColors.accent,
                                      fontSize: 14)),
                            ),
                        ],
                      ),
                    )
                  else ...[
                    SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.all(6),
                            onPressed: () => jump(-1),
                            child: const Icon(CupertinoIcons.chevron_left,
                                size: 18, color: AmColors.muted),
                          ),
                          Expanded(
                            child: _CurveGraph(
                              ease: ease,
                              overshootEnabled: true,
                              onBezierChanged: (e) {
                                onSetEase(seg!.$1, e);
                                setSheetState(() {});
                              },
                            ),
                          ),
                          CupertinoButton(
                            padding: const EdgeInsets.all(6),
                            onPressed: () => jump(1),
                            child: const Icon(
                                CupertinoIcons.chevron_right,
                                size: 18,
                                color: AmColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final preset in _CurvePanelState._presets)
                            SizedBox(
                              width: 74,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 8),
                                child: _PresetTile(
                                  ease: preset,
                                  selected: _CurvePanelState._samePreset(
                                      ease, preset),
                                  onTap: () {
                                    onSetEase(seg!.$1, preset);
                                    setSheetState(() {});
                                  },
                                ),
                              ),
                            ),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                            onPressed: () {
                              onSetEaseAll(ease);
                              setSheetState(() {});
                            },
                            child: const Text('Aplicar a\ntodos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AmColors.accent)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
  // Fechou o editor de curvas: devolve o painel que o abriu — o usuario
  // nunca "cai" de volta na timeline sem aviso. So reabre se NENHUM
  // outro sheet tomou o lugar nesse meio-tempo.
  if (paramSheetGeneration == myGen) onClosed?.call();
}

class _CurveGraph extends StatelessWidget {
  const _CurveGraph({
    required this.ease,
    required this.overshootEnabled,
    required this.onBezierChanged,
  });

  final Easing ease;
  final bool overshootEnabled;
  final ValueChanged<Easing> onBezierChanged;

  static const double _yMin = -0.5;
  static const double _yMax = 1.5;

  Offset _toPlot(Size size, double x, double y) => Offset(
        x * size.width,
        size.height - (y - _yMin) / (_yMax - _yMin) * size.height,
      );

  (double, double) _fromPlot(Size size, Offset p) => (
        (p.dx / size.width).clamp(0.0, 1.0),
        _yMin + (size.height - p.dy) / size.height * (_yMax - _yMin),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final h1 = _toPlot(size, ease.x1, ease.y1);
        final h2 = _toPlot(size, ease.x2, ease.y2);

        void drag(DragUpdateDetails d) {
          final p = d.localPosition;
          final near1 =
              (p - h1).distanceSquared < (p - h2).distanceSquared;
          var (x, y) = _fromPlot(size, p);
          if (!overshootEnabled) y = y.clamp(0.0, 1.0);
          onBezierChanged(near1
              ? ease.copyWith(x1: x, y1: y)
              : ease.copyWith(x2: x, y2: y));
        }

        final enabled = ease.type == EasingType.cubicBezier;
        // Reconhecedores vertical E horizontal (nao pan): dentro de um
        // bottom sheet persistente, o pan PERDE a arena de gestos para o
        // drag-de-fechar vertical do sheet — a alca "nao mexia" e o
        // gesto arrastava o sheet. Recognizer igual em no mais fundo
        // ganha a arena.
        return GestureDetector(
          onVerticalDragUpdate: enabled ? drag : null,
          onHorizontalDragUpdate: enabled ? drag : null,
          child: CustomPaint(
            size: size,
            painter: _AmCurvePainter(ease: ease, yMin: _yMin, yMax: _yMax),
          ),
        );
      },
    );
  }
}

class _AmCurvePainter extends CustomPainter {
  const _AmCurvePainter({
    required this.ease,
    required this.yMin,
    required this.yMax,
  });

  final Easing ease;
  final double yMin;
  final double yMax;

  Offset _pt(Size size, double x, double y) => Offset(
        x * size.width,
        size.height - (y - yMin) / (yMax - yMin) * size.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Grade pontilhada.
    final grid = Paint()
      ..color = const Color(0xFF34405A)
      ..strokeWidth = 1;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      for (var y = 0.0; y < size.height; y += 7) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 2.5), grid);
      }
    }
    for (var i = 1; i < 8; i++) {
      final y = size.height * i / 8;
      for (var x = 0.0; x < size.width; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 2.5, y), grid);
      }
    }
    // Limites (y=0 / y=1) tracejados claros.
    final dash = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1;
    for (final y in [0.0, 1.0]) {
      final py = _pt(size, 0, y).dy;
      for (var x = 0.0; x < size.width; x += 9) {
        canvas.drawLine(Offset(x, py), Offset(x + 4.5, py), dash);
      }
    }

    // Curva: branca com o miolo verde (estilo AM).
    Path buildPath(double from, double to) {
      final path = Path();
      var first = true;
      for (var i = 0; i <= 72; i++) {
        final t = from + (to - from) * i / 72;
        final p = _pt(size, t, ease.transform(t));
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    canvas.drawPath(
      buildPath(0, 1),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      buildPath(0.18, 0.82),
      Paint()
        ..color = AmColors.accent
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Pontos das extremidades + alcas.
    final endDot = Paint()..color = AmColors.accent;
    canvas.drawCircle(_pt(size, 0, 0), 5, endDot);
    canvas.drawCircle(_pt(size, 1, 1), 5, endDot);
    if (ease.type == EasingType.cubicBezier) {
      final handle = Paint()..color = Colors.white;
      canvas.drawCircle(_pt(size, ease.x1, ease.y1), 13, handle);
      canvas.drawCircle(_pt(size, ease.x2, ease.y2), 13, handle);
    }
  }

  @override
  bool shouldRepaint(_AmCurvePainter old) => old.ease != ease;
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.ease,
    required this.selected,
    required this.onTap,
  });

  final Easing ease;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: selected ? AmColors.panelHigh : AmColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: AmColors.accent, width: 1.5)
              : null,
        ),
        child: CustomPaint(
          painter: _PresetThumbPainter(ease: ease, selected: selected),
        ),
      ),
    );
  }
}

class _PresetThumbPainter extends CustomPainter {
  const _PresetThumbPainter({required this.ease, required this.selected});

  final Easing ease;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 10.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final paint = Paint()
      ..color = selected ? AmColors.accent : Colors.white70
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i <= 40; i++) {
      final t = i / 40;
      final v = ease.transform(t).clamp(-0.3, 1.3);
      final p = Offset(pad + t * w, pad + h - v * h);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
    final dot = Paint()..color = selected ? AmColors.accent : Colors.white;
    canvas.drawCircle(Offset(pad, pad + h), 3, dot);
    canvas.drawCircle(Offset(pad + w, pad), 3, dot);
  }

  @override
  bool shouldRepaint(_PresetThumbPainter old) =>
      old.ease != ease || old.selected != selected;
}
