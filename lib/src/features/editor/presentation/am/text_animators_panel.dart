import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../domain/text_animator.dart';
import '../../domain/text_presets.dart';
import '../../domain/text_recipe.dart';
import 'am_colors.dart';
import 'am_widgets.dart';

/// Visualizador de ESCALONAMENTO (spec autoria-de-texto §8): uma barra
/// por unidade, comecando em i*intervalo e durando "duracao". Mexer no
/// intervalo move as barras — a pessoa VE o escalonamento em vez de
/// imaginar.
class _StaggerPainter extends CustomPainter {
  const _StaggerPainter({required this.recipe});

  final TextRecipe recipe;

  /// Amostra de unidades na miniatura (o texto real pode ter dezenas).
  static const int units = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final n = recipe.unit == RecipeUnit.all ? 1 : units;
    final total = recipe.totalFor(n).inMicroseconds.toDouble();
    if (total <= 0) return;
    final s = recipe.stagger.inMicroseconds.toDouble();
    final d = recipe.duration.inMicroseconds.toDouble();
    final rowH = size.height / n;
    final paint = Paint()..color = AmColors.accent;
    for (var i = 0; i < n; i++) {
      final x0 = (i * s) / total * size.width;
      // Duracao zero (maquina de escrever) ainda precisa ser visivel.
      final w = math.max(2.0, d / total * size.width);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x0, i * rowH + rowH * 0.18,
              math.min(w, size.width - x0), rowH * 0.64),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StaggerPainter old) =>
      old.recipe.stagger != recipe.stagger ||
      old.recipe.duration != recipe.duration ||
      old.recipe.unit != recipe.unit;
}

/// Painel "Animadores" de camadas de texto: presets, pilha de animadores
/// (chips de propriedade + seletores) e a barra de cobertura visual.
class TextAnimatorsPanel extends ConsumerStatefulWidget {
  const TextAnimatorsPanel({
    super.key,
    required this.playback,
    required this.onBack,
  });

  final PlaybackController playback;
  final VoidCallback onBack;

  @override
  ConsumerState<TextAnimatorsPanel> createState() =>
      _TextAnimatorsPanelState();
}

class _TextAnimatorsPanelState extends ConsumerState<TextAnimatorsPanel> {
  /// Nivel 1 (PRONTO): grade de receitas. Cada tile mostra o
  /// ESCALONAMENTO — uma barra por unidade, na posicao em que ela comeca
  /// — que e o que torna "40 ms entre palavras" tangivel.
  Future<void> _showPresets(BuildContext context, String layerId) async {
    final controller = ref.read(editorControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          children: [
            const Text('Animar o texto',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
            const SizedBox(height: 2),
            const Text(
              'Toque para aplicar. Cada barra e uma unidade, na hora '
              'em que ela entra.',
              style: TextStyle(fontSize: 11, color: AmColors.muted),
            ),
            const SizedBox(height: 12),
            for (final recipe in RecipeLibrary.entrada)
              GestureDetector(
                onTap: () {
                  controller.applyTextRecipe(layerId, recipe);
                  Navigator.of(sheetContext).pop();
                  widget.playback.seek(Duration.zero);
                  widget.playback.play();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(recipe.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AmColors.accent)),
                            const SizedBox(height: 2),
                            Text(
                              '${_unitLabel(recipe.unit)} · '
                              '${recipe.stagger.inMilliseconds} ms entre · '
                              '${recipe.duration.inMilliseconds} ms cada',
                              style: const TextStyle(
                                  fontSize: 10, color: AmColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        height: 34,
                        child: CustomPaint(
                          painter: _StaggerPainter(recipe: recipe),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            const Text('Presets classicos',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in textPresets)
                  GestureDetector(
                    onTap: () {
                      controller.applyTextPreset(layerId, preset);
                      Navigator.of(sheetContext).pop();
                      widget.playback.seek(Duration.zero);
                      widget.playback.play();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      decoration: BoxDecoration(
                        color: AmColors.chip,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(preset.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AmColors.accent)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _unitLabel(RecipeUnit u) => switch (u) {
        RecipeUnit.character => 'Caractere',
        RecipeUnit.word => 'Palavra',
        RecipeUnit.line => 'Linha',
        RecipeUnit.all => 'Tudo junto',
      };

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer is! TextLayer || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }
    final controller = ref.read(editorControllerProvider.notifier);

    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AmRailButton(
                onTap: widget.onBack,
                child: const Icon(CupertinoIcons.chevron_back,
                    size: 24, color: AmColors.text),
              ),
            ],
          ),
          Expanded(
            child: ValueListenableBuilder<Duration>(
              valueListenable: widget.playback.time,
              builder: (context, t, _) {
                final local = layer.localTime(t);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _PillButton(
                            icon: CupertinoIcons.sparkles,
                            label: 'Presets',
                            onTap: () => _showPresets(context, id),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PillButton(
                            icon: CupertinoIcons.plus,
                            label: 'Animador',
                            onTap: () => controller.addTextAnimator(id),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final animator in layer.animators)
                      _AnimatorCard(
                        layerId: id,
                        layer: layer,
                        animator: animator,
                        local: local,
                        globalTime: t,
                      ),
                    if (layer.animators.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Aplique um preset ou adicione um animador.',
                            style: TextStyle(
                                fontSize: 12, color: AmColors.muted),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AmColors.accent),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AmColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _AnimatorCard extends ConsumerStatefulWidget {
  const _AnimatorCard({
    required this.layerId,
    required this.layer,
    required this.animator,
    required this.local,
    required this.globalTime,
  });

  final String layerId;
  final TextLayer layer;
  final TextAnimator animator;
  final Duration local;
  final Duration globalTime;

  @override
  ConsumerState<_AnimatorCard> createState() => _AnimatorCardState();
}

class _AnimatorCardState extends ConsumerState<_AnimatorCard> {
  /// Seletores ficam atras de "Avancado": o fluxo simples eso
  /// preset -> propriedades.
  bool _advanced = false;

  String get layerId => widget.layerId;
  TextLayer get layer => widget.layer;
  TextAnimator get animator => widget.animator;
  Duration get local => widget.local;
  Duration get globalTime => widget.globalTime;

  static const _propChips = <(TextAnimProp, String)>[
    (TextAnimProp.positionX, 'X'),
    (TextAnimProp.positionY, 'Y'),
    (TextAnimProp.scale, 'Escala'),
    (TextAnimProp.rotation, 'Rotacao'),
    (TextAnimProp.opacity, 'Opacidade'),
    (TextAnimProp.tracking, 'Tracking'),
  ];

  (double, double) _rangeOf(TextAnimProp type) => switch (type) {
        TextAnimProp.positionX ||
        TextAnimProp.positionY =>
          (-800.0, 800.0),
        TextAnimProp.scale => (0.0, 400.0),
        TextAnimProp.rotation => (-360.0, 360.0),
        TextAnimProp.opacity => (0.0, 100.0),
        TextAnimProp.tracking => (-200.0, 200.0),
      };

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(editorControllerProvider.notifier);
    final units = TextUnits.of(layer.text);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 12),
      decoration: BoxDecoration(
        color: AmColors.panelHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Opacity(
        opacity: animator.enabled ? 1 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(animator.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AmColors.text)),
                ),
                GestureDetector(
                  onTap: () =>
                      controller.toggleTextAnimator(layerId, animator.id),
                  child: Icon(
                      animator.enabled
                          ? CupertinoIcons.eye
                          : CupertinoIcons.eye_slash,
                      size: 18,
                      color: AmColors.text),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () =>
                      controller.removeTextAnimator(layerId, animator.id),
                  child: const Icon(CupertinoIcons.trash,
                      size: 18, color: AmColors.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // BARRA DE COBERTURA VISUAL: uma barrinha por unidade, altura
            // igual a cobertura c (spec §12).
            SizedBox(
              height: 42,
              child: CustomPaint(
                size: const Size(double.infinity, 42),
                painter: _CoveragePainter(
                  units: units,
                  animator: animator,
                  local: local,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Chips de propriedade.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (type, label) in _propChips)
                  GestureDetector(
                    onTap: () => controller.toggleAnimatorPropType(
                        layerId, animator.id, type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: animator.properties
                                .any((p) => p.type == type)
                            ? AmColors.accentDim
                            : AmColors.chip,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: animator.properties
                                      .any((p) => p.type == type)
                                  ? AmColors.accent
                                  : AmColors.text)),
                    ),
                  ),
              ],
            ),
            // Linhas das propriedades ativas.
            for (final p in animator.properties)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 86,
                      child: Text(
                        _propChips
                            .firstWhere((c) => c.$1 == p.type)
                            .$2,
                        style: const TextStyle(
                            fontSize: 14, color: AmColors.muted),
                      ),
                    ),
                    Expanded(
                      child: AmTickRuler(
                        value: p.value.valueAt(local),
                        min: _rangeOf(p.type).$1,
                        max: _rangeOf(p.type).$2,
                        unitsPerPixel:
                            (_rangeOf(p.type).$2 - _rangeOf(p.type).$1) /
                                500,
                        height: 52,
                        onChanged: (v) => controller.editAnimatorPropValue(
                            layerId, animator.id, p.id, globalTime, v),
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        amNumber(p.value.valueAt(local), 0),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 14, color: AmColors.text),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 10),
                      onPressed: () =>
                          controller.toggleAnimatorPropKeyframe(
                              layerId, animator.id, p.id, globalTime),
                      child: Icon(
                        p.value.hasKeyframeAt(local)
                            ? CupertinoIcons.rhombus_fill
                            : CupertinoIcons.rhombus,
                        size: 22,
                        color: p.value.isAnimated
                            ? AmColors.accent
                            : AmColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Seletores so no modo avancado — o basico fica limpo.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _advanced = !_advanced),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _advanced
                          ? CupertinoIcons.chevron_down
                          : CupertinoIcons.chevron_right,
                      size: 15,
                      color: AmColors.muted,
                    ),
                    const SizedBox(width: 6),
                    const Text('Avancado (seletores)',
                        style: TextStyle(
                            fontSize: 13, color: AmColors.muted)),
                  ],
                ),
              ),
            ),
            if (_advanced) ...[
              for (final s in animator.selectors)
                _SelectorCard(
                  layerId: layerId,
                  animatorId: animator.id,
                  selector: s,
                  local: local,
                  globalTime: globalTime,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  onPressed: () => controller
                      .addTextSelector(layerId, animator.id, wiggly: true),
                  child: const Text('+ Seletor wiggly',
                      style: TextStyle(
                          fontSize: 13, color: AmColors.accent)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra de cobertura: desenha as unidades do texto com altura = c.
class _CoveragePainter extends CustomPainter {
  const _CoveragePainter({
    required this.units,
    required this.animator,
    required this.local,
  });

  final TextUnits units;
  final TextAnimator animator;
  final Duration local;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      Paint()..color = AmColors.bg,
    );
    final n = units.length;
    if (n == 0) return;
    final barW = size.width / n;
    final paint = Paint()..color = AmColors.accent;
    final dim = Paint()..color = AmColors.accent.withValues(alpha: 0.25);
    for (var i = 0; i < n; i++) {
      final c = animator.enabled
          ? units
              .coverageFor(animator.selectors, i, local,
                  allowOvershoot: animator.allowOvershoot)
              .clamp(0.0, 1.0)
          : 0.0;
      final h = c * (size.height - 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              i * barW + 1, size.height - 2 - h, barW - 2, h),
          const Radius.circular(2),
        ),
        units.isWhitespace[i] ? dim : paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoveragePainter old) => true;
}

class _SelectorCard extends ConsumerWidget {
  const _SelectorCard({
    required this.layerId,
    required this.animatorId,
    required this.selector,
    required this.local,
    required this.globalTime,
  });

  final String layerId;
  final String animatorId;
  final TextSelector selector;
  final Duration local;
  final Duration globalTime;

  static String _modeLabel(SelectorMode m) => switch (m) {
        SelectorMode.add => 'Add',
        SelectorMode.subtract => 'Sub',
        SelectorMode.intersect => 'Inter',
        SelectorMode.min => 'Min',
        SelectorMode.max => 'Max',
        SelectorMode.difference => 'Dif',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final s = selector;

    Widget row(String label, AnimatedDouble track, String param, double min,
        double max, double scale) {
      return Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AmColors.muted)),
          ),
          Expanded(
            child: AmTickRuler(
              value: track.valueAt(local) * scale,
              min: min,
              max: max,
              unitsPerPixel: (max - min) / 500,
              height: 44,
              onChanged: (v) => controller.editSelectorParam(
                  layerId, animatorId, s.id, param, globalTime, v / scale),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              amNumber(track.valueAt(local) * scale, 0),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, color: AmColors.text),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AmColors.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s is WigglySelector ? 'Seletor Wiggly' : 'Seletor Intervalo',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AmColors.text),
                ),
              ),
              GestureDetector(
                onTap: () => controller.cycleSelectorMode(
                    layerId, animatorId, s.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(_modeLabel(s.mode),
                      style: const TextStyle(
                          fontSize: 12, color: AmColors.accent)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => controller.removeTextSelector(
                    layerId, animatorId, s.id),
                child: const Icon(CupertinoIcons.xmark,
                    size: 14, color: AmColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (s is RangeSelector) ...[
            // Formas.
            Wrap(
              spacing: 5,
              children: [
                for (final shape in SelectorShape.values)
                  GestureDetector(
                    onTap: () => controller.setRangeSelectorShape(
                        layerId, animatorId, s.id, shape),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: s.shape == shape
                            ? AmColors.accentDim
                            : AmColors.chip,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        shape.name,
                        style: TextStyle(
                            fontSize: 11,
                            color: s.shape == shape
                                ? AmColors.accent
                                : AmColors.muted),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            row('Inicio', s.start, 'start', 0, 100, 100),
            row('Fim', s.end, 'end', 0, 100, 100),
            row('Offset', s.offset, 'offset', -100, 100, 100),
            row('Amount', s.amount, 'amount', -100, 100, 1),
          ] else if (s is WigglySelector) ...[
            row('Freq', s.wigglesPerSecond, 'freq', 0, 16, 1),
            row('Correl.', s.correlation, 'correlation', 0, 100, 1),
            row('Min', s.minAmount, 'min', -100, 100, 1),
            row('Max', s.maxAmount, 'max', -100, 100, 1),
          ],
        ],
      ),
    );
  }
}
