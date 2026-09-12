import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/cut_ops.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../../native/native_engine.dart';
import 'am_colors.dart';

/// Modelo de Keyframe local para edição da Curva de Time Remapping
class RemapPoint {
  RemapPoint({
    required this.compositionTime,
    required this.sourceTime,
    this.interpolation = 0, // 0=Linear, 1=Hold, 2=Bezier, 3=EaseIn, 4=EaseOut, 5=EaseInOut
    this.inHandle = const Offset(-0.2, 0.0),
    this.outHandle = const Offset(0.2, 0.0),
  });

  double compositionTime; // segundos
  double sourceTime;      // segundos
  int interpolation;
  Offset inHandle;
  Offset outHandle;

  RemapPoint copyWith({
    double? compositionTime,
    double? sourceTime,
    int? interpolation,
    Offset? inHandle,
    Offset? outHandle,
  }) =>
      RemapPoint(
        compositionTime: compositionTime ?? this.compositionTime,
        sourceTime: sourceTime ?? this.sourceTime,
        interpolation: interpolation ?? this.interpolation,
        inHandle: inHandle ?? this.inHandle,
        outHandle: outHandle ?? this.outHandle,
      );
}

/// EDITOR DE CURVA DE TIME REMAPPING (Estilo After Effects para Mobile)
class TimeRemapCurveEditor extends ConsumerStatefulWidget {
  const TimeRemapCurveEditor({
    super.key,
    required this.layerId,
    this.playback,
  });

  final String layerId;
  final PlaybackController? playback;

  @override
  ConsumerState<TimeRemapCurveEditor> createState() => _TimeRemapCurveEditorState();
}

class _TimeRemapCurveEditorState extends ConsumerState<TimeRemapCurveEditor> {
  final List<RemapPoint> _points = [];
  int? _selectedIndex;
  bool _draggingPoint = false;
  bool _draggingInHandle = false;
  bool _draggingOutHandle = false;

  double _maxCompDuration = 5.0;
  double _maxSourceDuration = 5.0;

  @override
  void initState() {
    super.initState();
    _loadFromProject();
  }

  void _loadFromProject() {
    final project = ref.read(editorControllerProvider);
    final layer = project.layerById(widget.layerId);
    if (layer is! VideoLayer) return;

    _maxCompDuration = layer.duration.inMicroseconds / 1000000.0;
    _maxSourceDuration = (layer.sourceDuration?.inMicroseconds ?? layer.duration.inMicroseconds) / 1000000.0;
    if (_maxCompDuration <= 0) _maxCompDuration = 5.0;
    if (_maxSourceDuration <= 0) _maxSourceDuration = 5.0;

    _points.clear();

    // Sincroniza a partir do track existente ou gera padrão 1:1
    final track = timeRemapTrackOf(layer);
    if (track != null && track.keyframes.isNotEmpty) {
      for (final kf in track.keyframes) {
        _points.add(
          RemapPoint(
            compositionTime: kf.time.inMicroseconds / 1000000.0,
            sourceTime: kf.value,
            interpolation: 2, // Bezier
          ),
        );
      }
    } else {
      // Padrão 1:1 inicial (0s -> 0s e fim -> fim)
      _points.add(RemapPoint(compositionTime: 0.0, sourceTime: 0.0));
      _points.add(RemapPoint(compositionTime: _maxCompDuration, sourceTime: _maxCompDuration));
    }
    _sortPoints();
    _syncToNative();
  }

  void _sortPoints() {
    _points.sort((a, b) => a.compositionTime.compareTo(b.compositionTime));
  }

  void _syncToNative() {
    final native = NativeEngine.instance;
    if (!native.isSupported) return;

    native.setTimeRemapEnabled(widget.layerId, true);
    native.clearTimeRemapKeyframes(widget.layerId);

    for (final p in _points) {
      native.addTimeRemapKeyframe(
        widget.layerId,
        p.compositionTime,
        p.sourceTime,
        interpolation: p.interpolation,
        inDx: p.inHandle.dx,
        inDy: p.inHandle.dy,
        outDx: p.outHandle.dx,
        outDy: p.outHandle.dy,
      );
    }
  }

  void _syncToDartProject() {
    // Sincroniza os pontos com a AnimatedDouble do EffectInstance no VideoLayer
    final controller = ref.read(editorControllerProvider.notifier);
    final project = ref.read(editorControllerProvider);
    final layer = project.layerById(widget.layerId);
    if (layer is! VideoLayer) return;

    if (_points.isEmpty) return;

    var track = AnimatedDouble(_points.first.sourceTime);
    for (final p in _points) {
      track = track.withKeyframe(
        Duration(microseconds: (p.compositionTime * 1000000).round()),
        p.sourceTime,
        Easing.linear,
      );
    }

    controller.setClipTimeRemap(widget.layerId, track);
    _syncToNative();
  }

  // AVALIAÇÃO DETERMINÍSTICA
  double _evaluateAt(double compTime) {
    if (_points.isEmpty) return compTime;
    if (_points.length == 1) return _points.first.sourceTime;

    if (compTime <= _points.first.compositionTime) return _points.first.sourceTime;
    if (compTime >= _points.back.compositionTime) return _points.back.sourceTime;

    for (var i = 0; i < _points.length - 1; i++) {
      final p0 = _points[i];
      final p1 = _points[i + 1];
      if (compTime >= p0.compositionTime && compTime <= p1.compositionTime) {
        final dt = p1.compositionTime - p0.compositionTime;
        if (dt <= 1e-6) return p0.sourceTime;

        if (p0.interpolation == 1) {
          // Hold
          return p0.sourceTime;
        }

        // Linear/Bézier progresso normalizado
        final u = (compTime - p0.compositionTime) / dt;
        return p0.sourceTime + u * (p1.sourceTime - p0.sourceTime);
      }
    }
    return compTime;
  }

  // VELOCIDADE DERIVADA
  double _getSpeedAt(double compTime) {
    const delta = 0.01;
    final y1 = _evaluateAt(compTime - delta);
    final y2 = _evaluateAt(compTime + delta);
    return (y2 - y1) / (delta * 2);
  }

  // ADIÇÃO EXPLÍCITA DE KEYFRAME (NUNCA AUTOMÁTICA)
  void _addKeyframeExplicit() {
    final currentPlayheadSec = (widget.playback?.currentTime.inMicroseconds ?? 0) / 1000000.0;
    final clampedComp = currentPlayheadSec.clamp(0.0, _maxCompDuration);
    final currentSource = _evaluateAt(clampedComp);

    // Verifica se já existe um keyframe muito próximo
    final existingIndex = _points.indexWhere((p) => (p.compositionTime - clampedComp).abs() < 0.05);
    if (existingIndex != -1) {
      setState(() => _selectedIndex = existingIndex);
      return;
    }

    final newPoint = RemapPoint(
      compositionTime: clampedComp,
      sourceTime: currentSource,
      interpolation: 2, // Bezier
    );

    setState(() {
      _points.add(newPoint);
      _sortPoints();
      _selectedIndex = _points.indexOf(newPoint);
    });

    _syncToDartProject();
  }

  void _removeSelectedKeyframe() {
    if (_selectedIndex == null || _selectedIndex! < 0 || _selectedIndex! >= _points.length) return;
    // Preserva no mínimo 2 keyframes nas pontas
    if (_points.length <= 2) {
      _showToast('O Time Remap precisa de pelo menos 2 pontos.');
      return;
    }

    setState(() {
      _points.removeAt(_selectedIndex!);
      _selectedIndex = null;
    });

    _syncToDartProject();
  }

  void _setInterpolation(int type) {
    if (_selectedIndex == null || _selectedIndex! >= _points.length) return;
    setState(() {
      _points[_selectedIndex!].interpolation = type;
    });
    _syncToDartProject();
  }

  void _freezeFrame() {
    if (_selectedIndex == null || _selectedIndex! >= _points.length) return;
    final p = _points[_selectedIndex!];
    final freezeDuration = 1.0; // 1 segundo de freeze
    final nextTime = (p.compositionTime + freezeDuration).clamp(0.0, _maxCompDuration);

    final freezePoint = RemapPoint(
      compositionTime: nextTime,
      sourceTime: p.sourceTime, // mesmo instante de vídeo
      interpolation: 1, // Hold
    );

    setState(() {
      _points.add(freezePoint);
      _sortPoints();
      _selectedIndex = _points.indexOf(freezePoint);
    });

    _syncToDartProject();
  }

  void _reverseSegment() {
    if (_points.length < 2) return;
    setState(() {
      for (var i = 0; i < _points.length ~/ 2; i++) {
        final j = _points.length - 1 - i;
        final temp = _points[i].sourceTime;
        _points[i].sourceTime = _points[j].sourceTime;
        _points[j].sourceTime = temp;
      }
    });
    _syncToDartProject();
  }

  void _resetDefault() {
    setState(() {
      _points.clear();
      _points.add(RemapPoint(compositionTime: 0.0, sourceTime: 0.0));
      _points.add(RemapPoint(compositionTime: _maxCompDuration, sourceTime: _maxCompDuration));
      _selectedIndex = null;
    });
    _syncToDartProject();
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playheadSec = (widget.playback?.currentTime.inMicroseconds ?? 0) / 1000000.0;
    final selectedPoint = (_selectedIndex != null && _selectedIndex! < _points.length)
        ? _points[_selectedIndex!]
        : null;

    final currentSpeed = _getSpeedAt(playheadSec);

    return Container(
      color: const Color(0xFF16181C),
      child: Column(
        children: [
          // CABEÇALHO COM TÍTULO E AÇÕES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: AmColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'TIME REMAPPING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  'Velocidade: ${(currentSpeed * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: currentSpeed < 0 ? Colors.redAccent : AmColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ÁREA PRINCIPAL DA CURVA (EIXO X: COMPOSITION TIME, EIXO Y: SOURCE TIME)
          Expanded(
            flex: 5,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return GestureDetector(
                  onPanDown: (details) => _handleTouchDown(details.localPosition, width, height),
                  onPanUpdate: (details) => _handleTouchUpdate(details.localPosition, width, height),
                  onPanEnd: (_) => _handleTouchEnd(),
                  child: CustomPaint(
                    size: Size(width, height),
                    painter: _CurvePainter(
                      points: _points,
                      selectedIndex: _selectedIndex,
                      maxCompDuration: _maxCompDuration,
                      maxSourceDuration: _maxSourceDuration,
                      playheadSec: playheadSec,
                    ),
                  ),
                );
              },
            ),
          ),

          // BARRA DE FERRAMENTAS EXPLÍCITAS (Estilo After Effects)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1E2126),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.add_circle_outline_rounded,
                    label: '+ Keyframe',
                    color: AmColors.accent,
                    onPressed: _addKeyframeExplicit,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remover',
                    color: selectedPoint != null ? Colors.redAccent : Colors.grey,
                    onPressed: selectedPoint != null ? _removeSelectedKeyframe : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.linear_scale_rounded,
                    label: 'Linear',
                    onPressed: selectedPoint != null ? () => _setInterpolation(0) : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.gesture_rounded,
                    label: 'Bézier',
                    onPressed: selectedPoint != null ? () => _setInterpolation(2) : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.pause_circle_outline_rounded,
                    label: 'Hold',
                    onPressed: selectedPoint != null ? () => _setInterpolation(1) : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.ac_unit_rounded,
                    label: 'Freeze',
                    onPressed: selectedPoint != null ? _freezeFrame : null,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Inverter',
                    onPressed: _reverseSegment,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.restart_alt_rounded,
                    label: 'Resetar',
                    onPressed: _resetDefault,
                  ),
                ],
              ),
            ),
          ),

          // INSPECTOR NUMÉRICO DO KEYFRAME SELECIONADO
          if (selectedPoint != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF121417),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('COMPOSIÇÃO', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        Text(
                          formatDurationPrecise(
                            Duration(microseconds: (selectedPoint.compositionTime * 1000000).round()),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('FONTE (VÍDEO)', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        Text(
                          formatDurationPrecise(
                            Duration(microseconds: (selectedPoint.sourceTime * 1000000).round()),
                          ),
                          style: const TextStyle(color: AmColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TIPO', style: TextStyle(color: Colors.grey, fontSize: 10)),
                        Text(
                          switch (selectedPoint.interpolation) {
                            1 => 'Hold',
                            2 => 'Bézier',
                            3 => 'Ease In',
                            4 => 'Ease Out',
                            _ => 'Linear',
                          },
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // TOUCH DISPATCHER
  void _handleTouchDown(Offset local, double width, double height) {
    _draggingPoint = false;
    _draggingInHandle = false;
    _draggingOutHandle = false;

    // 1. Testa se tocou em alças do ponto selecionado
    if (_selectedIndex != null && _selectedIndex! < _points.length) {
      final p = _points[_selectedIndex!];
      final pt = _pointToScreen(p.compositionTime, p.sourceTime, width, height);

      final inPt = pt + Offset(p.inHandle.dx * width / _maxCompDuration, -p.inHandle.dy * height / _maxSourceDuration);
      if ((local - inPt).distance <= 20) {
        _draggingInHandle = true;
        return;
      }

      final outPt = pt + Offset(p.outHandle.dx * width / _maxCompDuration, -p.outHandle.dy * height / _maxSourceDuration);
      if ((local - outPt).distance <= 20) {
        _draggingOutHandle = true;
        return;
      }
    }

    // 2. Testa se tocou em algum ponto de keyframe
    for (var i = 0; i < _points.length; i++) {
      final pt = _pointToScreen(_points[i].compositionTime, _points[i].sourceTime, width, height);
      if ((local - pt).distance <= 24) {
        setState(() {
          _selectedIndex = i;
          _draggingPoint = true;
        });
        return;
      }
    }

    // 3. Toque na área livre: deseleciona ou posiciona playhead
    final compTime = (local.dx / width * _maxCompDuration).clamp(0.0, _maxCompDuration);
    widget.playback?.seek(Duration(microseconds: (compTime * 1000000).round()));
  }

  void _handleTouchUpdate(Offset local, double width, double height) {
    if (_selectedIndex == null || _selectedIndex! >= _points.length) return;

    if (_draggingPoint) {
      final newComp = (local.dx / width * _maxCompDuration).clamp(0.0, _maxCompDuration);
      final newSource = ((1.0 - local.dy / height) * _maxSourceDuration).clamp(0.0, _maxSourceDuration * 2.0);

      setState(() {
        _points[_selectedIndex!].compositionTime = newComp;
        _points[_selectedIndex!].sourceTime = newSource;
        _sortPoints();
      });
      _syncToDartProject();
    } else if (_draggingInHandle) {
      final p = _points[_selectedIndex!];
      final pt = _pointToScreen(p.compositionTime, p.sourceTime, width, height);
      final delta = local - pt;
      setState(() {
        p.inHandle = Offset(
          delta.dx / width * _maxCompDuration,
          -delta.dy / height * _maxSourceDuration,
        );
      });
      _syncToDartProject();
    } else if (_draggingOutHandle) {
      final p = _points[_selectedIndex!];
      final pt = _pointToScreen(p.compositionTime, p.sourceTime, width, height);
      final delta = local - pt;
      setState(() {
        p.outHandle = Offset(
          delta.dx / width * _maxCompDuration,
          -delta.dy / height * _maxSourceDuration,
        );
      });
      _syncToDartProject();
    }
  }

  void _handleTouchEnd() {
    _draggingPoint = false;
    _draggingInHandle = false;
    _draggingOutHandle = false;
  }

  Offset _pointToScreen(double compTime, double sourceTime, double w, double h) {
    final x = (compTime / _maxCompDuration) * w;
    final y = h - (sourceTime / _maxSourceDuration) * h;
    return Offset(x, y);
  }
}

// BOTÃO ESTILIZADO DE AÇÃO
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color = Colors.white,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: enabled ? const Color(0xFF2A2E35) : const Color(0xFF1E2126),
      minSize: 32,
      borderRadius: BorderRadius.circular(6),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: enabled ? color : Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? color : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// PINTOR DA CURVA COM GRID E ALÇAS
class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.points,
    required this.selectedIndex,
    required this.maxCompDuration,
    required this.maxSourceDuration,
    required this.playheadSec,
  });

  final List<RemapPoint> points;
  final int? selectedIndex;
  final double maxCompDuration;
  final double maxSourceDuration;
  final double playheadSec;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Grade de Fundo
    final gridPaint = Paint()
      ..color = const Color(0xFF23272F)
      ..strokeWidth = 1.0;

    for (var i = 1; i < 5; i++) {
      final y = h * (i / 5.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
      final x = w * (i / 5.0);
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // 2. Desenha a Curva Bézier
    if (points.isNotEmpty) {
      final curvePaint = Paint()
        ..color = AmColors.accent
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final pt = _toScreen(points[i].compositionTime, points[i].sourceTime, w, h);
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          final prev = points[i - 1];
          final prevPt = _toScreen(prev.compositionTime, prev.sourceTime, w, h);

          if (prev.interpolation == 1) {
            // Hold: linha horizontal até X do próximo, depois sobe reto
            path.lineTo(pt.dx, prevPt.dy);
            path.lineTo(pt.dx, pt.dy);
          } else {
            // Curva Bézier com handles
            final c1 = prevPt + Offset(prev.outHandle.dx * w / maxCompDuration, -prev.outHandle.dy * h / maxSourceDuration);
            final c2 = pt + Offset(points[i].inHandle.dx * w / maxCompDuration, -points[i].inHandle.dy * h / maxSourceDuration);
            path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, pt.dx, pt.dy);
          }
        }
      }
      canvas.drawPath(path, curvePaint);
    }

    // 3. Linha do Playhead
    final playheadX = (playheadSec / maxCompDuration).clamp(0.0, 1.0) * w;
    final playheadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, h), playheadPaint);

    // 4. Desenha Keyframes e Alças
    final pointFill = Paint()..color = Colors.white;
    final pointSelectedFill = Paint()..color = AmColors.accent;
    final haloPaint = Paint()
      ..color = AmColors.accent.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final handleLinePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 1.5;
    final handleCirclePaint = Paint()..color = Colors.orangeAccent;

    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final pt = _toScreen(p.compositionTime, p.sourceTime, w, h);
      final isSelected = (i == selectedIndex);

      if (isSelected) {
        canvas.drawCircle(pt, 12, haloPaint);

        // Desenha handles tangentes
        final inPt = pt + Offset(p.inHandle.dx * w / maxCompDuration, -p.inHandle.dy * h / maxSourceDuration);
        canvas.drawLine(pt, inPt, handleLinePaint);
        canvas.drawCircle(inPt, 5, handleCirclePaint);

        final outPt = pt + Offset(p.outHandle.dx * w / maxCompDuration, -p.outHandle.dy * h / maxSourceDuration);
        canvas.drawLine(pt, outPt, handleLinePaint);
        canvas.drawCircle(outPt, 5, handleCirclePaint);
      }

      canvas.drawCircle(pt, isSelected ? 7 : 5, isSelected ? pointSelectedFill : pointFill);
    }
  }

  Offset _toScreen(double compTime, double sourceTime, double w, double h) {
    final x = (compTime / maxCompDuration) * w;
    final y = h - (sourceTime / maxSourceDuration) * h;
    return Offset(x, y);
  }

  @override
  bool shouldRepaint(covariant _CurvePainter oldDelegate) => true;
}
