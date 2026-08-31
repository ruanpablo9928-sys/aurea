import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/application/projects_controller.dart';
import '../application/editor_controller.dart';
import '../application/playback_controller.dart';
import '../application/preview_stats.dart';
import '../application/video_layer_manager.dart';
import '../domain/gear.dart';
import '../domain/layer.dart';
import 'am/align_sheet.dart';
import 'am/am_colors.dart';
import 'am/export_sheet.dart';
import 'am/am_widgets.dart';
import 'am/am_timeline.dart';
import 'am/curve_panel.dart';
import 'am/effects_panel.dart';
import 'am/layer_menu.dart';
import 'am/text_animators_panel.dart';
import 'am/transform_panel.dart';
import 'widgets/add_layer_sheet.dart';
import 'widgets/preview_stage.dart';

enum _Mode { main, transform, blending, colorFill, effects, curve, animators }

/// Editor: preview, transporte, timeline com playhead central e paginas
/// de ferramenta em tela cheia.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _playback;
  final VideoLayerManager _videos = VideoLayerManager();

  _Mode _mode = _Mode.main;
  LayerProp _curveProp = LayerProp.position;
  _Mode _curveReturn = _Mode.transform;
  TransformTool _tool = TransformTool.rotation;

  @override
  void initState() {
    super.initState();
    _playback = PlaybackController(
      vsync: this,
      durationOf: () => ref.read(editorControllerProvider).duration,
    );
    _playback.time.addListener(_syncVideos);
    _playback.playing.addListener(_syncVideos);
  }

  void _syncVideos() {
    final project = ref.read(editorControllerProvider);
    // A midia devolve o RELOGIO MESTRE (PR-J1): o clock da composicao e
    // ancorado nela continuamente, em vez de corrigir a deriva em bloco
    // com um seek — que era a travada periodica.
    final master = _videos.sync(
        project.layers, _playback.time.value, _playback.playing.value);
    if (master != null) _playback.anchorToMedia(master);
  }

  @override
  void dispose() {
    _playback.dispose();
    _videos.dispose();
    super.dispose();
  }

  String get _title => switch (_mode) {
        _Mode.main => ref.read(editorControllerProvider).name,
        _Mode.transform => 'Movimentacao e transformacao',
        _Mode.blending => 'Mesclagem e opacidade',
        _Mode.colorFill => 'Cor e preenchimento',
        _Mode.effects => 'Efeitos',
        _Mode.curve => 'Curva de gradacao',
        _Mode.animators => 'Animadores de texto',
      };

  void _back() {
    switch (_mode) {
      case _Mode.main:
        Navigator.of(context).maybePop();
      case _Mode.curve:
        setState(() => _mode = _curveReturn);
      default:
        setState(() => _mode = _Mode.main);
    }
  }

  Set<int> _timesForProp(Layer layer, LayerProp prop) => switch (prop) {
        LayerProp.position => layer.positionTimesUs,
        LayerProp.scale => layer.scaleTimesUs,
        LayerProp.rotation => layer.rotationTimesUs,
        LayerProp.opacity => layer.opacityTimesUs,
        LayerProp.skew => layer.skewTimesUs,
        LayerProp.pivot => layer.pivotTimesUs,
        LayerProp.parent => const <int>{},
      };

  void _openCurve(LayerProp prop) {
    setState(() {
      _curveProp = prop;
      _curveReturn = _mode == _Mode.curve ? _curveReturn : _mode;
      _mode = _Mode.curve;
    });
  }

  Future<void> _onTapLayer(Layer layer) async {
    _playback.pause();
    final action =
        await showLayerMenu(context, ref, layer, _playback);
    if (!mounted || action == null) return;
    switch (action) {
      case LayerMenuAction.transform:
        setState(() => _mode = _Mode.transform);
      case LayerMenuAction.blending:
        setState(() => _mode = _Mode.blending);
      case LayerMenuAction.colorFill:
        setState(() => _mode = _Mode.colorFill);
      case LayerMenuAction.effects:
        setState(() => _mode = _Mode.effects);
      case LayerMenuAction.editText:
        _editText(layer);
      case LayerMenuAction.textAnimators:
        setState(() => _mode = _Mode.animators);
    }
  }

  Future<void> _editText(Layer layer) async {
    if (layer is! TextLayer) return;
    final controller = ref.read(editorControllerProvider.notifier);
    final textController = TextEditingController(text: layer.text);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: CupertinoTextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          style: const TextStyle(fontSize: 17, color: AmColors.text),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AmColors.chip,
            borderRadius: BorderRadius.circular(12),
          ),
          onChanged: (v) => controller.editTextLayer(layer.id, text: v),
          onSubmitted: (_) => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    textController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedLayerProvider);

    ref.listen(editorControllerProvider, (_, updated) {
      ref.read(projectsControllerProvider.notifier).upsert(updated);
      _syncVideos();
    });

    // Motor de preview: o clock compoe na taxa da COMPOSICAO, nao na da
    // tela — ticks sao quantizados no fps do projeto.
    _playback.compositionFps =
        ref.watch(editorControllerProvider.select((p) => p.fps));

    // Painel de ferramenta atual (null no modo principal).
    final Widget? panel = switch (_mode) {
      _Mode.main => null,
      _Mode.transform => TransformPanel(
          playback: _playback,
          tool: _tool,
          onToolChanged: (t) => setState(() => _tool = t),
          onBack: _back,
          onOpenCurve: _openCurve),
      _Mode.blending => BlendingPanel(
          playback: _playback, onBack: _back, onOpenCurve: _openCurve),
      _Mode.colorFill =>
        ColorFillPanel(onBack: _back, playback: _playback),
      _Mode.effects => EffectsPanel(playback: _playback, onBack: _back),
      _Mode.curve => CurvePanel(
          playback: _playback, prop: _curveProp, onBack: _back),
      _Mode.animators =>
        TextAnimatorsPanel(playback: _playback, onBack: _back),
    };

    final pinkPlayhead = _mode == _Mode.effects ||
        _mode == _Mode.curve ||
        _mode == _Mode.animators;

    // Diamantes da propriedade ativa acendem; os demais ficam apagados.
    final layer = selectedId == null
        ? null
        : ref.watch(editorControllerProvider).layerById(selectedId);
    final Set<int>? activeTimesUs = layer == null
        ? null
        : switch (_mode) {
            _Mode.main => null,
            _Mode.transform => _timesForProp(layer, propOfTool(_tool)),
            _Mode.curve => _timesForProp(layer, _curveProp),
            _Mode.blending => layer.opacityTimesUs,
            _Mode.effects => layer.effectTimesUs,
            _Mode.colorFill => const <int>{},
            _Mode.animators => null,
          };

    return Scaffold(
      key: paramSheetHostKey,
      backgroundColor: AmColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _TopBar(
                  title: _title,
                  isMain: _mode == _Mode.main,
                  onBack: _back,
                ),
                // RepaintBoundary: palco, timeline e painel pintam em
                // camadas separadas — repintar um nao repinta os outros.
                Expanded(
                  child: RepaintBoundary(
                    key: previewStageKey,
                    child:
                        PreviewStage(playback: _playback, videos: _videos),
                  ),
                ),
                _TransportBar(playback: _playback),
                // Barra de ACOES fixa (spec barra-de-acoes): comandos
                // estruturais sempre no mesmo lugar; desabilitado fica
                // esmaecido, nunca some.
                _ActionBar(playback: _playback),
                RepaintBoundary(
                  child: AmTimeline(
                    playback: _playback,
                    height: _mode == _Mode.main ? 280 : 116,
                    singleLayerId: _mode == _Mode.main ? null : selectedId,
                    playheadColor:
                        pinkPlayhead ? AmColors.pink : Colors.white,
                    onTapLayer: _onTapLayer,
                    activeTimesUs: activeTimesUs,
                  ),
                ),
                // Altura ADAPTATIVA (jamais cobrir/espremer o preview):
                // o painel nunca passa de 40% da tela — em iPhone e
                // telas baixas ele encolhe (todos tem scroll interno) e
                // o palco continua visivel.
                if (panel != null)
                  SizedBox(
                      height: math.min(
                          _mode == _Mode.animators ? 500.0 : 372.0,
                          MediaQuery.sizeOf(context).height * 0.40),
                      child: RepaintBoundary(child: panel)),
              ],
            ),
            // O "+" agora vive na barra de acoes fixa (spec
            // barra-de-acoes): sem FAB cobrindo a timeline.
            if (ref.watch(debugOverlayProvider))
              Positioned(
                top: 6,
                left: 8,
                child: IgnorePointer(
                    child: _DiagOverlay(playback: _playback)),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.isMain,
    required this.onBack,
  });

  final String title;
  final bool isMain;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      color: AmColors.topBar,
      child: Row(
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onPressed: onBack,
            child: const Icon(CupertinoIcons.chevron_back,
                size: 24, color: AmColors.text),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: isMain ? TextAlign.left : TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AmColors.text,
              ),
            ),
          ),
          if (isMain) ...[
            // Engrenagem: liga o overlay de diagnostico do preview
            // (composicoes/s, camadas, marcha — motor-de-preview §7).
            Consumer(
              builder: (context, ref, _) => CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () => ref
                    .read(debugOverlayProvider.notifier)
                    .state = !ref.read(debugOverlayProvider),
                child: Icon(CupertinoIcons.gear,
                    size: 23,
                    color: ref.watch(debugOverlayProvider)
                        ? AmColors.accent
                        : AmColors.text),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => showExportSheet(context, ref),
                child: Container(
                  width: 42,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AmColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(CupertinoIcons.square_arrow_up,
                      size: 20, color: Color(0xFF0B0E12)),
                ),
              ),
            ),
          ] else
            const SizedBox(width: 52),
        ],
      ),
    );
  }
}

/// Overlay de diagnostico (motor-de-preview §7 + marchas §9): a MARCHA
/// em destaque com o motivo, composicoes por segundo, variancia entre
/// ticks e % de tempo em marcha baixa — sem numeros, todo relato de
/// travamento vira adivinhacao.
class _DiagOverlay extends ConsumerWidget {
  const _DiagOverlay({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fps =
        ref.watch(editorControllerProvider.select((p) => p.fps));
    final total = ref.watch(
        editorControllerProvider.select((p) => p.layers.length));
    return ValueListenableBuilder<GearDecision?>(
      valueListenable: PreviewStats.gear,
      builder: (context, gear, _) => ValueListenableBuilder<int>(
        valueListenable: PreviewStats.compsPerSec,
        builder: (context, comps, _) => ValueListenableBuilder<double>(
          valueListenable: PreviewStats.tickVarianceMs,
          builder: (context, variance, _) =>
              ValueListenableBuilder<int>(
            valueListenable: PreviewStats.layersInFrame,
            builder: (context, inFrame, _) => ValueListenableBuilder<int>(
              valueListenable: PreviewStats.lowGearPercent,
              builder: (context, lowPct, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC12151A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AmColors.hairline),
                  ),
                  child: ValueListenableBuilder<FrameReport?>(
                    valueListenable: FrameLog.report,
                    builder: (context, r, _) => Text(
                      'MARCHA: ${gear == null ? '—' : gearLabel(gear.gear)}\n'
                      'motivo: ${gear?.reason ?? '—'}\n'
                      'compoe $comps/s · projeto ${fps}fps\n'
                      'variancia entre ticks: $variance ms\n'
                      'camadas no frame: $inFrame / $total · '
                      'M1+M2: $lowPct%\n'
                      '── registrador (${r?.seconds ?? 0}s) ──\n'
                      'mediana ${r?.medianMs ?? 0} ms · '
                      'pico ${r?.peakMs ?? 0} ms\n'
                      'travadas ${r?.stutters ?? 0} · '
                      'intervalo ${r?.gapS ?? 0}s (±${r?.gapSdS ?? 0})\n'
                      'deriva video-audio ${r?.driftMs ?? 0} ms',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AmColors.accent,
                        height: 1.4,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de ACOES fixa (spec AUREA-barra-de-acoes §2): [+] isolado a
/// esquerda; dividir/duplicar/agrupar/vincular no centro; excluir isolado
/// a direita. Posicoes IMUTAVEIS: sem alvo, o botao esmaece e o toque
/// explica a razao. Excluir nao pede confirmacao — snackbar "Desfazer".
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final project = ref.watch(editorControllerProvider);
    final selId = ref.watch(selectedLayerProvider);
    final multi = ref.watch(multiSelectProvider);
    final targets = <String>{...multi, ?selId};
    final n = targets.length;

    Widget btn({
      required IconData icon,
      required bool enabled,
      required VoidCallback onTap,
      required String reason,
      Color color = AmColors.text,
    }) {
      return CupertinoButton(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        onPressed: () {
          if (enabled) {
            onTap();
          } else {
            showReasonToast(context, reason);
          }
        },
        child: Opacity(
          opacity: enabled ? 1 : 0.32,
          child: Icon(icon, size: 21, color: color),
        ),
      );
    }

    Widget divider() =>
        Container(width: 1, height: 22, color: AmColors.hairline);

    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: AmColors.bg,
        border: Border(
          top: BorderSide(color: AmColors.hairline),
          bottom: BorderSide(color: AmColors.hairline),
        ),
      ),
      child: Row(
        children: [
          // [+] nunca depende de selecao.
          btn(
            icon: CupertinoIcons.plus,
            enabled: true,
            reason: '',
            color: AmColors.accent,
            onTap: () {
              playback.pause();
              showAddLayerSheet(context, ref, playback.time.value);
            },
          ),
          divider(),
          btn(
            icon: CupertinoIcons.scissors,
            enabled: n >= 1,
            reason: 'Selecione uma camada',
            onTap: () {
              for (final id in targets) {
                controller.splitLayer(id, playback.time.value);
              }
            },
          ),
          btn(
            icon: CupertinoIcons.plus_square_on_square,
            enabled: n >= 1,
            reason: 'Selecione uma camada',
            onTap: () {
              for (final id in targets) {
                controller.duplicateLayer(id);
              }
            },
          ),
          btn(
            icon: CupertinoIcons.square_stack_3d_up,
            enabled: n >= 2,
            reason:
                'Selecione duas ou mais camadas (toque longo nas barras)',
            onTap: () => controller.groupLayers(targets.toList()),
          ),
          btn(
            icon: CupertinoIcons.link,
            enabled: n == 1,
            reason: 'Selecione UMA camada para vincular',
            onTap: () {
              final layer = project.layerById(targets.first);
              if (layer != null) {
                showParentSheet(
                    context, ref, layer, playback.time.value);
              }
            },
          ),
          // ALINHAR E DISTRIBUIR (PR-X1): exato ao pixel, o que no dedo
          // nunca fica.
          btn(
            icon: CupertinoIcons.square_grid_3x2,
            enabled: n >= 1,
            reason: 'Selecione uma camada',
            onTap: () => showAlignSheet(
                context, ref, targets.toList(), playback.time.value),
          ),
          const Spacer(),
          if (n > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text('$n camadas',
                  style: const TextStyle(
                      fontSize: 12, color: AmColors.accent)),
            ),
          divider(),
          btn(
            icon: CupertinoIcons.trash,
            enabled: n >= 1,
            reason: 'Selecione uma camada',
            onTap: () {
              final count = n;
              controller.removeLayers(targets);
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(count == 1
                      ? 'Camada excluida'
                      : '$count camadas excluidas'),
                  duration: const Duration(seconds: 5),
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Desfazer',
                    onPressed: controller.undo,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransportBar extends ConsumerWidget {
  const _TransportBar({required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ref.watch(editorControllerProvider).duration;
    final selectedId = ref.watch(selectedLayerProvider);

    final controller = ref.read(editorControllerProvider.notifier);
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: controller.canUndo ? controller.undo : null,
            child: Icon(CupertinoIcons.arrow_uturn_left,
                size: 21,
                color:
                    controller.canUndo ? AmColors.text : AmColors.muted),
          ),
          GestureDetector(
            onTap: controller.canRedo ? controller.redo : null,
            child: Icon(CupertinoIcons.arrow_uturn_right,
                size: 21,
                color:
                    controller.canRedo ? AmColors.text : AmColors.muted),
          ),
          GestureDetector(
            onTap: () => playback.seek(Duration.zero),
            child: const Icon(CupertinoIcons.backward_end,
                size: 22, color: AmColors.text),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: playback.playing,
            builder: (context, playing, _) => GestureDetector(
              onTap: playback.toggle,
              child: Icon(
                playing
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => playback.seek(duration),
            child: const Icon(CupertinoIcons.forward_end,
                size: 22, color: AmColors.text),
          ),
          GestureDetector(
            onTap: selectedId == null
                ? null
                : () => ref
                    .read(editorControllerProvider.notifier)
                    .duplicateLayer(selectedId),
            child: Icon(CupertinoIcons.plus_square_on_square,
                size: 21,
                color:
                    selectedId == null ? AmColors.muted : AmColors.text),
          ),
          const Icon(Icons.fullscreen, size: 24, color: AmColors.text),
        ],
      ),
    );
  }
}
