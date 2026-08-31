import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

enum TransformTool { position, rotation, scale, skew, pivot }

LayerProp propOfTool(TransformTool tool) => switch (tool) {
      TransformTool.position => LayerProp.position,
      TransformTool.rotation => LayerProp.rotation,
      TransformTool.scale => LayerProp.scale,
      TransformTool.skew => LayerProp.skew,
      TransformTool.pivot => LayerProp.pivot,
    };

/// Painel "Movimentacao e transformacao": trilho esquerdo (voltar,
/// keyframe, curva), controle central com navegacao de keyframes
/// e sub-ferramentas a direita (posicao/rotacao/escala/skew/pivo).
class TransformPanel extends ConsumerStatefulWidget {
  const TransformPanel({
    super.key,
    required this.playback,
    required this.tool,
    required this.onToolChanged,
    required this.onBack,
    required this.onOpenCurve,
  });

  final PlaybackController playback;
  final TransformTool tool;
  final ValueChanged<TransformTool> onToolChanged;
  final VoidCallback onBack;
  final void Function(LayerProp prop) onOpenCurve;

  @override
  ConsumerState<TransformPanel> createState() => _TransformPanelState();
}

class _TransformPanelState extends ConsumerState<TransformPanel> {
  bool _scaleLinked = true;

  LayerProp get _prop => propOfTool(widget.tool);

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer == null || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }
    final controller = ref.read(editorControllerProvider.notifier);

    // O painel ESCUTA o relogio: sem isso, o `t` capturado no build fica
    // velho apos scrub na timeline e o diamante marcava keyframe no tempo
    // de quando o painel abriu (o bug do "keyframe fora do playhead").
    return ValueListenableBuilder<Duration>(
      valueListenable: widget.playback.time,
      builder: (context, t, _) {
        final local = layer.localTime(t);
        // Rotacao: keyframe e GLOBAL entre os eixos X/Y/Z.
        final hasKfHere = switch (widget.tool) {
          TransformTool.position => layer.position.hasKeyframeAt(local),
          TransformTool.rotation => layer.rotation.hasKeyframeAt(local) ||
              layer.rotationX.hasKeyframeAt(local) ||
              layer.rotationY.hasKeyframeAt(local),
          TransformTool.scale => layer.scaleX.hasKeyframeAt(local),
          TransformTool.skew => layer.skewX.hasKeyframeAt(local),
          TransformTool.pivot => layer.pivot.hasKeyframeAt(local),
        };
        final animated = switch (widget.tool) {
          TransformTool.position => layer.position.isAnimated,
          TransformTool.rotation => layer.rotation.isAnimated ||
              layer.rotationX.isAnimated ||
              layer.rotationY.isAnimated,
          TransformTool.scale => layer.scaleX.isAnimated,
          TransformTool.skew => layer.skewX.isAnimated,
          TransformTool.pivot => layer.pivot.isAnimated,
        };

        return _buildBody(
            context, controller, id, layer, t, hasKfHere, animated);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    EditorController controller,
    String id,
    Layer layer,
    Duration t,
    bool hasKfHere,
    bool animated,
  ) {
    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trilho esquerdo.
          Column(
            children: [
              AmRailButton(
                onTap: widget.onBack,
                child: const Icon(CupertinoIcons.chevron_back,
                    size: 24, color: AmColors.text),
              ),
              AmRailButton(
                // Le o relogio NO TOQUE: o keyframe cai exatamente onde o
                // playhead esta agora, nunca num tempo capturado antes.
                onTap: () => controller.toggleKeyframe(
                    id, widget.playback.time.value, _prop),
                child: AmDiamondAdd(active: animated, filled: hasKfHere),
              ),
              AmRailButton(
                onTap: animated ? () => widget.onOpenCurve(_prop) : null,
                child: AmCurveIcon(
                    color: animated ? AmColors.text : AmColors.muted),
              ),
            ],
          ),
          // Controle central + navegacao de keyframes.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
              child: Column(
                children: [
                  Expanded(
                    child: switch (widget.tool) {
                      TransformTool.position => _PositionControl(
                          layer: layer, playback: widget.playback),
                      TransformTool.rotation => _RotationControl(
                          layer: layer, playback: widget.playback),
                      TransformTool.scale => _ScaleControl(
                          layer: layer,
                          playback: widget.playback,
                          linked: _scaleLinked,
                          onToggleLink: () => setState(
                              () => _scaleLinked = !_scaleLinked),
                        ),
                      TransformTool.skew => _SkewControl(
                          layer: layer, playback: widget.playback),
                      TransformTool.pivot => _PivotControl(
                          layer: layer, playback: widget.playback),
                    },
                  ),
                  // ‹◆  ◆›  ↺ — navegar entre keyframes e resetar.
                  KeyframeNavRow(
                    playback: widget.playback,
                    layer: layer,
                    prop: _prop,
                    onReset: () => controller.resetProp(id, _prop),
                  ),
                ],
              ),
            ),
          ),
          // Sub-ferramentas a direita.
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 2),
                _ToolButton(
                  tool: TransformTool.position,
                  current: widget.tool,
                  onTap: widget.onToolChanged,
                  child: (c) => Icon(Icons.open_with, size: 24, color: c),
                ),
                _ToolButton(
                  tool: TransformTool.rotation,
                  current: widget.tool,
                  onTap: widget.onToolChanged,
                  child: (c) => Icon(Icons.crop_rotate, size: 22, color: c),
                ),
                _ToolButton(
                  tool: TransformTool.scale,
                  current: widget.tool,
                  onTap: widget.onToolChanged,
                  child: (c) => Icon(Icons.open_in_full, size: 22, color: c),
                ),
                _ToolButton(
                  tool: TransformTool.skew,
                  current: widget.tool,
                  onTap: widget.onToolChanged,
                  child: (c) => Transform(
                    transform: Matrix4.skewX(-0.35),
                    alignment: Alignment.center,
                    child: Icon(Icons.crop_square, size: 22, color: c),
                  ),
                ),
                _ToolButton(
                  tool: TransformTool.pivot,
                  current: widget.tool,
                  onTap: widget.onToolChanged,
                  child: (c) =>
                      Icon(Icons.filter_center_focus, size: 22, color: c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tool,
    required this.current,
    required this.onTap,
    required this.child,
  });

  final TransformTool tool;
  final TransformTool current;
  final ValueChanged<TransformTool> onTap;
  final Widget Function(Color color) child;

  @override
  Widget build(BuildContext context) {
    final selected = tool == current;
    return AmRailButton(
      selected: selected,
      onTap: () => onTap(tool),
      child: child(selected ? AmColors.accent : AmColors.text),
    );
  }
}

/// Fileira ‹◆ | ◆› | ↺ compartilhada pelos paineis de propriedade.
class KeyframeNavRow extends ConsumerWidget {
  const KeyframeNavRow({
    super.key,
    required this.playback,
    required this.layer,
    required this.prop,
    required this.onReset,
  });

  final PlaybackController playback;
  final Layer layer;
  final LayerProp prop;
  final VoidCallback onReset;

  void _jump(WidgetRef ref, int dir) {
    final controller = ref.read(editorControllerProvider.notifier);
    final times = controller.propKeyframeTimes(layer, prop);
    if (times.isEmpty) return;
    final local = layer.localTime(playback.time.value);
    Duration? target;
    if (dir < 0) {
      for (final kt in times) {
        if (kt < local - const Duration(milliseconds: 8)) target = kt;
      }
    } else {
      for (final kt in times.reversed) {
        if (kt > local + const Duration(milliseconds: 8)) target = kt;
      }
    }
    if (target != null) {
      playback.pause();
      playback.seek(layer.startTime + target);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            onPressed: () => _jump(ref, -1),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_left,
                    size: 15, color: AmColors.muted),
                Icon(CupertinoIcons.rhombus, size: 14, color: AmColors.muted),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            onPressed: () => _jump(ref, 1),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.rhombus, size: 14, color: AmColors.muted),
                Icon(CupertinoIcons.chevron_right,
                    size: 15, color: AmColors.muted),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            onPressed: onReset,
            child: const Icon(CupertinoIcons.arrow_counterclockwise,
                size: 17, color: AmColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PositionControl extends ConsumerStatefulWidget {
  const _PositionControl({required this.layer, required this.playback});

  final Layer layer;
  final PlaybackController playback;

  @override
  ConsumerState<_PositionControl> createState() => _PositionControlState();
}

class _PositionControlState extends ConsumerState<_PositionControl> {
  Layer get layer => widget.layer;
  PlaybackController get playback => widget.playback;

  Offset _dragStart = Offset.zero;
  Offset _accum = Offset.zero;

  Future<void> _pickLinkSource(
      BuildContext context, WidgetRef ref, Duration t) async {
    final project = ref.read(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('Seguir a posicao de...',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AmColors.text)),
            ),
            for (final other in project.layers)
              if (other.id != layer.id)
                ListTile(
                  title: Text(other.name,
                      style: const TextStyle(color: AmColors.text)),
                  onTap: () {
                    controller.linkProperty(
                        layer.id, LayerProp.position, other.id, t);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Arrasto com trava de eixo (gesto claramente horizontal/vertical nao
  /// "sai torto") + snap no centro da composicao.
  void _onPadUpdate(Offset delta) {
    final controller = ref.read(editorControllerProvider.notifier);
    final project = ref.read(editorControllerProvider);
    final t = playback.time.value;
    _accum += delta * 2;

    var target = _dragStart + _accum;
    final adx = _accum.dx.abs();
    final ady = _accum.dy.abs();
    if (adx > 24 || ady > 24) {
      if (adx > ady * 2.5) {
        target = Offset(target.dx, _dragStart.dy);
      } else if (ady > adx * 2.5) {
        target = Offset(_dragStart.dx, target.dy);
      }
    }
    final cx = project.outputWidth / 2;
    final cy = project.outputHeight / 2;
    if ((target.dx - cx).abs() < 16) target = Offset(cx, target.dy);
    if ((target.dy - cy).abs() < 16) target = Offset(target.dx, cy);

    controller.editPosition(layer.id, t, target);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final project = ref.watch(editorControllerProvider);
    final t = playback.time.value;
    final local = layer.localTime(t);
    final pos = layer.position.valueAt(local);
    final z = layer.positionZ.valueAt(local);
    final controller = ref.read(editorControllerProvider.notifier);
    final link = project.linkFor(layer.id, LayerProp.position);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmValueChip(text: amNumber(pos.dx), label: 'X', width: 96),
            const SizedBox(width: 10),
            AmValueChip(text: amNumber(pos.dy), label: 'Y', width: 96),
            if (layer.is3D) ...[
              const SizedBox(width: 10),
              AmValueChip(text: amNumber(z), label: 'Z', width: 96),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 4),
            const Text('3D',
                style: TextStyle(fontSize: 12, color: AmColors.muted)),
            Transform.scale(
              scale: 0.72,
              child: CupertinoSwitch(
                value: layer.is3D,
                activeTrackColor: AmColors.accent,
                onChanged: (_) => controller.toggle3D(layer.id),
              ),
            ),
            const Spacer(),
            // Pickwhip: seguir a posicao de outra camada.
            GestureDetector(
              onTap: link != null
                  ? () => controller.unlinkProperty(
                      layer.id, LayerProp.position)
                  : () => _pickLinkSource(context, ref, t),
              child: Row(
                children: [
                  Icon(
                    link != null
                        ? CupertinoIcons.link_circle_fill
                        : CupertinoIcons.link,
                    size: 18,
                    color:
                        link != null ? AmColors.accent : AmColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    link != null ? 'Vinculado' : 'Vincular',
                    style: TextStyle(
                        fontSize: 11,
                        color: link != null
                            ? AmColors.accent
                            : AmColors.muted),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
        if (layer.is3D)
          AmTickRuler(
            value: z,
            min: -1000,
            max: 4000,
            unitsPerPixel: 4,
            height: 34,
            onChanged: (v) => controller.editPositionZ(layer.id, t, v),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              _dragStart = layer.position
                  .valueAt(layer.localTime(playback.time.value));
              _accum = Offset.zero;
            },
            onPanUpdate: (d) => _onPadUpdate(d.delta),
            child: Container(
              decoration: BoxDecoration(
                color: AmColors.bg.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_with, size: 30, color: AmColors.muted),
                    SizedBox(height: 4),
                    Text('Arraste para mover (alinha no eixo)',
                        style:
                            TextStyle(fontSize: 12, color: AmColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PivotControl extends ConsumerWidget {
  const _PivotControl({required this.layer, required this.playback});

  final Layer layer;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = playback.time.value;
    final pivot = layer.pivot.valueAt(layer.localTime(t));
    final controller = ref.read(editorControllerProvider.notifier);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmValueChip(text: amNumber(pivot.dx), label: 'Pivo X', width: 112),
            const SizedBox(width: 18),
            AmValueChip(text: amNumber(pivot.dy), label: 'Pivo Y', width: 112),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) =>
                controller.editPivot(layer.id, t, pivot + d.delta * 2),
            onDoubleTap: () =>
                controller.editPivot(layer.id, t, Offset.zero),
            child: Container(
              decoration: BoxDecoration(
                color: AmColors.bg.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_center_focus,
                        size: 32, color: AmColors.muted),
                    SizedBox(height: 6),
                    Text('Arraste o ponto de giro\n(toque duplo = centro)',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: AmColors.muted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RotationControl extends ConsumerWidget {
  const _RotationControl({required this.layer, required this.playback});

  final Layer layer;
  final PlaybackController playback;

  void _setFromPoint(WidgetRef ref, Offset localPos, Size size, Duration t) {
    final center = Offset(size.width / 2, size.height / 2);
    final v = localPos - center;
    final deg = math.atan2(v.dy, v.dx) * 180 / math.pi;
    ref.read(editorControllerProvider.notifier).editRotation(layer.id, t, deg);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = playback.time.value;
    final local = layer.localTime(t);
    final deg = layer.rotation.valueAt(local);
    // Contador de voltas (aceita >360).
    final turns = (deg / 360).truncate();
    final controller = ref.read(editorControllerProvider.notifier);

    final dial = LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final radius = math.min(size.width, size.height) / 2 - 16;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _setFromPoint(ref, d.localPosition, size, t),
          onTapDown: (d) => _setFromPoint(ref, d.localPosition, size, t),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(size: size, painter: _DialPainter(radius: radius)),
              Container(
                width: 190,
                height: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AmColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  turns == 0
                      ? '${amNumber(deg, 0)}°'
                      : '${amNumber(deg % 360, 0)}°, ${turns}x',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    color: AmColors.accent,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(
                  math.cos(deg * math.pi / 180) * radius,
                  math.sin(deg * math.pi / 180) * radius,
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!layer.is3D) return dial;

    // Camada 3D: alem do dial (eixo Z), reguas para girar em X e Y.
    final rx = layer.rotationX.valueAt(local);
    final ry = layer.rotationY.valueAt(local);
    return Column(
      children: [
        Expanded(child: dial),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(
                width: 44,
                child: Text('3D X',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: AmColors.muted))),
            Expanded(
              child: AmTickRuler(
                value: rx,
                min: -1080,
                max: 1080,
                unitsPerPixel: 0.8,
                height: 40,
                onChanged: (v) =>
                    controller.editRotationX(layer.id, t, v),
              ),
            ),
            SizedBox(
                width: 62,
                child: Text('${amNumber(rx, 0)}°',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AmColors.accent))),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(
                width: 44,
                child: Text('3D Y',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: AmColors.muted))),
            Expanded(
              child: AmTickRuler(
                value: ry,
                min: -1080,
                max: 1080,
                unitsPerPixel: 0.8,
                accentCenter: false,
                height: 40,
                onChanged: (v) =>
                    controller.editRotationY(layer.id, t, v),
              ),
            ),
            SizedBox(
                width: 62,
                child: Text('${amNumber(ry, 0)}°',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AmColors.accent))),
          ],
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF3A4660)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.radius != radius;
}

class _ScaleControl extends ConsumerWidget {
  const _ScaleControl({
    required this.layer,
    required this.playback,
    required this.linked,
    required this.onToggleLink,
  });

  final Layer layer;
  final PlaybackController playback;
  final bool linked;
  final VoidCallback onToggleLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = playback.time.value;
    final local = layer.localTime(t);
    final sx = layer.scaleX.valueAt(local);
    final sy = layer.scaleY.valueAt(local);
    final controller = ref.read(editorControllerProvider.notifier);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmValueChip(
                text: amNumber(sx * 100), label: 'Largura', width: 112),
            GestureDetector(
              onTap: onToggleLink,
              child: Container(
                width: 46,
                height: 46,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: linked ? const Color(0xFFE9EDF2) : AmColors.chip,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(CupertinoIcons.link,
                    size: 20,
                    color:
                        linked ? const Color(0xFF12151A) : AmColors.muted),
              ),
            ),
            AmValueChip(
                text: amNumber(sy * 100), label: 'Altura', width: 112),
          ],
        ),
        const SizedBox(height: 10),
        if (linked)
          Expanded(
            child: AmTickRuler(
              value: sx * 100,
              min: 1,
              max: 2000,
              unitsPerPixel: 0.6,
              height: double.infinity,
              onChanged: (v) =>
                  controller.editScaleUniform(layer.id, t, v / 100),
            ),
          )
        else ...[
          Expanded(
            child: AmTickRuler(
              value: sx * 100,
              min: 1,
              max: 2000,
              unitsPerPixel: 0.6,
              height: double.infinity,
              onChanged: (v) => controller.editScaleX(layer.id, t, v / 100),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AmTickRuler(
              value: sy * 100,
              min: 1,
              max: 2000,
              unitsPerPixel: 0.6,
              accentCenter: false,
              height: double.infinity,
              onChanged: (v) => controller.editScaleY(layer.id, t, v / 100),
            ),
          ),
        ],
      ],
    );
  }
}

class _SkewControl extends ConsumerWidget {
  const _SkewControl({required this.layer, required this.playback});

  final Layer layer;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = playback.time.value;
    final local = layer.localTime(t);
    final kx = layer.skewX.valueAt(local);
    final ky = layer.skewY.valueAt(local);
    final controller = ref.read(editorControllerProvider.notifier);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AmValueChip(text: '${amNumber(kx, 2)}°', label: 'X Skew', width: 112),
            const SizedBox(width: 18),
            AmValueChip(text: '${amNumber(ky, 2)}°', label: 'Y Skew', width: 112),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AmTickRuler(
            value: kx,
            min: -80,
            max: 80,
            unitsPerPixel: 0.25,
            height: double.infinity,
            onChanged: (v) => controller.editSkewX(layer.id, t, v),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: AmTickRuler(
            value: ky,
            min: -80,
            max: 80,
            unitsPerPixel: 0.25,
            accentCenter: false,
            height: double.infinity,
            onChanged: (v) => controller.editSkewY(layer.id, t, v),
          ),
        ),
      ],
    );
  }
}
