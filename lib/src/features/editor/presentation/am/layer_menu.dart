import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/caption.dart';
import '../../domain/element3d.dart';
import '../../domain/grid_rig.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../domain/mask.dart';
import '../../domain/shape.dart';
import 'am_colors.dart';
import '../../../../core/ui/snack.dart';
import 'am_widgets.dart';
import 'color_picker_sheet.dart';
import 'curve_panel.dart';
import 'oficio_sheets.dart';
import 'scene3d_sheet.dart';
import 'scene3d_studio.dart';

/// Acao escolhida no menu da camada.
enum LayerMenuAction {
  transform,
  blending,
  colorFill,
  effects,
  editText,
  textAnimators,
}

/// Menu que abre ao tocar na barra da camada selecionada:
/// grid com as paginas de edicao + acoes rapidas.
Future<LayerMenuAction?> showLayerMenu(
  BuildContext context,
  WidgetRef ref,
  Layer layer,
  PlaybackController playback,
) {
  return showModalBottomSheet<LayerMenuAction>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              layer.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AmColors.text,
              ),
            ),
            const SizedBox(height: 14),
            // INSPETOR (spec barra-de-acoes §4): UMA linha, altura
            // constante, so editores de propriedade. O que nao se aplica
            // ao tipo aparece ESMAECIDO com a razao ao toque — nenhum
            // controle visivel pode ser inerte. Comandos estruturais
            // (dividir/duplicar/agrupar/excluir) vivem na barra de acoes.
            Row(
              children: [
                _MenuTile(
                  icon: Icons.open_with,
                  label: 'Mover',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(LayerMenuAction.transform),
                ),
                _MenuTile(
                  icon: CupertinoIcons.circle_lefthalf_fill,
                  label: 'Mesclar',
                  enabled: layer is! NullLayer,
                  disabledReason: 'Objeto nulo nao tem mesclagem',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(LayerMenuAction.blending),
                ),
                _MenuTile(
                  icon: CupertinoIcons.paintbrush,
                  label: 'Cor',
                  enabled: layer is ShapeLayer ||
                      layer is TextLayer ||
                      layer is Element3DLayer ||
                      layer is Scene3DLayer,
                  disabledReason: layer is AdjustmentLayer
                      ? 'Camada de ajuste nao tem preenchimento proprio'
                      : 'Este tipo de camada nao tem cor editavel',
                  onTap: () {
                    // Cena 3D: a cor mora no material de cada objeto.
                    if (layer is Scene3DLayer) {
                      Navigator.of(sheetContext).pop();
                      Future.microtask(() {
                        if (context.mounted) {
                          showScene3DSheet(context, ref, layer.id);
                        }
                      });
                      return;
                    }
                    // Elemento 3D edita cor/forma no sheet proprio.
                    if (layer is Element3DLayer) {
                      Navigator.of(sheetContext).pop();
                      Future.microtask(() {
                        if (context.mounted) {
                          showElement3DSheet(context, ref, layer.id);
                        }
                      });
                      return;
                    }
                    Navigator.of(sheetContext)
                        .pop(LayerMenuAction.colorFill);
                  },
                ),
                _MenuTile(
                  icon: CupertinoIcons.wand_stars,
                  label: 'Efeitos',
                  enabled: layer is! NullLayer,
                  disabledReason: 'Objeto nulo nao renderiza efeitos',
                  onTap: () => Navigator.of(sheetContext)
                      .pop(LayerMenuAction.effects),
                ),
                _MenuTile(
                  icon: CupertinoIcons.scope,
                  label: 'Mascaras',
                  enabled: layer is! NullLayer,
                  disabledReason: 'Objeto nulo nao tem conteudo',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showMasksSheet(context, ref, layer.id, playback);
                  },
                ),
                _MenuTile(
                  icon: CupertinoIcons.ellipsis,
                  label: 'Mais',
                  onTap: () async {
                    final action = await _showMoreSheet(
                        context, ref, layer, playback);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop(action);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Toast curto com a razao de um controle desabilitado ou de um comando
/// sem alvo (contrato: nada visivel pode ser inerte em silencio).
void showReasonToast(BuildContext context, String msg) {
  AureaSnack.show(context, msg,
      duration: const Duration(milliseconds: 1500));
}

/// Sheet "mais" do inspetor: o que e raro ou especifico do tipo.
Future<LayerMenuAction?> _showMoreSheet(BuildContext context,
    WidgetRef ref, Layer layer, PlaybackController playback) async {
  final controller = ref.read(editorControllerProvider.notifier);
  return showModalBottomSheet<LayerMenuAction>(
    context: context,
    backgroundColor: AmColors.panelHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (moreContext) {
      Widget item(IconData icon, String label, VoidCallback onTap) =>
          Material(
            color: Colors.transparent,
            child: ListTile(
              leading:
                  Icon(icon, size: 20, color: AmColors.accent),
              title: Text(label,
                  style: const TextStyle(
                      fontSize: 15, color: AmColors.text)),
              onTap: onTap,
            ),
          );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            if (layer is TextLayer) ...[
              item(CupertinoIcons.pencil, 'Editar texto', () {
                Navigator.of(moreContext)
                    .pop(LayerMenuAction.editText);
              }),
              item(CupertinoIcons.textformat_abc_dottedunderline,
                  'Animadores de texto', () {
                Navigator.of(moreContext)
                    .pop(LayerMenuAction.textAnimators);
              }),
            ],
            if (layer is NullLayer)
              item(CupertinoIcons.circle_grid_3x3, 'Modulo Grade', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showGridSheet(context, ref, layer.id, playback);
                  }
                });
              }),
            if (layer is ParticlesLayer)
              item(CupertinoIcons.sparkles, 'Particulas', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showParticlesSheet(context, ref, layer.id);
                  }
                });
              }),
            // OFICIO (motion-graphics-pro): organizacao, estilos e loop.
            item(CupertinoIcons.tag, 'Organizar (rotulo, solo, timida)',
                () {
              Navigator.of(moreContext).pop();
              Future.microtask(() {
                if (context.mounted) {
                  showOrganizeSheet(context, ref, layer.id);
                }
              });
            }),
            item(CupertinoIcons.sparkles, 'Estilos de camada', () {
              Navigator.of(moreContext).pop();
              Future.microtask(() {
                if (context.mounted) {
                  showLayerStylesSheet(context, ref, layer.id, playback);
                }
              });
            }),
            item(CupertinoIcons.repeat, 'Loop de keyframes', () {
              Navigator.of(moreContext).pop();
              Future.microtask(() {
                if (context.mounted) {
                  showLoopSheet(context, ref, layer.id);
                }
              });
            }),
            if (layer is CaptionLayer)
              item(CupertinoIcons.text_badge_checkmark,
                  'Editar legendas', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showCaptionCuesSheet(
                        context, ref, layer.id, playback);
                  }
                });
              }),
            if (layer is ShapeLayer)
              item(CupertinoIcons.slider_horizontal_below_rectangle,
                  'Forma (geometria)', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showShapeParamsSheet(
                        context, ref, layer.id, playback);
                  }
                });
              }),
            if (layer is Element3DLayer)
              item(CupertinoIcons.cube, 'Elemento 3D', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showElement3DSheet(context, ref, layer.id);
                  }
                });
              }),
            if (layer is Scene3DLayer) ...[
              item(CupertinoIcons.cube_box, 'Cena 3D', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    showScene3DSheet(context, ref, layer.id);
                  }
                });
              }),
              item(CupertinoIcons.viewfinder, 'Estudio 3D', () {
                Navigator.of(moreContext).pop();
                Future.microtask(() {
                  if (context.mounted) {
                    openScene3DStudio(context, ref, layer.id);
                  }
                });
              }),
            ],
            // MONTAGEM: o que faz a linha do tempo se comportar como
            // fila, em vez de retangulos soltos.
            item(CupertinoIcons.delete_left, 'Excluir e fechar', () {
              Navigator.of(moreContext).pop();
              controller.rippleDeleteLayer(layer.id);
              if (context.mounted) {
                AureaSnack.show(context,
                    'Camada excluida — o que vinha depois andou para tras',
                    actionLabel: 'Desfazer', onAction: controller.undo);
              }
            }),
            item(CupertinoIcons.arrow_left_to_line, 'Fechar buracos', () {
              final n = controller.gapCount();
              Navigator.of(moreContext).pop();
              if (n == 0) {
                if (context.mounted) {
                  showReasonToast(context, 'Nao ha buraco para fechar');
                }
                return;
              }
              controller.closeTimelineGaps();
              if (context.mounted) {
                AureaSnack.show(
                    context, n == 1 ? '1 buraco fechado' : '$n buracos fechados',
                    actionLabel: 'Desfazer', onAction: controller.undo);
              }
            }),
            if (layer is GroupLayer)
              item(CupertinoIcons.square_stack_3d_down_right,
                  'Desagrupar', () {
                controller.ungroupLayer(layer.id);
                Navigator.of(moreContext).pop();
              })
            else
              item(CupertinoIcons.square_stack_3d_up, 'Precompor',
                  () {
                controller.groupLayer(layer.id);
                Navigator.of(moreContext).pop();
              }),
            Builder(builder: (context) {
              final linked = ref
                  .read(editorControllerProvider)
                  .linkFor(layer.id, LayerProp.parent);
              return item(
                linked != null
                    ? CupertinoIcons.link_circle_fill
                    : CupertinoIcons.link,
                linked != null ? 'Soltar do pai' : 'Vincular ao pai',
                () {
                  Navigator.of(moreContext).pop();
                  if (linked != null) {
                    controller.unlinkProperty(
                        layer.id, LayerProp.parent);
                  } else {
                    Future.microtask(() {
                      if (context.mounted) {
                        showParentSheet(
                            context, ref, layer, playback.time.value);
                      }
                    });
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Modulo GRADE do objeto nulo (spec AM2-modulo-grid): o rig posiciona os
/// assets; a transform de cada camada e um offset por cima (mover uma
/// camada nao quebra a grade). Modos Retangular/Radial/Esferico + Morph
/// animavel (caminho mais curto) + Proximidade com effector esferico 3D.
Future<void> showGridSheet(BuildContext context, WidgetRef ref,
    String nullId, PlaybackController playback) async {
  final controller = ref.read(editorControllerProvider.notifier);

  Future<void> pickAssets(
      BuildContext ctx, StateSetter setSheetState) async {
    final project = ref.read(editorControllerProvider);
    final current = (project.layerById(nullId) as NullLayer?)?.grid;
    final picked = <String>{...(current?.assets ?? const [])};
    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: AmColors.panelHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c2) => StatefulBuilder(
        builder: (c2, setInner) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Camadas da grade (ordem = indice)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in project.layers)
                      if (l.id != nullId && l is! NullLayer)
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            dense: true,
                            value: picked.contains(l.id),
                            activeColor: AmColors.accent,
                            checkColor: const Color(0xFF0B0E12),
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            title: Text(l.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AmColors.text)),
                            onChanged: (v) => setInner(() {
                              if (v == true) {
                                picked.add(l.id);
                              } else {
                                picked.remove(l.id);
                              }
                            }),
                          ),
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: AmColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () {
                      controller.setGridAssets(nullId, picked.toList());
                      Navigator.of(c2).pop();
                    },
                    child: Text('Usar ${picked.length} camada(s)',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0B0E12))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setSheetState(() {});
  }

  await showParamSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) =>
          ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (sheetContext, t, _) {
        final layer =
            ref.read(editorControllerProvider).layerById(nullId);
        if (layer is! NullLayer) return const SizedBox.shrink();
        final rig = layer.grid;
        final local = layer.localTime(t);

        Widget ruler(String label, double value, double min, double max,
            String display, ValueChanged<double> onChanged) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 92,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.muted))),
                Expanded(
                  child: AmTickRuler(
                    value: value,
                    min: min,
                    max: max,
                    unitsPerPixel: (max - min) / 420,
                    height: 42,
                    onChanged: (v) {
                      onChanged(v);
                      setSheetState(() {});
                    },
                  ),
                ),
                SizedBox(
                    width: 56,
                    child: Text(display,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.accent))),
              ],
            ),
          );
        }

        // Linha ANIMAVEL: cada parametro da grade tem sua trilha de
        // keyframes propria, com diamante no playhead atual.
        Widget animRow(String label, String key, AnimatedDouble track,
            double min, double max, String display,
            {double scale = 1}) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 92,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.muted))),
                Expanded(
                  child: AmTickRuler(
                    value: track.valueAt(local) * scale,
                    min: min,
                    max: max,
                    unitsPerPixel: (max - min) / 420,
                    height: 42,
                    onChanged: (v) {
                      controller.editGridParam(
                          nullId, key, t, v / scale);
                      setSheetState(() {});
                    },
                  ),
                ),
                SizedBox(
                    width: 48,
                    child: Text(display,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.accent))),
                CupertinoButton(
                  padding: const EdgeInsets.only(left: 2),
                  onPressed: () {
                    controller.toggleGridParamKeyframe(nullId, key, t);
                    setSheetState(() {});
                  },
                  child: Icon(
                    track.hasKeyframeAt(local)
                        ? CupertinoIcons.rhombus_fill
                        : CupertinoIcons.rhombus,
                    size: 17,
                    color: track.isAnimated
                        ? AmColors.accent
                        : AmColors.muted,
                  ),
                ),
                // Curve editor POR PARAMETRO: cada trilha da grade tem
                // sua propria curva de easing por segmento.
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (track.keyframes.length < 2) {
                      showReasonToast(context,
                          'Crie 2+ keyframes em "$label" para editar a curva');
                      return;
                    }
                    showGridCurveSheet(
                        context, ref, playback, nullId, key, label,
                        onClosed: () {
                      if (context.mounted) {
                        showGridSheet(context, ref, nullId, playback);
                      }
                    });
                  },
                  child: Icon(
                    CupertinoIcons.graph_square,
                    size: 17,
                    color: track.keyframes.length >= 2
                        ? AmColors.accent
                        : AmColors.muted,
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 14, 18,
                14 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Modulo Grade',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AmColors.text)),
                    ),
                    if (rig != null)
                      GestureDetector(
                        onTap: () {
                          controller.removeGrid(nullId);
                          setSheetState(() {});
                        },
                        child: const Text('Remover',
                            style: TextStyle(
                                fontSize: 13, color: AmColors.muted)),
                      ),
                  ],
                ),
                // Mini-transporte: anime keyframes SEM fechar o painel.
                SheetTransport(
                  playback: playback,
                  duration: ref.read(editorControllerProvider).duration,
                  fps: ref.read(editorControllerProvider).fps,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    color: rig == null ? AmColors.accent : AmColors.chip,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: () =>
                        pickAssets(sheetContext, setSheetState),
                    child: Text(
                      rig == null
                          ? 'Escolher camadas da grade...'
                          : 'Camadas: ${rig.assets.length}  (editar)',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: rig == null
                              ? const Color(0xFF0B0E12)
                              : AmColors.accent),
                    ),
                  ),
                ),
                if (rig != null) ...[
                  const SizedBox(height: 12),
                  // Modo / morph: 1 Retangular, 2 Radial, 3 Esferico.
                  Row(
                    children: [
                      for (final (label, mode) in const [
                        ('Retangular', 1.0),
                        ('Radial', 2.0),
                        ('Esferico', 3.0),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              // Com o morph ANIMADO, escolher um modo
                              // cria keyframe no playhead (nao apaga a
                              // animacao); sem animacao, so troca o modo.
                              if (rig.transition.isAnimated) {
                                controller.editGridTransition(
                                    nullId, playback.time.value, mode);
                              } else {
                                controller.updateGrid(
                                    nullId,
                                    (g) => g.copyWith(
                                        transition:
                                            AnimatedDouble(mode)));
                              }
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (!rig.transition.isAnimated &&
                                        rig.transition
                                                .valueAt(local)
                                                .round() ==
                                            mode.round())
                                    ? AmColors.accentDim
                                    : AmColors.chip,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AmColors.accent)),
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Diamante do MORPH (transition animavel).
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          controller.toggleGridTransitionKeyframe(
                              nullId, t);
                          setSheetState(() {});
                        },
                        child: Icon(
                          rig.transition.hasKeyframeAt(local)
                              ? CupertinoIcons.rhombus_fill
                              : CupertinoIcons.rhombus,
                          size: 18,
                          color: rig.transition.isAnimated
                              ? AmColors.accent
                              : AmColors.muted,
                        ),
                      ),
                      // Curva do MORPH.
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () {
                          if (rig.transition.keyframes.length < 2) {
                            showReasonToast(context,
                                'Crie 2+ keyframes no morph para editar a curva');
                            return;
                          }
                          showGridCurveSheet(context, ref, playback,
                              nullId, 'transition', 'Morph',
                              onClosed: () {
                            if (context.mounted) {
                              showGridSheet(
                                  context, ref, nullId, playback);
                            }
                          });
                        },
                        child: Icon(
                          CupertinoIcons.graph_square,
                          size: 18,
                          color: rig.transition.keyframes.length >= 2
                              ? AmColors.accent
                              : AmColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ruler(
                      'Morph',
                      rig.transition.valueAt(local),
                      1,
                      3,
                      amNumber(rig.transition.valueAt(local), 1),
                      (v) =>
                          controller.editGridTransition(nullId, t, v)),
                  ruler('Colunas', rig.columns.toDouble(), 1, 12,
                      '${rig.columns}',
                      (v) => controller.updateGrid(nullId,
                          (g) => g.copyWith(columns: v.round()))),
                  animRow('Espaco X', 'spacingX', rig.spacingX, 20, 800,
                      amNumber(rig.spacingX.valueAt(local), 0)),
                  animRow('Espaco Y', 'spacingY', rig.spacingY, 20, 800,
                      amNumber(rig.spacingY.valueAt(local), 0)),
                  animRow('Raio', 'radius', rig.radius, 40, 1200,
                      amNumber(rig.radius.valueAt(local), 0)),
                  animRow(
                      'Rotacao',
                      'rotation',
                      rig.gridRotationDeg,
                      -180,
                      180,
                      '${amNumber(rig.gridRotationDeg.valueAt(local), 0)}°'),
                  animRow('Twist', 'twist', rig.twistDeg, -180, 180,
                      '${amNumber(rig.twistDeg.valueAt(local), 0)}°'),
                  animRow(
                      'Stagger',
                      'stagger',
                      rig.staggerDeg,
                      -360,
                      360,
                      '${amNumber(rig.staggerDeg.valueAt(local), 0)}°'),
                  animRow('Prof. Z', 'zDepth', rig.zDepth, -400, 400,
                      amNumber(rig.zDepth.valueAt(local), 0)),
                  animRow(
                      'Esc. frente',
                      'scaleFront',
                      rig.scaleFront,
                      10,
                      300,
                      amNumber(rig.scaleFront.valueAt(local) * 100, 0),
                      scale: 100),
                  animRow(
                      'Esc. tras',
                      'scaleBack',
                      rig.scaleBack,
                      10,
                      300,
                      amNumber(rig.scaleBack.valueAt(local) * 100, 0),
                      scale: 100),
                  animRow(
                      'Aleatorio',
                      'randomOffset',
                      rig.randomOffset,
                      0,
                      300,
                      amNumber(rig.randomOffset.valueAt(local), 0)),
                  ruler('Semente', rig.seed.toDouble(), 0, 100,
                      '${rig.seed}',
                      (v) => controller.updateGrid(
                          nullId, (g) => g.copyWith(seed: v.round()))),
                  Row(
                    children: [
                      const Text('Embaralhar',
                          style: TextStyle(
                              fontSize: 13, color: AmColors.muted)),
                      Transform.scale(
                        scale: 0.68,
                        child: CupertinoSwitch(
                          value: rig.shuffle,
                          activeTrackColor: AmColors.accent,
                          onChanged: (v) {
                            controller.updateGrid(nullId,
                                (g) => g.copyWith(shuffle: v));
                            setSheetState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('Proximidade',
                          style: TextStyle(
                              fontSize: 13, color: AmColors.muted)),
                      Transform.scale(
                        scale: 0.68,
                        child: CupertinoSwitch(
                          value: rig.proximity?.enabled ?? false,
                          activeTrackColor: AmColors.accent,
                          onChanged: (v) {
                            controller.updateGrid(nullId, (g) {
                              if (v) {
                                return g.copyWith(
                                    proximity: (g.proximity ??
                                            ProximityGroup())
                                        .copyWith(enabled: true));
                              }
                              return g.copyWith(
                                  proximity: g.proximity
                                      ?.copyWith(enabled: false));
                            });
                            setSheetState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Nulo CONTROLADOR: um SEGUNDO nulo cujo transform
                  // modula a grade — animar/curvar o nulo anima a grade.
                  Row(
                    children: [
                      const Text('Nulo controlador',
                          style: TextStyle(
                              fontSize: 13, color: AmColors.muted)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final pickedId = await _pickControllerNull(
                                sheetContext, ref, nullId);
                            if (pickedId == '') {
                              controller.setGridController(nullId, null);
                            } else if (pickedId != null) {
                              controller.setGridController(
                                  nullId, pickedId);
                            }
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: rig.controllerId != null
                                  ? AmColors.accentDim
                                  : AmColors.chip,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              rig.controllerId == null
                                  ? 'Nenhum'
                                  : (ref
                                          .read(editorControllerProvider)
                                          .layerById(rig.controllerId!)
                                          ?.name ??
                                      'Nulo removido'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AmColors.accent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (rig.controllerId != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Escala do nulo -> espacamento/raio · Rotacao Z '
                        '-> rotacao da grade · Rotacao Y -> twist.',
                        style: TextStyle(
                            fontSize: 11, color: AmColors.muted),
                      ),
                    ),
                  if (rig.proximity?.enabled ?? false) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'O effector e uma ESFERA 3D: raio 200 tambem '
                      'alcanca 200 de profundidade.',
                      style:
                          TextStyle(fontSize: 11, color: AmColors.muted),
                    ),
                    const SizedBox(height: 6),
                    ruler(
                        'Effector X',
                        rig.proximity!.effector.valueAt(local).dx,
                        -800,
                        800,
                        amNumber(
                            rig.proximity!.effector.valueAt(local).dx, 0),
                        (v) => controller.updateGrid(nullId, (g) {
                              final p = g.proximity!;
                              final cur = p.effector.valueAt(local);
                              return g.copyWith(
                                  proximity: p.copyWith(
                                      effector: p.effector.edited(
                                          local, Offset(v, cur.dy))));
                            })),
                    ruler(
                        'Effector Y',
                        rig.proximity!.effector.valueAt(local).dy,
                        -800,
                        800,
                        amNumber(
                            rig.proximity!.effector.valueAt(local).dy, 0),
                        (v) => controller.updateGrid(nullId, (g) {
                              final p = g.proximity!;
                              final cur = p.effector.valueAt(local);
                              return g.copyWith(
                                  proximity: p.copyWith(
                                      effector: p.effector.edited(
                                          local, Offset(cur.dx, v))));
                            })),
                    ruler(
                        'Raio prox.',
                        rig.proximity!.radius.valueAt(local),
                        20,
                        800,
                        amNumber(
                            rig.proximity!.radius.valueAt(local), 0),
                        (v) => controller.updateGrid(nullId, (g) {
                              final p = g.proximity!;
                              return g.copyWith(
                                  proximity: p.copyWith(
                                      radius:
                                          p.radius.edited(local, v)));
                            })),
                    ruler(
                        'Escala max',
                        rig.proximity!.scaleMax * 100,
                        20,
                        400,
                        amNumber(rig.proximity!.scaleMax * 100, 0),
                        (v) => controller.updateGrid(nullId, (g) {
                              return g.copyWith(
                                  proximity: g.proximity!
                                      .copyWith(scaleMax: v / 100));
                            })),
                    ruler(
                        'Atrair',
                        rig.proximity!.attract.valueAt(local),
                        -300,
                        300,
                        amNumber(
                            rig.proximity!.attract.valueAt(local), 0),
                        (v) => controller.updateGrid(nullId, (g) {
                              final p = g.proximity!;
                              return g.copyWith(
                                  proximity: p.copyWith(
                                      attract:
                                          p.attract.edited(local, v)));
                            })),
                  ],
                ],
              ],
            ),
          ),
        );
        },
      ),
    ),
  );
}

/// Painel de MASCARAS da camada (spec AM2-mascaras-e-formas, PR-M2):
/// pilha de mascaras com modo, inverter, feather, expansao e opacidade —
/// tudo animavel; o caminho tambem aceita keyframe (diamante).
Future<void> showMasksSheet(BuildContext context, WidgetRef ref,
    String layerId, PlaybackController playback) async {
  final controller = ref.read(editorControllerProvider.notifier);

  String modeLabel(MaskMode m) => switch (m) {
        MaskMode.none => 'Nenhum',
        MaskMode.add => 'Somar',
        MaskMode.subtract => 'Subtrair',
        MaskMode.intersect => 'Intersecao',
        MaskMode.lighten => 'Clarear',
        MaskMode.darken => 'Escurecer',
        MaskMode.difference => 'Diferenca',
      };

  await showParamSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) =>
          ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (sheetContext, t, _) {
        final layer =
            ref.read(editorControllerProvider).layerById(layerId);
        if (layer == null) return const SizedBox.shrink();
        final local = layer.localTime(t);

        Widget ruler(String label, double value, double min, double max,
            String display, ValueChanged<double> onChanged) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                    width: 86,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.muted))),
                Expanded(
                  child: AmTickRuler(
                    value: value,
                    min: min,
                    max: max,
                    unitsPerPixel: (max - min) / 420,
                    height: 44,
                    onChanged: (v) {
                      onChanged(v);
                      setSheetState(() {});
                    },
                  ),
                ),
                SizedBox(
                    width: 56,
                    child: Text(display,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.accent))),
              ],
            ),
          );
        }

        Widget preset(String label, BezierPath path) {
          return GestureDetector(
            onTap: () {
              controller.addMask(
                  layerId,
                  LayerMask(
                      name: label,
                      path: AnimatedPath(path),
                      feather: AnimatedDouble(0)));
              setSheetState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('+ $label',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmColors.accent)),
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 14, 18,
                14 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mascaras',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                SheetTransport(
                  playback: playback,
                  duration: ref.read(editorControllerProvider).duration,
                  fps: ref.read(editorControllerProvider).fps,
                ),
                const SizedBox(height: 4),
                const Text(
                  'A primeira corta o alfa da camada; as seguintes '
                  'operam sobre as de cima.',
                  style: TextStyle(fontSize: 12, color: AmColors.muted),
                ),
                const SizedBox(height: 12),
                for (final (i, m) in layer.masks.indexed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    decoration: BoxDecoration(
                      color: AmColors.bg.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${i + 1}. ${m.name}',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AmColors.text)),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                controller.cycleMaskMode(layerId, m.id);
                                setSheetState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AmColors.chip,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(modeLabel(m.mode),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AmColors.accent)),
                              ),
                            ),
                            const Spacer(),
                            const Text('Inv',
                                style: TextStyle(
                                    fontSize: 12, color: AmColors.muted)),
                            Transform.scale(
                              scale: 0.68,
                              child: CupertinoSwitch(
                                value: m.inverted,
                                activeTrackColor: AmColors.accent,
                                onChanged: (_) {
                                  controller.toggleMaskInverted(
                                      layerId, m.id);
                                  setSheetState(() {});
                                },
                              ),
                            ),
                            // Diamante: keyframe do CAMINHO.
                            CupertinoButton(
                              padding: const EdgeInsets.all(4),
                              onPressed: () {
                                controller.toggleMaskPathKeyframe(
                                    layerId, m.id, t);
                                setSheetState(() {});
                              },
                              child: Icon(
                                m.path.hasKeyframeAt(local)
                                    ? CupertinoIcons.rhombus_fill
                                    : CupertinoIcons.rhombus,
                                size: 18,
                                color: m.path.isAnimated
                                    ? AmColors.accent
                                    : AmColors.muted,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                controller.removeMask(layerId, m.id);
                                setSheetState(() {});
                              },
                              child: const Icon(CupertinoIcons.xmark,
                                  size: 15, color: AmColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ruler(
                            'Feather',
                            m.feather.valueAt(local),
                            0,
                            200,
                            amNumber(m.feather.valueAt(local), 0),
                            (v) => controller.editMaskParam(
                                layerId, m.id, 'feather', t, v)),
                        ruler(
                            'Expansao',
                            m.expansion.valueAt(local),
                            -200,
                            200,
                            amNumber(m.expansion.valueAt(local), 0),
                            (v) => controller.editMaskParam(
                                layerId, m.id, 'expansion', t, v)),
                        ruler(
                            'Opacidade',
                            m.opacity.valueAt(local) * 100,
                            0,
                            100,
                            amNumber(m.opacity.valueAt(local) * 100, 0),
                            (v) => controller.editMaskParam(layerId, m.id,
                                'opacity', t, v / 100)),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    preset('Retangulo', BezierPath.rect(460, 460)),
                    preset('Circulo', BezierPath.ellipse(480, 480)),
                    preset('Estrela', BezierPath.star(5, 250, 125)),
                    preset('Coracao', BezierPath.heart(440, 420)),
                  ],
                ),
              ],
            ),
          ),
        );
        },
      ),
    ),
  );
}

/// Escolher o PAI (objeto nulo ou qualquer camada): o filho segue o delta
/// de posicao/rotacao/escala do pai a partir de agora.
Future<void> showParentSheet(
    BuildContext context, WidgetRef ref, Layer child, Duration t) async {
  final project = ref.read(editorControllerProvider);
  final controller = ref.read(editorControllerProvider.notifier);
  final candidates = [
    ...project.layers.whereType<NullLayer>(),
    ...project.layers.where((l) => l is! NullLayer),
  ];

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
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Seguir a camada (pai)...',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
          ),
          for (final other in candidates)
            if (other.id != child.id)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: Icon(
                    other is NullLayer
                        ? CupertinoIcons.viewfinder
                        : CupertinoIcons.square_on_square,
                    size: 20,
                    color: other is NullLayer
                        ? AmColors.tealBright
                        : AmColors.muted,
                  ),
                  title: Text(other.name,
                      style: const TextStyle(color: AmColors.text)),
                  subtitle: other is NullLayer
                      ? const Text('Objeto nulo',
                          style: TextStyle(
                              fontSize: 11, color: AmColors.muted))
                      : null,
                  onTap: () {
                    controller.linkProperty(
                        child.id, LayerProp.parent, other.id, t);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Painel de parametros do sistema de particulas.
Future<void> showParticlesSheet(
    BuildContext context, WidgetRef ref, String layerId) async {
  final controller = ref.read(editorControllerProvider.notifier);

  await showParamSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final layer = ref
            .read(editorControllerProvider)
            .layerById(layerId);
        if (layer is! ParticlesLayer) return const SizedBox.shrink();

        Widget row(String label, double value, double min, double max,
            double upp, String display,
            ValueChanged<double> onChanged) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 86,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.muted))),
                Expanded(
                  child: AmTickRuler(
                    value: value,
                    min: min,
                    max: max,
                    unitsPerPixel: upp,
                    height: 46,
                    onChanged: (v) {
                      onChanged(v);
                      setSheetState(() {});
                    },
                  ),
                ),
                SizedBox(
                    width: 64,
                    child: Text(display,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: AmColors.accent))),
              ],
            ),
          );
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 14, 18,
                14 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Particulas 3D',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                const SizedBox(height: 14),
                row('Quantidade', layer.count.toDouble(), 1, 800, 1.2,
                    '${layer.count}',
                    (v) => controller.updateParticles(layerId,
                        (p) => p.copyParticles(count: v.round()))),
                row('Velocidade', layer.speed, 0, 2000, 3,
                    amNumber(layer.speed, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(speed: v))),
                row('Abertura', layer.spreadDeg, 0, 360, 0.9,
                    '${amNumber(layer.spreadDeg, 0)}°',
                    (v) => controller.updateParticles(layerId,
                        (p) => p.copyParticles(spreadDeg: v))),
                row('Direcao', layer.directionDeg, -180, 180, 0.9,
                    '${amNumber(layer.directionDeg, 0)}°',
                    (v) => controller.updateParticles(layerId,
                        (p) => p.copyParticles(directionDeg: v))),
                row('Gravidade', layer.gravity, -2000, 2000, 4,
                    amNumber(layer.gravity, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(gravity: v))),
                row('Tamanho', layer.size, 1, 120, 0.3,
                    amNumber(layer.size, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(size: v))),
                row('Vida (s)', layer.lifetimeMs / 1000, 0.3, 10, 0.02,
                    amNumber(layer.lifetimeMs / 1000, 1),
                    (v) => controller.updateParticles(
                        layerId,
                        (p) => p.copyParticles(
                            lifetimeMs: (v * 1000).round()))),
                row('3D (Z)', layer.depth, 0, 3000, 5,
                    amNumber(layer.depth, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(depth: v))),
                row('Area X', layer.emitW, 0, 2400, 4,
                    amNumber(layer.emitW, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(emitW: v))),
                row('Area Y', layer.emitH, 0, 2400, 4,
                    amNumber(layer.emitH, 0),
                    (v) => controller.updateParticles(
                        layerId, (p) => p.copyParticles(emitH: v))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('Estrelas',
                        style: TextStyle(
                            fontSize: 13, color: AmColors.muted)),
                    Transform.scale(
                      scale: 0.72,
                      child: CupertinoSwitch(
                        value: layer.star,
                        activeTrackColor: AmColors.accent,
                        onChanged: (v) {
                          controller.updateParticles(layerId,
                              (p) => p.copyParticles(star: v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('Cintilar',
                        style: TextStyle(
                            fontSize: 13, color: AmColors.muted)),
                    Transform.scale(
                      scale: 0.72,
                      child: CupertinoSwitch(
                        value: layer.twinkle,
                        activeTrackColor: AmColors.accent,
                        onChanged: (v) {
                          controller.updateParticles(layerId,
                              (p) => p.copyParticles(twinkle: v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const Spacer(),
                    for (final c in const [
                      Color(0xFFFF3B52),
                      Color(0xFFB8FF3D),
                      Color(0xFF7C62FF),
                      Color(0xFFFFFFFF),
                      Color(0xFFFFB020),
                      Color(0xFF35C4E7),
                    ])
                      GestureDetector(
                        onTap: () {
                          controller.updateParticles(layerId,
                              (p) => p.copyParticles(color: c));
                          setSheetState(() {});
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: layer.color == c
                                ? Border.all(
                                    color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Sheet do ELEMENTO 3D: tipo do solido, tamanho, cor e arestas. A
/// rotacao vem do transform normal da camada (X/Y/Z, keyframes e curvas
/// de sempre) — e da cadeia de nulos quando vinculado a um pai.
Future<void> showElement3DSheet(
    BuildContext context, WidgetRef ref, String layerId) async {
  final controller = ref.read(editorControllerProvider.notifier);

  await showParamSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final layer =
            ref.read(editorControllerProvider).layerById(layerId);
        if (layer is! Element3DLayer) return const SizedBox.shrink();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 14, 18,
                14 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Elemento 3D',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kind in Element3DKind.values)
                      GestureDetector(
                        onTap: () {
                          controller.updateElement3D(layerId,
                              (e) => e.copyElement3D(kind: kind));
                          setSheetState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: layer.kind == kind
                                ? AmColors.accentDim
                                : AmColors.chip,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(element3DLabel(kind),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AmColors.accent)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                        width: 86,
                        child: Text('Tamanho',
                            style: TextStyle(
                                fontSize: 13, color: AmColors.muted))),
                    Expanded(
                      child: AmTickRuler(
                        value: layer.size,
                        min: 20,
                        max: 600,
                        unitsPerPixel: 1.4,
                        height: 46,
                        onChanged: (v) {
                          controller.updateElement3D(layerId,
                              (e) => e.copyElement3D(size: v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                    SizedBox(
                        width: 56,
                        child: Text(amNumber(layer.size, 0),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14, color: AmColors.accent))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Arestas',
                        style: TextStyle(
                            fontSize: 13, color: AmColors.muted)),
                    Transform.scale(
                      scale: 0.72,
                      child: CupertinoSwitch(
                        value: layer.edges,
                        activeTrackColor: AmColors.accent,
                        onChanged: (v) {
                          controller.updateElement3D(layerId,
                              (e) => e.copyElement3D(edges: v));
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const Spacer(),
                    // Qualquer cor: espectro, hex e alfa.
                    ColorWell(
                      color: layer.color,
                      size: 30,
                      onChanged: (c) {
                        controller.updateElement3D(layerId,
                            (e) => e.copyElement3D(color: c));
                        setSheetState(() {});
                      },
                    ),
                    for (final c in const [
                      Color(0xFF7C62FF),
                      Color(0xFFB8FF3D),
                      Color(0xFFFF3B52),
                      Color(0xFFFFFFFF),
                    ])
                      GestureDetector(
                        onTap: () {
                          controller.updateElement3D(layerId,
                              (e) => e.copyElement3D(color: c));
                          setSheetState(() {});
                        },
                        child: Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: layer.color == c
                                ? Border.all(
                                    color: Colors.white, width: 2.5)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gire com a rotacao X/Y/Z normal da camada — ou '
                  'vincule a um nulo 3D e gire o nulo.',
                  style: TextStyle(fontSize: 11, color: AmColors.muted),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Sheet FORMA (spec AUREA-parametros-de-forma §4): parametros da
/// GEOMETRIA — Tamanho e parametro do caminho e nao engorda o traco;
/// Escala (em Mover) engorda tudo junto. Todo numero e animavel com
/// diamante e curva.
Future<void> showShapeParamsSheet(BuildContext context, WidgetRef ref,
    String layerId, PlaybackController playback) async {
  final controller = ref.read(editorControllerProvider.notifier);

  await showParamSheet(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) =>
          ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (sheetContext, t, _) {
          final layer =
              ref.read(editorControllerProvider).layerById(layerId);
          if (layer is! ShapeLayer) return const SizedBox.shrink();
          final local = layer.localTime(t);
          ShapeParametric? sp;
          for (final item in layer.contents) {
            if (item is ShapeParametric) {
              sp = item;
              break;
            }
          }

          Widget animRow(String label, String key, double min,
              double max, String display,
              {double scale = 1}) {
            final track = shapeParamTrackOf(sp!, key)!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 88,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 13, color: AmColors.muted))),
                  Expanded(
                    child: AmTickRuler(
                      value: track.valueAt(local) * scale,
                      min: min,
                      max: max,
                      unitsPerPixel: (max - min) / 420,
                      height: 42,
                      onChanged: (v) {
                        controller.editShapeParam(
                            layerId, key, t, v / scale);
                        setSheetState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                      width: 48,
                      child: Text(display,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: AmColors.accent))),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 2),
                    onPressed: () {
                      controller.toggleShapeParamKeyframe(
                          layerId, key, t);
                      setSheetState(() {});
                    },
                    child: Icon(
                      track.hasKeyframeAt(local)
                          ? CupertinoIcons.rhombus_fill
                          : CupertinoIcons.rhombus,
                      size: 17,
                      color: track.isAnimated
                          ? AmColors.accent
                          : AmColors.muted,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      if (track.keyframes.length < 2) {
                        showReasonToast(context,
                            'Crie 2+ keyframes em "$label" para editar a curva');
                        return;
                      }
                      showTrackCurveSheet(
                        context,
                        ref,
                        playback,
                        label: label,
                        layerId: layerId,
                        trackOf: (l) {
                          if (l is! ShapeLayer) return null;
                          for (final item in l.contents) {
                            if (item is ShapeParametric) {
                              return shapeParamTrackOf(item, key);
                            }
                          }
                          return null;
                        },
                        onSetEase: (segStart, ease) =>
                            controller.setShapeParamSegmentEase(
                                layerId, key, segStart, ease),
                        onSetEaseAll: (ease) =>
                            controller.applyEaseToAllShapeParamSegments(
                                layerId, key, ease),
                        onClosed: () {
                          if (context.mounted) {
                            showShapeParamsSheet(
                                context, ref, layerId, playback);
                          }
                        },
                      );
                    },
                    child: Icon(
                      CupertinoIcons.graph_square,
                      size: 17,
                      color: track.keyframes.length >= 2
                          ? AmColors.accent
                          : AmColors.muted,
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, 14, 18,
                  14 + MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Forma — geometria',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AmColors.text)),
                  SheetTransport(
                    playback: playback,
                    duration:
                        ref.read(editorControllerProvider).duration,
                    fps: ref.read(editorControllerProvider).fps,
                  ),
                  const SizedBox(height: 6),
                  if (sp == null) ...[
                    const Text(
                      'Esta forma e um caminho desenhado (sem '
                      'parametros). Converta para editar Tamanho, '
                      'Arredondamento, Pontas e afins — animaveis.',
                      style: TextStyle(
                          fontSize: 13, color: AmColors.muted),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: AmColors.accent,
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          controller.convertShapeToParametric(layerId);
                          if (controller.shapeParametricOf(layerId) ==
                              null) {
                            showReasonToast(context,
                                'Esta forma nao tem equivalente parametrico');
                          }
                          setSheetState(() {});
                        },
                        child: const Text('Converter para parametrica',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0B0E12))),
                      ),
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (label, kind) in const [
                          ('Retangulo', ParamShapeKind.rect),
                          ('Elipse', ParamShapeKind.ellipse),
                          ('Poligono', ParamShapeKind.polygon),
                          ('Estrela', ParamShapeKind.star),
                          ('Setor', ParamShapeKind.sector),
                        ])
                          GestureDetector(
                            onTap: () {
                              controller.setShapeParamKind(
                                  layerId, kind);
                              setSheetState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: sp.kind == kind
                                    ? AmColors.accentDim
                                    : AmColors.chip,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AmColors.accent)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (sp.kind == ParamShapeKind.rect ||
                        sp.kind == ParamShapeKind.ellipse) ...[
                      animRow('Tamanho X', 'sizeX', 4, 1000,
                          amNumber(sp.sizeX.valueAt(local), 0)),
                      animRow('Tamanho Y', 'sizeY', 4, 1000,
                          amNumber(sp.sizeY.valueAt(local), 0)),
                    ],
                    if (sp.kind == ParamShapeKind.rect) ...[
                      animRow(
                          'Arredond.',
                          'roundness',
                          0,
                          sp.roundnessPercent ? 100 : 300,
                          amNumber(sp.roundness.valueAt(local), 0)),
                      Row(
                        children: [
                          const Text('Unidade do canto',
                              style: TextStyle(
                                  fontSize: 12, color: AmColors.muted)),
                          const SizedBox(width: 10),
                          for (final (label, pct) in const [
                            ('% do lado', true),
                            ('px fixo', false),
                          ])
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  controller.setShapeRoundnessUnit(
                                      layerId,
                                      percent: pct);
                                  setSheetState(() {});
                                },
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6),
                                  decoration: BoxDecoration(
                                    color: sp.roundnessPercent == pct
                                        ? AmColors.accentDim
                                        : AmColors.chip,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(label,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AmColors.accent)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    if (sp.kind == ParamShapeKind.polygon ||
                        sp.kind == ParamShapeKind.star) ...[
                      animRow('Pontas', 'points', 2, 16,
                          amNumber(sp.points.valueAt(local), 1)),
                      animRow('Raio', 'outerRadius', 10, 600,
                          amNumber(sp.outerRadius.valueAt(local), 0)),
                      animRow(
                          'Arred. ext',
                          'outerRoundness',
                          -100,
                          200,
                          amNumber(
                              sp.outerRoundness.valueAt(local), 0)),
                      animRow(
                          'Rotacao',
                          'shapeRotation',
                          -180,
                          180,
                          '${amNumber(sp.shapeRotation.valueAt(local), 0)}°'),
                    ],
                    if (sp.kind == ParamShapeKind.star) ...[
                      animRow('Raio int', 'innerRadius', 0, 600,
                          amNumber(sp.innerRadius.valueAt(local), 0)),
                      animRow(
                          'Arred. int',
                          'innerRoundness',
                          -100,
                          200,
                          amNumber(
                              sp.innerRoundness.valueAt(local), 0)),
                    ],
                    if (sp.kind == ParamShapeKind.sector) ...[
                      animRow('Raio', 'outerRadius', 10, 600,
                          amNumber(sp.outerRadius.valueAt(local), 0)),
                      animRow('Raio int', 'sectorInner', 0, 600,
                          amNumber(sp.sectorInner.valueAt(local), 0)),
                      animRow(
                          'Ang. inicial',
                          'startAngle',
                          -180,
                          360,
                          '${amNumber(sp.startAngle.valueAt(local), 0)}°'),
                      animRow('Varredura', 'sweep', 0, 360,
                          '${amNumber(sp.sweep.valueAt(local), 0)}°'),
                    ],
                    const Text(
                      'Tamanho muda a GEOMETRIA (traco constante). '
                      'Escala, em Mover, engorda tudo junto.',
                      style: TextStyle(
                          fontSize: 11, color: AmColors.muted),
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
}

/// Editor de LEGENDAS: lista de cues com texto corrigivel em linha
/// (editar trava o cue — retranscrever nao sobrescreve), toque no tempo
/// para dar seek e ouvir, e X para descartar um cue errado. Sheet
/// persistente: o preview segue visivel enquanto voce revisa.
Future<void> showCaptionCuesSheet(BuildContext context, WidgetRef ref,
    String layerId, PlaybackController playback) async {
  final controller = ref.read(editorControllerProvider.notifier);
  // Um TextEditingController ESTAVEL por cue: o sheet pode reconstruir
  // (setSheetState) sem perder cursor nem texto digitado.
  final editors = <String, TextEditingController>{};

  await showParamSheet(
    context,
    heightFactor: 0.55,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final project = ref.read(editorControllerProvider);
        final layer = project.layerById(layerId);
        if (layer is! CaptionLayer) return const SizedBox.shrink();
        final cues = layer.cues;

        TextEditingController editorOf(Cue c) =>
            editors.putIfAbsent(c.id, () {
              final e = TextEditingController(
                  text: c.text.replaceAll('\n', ' '));
              // So grava quando o TEXTO muda (o listener tambem dispara
              // por cursor/selecao — isso nao pode travar o cue).
              var last = e.text;
              e.addListener(() {
                if (e.text == last) return;
                last = e.text;
                controller.updateCueText(layerId, c.id, e.text);
              });
              return e;
            });

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18,
                10 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Legendas — ${cues.length} cues',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                SheetTransport(
                  playback: playback,
                  duration: project.duration,
                  fps: project.fps,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toque no tempo para ouvir o trecho; corrija o texto '
                  'direto. Editar trava o cue.',
                  style: TextStyle(fontSize: 11, color: AmColors.muted),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: cues.isEmpty
                      ? const Center(
                          child: Text('Sem cues nesta camada.',
                              style: TextStyle(
                                  fontSize: 13, color: AmColors.muted)),
                        )
                      : ListView.builder(
                          itemCount: cues.length,
                          itemBuilder: (context, i) {
                            final c = cues[i];
                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => playback.seek(
                                        layer.startTime + c.start),
                                    child: Container(
                                      width: 74,
                                      padding: const EdgeInsets
                                          .symmetric(vertical: 8),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AmColors.chip,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        formatTimecode(
                                            c.start, project.fps),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.locked
                                              ? AmColors.accent
                                              : AmColors.muted,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: editorOf(c),
                                      maxLines: 1,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: AmColors.text),
                                      padding: const EdgeInsets
                                          .symmetric(
                                          horizontal: 10,
                                          vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AmColors.chip,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.only(
                                        left: 6),
                                    onPressed: () {
                                      controller.removeCue(
                                          layerId, c.id);
                                      editors
                                          .remove(c.id)
                                          ?.dispose();
                                      setSheetState(() {});
                                    },
                                    child: const Icon(
                                        CupertinoIcons.xmark_circle,
                                        size: 20,
                                        color: AmColors.muted),
                                  ),
                                ],
                              ),
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
  for (final e in editors.values) {
    e.dispose();
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.disabledReason,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Matriz de aplicabilidade: desabilitado fica ESMAECIDO no mesmo
  /// lugar, e o toque explica a razao (nunca some, nunca e inerte).
  final bool enabled;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? onTap
            : () => showReasonToast(
                context, disabledReason ?? 'Indisponivel para esta camada'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AmColors.chip,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 23, color: AmColors.accent),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 10, color: AmColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blend modes oferecidos (familias estilo compositor classico).
const amBlendModes = <(String, BlendMode)>[
  ('Normal', BlendMode.srcOver),
  ('Escurecer', BlendMode.darken),
  ('Multiplicar', BlendMode.multiply),
  ('Color Burn', BlendMode.colorBurn),
  ('Clarear', BlendMode.lighten),
  ('Screen', BlendMode.screen),
  ('Color Dodge', BlendMode.colorDodge),
  ('Adicionar', BlendMode.plus),
  ('Overlay', BlendMode.overlay),
  ('Soft Light', BlendMode.softLight),
  ('Hard Light', BlendMode.hardLight),
  ('Diferenca', BlendMode.difference),
  ('Exclusao', BlendMode.exclusion),
  ('Matiz', BlendMode.hue),
  ('Saturacao', BlendMode.saturation),
  ('Cor', BlendMode.color),
  ('Luminosidade', BlendMode.luminosity),
];

/// Painel "Mesclagem e opacidade": blend mode + regua de opacidade.
class BlendingPanel extends ConsumerWidget {
  const BlendingPanel({
    super.key,
    required this.playback,
    required this.onBack,
    required this.onOpenCurve,
  });

  final PlaybackController playback;
  final VoidCallback onBack;
  final void Function(LayerProp prop) onOpenCurve;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer == null || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }
    final controller = ref.read(editorControllerProvider.notifier);

    // Escuta o relogio: `t` sempre atual (keyframe cai no playhead real).
    return ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (context, t, _) {
    final local = layer.localTime(t);
    final opacity = layer.opacity.valueAt(local);

    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AmRailButton(
                onTap: onBack,
                child: const Icon(CupertinoIcons.chevron_back,
                    size: 24, color: AmColors.text),
              ),
              AmRailButton(
                onTap: () =>
                    controller.toggleKeyframe(id, t, LayerProp.opacity),
                child: AmDiamondAdd(
                  active: layer.opacity.isAnimated,
                  filled: layer.opacity.hasKeyframeAt(local),
                ),
              ),
              AmRailButton(
                onTap: layer.opacity.isAnimated
                    ? () => onOpenCurve(LayerProp.opacity)
                    : null,
                child: AmCurveIcon(
                    color: layer.opacity.isAnimated
                        ? AmColors.text
                        : AmColors.muted),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fileira de blend modes (rolavel).
                  SizedBox(
                    height: 62,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final (label, mode) in amBlendModes)
                          GestureDetector(
                            onTap: () => controller.setBlendMode(id, mode),
                            child: Container(
                              width: 74,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: AmColors.chip,
                                borderRadius: BorderRadius.circular(10),
                                border: layer.blendMode == mode
                                    ? Border.all(
                                        color: AmColors.accent, width: 2)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.circle_lefthalf_fill,
                                      size: 18,
                                      color: layer.blendMode == mode
                                          ? AmColors.accent
                                          : AmColors.muted),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: layer.blendMode == mode
                                          ? AmColors.accent
                                          : AmColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Matte (PR-M5): outra camada recorta esta.
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(right: 8, top: 10),
                          child: Text('Matte',
                              style: TextStyle(
                                  fontSize: 12, color: AmColors.muted)),
                        ),
                        for (final (label, mode) in const [
                          ('Nenhum', MatteMode.none),
                          ('Alfa', MatteMode.alpha),
                          ('Alfa inv.', MatteMode.alphaInvert),
                          ('Luma', MatteMode.luma),
                          ('Luma inv.', MatteMode.lumaInvert),
                        ])
                          GestureDetector(
                            onTap: () async {
                              if (mode == MatteMode.none) {
                                controller.setMatte(
                                    id, MatteMode.none, null);
                                return;
                              }
                              var srcId = layer.matteSourceId;
                              srcId ??= await _pickMatteSource(
                                  context, ref, layer);
                              if (srcId != null) {
                                controller.setMatte(id, mode, srcId);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: layer.matteMode == mode
                                    ? AmColors.accentDim
                                    : AmColors.chip,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: layer.matteMode == mode
                                          ? AmColors.accent
                                          : AmColors.text)),
                            ),
                          ),
                        if (layer.matteMode != MatteMode.none)
                          GestureDetector(
                            onTap: () async {
                              final srcId = await _pickMatteSource(
                                  context, ref, layer);
                              if (srcId != null) {
                                controller.setMatte(
                                    id, layer.matteMode, srcId);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(
                                'Fonte: ${ref.read(editorControllerProvider).layerById(layer.matteSourceId ?? '')?.name ?? 'escolher...'}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AmColors.accent,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AmColors.accent),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: AmValueChip(
                        text: amNumber(opacity * 100, 0),
                        label: 'Opacidade',
                        width: 150),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: AmTickRuler(
                      value: opacity * 100,
                      min: 0,
                      max: 100,
                      unitsPerPixel: 0.35,
                      height: double.infinity,
                      onChanged: (v) =>
                          controller.editOpacity(id, t, v / 100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
        });
  }
}

/// Escolher a camada FONTE do matte (qualquer camada da cena).
/// Picker do nulo CONTROLADOR da grade: null = cancelou, '' = nenhum.
Future<String?> _pickControllerNull(
    BuildContext context, WidgetRef ref, String ownerId) async {
  final project = ref.read(editorControllerProvider);
  final nulls = [
    for (final l in project.layers)
      if (l is NullLayer && l.id != ownerId) l,
  ];
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Nulo controlador da grade',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
          ),
          if (nulls.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Crie outro Nulo 3D para usar como controlador '
                '(o proprio nulo da grade nao conta).',
                style: TextStyle(fontSize: 13, color: AmColors.muted),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: ListTile(
              title: const Text('Nenhum',
                  style: TextStyle(color: AmColors.muted)),
              onTap: () => Navigator.of(sheetContext).pop(''),
            ),
          ),
          for (final other in nulls)
            Material(
              color: Colors.transparent,
              child: ListTile(
                title: Text(other.name,
                    style: const TextStyle(color: AmColors.text)),
                subtitle: const Text(
                    'Escala/rotacao dele passam a modular a grade',
                    style:
                        TextStyle(fontSize: 11, color: AmColors.muted)),
                onTap: () => Navigator.of(sheetContext).pop(other.id),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<String?> _pickMatteSource(
    BuildContext context, WidgetRef ref, Layer target) async {
  final project = ref.read(editorControllerProvider);
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Usar como matte...',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
          ),
          for (final other in project.layers)
            if (other.id != target.id)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  title: Text(other.name,
                      style: const TextStyle(color: AmColors.text)),
                  subtitle: const Text('A fonte fica oculta na cena',
                      style: TextStyle(
                          fontSize: 11, color: AmColors.muted)),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(other.id),
                ),
              ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Painel "Cor e preenchimento" (forma/texto) + operadores vetoriais
/// (Trim Paths e Repeater) quando a camada e uma forma.
class ColorFillPanel extends ConsumerWidget {
  const ColorFillPanel({
    super.key,
    required this.onBack,
    required this.playback,
  });

  final VoidCallback onBack;
  final PlaybackController playback;

  static const _swatches = [
    Color(0xFFB97A5E),
    Color(0xFF4A7BA6),
    Color(0xFFFF5566),
    Color(0xFFFFB020),
    Color(0xFF2BE3A0),
    Color(0xFF35C4E7),
    Color(0xFF7C62FF),
    Color(0xFFFFFFFF),
    Color(0xFF10151D),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer == null || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }
    final controller = ref.read(editorControllerProvider.notifier);
    final current = switch (layer) {
      ShapeLayer l => l.primaryColor,
      TextLayer l => l.color,
      _ => null,
    };

    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AmRailButton(
                onTap: onBack,
                child: const Icon(CupertinoIcons.chevron_back,
                    size: 24, color: AmColors.text),
              ),
            ],
          ),
          Expanded(
            child: current == null
                ? const Center(
                    child: Text(
                      'Esta camada nao tem cor editavel.',
                      style:
                          TextStyle(color: AmColors.muted, fontSize: 13),
                    ),
                  )
                : ValueListenableBuilder<Duration>(
                    valueListenable: playback.time,
                    builder: (context, t, _) => ListView(
                      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
                      children: [
                        // QUALQUER COR: espectro completo, hex e alfa.
                        // Os atalhos abaixo continuam para o caso comum.
                        GestureDetector(
                          onTap: () async {
                            void set(Color c) {
                              if (layer is ShapeLayer) {
                                controller.setShapePrimaryColor(id, c);
                              } else if (layer is TextLayer) {
                                controller.editTextLayer(id, color: c);
                              }
                            }

                            final picked = await showColorPicker(
                              context,
                              initial: current,
                              onChanged: set,
                            );
                            if (picked != null) set(picked);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              color: AmColors.chip,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: current,
                                    borderRadius:
                                        BorderRadius.circular(9),
                                    border: Border.all(
                                        color: Colors.white24),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('Escolher qualquer cor',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AmColors.text)),
                                ),
                                const Icon(CupertinoIcons.chevron_right,
                                    size: 15, color: AmColors.muted),
                              ],
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            for (final c in _swatches)
                              GestureDetector(
                                onTap: () {
                                  if (layer is ShapeLayer) {
                                    controller.setShapePrimaryColor(
                                        id, c);
                                  } else if (layer is TextLayer) {
                                    controller.editTextLayer(id,
                                        color: c);
                                  }
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: current.toARGB32() ==
                                              c.toARGB32()
                                          ? AmColors.accent
                                          : Colors.white24,
                                      width: current.toARGB32() ==
                                              c.toARGB32()
                                          ? 3
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (layer is ShapeLayer)
                          _ShapeOperators(
                            layer: layer,
                            layerId: id,
                            globalTime: t,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Operadores vetoriais da forma: Trim Paths e Repeater, animaveis.
class _ShapeOperators extends ConsumerWidget {
  const _ShapeOperators({
    required this.layer,
    required this.layerId,
    required this.globalTime,
  });

  final ShapeLayer layer;
  final String layerId;
  final Duration globalTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(editorControllerProvider.notifier);
    final local = layer.localTime(globalTime);

    Widget ruler(String label, double value, double min, double max,
        ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AmColors.muted)),
          ),
          Expanded(
            child: AmTickRuler(
              value: value,
              min: min,
              max: max,
              unitsPerPixel: (max - min) / 450,
              height: 30,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(amNumber(value, 0),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11, color: AmColors.text)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('OPERADORES',
            style: TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                color: AmColors.muted)),
        const SizedBox(height: 8),
        for (final item in layer.contents)
          if (item is TrimOperator)
            Container(
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
                      const Expanded(
                        child: Text('Trim Paths',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AmColors.text)),
                      ),
                      // PR-M8: Individually (cascata) x Simultaneously.
                      GestureDetector(
                        onTap: () => controller.setTrimMode(
                            layerId, item.id, !item.individually),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: AmColors.chip,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            item.individually ? 'Individual' : 'Continuo',
                            style: const TextStyle(
                                fontSize: 11, color: AmColors.accent),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            controller.removeShapeItem(layerId, item.id),
                        child: const Icon(CupertinoIcons.xmark,
                            size: 14, color: AmColors.muted),
                      ),
                    ],
                  ),
                  ruler('Inicio', item.start.valueAt(local) * 100, 0, 100,
                      (v) => controller.editTrim(
                          layerId, item.id, 'start', globalTime, v / 100)),
                  ruler('Fim', item.end.valueAt(local) * 100, 0, 100,
                      (v) => controller.editTrim(
                          layerId, item.id, 'end', globalTime, v / 100)),
                  ruler(
                      'Offset',
                      item.offset.valueAt(local) * 100,
                      -100,
                      100,
                      (v) => controller.editTrim(layerId, item.id,
                          'offset', globalTime, v / 100)),
                ],
              ),
            )
          else if (item is RepeaterOperator)
            Container(
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
                      const Expanded(
                        child: Text('Repeater',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AmColors.text)),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: item.copies > 1
                            ? () => controller.editRepeater(
                                layerId, item.id, globalTime,
                                copies: item.copies - 1)
                            : null,
                        child: const Icon(CupertinoIcons.minus_circle,
                            size: 18, color: AmColors.muted),
                      ),
                      Text('${item.copies}',
                          style: const TextStyle(
                              fontSize: 13, color: AmColors.text)),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => controller.editRepeater(
                            layerId, item.id, globalTime,
                            copies: item.copies + 1),
                        child: const Icon(CupertinoIcons.plus_circle,
                            size: 18, color: AmColors.accent),
                      ),
                      GestureDetector(
                        onTap: () =>
                            controller.removeShapeItem(layerId, item.id),
                        child: const Icon(CupertinoIcons.xmark,
                            size: 14, color: AmColors.muted),
                      ),
                    ],
                  ),
                  ruler(
                      'Desloc X',
                      item.dx,
                      -400,
                      400,
                      (v) => controller.editRepeater(
                          layerId, item.id, globalTime, dx: v)),
                  ruler(
                      'Desloc Y',
                      item.dy,
                      -400,
                      400,
                      (v) => controller.editRepeater(
                          layerId, item.id, globalTime, dy: v)),
                  ruler(
                      'Rotacao',
                      item.rotation.valueAt(local),
                      -180,
                      180,
                      (v) => controller.editRepeater(
                          layerId, item.id, globalTime, rotationDeg: v)),
                ],
              ),
            )
          else if (item is ShapeMorph)
            Container(
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
                          'Morph  '
                          '${_primName(item.from.primitive)} -> '
                          '${_primName(item.to.primitive)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AmColors.text),
                        ),
                      ),
                      // Diamante: keyframe do progresso do morph.
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => controller.toggleMorphKeyframe(
                            layerId, item.id, globalTime),
                        child: Icon(
                          item.progress.hasKeyframeAt(local)
                              ? CupertinoIcons.rhombus_fill
                              : CupertinoIcons.rhombus,
                          size: 18,
                          color: item.progress.isAnimated
                              ? AmColors.accent
                              : AmColors.muted,
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            controller.removeMorph(layerId, item.id),
                        child: const Icon(CupertinoIcons.xmark,
                            size: 14, color: AmColors.muted),
                      ),
                    ],
                  ),
                  ruler(
                      'Progresso',
                      item.progress.valueAt(local) * 100,
                      0,
                      100,
                      (v) => controller.editMorphProgress(
                          layerId, item.id, globalTime, v / 100)),
                ],
              ),
            ),
        Row(
          children: [
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onPressed: () =>
                  controller.addShapeOperator(layerId, repeater: false),
              child: const Text('+ Trim Paths',
                  style: TextStyle(fontSize: 12, color: AmColors.accent)),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onPressed: () =>
                  controller.addShapeOperator(layerId, repeater: true),
              child: const Text('+ Repeater',
                  style: TextStyle(fontSize: 12, color: AmColors.accent)),
            ),
            CupertinoButton(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onPressed: () => _pickMorphTarget(context, ref),
              child: const Text('+ Morfar',
                  style: TextStyle(fontSize: 12, color: AmColors.accent)),
            ),
          ],
        ),
      ],
    );
  }

  static String _primName(ShapePrimitive p) => switch (p) {
        ShapePrimitive.rectangle => 'Retangulo',
        ShapePrimitive.roundedRectangle => 'Retangulo',
        ShapePrimitive.ellipse => 'Circulo',
        ShapePrimitive.polygon => 'Poligono',
        ShapePrimitive.star => 'Estrela',
        ShapePrimitive.ring => 'Anel',
        ShapePrimitive.arc => 'Arco',
        ShapePrimitive.wave => 'Onda',
        ShapePrimitive.heart => 'Coracao',
        ShapePrimitive.gear => 'Engrenagem',
        ShapePrimitive.arrow => 'Seta',
        ShapePrimitive.check => 'Check',
        ShapePrimitive.plus => 'Mais',
        ShapePrimitive.drop => 'Gota',
        ShapePrimitive.flower => 'Flor',
        ShapePrimitive.sparkle => 'Faisca',
      };

  /// Escolhe a forma DESTINO do morph.
  Future<void> _pickMorphTarget(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(editorControllerProvider.notifier);
    final options = <(String, ShapePath)>[
      ('Circulo', ShapePath(primitive: ShapePrimitive.ellipse)),
      (
        'Retangulo',
        ShapePath(primitive: ShapePrimitive.roundedRectangle)
      ),
      ('Estrela', ShapePath(primitive: ShapePrimitive.star)),
      ('Poligono', ShapePath(primitive: ShapePrimitive.polygon, points: 6)),
      ('Coracao', ShapePath(primitive: ShapePrimitive.heart)),
      ('Arco', ShapePath(primitive: ShapePrimitive.arc)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AmColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Morfar para...',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AmColors.text)),
              const SizedBox(height: 6),
              const Text(
                'A forma atual vira a origem; anime o Progresso com '
                'keyframes para ver a transformacao.',
                style: TextStyle(fontSize: 12, color: AmColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (label, path) in options)
                    GestureDetector(
                      onTap: () {
                        controller.convertShapeToMorph(layerId, path);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: AmColors.chip,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AmColors.accent)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
