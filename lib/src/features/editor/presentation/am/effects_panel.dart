import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/blob_track_service.dart';
import '../../../../core/ui/snack.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../application/playback_controller.dart';
import '../../domain/effect.dart';
import '../../domain/effect_preset.dart';
import '../../domain/keyframe.dart';
import 'am_colors.dart';
import 'color_picker_sheet.dart';
import 'am_widgets.dart';

/// Painel "Efeitos": LISTA VERTICAL de blocos colapsaveis, um por efeito.
/// Cabecalho = chevron (colapsa) + nome + "..." (menu) + lixeira. Cada
/// linha de parametro = ponto verde (tem keyframes) + nome + regua de
/// ticks + valor alinhado (par X/Y numa linha so) + diamante ("keyframe
/// em tudo"). O trilho esquerdo tem voltar e o diamante do parametro
/// selecionado.
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

  /// Efeitos RECOLHIDOS (nao os expandidos): assim todo efeito nasce
  /// aberto — inclusive os que chegam depois por addEffect/applyPreset —
  /// sem precisar semear o conjunto a cada build.
  final Set<String> _recolhidos = <String>{};

  bool _expandido(String effectId) => !_recolhidos.contains(effectId);

  void _alternarExpandido(String effectId) {
    setState(() {
      if (!_recolhidos.remove(effectId)) _recolhidos.add(effectId);
    });
  }

  /// Menu "..." do efeito: SO o que o controller sabe fazer de verdade
  /// (mover, ligar/desligar, resetar, remover). Duplicar e curva de
  /// parametro ficam de fora porque nao existem no EditorController.
  Future<void> _menuDoEfeito(
    BuildContext context,
    String layerId,
    EffectInstance effect,
    int index,
    int total,
  ) async {
    final controller = ref.read(editorControllerProvider.notifier);
    const estilo = TextStyle(color: AmColors.text, fontSize: 15);
    // ListTile so esmaece via tema, e nossas cores explicitas vencem o
    // tema: nas pontas o item ficaria igual ao ativo e inerte. Opacity
    // 0.32 e a mesma de _MenuTile, para o "desligado" ter uma cara so.
    final podeSubir = index > 0;
    final podeDescer = index < total - 1;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titulo: qual efeito esta sendo mexido, ja que o menu cobre
            // a lista.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(effect.spec.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
              ),
            ),
            // Nas pontas o item fica esmaecido em vez de sumir: a pessoa
            // ve que o comando existe, so nao faz sentido agora.
            Opacity(
              opacity: podeSubir ? 1 : 0.32,
              child: ListTile(
                enabled: podeSubir,
                leading: const Icon(CupertinoIcons.arrow_up,
                    color: AmColors.muted, size: 20),
                title: const Text('Mover para cima', style: estilo),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.reorderEffect(layerId, effect.id, -1);
                },
              ),
            ),
            Opacity(
              opacity: podeDescer ? 1 : 0.32,
              child: ListTile(
                enabled: podeDescer,
                leading: const Icon(CupertinoIcons.arrow_down,
                    color: AmColors.muted, size: 20),
                title: const Text('Mover para baixo', style: estilo),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.reorderEffect(layerId, effect.id, 1);
                },
              ),
            ),
            ListTile(
              leading: Icon(
                  effect.enabled
                      ? CupertinoIcons.eye_slash
                      : CupertinoIcons.eye,
                  color: AmColors.muted,
                  size: 20),
              title: Text(effect.enabled ? 'Desligar' : 'Ligar',
                  style: estilo),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.toggleEffectEnabled(layerId, effect.id);
              },
            ),
            // RESET = cada parametro volta ao valor inicial da ficha NESTE
            // tempo: num parametro animado isso grava um keyframe com o
            // inicial (edited), nao apaga a trilha — nao ha API para isso.
            // As N edicoes viram um undo so (coalesce de 450 ms).
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_counterclockwise,
                  color: AmColors.muted, size: 20),
              title: const Text('Resetar parametros', style: estilo),
              onTap: () {
                Navigator.of(sheetContext).pop();
                // O tempo e lido NO TOQUE, nao ao abrir o menu: o painel
                // nao pausa a reproducao, e o menu pode ficar aberto por
                // segundos — o keyframe do reset tem de cair onde o
                // cabecote esta agora, nao onde estava.
                final agora = widget.playback.time.value;
                for (final e in effect.spec.params.entries) {
                  controller.editEffectParam(
                      layerId, effect.id, e.key, agora, e.value.initial);
                }
                if (effect.spec.hasColor) {
                  controller.setEffectColor(
                      layerId, effect.id, const Color(0xFFFF5566));
                }
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.trash,
                  color: AmColors.pink, size: 20),
              title: const Text('Remover',
                  style: TextStyle(color: AmColors.pink, fontSize: 15)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.removeEffect(layerId, effect.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

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
                        // PREGUICOSO: `ListView(children:)` constroi
                        // TUDO de uma vez. Com `builder`, so o visivel
                        // (mais uma margem) existe.
                        ? ListView.builder(
                            itemCount: factoryPresets().length,
                            itemBuilder: (context, i) {
                              final p = factoryPresets()[i];
                              return ListTile(
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
                              );
                            },
                          )
                        // ESTADO VAZIO com aparencia propria, e a lista
                        // preguicosa: trinta e oito ListTile construidos
                        // de uma vez e trabalho jogado fora, porque so
                        // meia duzia cabe na tela.
                        : results.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.search,
                                          size: 30,
                                          color: AmColors.muted),
                                      SizedBox(height: 10),
                                      Text(
                                        'Nada encontrado. '
                                        'Tente "glow", "rgb", "pixel" '
                                        'ou "shake".',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: AmColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, i) {
                                  final type = results[i];
                                  final spec = effectSpecs[type]!;
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                        CupertinoIcons.wand_stars,
                                        color: AmColors.accent,
                                        size: 20),
                                    title: Text(spec.name,
                                        style: const TextStyle(
                                            color: AmColors.text,
                                            fontSize: 14)),
                                    subtitle: Text(
                                      '${spec.category}'
                                      '${spec.cost > 1 ? ' · custo ${spec.cost}' : ''}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AmColors.muted),
                                    ),
                                    onTap: () {
                                      controller.addEffect(layerId, type);
                                      Navigator.of(sheetContext).pop();
                                    },
                                  );
                                },
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
      // Reavalia os valores conforme o playhead anda. Envolve o Row
      // inteiro porque o diamante do trilho tambem precisa saber se ha
      // keyframe no cabecote.
      child: ValueListenableBuilder<Duration>(
        valueListenable: widget.playback.time,
        builder: (context, t, _) {
          final local = layer.localTime(t);

          // Parametro selecionado -> efeito + chaves (par X/Y vem como
          // 'x|y'). Resolve por id, nunca por indice: o efeito pode ter
          // sido removido ou reordenado desde a selecao.
          final partes = _selectedParam?.split('/');
          EffectInstance? sel;
          final chaves = <String>[];
          if (partes != null && partes.length == 2) {
            for (final e in layer.effects) {
              if (e.id == partes[0]) sel = e;
            }
            chaves.addAll(partes[1].split('|'));
          }
          final selAnimado =
              sel != null && chaves.any((k) => sel!.track(k).isAnimated);
          final selKfAqui = sel != null &&
              chaves.every((k) => sel!.track(k).hasKeyframeAt(local));

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  AmRailButton(
                    onTap: widget.onBack,
                    child: const Icon(CupertinoIcons.chevron_back,
                        size: 24, color: AmColors.text),
                  ),
                  // Diamante do parametro selecionado, como nos outros
                  // paineis: apagado e inerte quando nada esta selecionado.
                  // Com o par 'x|y' em estado misto (so um eixo com
                  // keyframe aqui, cenario da regua arrastada) o toggle
                  // cego trocaria o keyframe de eixo. Regra: diamante vazio
                  // COMPLETA (so onde falta), diamante cheio LIMPA os dois.
                  AmRailButton(
                    onTap: sel == null
                        ? null
                        : () {
                            for (final k in chaves) {
                              if (selKfAqui ||
                                  !sel!.track(k).hasKeyframeAt(local)) {
                                controller.toggleEffectParamKeyframe(
                                    id, sel!.id, k, t);
                              }
                            }
                          },
                    child: AmDiamondAdd(
                        active: selAnimado, filled: selKfAqui),
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                  children: [
                    for (var i = 0; i < layer.effects.length; i++)
                      _EffectCard(
                        effect: layer.effects[i],
                        local: local,
                        expanded: _expandido(layer.effects[i].id),
                        selectedParam: _selectedParam,
                        onToggleExpanded: () =>
                            _alternarExpandido(layer.effects[i].id),
                        onMenu: () => _menuDoEfeito(context, id,
                            layer.effects[i], i, layer.effects.length),
                        onSelectParam: (p) =>
                            setState(() => _selectedParam = p),
                        onParam: (key, v) => controller.editEffectParam(
                            id, layer.effects[i].id, key, t, v),
                        onParamKeyframe: (key) =>
                            controller.toggleEffectParamKeyframe(
                                id, layer.effects[i].id, key, t),
                        onToggleEnabled: () => controller
                            .toggleEffectEnabled(id, layer.effects[i].id),
                        onColor: (c) => controller.setEffectColor(
                            id, layer.effects[i].id, c),
                        onRemove: () =>
                            controller.removeEffect(id, layer.effects[i].id),
                      ),
                    // ANALISAR: o Blob Tracker precisa varrer o video
                    // uma vez antes de desenhar. Sem o comando, o efeito
                    // so mostra o rastreio simulado — e a pessoa nao
                    // teria como saber que falta um passo.
                    for (final effect in layer.effects)
                      if (effect.type == EffectType.blobTracker &&
                          layer is VideoLayer)
                        _BotaoAnalisar(
                          effectId: effect.id,
                          layerId: id,
                          controller: controller,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EffectCard extends StatelessWidget {
  const _EffectCard({
    required this.effect,
    required this.local,
    required this.expanded,
    required this.selectedParam,
    required this.onToggleExpanded,
    required this.onMenu,
    required this.onSelectParam,
    required this.onParam,
    required this.onParamKeyframe,
    required this.onColor,
    required this.onRemove,
    required this.onToggleEnabled,
  });

  final EffectInstance effect;
  final Duration local;
  final bool expanded;
  final String? selectedParam;
  final VoidCallback onToggleExpanded;
  final VoidCallback onMenu;
  final ValueChanged<String> onSelectParam;
  final void Function(String key, double value) onParam;
  final void Function(String key) onParamKeyframe;
  final ValueChanged<Color> onColor;
  final VoidCallback onRemove;
  final VoidCallback onToggleEnabled;

  /// Linhas de parametro. O par X/Y de um ponto (ParamKind.point) vira
  /// UMA linha com dois valores. Pareia por ADJACENCIA + kind, nunca por
  /// nome: 'tile_center'/'tile_center_y' nao segue o sufixo X.
  List<Widget> _linhas() {
    final entradas = effect.spec.params.entries.toList();
    final linhas = <Widget>[];
    for (var i = 0; i < entradas.length; i++) {
      final entry = entradas[i];
      final ehPar = entry.value.kind == ParamKind.point &&
          i + 1 < entradas.length &&
          entradas[i + 1].value.kind == ParamKind.point;
      if (ehPar) {
        final x = entry;
        final y = entradas[i + 1];
        final paramKey = '${effect.id}/${x.key}|${y.key}';
        final xt = effect.track(x.key);
        final yt = effect.track(y.key);
        // O diamante do par so mostra "cheio" com keyframe nos DOIS
        // eixos. Em estado misto (regua de um eixo arrastada grava so
        // nele) um toggle cego apagaria o eixo que tinha e criaria no
        // outro: o diamante seguiria vazio e o keyframe sumiria. Por
        // isso decide por eixo: vazio completa onde falta, cheio limpa.
        final ambos = xt.hasKeyframeAt(local) && yt.hasKeyframeAt(local);
        linhas.add(_PointRow(
          paramKey: paramKey,
          label: x.value.label.replaceFirst(RegExp(r' X$'), ''),
          xTrack: xt,
          yTrack: yt,
          local: local,
          xMin: x.value.min,
          xMax: x.value.max,
          yMin: y.value.min,
          yMax: y.value.max,
          selected: selectedParam == paramKey,
          onSelect: onSelectParam,
          onChangedX: (v) => onParam(x.key, v),
          onChangedY: (v) => onParam(y.key, v),
          // Dois toggles separados, coalescidos num undo so pelo
          // controller (450 ms).
          onKeyframe: () {
            if (ambos || !xt.hasKeyframeAt(local)) onParamKeyframe(x.key);
            if (ambos || !yt.hasKeyframeAt(local)) onParamKeyframe(y.key);
          },
        ));
        i++;
        continue;
      }
      // PR-C1: cada TIPO de parametro ganha seu controle. Antes so
      // havia numero, e todo efeito que precisava de escolha ou
      // ponto ficava visivel e inerte.
      linhas.add(switch (entry.value.kind) {
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
            onChanged: (v) => onParam(entry.key, v ? 1.0 : 0.0),
          ),
        // Numero (e ponto solteiro) usam a regua; o ponto vem em 0..1.
        _ => _ParamRow(
            paramKey: '${effect.id}/${entry.key}',
            label: entry.value.label,
            track: effect.track(entry.key),
            local: local,
            min: entry.value.min,
            max: entry.value.max,
            selected: selectedParam == '${effect.id}/${entry.key}',
            onSelect: onSelectParam,
            onChanged: (v) => onParam(entry.key, v),
            onKeyframe: () => onParamKeyframe(entry.key),
          ),
      });
    }
    return linhas;
  }

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
        // Desligado continua visivel, so esmaecido.
        opacity: effect.enabled ? 1 : 0.45,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // So chevron + nome colapsam: um toque em "..." ou na
                // lixeira nao pode fechar o bloco junto.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggleExpanded,
                    child: Row(
                      children: [
                        Icon(
                          expanded
                              ? CupertinoIcons.chevron_down
                              : CupertinoIcons.chevron_right,
                          size: 14,
                          color: AmColors.text,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            effect.spec.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AmColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // O OLHO FICA NO CABECALHO, a um toque. Ligar e desligar
                // um efeito para comparar e a acao mais frequente que
                // existe aqui — escondida no menu viraria dois toques por
                // comparacao, e comparar e o que se faz o tempo todo.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleEnabled,
                  child: Icon(
                    effect.enabled
                        ? CupertinoIcons.eye
                        : CupertinoIcons.eye_slash,
                    size: 22,
                    color: effect.enabled ? AmColors.text : AmColors.muted,
                  ),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: onMenu,
                  child: const Icon(CupertinoIcons.ellipsis,
                      size: 22, color: AmColors.text),
                ),
                const SizedBox(width: 14),
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(CupertinoIcons.trash,
                      size: 22, color: AmColors.text),
                ),
              ],
            ),
            // Recolhido: nem constroi o corpo.
            if (expanded) ...[
              const SizedBox(height: 8),
              ..._linhas(),
              if (effect.spec.hasColor)
                _ColorRow(effect: effect, onColor: onColor),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ponto verde a esquerda do nome quando o parametro tem keyframes. O
/// espaco existe SEMPRE, para o nome nao pular de lugar ao animar.
class _PontoAnimado extends StatelessWidget {
  const _PontoAnimado({required this.animated});

  final bool animated;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      child: animated
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AmColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

/// Nome do parametro, selecionavel (fundo accentDim quando selecionado).
class _NomeParam extends StatelessWidget {
  const _NomeParam({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A linha tem 58 px (altura da regua); sem altura propria o alvo do
    // nome ficava com ~30 px e metade da linha nao selecionava o
    // parametro — e selecionar e o que liga o diamante do trilho. 44 px
    // e o minimo de toque do iOS e cabe sem crescer a linha; o `opaque`
    // faz o padding transparente contar como toque.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 88,
        height: 44,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
          ),
        ),
      ),
    );
  }
}

/// Valor alinhado a direita com digitos tabulares: ao arrastar a regua o
/// numero nao "danca" de largura.
const _estiloValor = TextStyle(
  fontSize: 14,
  color: AmColors.text,
  fontFeatures: [FontFeature.tabularFigures()],
);

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
  final AnimatedDouble track;
  final Duration local;
  final double min;
  final double max;
  final bool selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<double> onChanged;
  final VoidCallback onKeyframe;

  @override
  Widget build(BuildContext context) {
    final value = track.valueAt(local);
    final animated = track.isAnimated;
    final kfHere = track.hasKeyframeAt(local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _PontoAnimado(animated: animated),
          _NomeParam(
            label: label,
            selected: selected,
            onTap: () => onSelect(paramKey),
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
              style: _estiloValor,
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

/// Par X/Y de um ponto numa linha so: duas reguas curtas e dois valores
/// alinhados. A sensibilidade da regua e por pixel (unitsPerPixel), entao
/// meia largura nao muda o arrasto — so o tanto de ticks visiveis.
class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.paramKey,
    required this.label,
    required this.xTrack,
    required this.yTrack,
    required this.local,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.selected,
    required this.onSelect,
    required this.onChangedX,
    required this.onChangedY,
    required this.onKeyframe,
  });

  final String paramKey;
  final String label;
  final AnimatedDouble xTrack;
  final AnimatedDouble yTrack;
  final Duration local;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final bool selected;
  final ValueChanged<String> onSelect;
  final ValueChanged<double> onChangedX;
  final ValueChanged<double> onChangedY;
  final VoidCallback onKeyframe;

  @override
  Widget build(BuildContext context) {
    final x = xTrack.valueAt(local);
    final y = yTrack.valueAt(local);
    // Animado se qualquer eixo anima; "no cabecote" so se os DOIS tem
    // keyframe aqui — senao o diamante cheio mentiria sobre um deles.
    final animated = xTrack.isAnimated || yTrack.isAnimated;
    final kfHere =
        xTrack.hasKeyframeAt(local) && yTrack.hasKeyframeAt(local);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          _PontoAnimado(animated: animated),
          _NomeParam(
            label: label,
            selected: selected,
            onTap: () => onSelect(paramKey),
          ),
          Expanded(
            child: AmTickRuler(
              value: x,
              min: xMin,
              max: xMax,
              unitsPerPixel: (xMax - xMin) / 400,
              height: 58,
              onChanged: (v) {
                onSelect(paramKey);
                onChangedX(v);
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: AmTickRuler(
              value: y,
              min: yMin,
              max: yMax,
              unitsPerPixel: (yMax - yMin) / 400,
              height: 58,
              onChanged: (v) {
                onSelect(paramKey);
                onChangedY(v);
              },
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(amNumber(x, 2),
                textAlign: TextAlign.right, style: _estiloValor),
          ),
          SizedBox(
            width: 44,
            child: Text(amNumber(y, 2),
                textAlign: TextAlign.right, style: _estiloValor),
          ),
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
          // Mesma coluna do nome das linhas com regua (ponto + 88).
          const SizedBox(width: 12),
          SizedBox(
              width: 88,
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
          // Mesma coluna do nome das linhas com regua (ponto + 88).
          const SizedBox(width: 12),
          SizedBox(
              width: 88,
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
        // Mesma coluna do nome das linhas com regua (ponto + 88).
        const SizedBox(width: 12),
        SizedBox(
            width: 88,
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
          // Mesma coluna do nome das linhas com regua (ponto + 88).
          const SizedBox(width: 12),
          const SizedBox(
            width: 88,
            child: Text(
              'Cor',
              style: TextStyle(fontSize: 13, color: AmColors.muted),
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

/// O comando de analise do Blob Tracker, com o estado do que ja rodou.
class _BotaoAnalisar extends StatefulWidget {
  const _BotaoAnalisar({
    required this.effectId,
    required this.layerId,
    required this.controller,
  });

  final String effectId;
  final String layerId;
  final EditorController controller;

  @override
  State<_BotaoAnalisar> createState() => _BotaoAnalisarState();
}

class _BotaoAnalisarState extends State<_BotaoAnalisar> {
  bool _rodando = false;

  @override
  void initState() {
    super.initState();
    // Analise de outra sessao: le do disco em vez de refazer.
    BlobTrackService.instance.load(widget.effectId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: BlobTrackService.instance.revision,
      builder: (context, _, _) {
        final dados = BlobTrackService.instance.dataFor(widget.effectId);
        final temAnalise = dados != null && !dados.isEmpty;
        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _rodando
                    ? null
                    : () async {
                        setState(() => _rodando = true);
                        final n = await widget.controller
                            .analyzeBlobsFor(
                                widget.layerId, widget.effectId);
                        if (!context.mounted) return;
                        setState(() => _rodando = false);
                        AureaSnack.show(
                          context,
                          n == null
                              ? 'Nao consegui ler esse video'
                              : '$n quadros analisados',
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: temAnalise
                        ? AmColors.chip
                        : AmColors.accentDim,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _rodando
                        ? 'Analisando o video...'
                        : (temAnalise
                            ? 'Analisar de novo'
                            : 'Analisar o video'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          temAnalise ? AmColors.text : AmColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                temAnalise
                    ? '${dados.frames.length} quadros com caixas gravadas. '
                        'Desenhar virou consulta: o seek e instantaneo.'
                    : 'Ainda nao analisado — o que aparece e um rastreio '
                        'simulado, para ajustar a aparencia.',
                style: const TextStyle(
                    fontSize: 11, height: 1.35, color: AmColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}
