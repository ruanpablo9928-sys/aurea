import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import '../../application/media_preview_service.dart';
import '../../application/proxy_service.dart';
import 'am_colors.dart';
import 'clip_preview_painters.dart';

const double kAmRowHeight = 46;
const double kAmBarHeight = 38;

/// Timeline do editor: regua com relogio central, playhead fixo no centro,
/// pilulas de camada (olho + miniatura) fixas a esquerda e barras teal.
///
/// [singleLayerId] != null -> modo pagina de ferramenta: mostra so a camada
/// selecionada, com setas < > para navegar entre camadas.
class AmTimeline extends ConsumerStatefulWidget {
  const AmTimeline({
    super.key,
    required this.playback,
    this.singleLayerId,
    this.playheadColor = Colors.white,
    this.height = 260,
    this.onTapLayer,
    this.activeTimesUs,
  });

  final PlaybackController playback;
  final String? singleLayerId;
  final Color playheadColor;
  final double height;
  final void Function(Layer layer)? onTapLayer;

  /// Tempos locais (em us) com keyframe da propriedade ATIVA: esses
  /// diamantes acendem; os demais aparecem apagados. null = todos acesos.
  final Set<int>? activeTimesUs;

  @override
  ConsumerState<AmTimeline> createState() => _AmTimelineState();
}

class _AmTimelineState extends ConsumerState<AmTimeline> {
  final ScrollController _scroll = ScrollController();
  double _pps = 80;
  double _ppsAtGestureStart = 80;
  double _scrollAtGestureStart = 0;
  double _focalAtGestureStart = 0;
  bool _syncingScroll = false;
  bool _editingBar = false;

  @override
  void initState() {
    super.initState();
    widget.playback.time.addListener(_onClock);
    // Sem isso, uma timeline recem-criada (ex.: ao abrir um painel) fica
    // com scroll 0 enquanto o tempo real esta em outro ponto — e o
    // keyframe parece nascer "fora" do playhead.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onClock());
  }

  @override
  void dispose() {
    widget.playback.time.removeListener(_onClock);
    _scroll.dispose();
    super.dispose();
  }

  void _onClock() {
    if (!_scroll.hasClients || _editingBar) return;
    final target = _timeToPx(widget.playback.time.value);
    if ((target - _scroll.offset).abs() < 0.5) return;
    _syncingScroll = true;
    _scroll.jumpTo(target.clamp(0.0, _scroll.position.maxScrollExtent));
    _syncingScroll = false;
  }

  double _timeToPx(Duration t) => t.inMicroseconds / 1e6 * _pps;

  Duration _pxToTime(double px) =>
      Duration(microseconds: (px / _pps * 1e6).round());

  bool _onScroll(ScrollNotification n) {
    if (_syncingScroll || _editingBar) return false;
    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null && widget.playback.playing.value) {
        widget.playback.pause();
      }
      if (!widget.playback.playing.value) {
        widget.playback.seek(_pxToTime(n.metrics.pixels));
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selectedId = ref.watch(selectedLayerProvider);
    final multi = ref.watch(multiSelectProvider);
    final layers = widget.singleLayerId != null
        ? [
            if (project.layerById(widget.singleLayerId!) != null)
              project.layerById(widget.singleLayerId!)!,
          ]
        : project.layers;
    final totalWidth = _timeToPx(project.duration);

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pad = constraints.maxWidth / 2;
          return GestureDetector(
            onScaleStart: (d) {
              _ppsAtGestureStart = _pps;
              _scrollAtGestureStart =
                  _scroll.hasClients ? _scroll.offset : 0;
              _focalAtGestureStart = d.localFocalPoint.dx;
            },
            onScaleUpdate: (d) {
              if (d.pointerCount < 2) return;
              setState(() {
                // Zoom ancorado no CENTROIDE da pinca (AUREA §3.1-5):
                // o conteudo sob os dedos fica sob os dedos.
                final newPps =
                    (_ppsAtGestureStart * d.scale).clamp(16.0, 400.0);
                final k = newPps / _ppsAtGestureStart;
                final contentAtFocal = _scrollAtGestureStart +
                    (_focalAtGestureStart - pad);
                final newOffset =
                    contentAtFocal * k - (_focalAtGestureStart - pad);
                _pps = newPps;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    // Sem suprimir o seek: o tempo sob o playhead central
                    // continua verdadeiro durante o zoom.
                    _scroll.jumpTo(newOffset.clamp(
                        0.0, _scroll.position.maxScrollExtent));
                  }
                });
              });
            },
            child: Stack(
              children: [
                // Conteudo rolavel: regua + linhas de camada.
                NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    // Rubber-band nas pontas em vez de parede seca
                    // (AUREA §3.1-4: "parecer iOS").
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      child: SizedBox(
                        width: totalWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 20,
                              width: totalWidth,
                              child: CustomPaint(
                                painter: _AmRulerPainter(pps: _pps),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    for (final layer in layers)
                                      _AmLayerRow(
                                        key: ValueKey(layer.id),
                                        layer: layer,
                                        pps: _pps,
                                        totalWidth: totalWidth,
                                        selected: layer.id == selectedId ||
                                            multi.contains(layer.id) ||
                                            widget.singleLayerId != null,
                                        compact:
                                            widget.singleLayerId != null,
                                        playback: widget.playback,
                                        onTapLayer: widget.onTapLayer,
                                        activeTimesUs:
                                            widget.activeTimesUs,
                                        onEditStart: () =>
                                            _editingBar = true,
                                        onEditEnd: () =>
                                            _editingBar = false,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Relogio central sob a regua.
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: widget.playback.time,
                      builder: (context, t, _) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        color: AmColors.bg,
                        child: Text(
                          formatTimecode(t, project.fps),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white70,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Playhead central.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 1.6,
                      color: widget.playheadColor,
                    ),
                  ),
                ),
                if (widget.playheadColor != Colors.white)
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 0),
                        decoration: BoxDecoration(
                          color: widget.playheadColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                // Tesoura no CABECOTE: divide a camada selecionada onde
                // a mao ja esta (spec barra-de-acoes §3).
                if (widget.singleLayerId == null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final id = ref.read(selectedLayerProvider);
                        if (id == null) return;
                        ref
                            .read(editorControllerProvider.notifier)
                            .splitLayer(id, widget.playback.time.value);
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: AmColors.panelHigh,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AmColors.hairline),
                        ),
                        child: const Icon(CupertinoIcons.scissors,
                            size: 17, color: AmColors.text),
                      ),
                    ),
                  ),
                // Pilulas fixas a esquerda (olho + miniatura), uma por linha.
                Positioned(
                  left: 0,
                  top: 50,
                  child: Column(
                    children: [
                      for (final layer in layers)
                        _AmLayerPill(layer: layer),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pilula fixa: olho + miniatura da camada.
class _AmLayerPill extends StatelessWidget {
  const _AmLayerPill({required this.layer});

  final Layer layer;

  Color get _thumbColor => switch (layer) {
        ShapeLayer l => l.primaryColor,
        TextLayer _ => Colors.white,
        VideoLayer _ => const Color(0xFF3D6BB3),
        ImageLayer _ => const Color(0xFF8A5BA0),
        AudioLayer _ => const Color(0xFF2E8B62),
        CaptionLayer _ => const Color(0xFFE8B93E),
        GroupLayer _ => const Color(0xFF6B7A94),
        NullLayer _ => const Color(0xFF9F8CFF),
        ParticlesLayer l => l.color,
        Element3DLayer l => l.color,
        AdjustmentLayer _ => const Color(0xFF56D1C4),
        Scene3DLayer _ => const Color(0xFF35C4E7),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kAmRowHeight,
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 4),
        decoration: const BoxDecoration(
          color: AmColors.panel,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.eye, size: 18, color: AmColors.text),
            const SizedBox(width: 8),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _thumbColor,
                borderRadius: BorderRadius.circular(
                    layer is ShapeLayer ? 13 : 5),
              ),
              child: layer is TextLayer
                  ? const Center(
                      child: Text('T',
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmRulerPainter extends CustomPainter {
  const _AmRulerPainter({required this.pps});

  final double pps;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFF5A6880)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFF8A97AD)
      ..strokeWidth = 1.4;
    final step = pps / 10; // 10 ticks por segundo
    var i = 0;
    for (var x = 0.0; x < size.width; x += step) {
      final isMajor = i % 10 == 0;
      canvas.drawLine(
        Offset(x, isMajor ? 2 : 9),
        Offset(x, size.height - 2),
        isMajor ? major : minor,
      );
      i++;
    }
  }

  @override
  bool shouldRepaint(_AmRulerPainter old) => old.pps != pps;
}

class _AmLayerRow extends ConsumerStatefulWidget {
  const _AmLayerRow({
    super.key,
    required this.layer,
    required this.pps,
    required this.totalWidth,
    required this.selected,
    required this.compact,
    required this.playback,
    required this.onEditStart,
    required this.onEditEnd,
    this.onTapLayer,
    this.activeTimesUs,
  });

  final Layer layer;
  final double pps;
  final double totalWidth;
  final bool selected;

  /// Modo pagina de ferramenta (faixa unica com setas de navegacao).
  final bool compact;
  final PlaybackController playback;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;
  final void Function(Layer layer)? onTapLayer;
  final Set<int>? activeTimesUs;

  @override
  ConsumerState<_AmLayerRow> createState() => _AmLayerRowState();
}

class _AmLayerRowState extends ConsumerState<_AmLayerRow> {
  Layer get layer => widget.layer;
  double get pps => widget.pps;
  double get totalWidth => widget.totalWidth;
  bool get selected => widget.selected;
  bool get compact => widget.compact;
  PlaybackController get playback => widget.playback;
  VoidCallback get onEditStart => widget.onEditStart;
  VoidCallback get onEditEnd => widget.onEditEnd;
  void Function(Layer layer)? get onTapLayer => widget.onTapLayer;
  Set<int>? get activeTimesUs => widget.activeTimesUs;

  // Arrasto acumulado desde o inicio do gesto: o snap nao "prende" a
  // barra, porque a posicao desejada e recalculada do ponto de origem.
  Duration _dragStart0 = Duration.zero;
  double _accumPx = 0;
  Duration _trimStart0 = Duration.zero;
  double _trimAccumPx = 0;

  /// Ultimo alvo de snap: o tique haptico dispara UMA vez por encaixe.
  Duration? _lastSnapTarget;

  void _hapticIfSnapped(Duration desired, Duration snapped) {
    if (snapped == desired) {
      _lastSnapTarget = null;
      return;
    }
    if (_lastSnapTarget != snapped) {
      _lastSnapTarget = snapped;
      HapticFeedback.selectionClick();
    }
  }

  Duration _pxToDur(double px) =>
      Duration(microseconds: (px / pps * 1e6).round());

  /// Snap magnetico: playhead, 0s e bordas das outras camadas.
  Duration _snap(Duration v) {
    final tolUs = (12 / pps * 1e6).round();
    final project = ref.read(editorControllerProvider);
    var best = v;
    var bestD = tolUs + 1;
    void consider(Duration target) {
      final d = (v - target).inMicroseconds.abs();
      if (d < bestD) {
        bestD = d;
        best = target;
      }
    }

    consider(Duration.zero);
    consider(playback.time.value);
    for (final l in project.layers) {
      if (l.id == layer.id) continue;
      consider(l.startTime);
      consider(l.endTime);
    }
    return best;
  }

  /// Ao mover a barra, tanto o INICIO quanto o FIM podem grudar.
  Duration _snapMove(Duration desiredStart) {
    final dur = layer.duration;
    final s1 = _snap(desiredStart);
    final s2 = _snap(desiredStart + dur) - dur;
    final d1 = (s1 - desiredStart).inMicroseconds.abs();
    final d2 = (s2 - desiredStart).inMicroseconds.abs();
    return d1 <= d2 ? s1 : s2;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(editorControllerProvider.notifier);
    final left = layer.startTime.inMicroseconds / 1e6 * pps;
    final width =
        (layer.duration.inMicroseconds / 1e6 * pps).clamp(40.0, 1e6);

    return SizedBox(
      height: kAmRowHeight,
      width: totalWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: left,
            top: 0,
            width: width.toDouble(),
            height: kAmBarHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (compact) return;
                // Toque simples limpa a selecao multipla.
                ref.read(multiSelectProvider.notifier).state = const {};
                if (ref.read(selectedLayerProvider) == layer.id) {
                  onTapLayer?.call(layer);
                } else {
                  ref.read(selectedLayerProvider.notifier).state = layer.id;
                }
              },
              // Toque LONGO alterna a camada na selecao multipla (a
              // barra de acoes agrupa/duplica/exclui o conjunto).
              onLongPress: compact
                  ? null
                  : () {
                      final set =
                          {...ref.read(multiSelectProvider)};
                      final primary =
                          ref.read(selectedLayerProvider);
                      if (primary != null) set.add(primary);
                      if (!set.add(layer.id)) set.remove(layer.id);
                      ref.read(multiSelectProvider.notifier).state = set;
                      HapticFeedback.selectionClick();
                    },
              onHorizontalDragStart: selected && !compact
                  ? (_) {
                      onEditStart();
                      _dragStart0 = layer.startTime;
                      _accumPx = 0;
                    }
                  : null,
              onHorizontalDragUpdate: selected && !compact
                  ? (d) {
                      _accumPx += d.delta.dx;
                      final desired = _dragStart0 + _pxToDur(_accumPx);
                      final snapped = _snapMove(desired);
                      _hapticIfSnapped(desired, snapped);
                      controller.moveLayer(layer.id, snapped);
                    }
                  : null,
              onHorizontalDragEnd:
                  selected && !compact ? (_) => onEditEnd() : null,
              onHorizontalDragCancel:
                  selected && !compact ? onEditEnd : null,
              child: CustomPaint(
                painter: _AmBarPainter(selected: selected),
                // FORMA DE ONDA e TIRA DE MINIATURAS dentro da barra:
                // sem elas, achar o corte e tatear.
                child: _ClipPreview(
                  layer: layer,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          layer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (layer.hasAnimation) ...[
                        const SizedBox(width: 6),
                        const Icon(CupertinoIcons.rhombus,
                            size: 12, color: Colors.white),
                      ],
                      const Spacer(),
                      if (!compact && width > 90)
                        const Icon(CupertinoIcons.line_horizontal_3,
                            size: 16, color: Colors.white70),
                    ],
                  ),
                  ),
                ),
              ),
            ),
          ),
          // Cues de legenda como marcas dentro da barra (§6.5).
          if (layer is CaptionLayer)
            for (final cue in (layer as CaptionLayer).cues)
              Positioned(
                left: left + (cue.start.inMicroseconds / 1e6 * pps),
                top: 6,
                width: ((cue.end - cue.start).inMicroseconds / 1e6 * pps)
                    .clamp(3.0, 1e6),
                height: kAmBarHeight - 12,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
          // Diamantes de keyframe sobre a barra: acesos = propriedade
          // ativa; apagados e sem borda = de outra propriedade.
          for (final kf in layer.keyframeTimes)
            Positioned(
              left: left + (kf.inMicroseconds / 1e6 * pps) - 5,
              top: kAmBarHeight / 2 - 5,
              child: IgnorePointer(
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Builder(builder: (context) {
                    final active = activeTimesUs == null ||
                        activeTimesUs!.contains(kf.inMicroseconds);
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(2),
                        border: active
                            ? Border.all(color: Colors.black38)
                            : null,
                      ),
                    );
                  }),
                ),
              ),
            ),
          // Setas de navegacao entre camadas (paginas de ferramenta).
          if (compact) ...[
            Positioned(
              left: left - 40,
              top: 0,
              height: kAmBarHeight,
              child: _NavArrow(
                icon: CupertinoIcons.chevron_left,
                onTap: () => controller.selectNeighbor(1),
              ),
            ),
            Positioned(
              left: left + width + 4,
              top: 0,
              height: kAmBarHeight,
              child: _NavArrow(
                icon: CupertinoIcons.chevron_right,
                onTap: () => controller.selectNeighbor(-1),
              ),
            ),
          ],
          // Alcas de trim (com snap magnetico).
          if (selected && !compact) ...[
            _TrimHandle(
              left: left - 3,
              onStart: () {
                onEditStart();
                _trimStart0 = layer.startTime;
                _trimAccumPx = 0;
              },
              onEnd: onEditEnd,
              onDrag: (dx) {
                _trimAccumPx += dx;
                final desired = _trimStart0 + _pxToDur(_trimAccumPx);
                final snapped = _snap(desired);
                _hapticIfSnapped(desired, snapped);
                controller.trimLayerStart(layer.id, snapped);
              },
            ),
            _TrimHandle(
              left: left + width - 13,
              onStart: () {
                onEditStart();
                _trimStart0 = layer.endTime;
                _trimAccumPx = 0;
              },
              onEnd: onEditEnd,
              onDrag: (dx) {
                _trimAccumPx += dx;
                final desired = _trimStart0 + _pxToDur(_trimAccumPx);
                final snapped = _snap(desired);
                _hapticIfSnapped(desired, snapped);
                controller.trimLayerEnd(layer.id, snapped);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFE9EDF2),
          borderRadius: BorderRadius.circular(19),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF12151A)),
      ),
    );
  }
}

/// Barra teal; selecionada ganha listras diagonais claras.
class _AmBarPainter extends CustomPainter {
  const _AmBarPainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(8));
    canvas.drawRRect(
        rrect, Paint()..color = selected ? AmColors.teal : AmColors.teal);
    if (selected) {
      canvas.save();
      canvas.clipRRect(rrect);
      final stripe = Paint()
        ..color = AmColors.tealBright.withValues(alpha: 0.55)
        ..strokeWidth = 7;
      for (var x = -size.height; x < size.width + size.height; x += 22) {
        canvas.drawLine(Offset(x, size.height + 4),
            Offset(x + size.height + 8, -4), stripe);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_AmBarPainter old) => old.selected != selected;
}

class _TrimHandle extends StatelessWidget {
  const _TrimHandle({
    required this.left,
    required this.onDrag,
    required this.onStart,
    required this.onEnd,
  });

  final double left;
  final ValueChanged<double> onDrag;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 2,
      height: kAmBarHeight - 4,
      width: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => onStart(),
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        onHorizontalDragCancel: onEnd,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Center(
            child: SizedBox(
              width: 2,
              height: 14,
              child: ColoredBox(color: Colors.black26),
            ),
          ),
        ),
      ),
    );
  }
}

/// PREVIA DENTRO DA BARRA: forma de onda para audio, tira de
/// miniaturas para video.
///
/// As duas sao caras de calcular, entao sao pedidas uma vez e chegam
/// depois — a barra aparece na hora e ganha a previa quando fica pronta,
/// em vez de segurar a interface esperando o FFmpeg.
class _ClipPreview extends StatefulWidget {
  const _ClipPreview({required this.layer, required this.child});

  final Layer layer;
  final Widget child;

  @override
  State<_ClipPreview> createState() => _ClipPreviewState();
}

class _ClipPreviewState extends State<_ClipPreview> {
  final _service = MediaPreviewService.instance;

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  @override
  void didUpdateWidget(_ClipPreview old) {
    super.didUpdateWidget(old);
    if (old.layer.id != widget.layer.id) _pedir();
  }

  void _pedir() {
    final l = widget.layer;
    if (l is AudioLayer) {
      _service.ensureWaveform(l.sourcePath);
    } else if (l is VideoLayer) {
      _service.ensureWaveform(l.sourcePath);
      _service.ensureFilmstrip(
          l.sourcePath, l.sourceOffset + l.duration);
      // PROXY: pedido daqui porque a barra do clipe sempre monta —
      // pendurar no caminho de sincronia do player era fragil, ele so
      // roda quando o relogio anda.
      ProxyService.instance.ensureProxy(l.sourcePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.layer;
    if (l is! AudioLayer && l is! VideoLayer) return widget.child;

    final path = l is AudioLayer
        ? l.sourcePath
        : (l as VideoLayer).sourcePath;
    final inicio = l is VideoLayer
        ? l.sourceOffset
        : (l as AudioLayer).sourceOffset;
    final fim = inicio + l.duration;

    return ValueListenableBuilder<int>(
      valueListenable: _service.revision,
      builder: (context, _, child) {
        final peaks = _service.peaksOf(path);
        final strip =
            l is VideoLayer ? _service.stripOf(path) : null;

        final temStrip = strip != null && strip.isNotEmpty;
        final temOnda = peaks != null && peaks.isNotEmpty;

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // MINIATURAS em cima da barra, opacas: meia opacidade
              // sobre o violeta lava a imagem e ela deixa de informar.
              if (temStrip)
                Positioned.fill(
                  child: CustomPaint(
                    painter: FilmstripPainter(
                      frames: strip,
                      start: inicio,
                      end: fim,
                      sourceDuration: fim,
                    ),
                  ),
                ),
              // Veu escuro so onde o nome do clipe passa, para o texto
              // continuar legivel sobre qualquer cena.
              if (temStrip)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.62),
                          Colors.black.withValues(alpha: 0.22),
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                  ),
                ),
              // Audio do proprio video: faixa fina embaixo, para nao
              // brigar com a imagem.
              if (temOnda)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: temStrip ? kAmBarHeight * 0.34 : null,
                  top: temStrip ? null : 0,
                  child: CustomPaint(
                    painter: WaveformPainter(
                      peaks: peaks,
                      start: inicio,
                      end: fim,
                      color: temStrip
                          ? AmColors.accent.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              child!,
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
