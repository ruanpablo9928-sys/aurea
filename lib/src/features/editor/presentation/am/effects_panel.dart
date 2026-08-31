import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/effect.dart';
import '../../domain/effect_preset.dart';
import 'am_colors.dart';
import 'color_picker_sheet.dart';
import 'am_widgets.dart';

/// Painel "Efeitos": pilha de cards, cada parametro com regua + diamante
/// ("keyframe em tudo"), olho para ligar/desligar e reordenacao.
class EffectsPanel extends ConsumerStatefulWidget {
  const EffectsPanel({
    super.key,
    required this.playback,
    required this.onBack,
  });

  final PlaybackController playback;
  final VoidCallback onBack;

  @override
  ConsumerState<EffectsPanel> createState() => _EffectsPanelState();
}

class _EffectsPanelState extends ConsumerState<EffectsPanel> {
  String? _selectedParam;

  /// CATALOGO (PR-C4): o gargalo de quem tem muitos efeitos nao e ter —
  /// e ACHAR. Busca com sinonimos, chips por categoria com contador,
  /// presets de fabrica, e aplicacao em dois toques.
  Future<void> _addEffect(BuildContext context, String layerId) async {
    final controller = ref.read(editorControllerProvider.notifier);
    final search = TextEditingController();
    var query = '';
    String? category;
    var showPresets = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      isScrollControlled: true,
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final results = query.isNotEmpty
              ? searchEffects(query)
              : (category == null
                  ? effectSpecs.keys.toList()
                  : effectsInCategory(category!));

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16,
                  10 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Efeitos',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AmColors.text)),
                      ),
                      GestureDetector(
                        onTap: () => setSheetState(
                            () => showPresets = !showPresets),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: showPresets
                                ? AmColors.accentDim
                                : AmColors.chip,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Text('Presets',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AmColors.accent)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: search,
                    placeholder: 'buscar (glow, rgb split, pixelate...)',
                    placeholderStyle: const TextStyle(
                        fontSize: 13, color: AmColors.muted),
                    style: const TextStyle(
                        fontSize: 14, color: AmColors.text),
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Icon(CupertinoIcons.search,
                          size: 16, color: AmColors.muted),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AmColors.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onChanged: (v) => setSheetState(() {
                      query = v;
                      showPresets = false;
                    }),
                  ),
                  const SizedBox(height: 10),
                  if (!showPresets && query.isEmpty)
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final c in [null, ...effectCategories])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setSheetState(
                                    () => category = c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: category == c
                                        ? AmColors.accentDim
                                        : AmColors.chip,
                                    borderRadius:
                                        BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    c == null
                                        ? 'Todos ${effectSpecs.length}'
                                        : '$c ${effectsInCategory(c).length}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AmColors.accent),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: showPresets
                        ? ListView(
                            children: [
                              for (final p in factoryPresets())
                                ListTile(
                                  leading: const Icon(
                                      CupertinoIcons.square_stack_3d_down_right,
                                      color: AmColors.accent,
                                      size: 20),
                                  title: Text(p.name,
                                      style: const TextStyle(
                                          color: AmColors.text,
                                          fontSize: 14)),
                                  subtitle: Text(
                                    '${p.category} · '
                                    '${p.effects.length} efeito(s)',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AmColors.muted),
                                  ),
                                  onTap: () {
                                    controller.applyPreset(
                                        layerId, p,
                                        at: widget.playback.time.value);
                                    Navigator.of(sheetContext).pop();
                                  },
                                ),
                            ],
                          )
                        : ListView(
                            children: [
                              if (results.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      'Nada encontrado. Tente "glow", '
                                      '"rgb", "pixel", "shake".',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: AmColors.muted)),
                                ),
                              for (final type in results)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                      CupertinoIcons.wand_stars,
                                      color: AmColors.accent,
                                      size: 20),
                                  title: Text(effectSpecs[type]!.name,
                                      style: const TextStyle(
                                          color: AmColors.text,
                                          fontSize: 14)),
                                  subtitle: Text(
                                    '${effectSpecs[type]!.category}'
                                    '${effectSpecs[type]!.cost > 1 ? ' · custo ${effectSpecs[type]!.cost}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AmColors.muted),
                                  ),
                                  onTap: () {
                                    controller.addEffect(layerId, type);
                                    Navigator.of(sheetContext).pop();
                                  },
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
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
            // Reavalia os valores conforme o playhead anda.
            child: ValueListenableBuilder<Duration>(
              valueListenable: widget.playback.time,
              builder: (context, t, _) {
                final local = layer.localTime(t);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                  children: [
                    for (final effect in layer.effects)
                      _EffectCard(
                        effect: effect,
                        local: local,
                        selectedParam: _selectedParam,
                        onSelectParam: (p) =>
                            setState(() => _selectedParam = p),
                        onParam: (key, v) => controller.editEffectParam(
                            id, effect.id, key, t, v),
                        onParamKeyframe: (key) => controller
                            .toggleEffectParamKeyframe(id, effect.id, key, t),
                        onColor: (c) =>
                            controller.setEffectColor(id, effect.id, c),
                        onRemove: () =>
                            controller.removeEffect(id, effect.id),
                        onToggleEnabled: () =>
                            controller.toggleEffectEnabled(id, effect.id),
                      ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _addEffect(context, id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AmColors.chip,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.plus,
                                size: 17, color: AmColors.accent),
                            SizedBox(width: 8),
                            Text('Adicionar efeito',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AmColors.accent)),
                          ],
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

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.local,
    required this.selectedParam,
    required this.onSelectParam,
    required this.onParam,
    required this.onParamKeyframe,
    required this.onColor,
    required this.onRemove,
    required this.onToggleEnabled,
  });

  final EffectInstance effect;
  final Duration local;
  final String? selectedParam;
  final ValueChanged<String> onSelectParam;
  final void Function(String key, double value) onParam;
  final void Function(String key) onParamKeyframe;
  final ValueChanged<Color> onColor;
  final VoidCallback onRemove;
  final VoidCallback onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
      decoration: BoxDecoration(
        color: AmColors.panelHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Opacity(
        opacity: effect.enabled ? 1 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.arrowtriangle_down_fill,
                    size: 12, color: AmColors.text),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    effect.spec.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AmColors.text,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onToggleEnabled,
                  child: Icon(
                    effect.enabled
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 22,
                    color: AmColors.text,
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(CupertinoIcons.trash,
                      size: 22, color: AmColors.text),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // PR-C1: cada TIPO de parametro ganha seu controle. Antes so
            // havia numero, e todo efeito que precisava de escolha ou
            // ponto ficava visivel e inerte.
            for (final entry in effect.spec.params.entries)
              switch (entry.value.kind) {
                ParamKind.choice => _ChoiceRow(
                    label: entry.value.label,
                    options: entry.value.options,
                    value: effect
                        .paramAt(entry.key, local)
                        .round()
                        .clamp(0, entry.value.options.length - 1),
                    onChanged: (i) => onParam(entry.key, i.toDouble()),
                  ),
                ParamKind.seed => _SeedRow(
                    label: entry.value.label,
                    value: effect.paramAt(entry.key, local),
                    onChanged: (v) => onParam(entry.key, v),
                  ),
                ParamKind.toggle => _ToggleRow(
                    label: entry.value.label,
                    value: effect.paramAt(entry.key, local) > 0.5,
                    onChanged: (v) =>
                        onParam(entry.key, v ? 1.0 : 0.0),
                  ),
                // Ponto e numero usam a regua; o ponto vem em 0..1 e o
                // par X/Y aparece como duas linhas nomeadas.
                _ => _ParamRow(
                    paramKey: '${effect.id}/${entry.key}',
                    label: entry.value.label,
                    track: effect.track(entry.key),
                    local: local,
                    min: entry.value.min,
                    max: entry.value.max,
                    selected:
                        selectedParam == '${effect.id}/${entry.key}',
                    onSelect: onSelectParam,
                    onChanged: (v) => onParam(entry.key, v),
                    onKeyframe: () => onParamKeyframe(entry.key),
                  ),
              },
            if (effect.spec.hasColor)
              _ColorRow(effect: effect, onColor: onColor),
          ],
        ),
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    required this.paramKey,
    required this.label,
    required this.track,
    required this.local,
    required this.min,
    required this.max,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
    required this.onKeyframe,
  });

  final String paramKey;
  final String label;
  final dynamic track; // AnimatedDouble
  final Duration local;
  final double min;
  final double max;
  final bool selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<double> onChanged;
  final VoidCallback onKeyframe;

  @override
  Widget build(BuildContext context) {
    final double value = track.valueAt(local);
    final bool animated = track.isAnimated;
    final bool kfHere = track.hasKeyframeAt(local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => onSelect(paramKey),
            child: Container(
              width: 88,
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AmColors.accentDim.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? AmColors.accent : AmColors.muted,
                  decoration: TextDecoration.underline,
                  decorationColor:
                      selected ? AmColors.accent : AmColors.muted,
                ),
              ),
            ),
          ),
          Expanded(
            child: AmTickRuler(
              value: value,
              min: min,
              max: max,
              unitsPerPixel: (max - min) / 400,
              height: 58,
              onChanged: (v) {
                onSelect(paramKey);
                onChanged(v);
              },
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              amNumber(value, value.abs() >= 10 ? 1 : 3),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: AmColors.text),
            ),
          ),
          // Diamante do parametro ("keyframe em tudo").
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            onPressed: onKeyframe,
            child: Icon(
              kfHere ? CupertinoIcons.rhombus_fill : CupertinoIcons.rhombus,
              size: 24,
              color: animated ? AmColors.accent : AmColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Controle de ESCOLHA em chips (PR-C1).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AmColors.muted))),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < options.length; i++)
                  GestureDetector(
                    onTap: () => onChanged(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: value == i
                            ? AmColors.accentDim
                            : AmColors.chip,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(options[i],
                          style: const TextStyle(
                              fontSize: 12, color: AmColors.accent)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SEMENTE (PR-C1): inteiro que nunca interpola — o dado sorteia de
/// novo, o resultado continua deterministico.
class _SeedRow extends StatelessWidget {
  const _SeedRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: AmColors.muted))),
          Text('${value.round()}',
              style: const TextStyle(
                  fontSize: 13, color: AmColors.accent)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () =>
                onChanged(((value.round() + 1) % 100).toDouble()),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.shuffle,
                      size: 14, color: AmColors.accent),
                  SizedBox(width: 6),
                  Text('Sortear',
                      style: TextStyle(
                          fontSize: 12, color: AmColors.accent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Liga/desliga (PR-C1).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AmColors.muted))),
        Transform.scale(
          scale: 0.7,
          child: CupertinoSwitch(
            value: value,
            activeTrackColor: AmColors.accent,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.effect, required this.onColor});

  final EffectInstance effect;
  final ValueChanged<Color> onColor;

  static const _swatches = [
    Color(0xFFFF5566),
    Color(0xFFFFB020),
    Color(0xFF2BE3A0),
    Color(0xFF35C4E7),
    Color(0xFF7C62FF),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final c = effect.color;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 88,
            child: Text(
              'Cor',
              style: TextStyle(
                fontSize: 13,
                color: AmColors.muted,
                decoration: TextDecoration.underline,
                decorationColor: AmColors.muted,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${(c.r * 255).round()} ${(c.g * 255).round()} ${(c.b * 255).round()}',
            style: const TextStyle(fontSize: 13, color: AmColors.accent),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () async {
              // Espectro completo: qualquer cor, com hex e alfa.
              final picked = await showColorPicker(
                context,
                initial: c,
                recent: _swatches,
                onChanged: onColor,
              );
              if (picked != null) onColor(picked);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
