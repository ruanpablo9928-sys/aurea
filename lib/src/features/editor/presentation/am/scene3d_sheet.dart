import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../domain/glb_import.dart';
import '../../../../core/ui/snack.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/camera3d.dart';
import '../../domain/element3d.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../domain/scene3d.dart';
import '../widgets/element3d_painter.dart';
import 'am_colors.dart';
import 'am_widgets.dart';
import 'color_picker_sheet.dart';
import 'scene3d_studio.dart';

/// SHEET DA CENA 3D: estrutura da cena, materiais, luzes, camera com os
/// tres jeitos de ver a mesma grandeza (focal, angulo, zoom), a
/// profundidade de campo completa, os rigs e as ajudas.
///
/// Tudo aqui e parametro real do modelo — nada de caixa-preta.
Future<void> showScene3DSheet(
  BuildContext context,
  WidgetRef ref,
  String layerId,
) async {
  var tab = 0;
  String? selectedNode;

  await showParamSheet(
    context,
    title: 'Cena 3D',
    heightFactor: 0.55,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final layer = ref.read(editorControllerProvider).layerById(layerId);
        if (layer is! Scene3DLayer) return const SizedBox.shrink();
        final controller = ref.read(editorControllerProvider.notifier);
        final compWidth =
            ref.read(editorControllerProvider).outputWidth.toDouble();

        void redraw() => setSheetState(() {});

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
                child: Row(
                  children: [
                    const Text('Cena 3D',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AmColors.text)),
                    const SizedBox(width: 10),
                    _BudgetBadge(layer: layer),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(sheetContext).maybePop();
                        Future.microtask(() {
                          if (context.mounted) {
                            openScene3DStudio(context, ref, layerId);
                          }
                        });
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.viewfinder,
                              size: 18, color: AmColors.accent),
                          SizedBox(width: 5),
                          Text('Estudio',
                              style: TextStyle(
                                  fontSize: 13, color: AmColors.accent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Tabs(
                labels: const [
                  'Objetos',
                  'Luzes',
                  'Camera',
                  'Foco',
                  'Ajudas',
                ],
                index: tab,
                onChanged: (i) => setSheetState(() => tab = i),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18, 10, 18,
                      16 + MediaQuery.of(sheetContext).viewInsets.bottom),
                  child: switch (tab) {
                    0 => _ObjectsTab(
                        layer: layer,
                        controller: controller,
                        selected: selectedNode,
                        onSelect: (id) =>
                            setSheetState(() => selectedNode = id),
                        onChanged: redraw,
                      ),
                    1 => _LightsTab(
                        layer: layer,
                        controller: controller,
                        onChanged: redraw,
                      ),
                    2 => _CameraTab(
                        layer: layer,
                        controller: controller,
                        compWidth: compWidth,
                        onChanged: redraw,
                      ),
                    3 => _DofTab(
                        layer: layer,
                        controller: controller,
                        onChanged: redraw,
                      ),
                    _ => _HelpersTab(
                        layer: layer,
                        controller: controller,
                        onChanged: redraw,
                      ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ------------------------------------------------------------ objetos

class _ObjectsTab extends StatelessWidget {
  const _ObjectsTab({
    required this.layer,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });

  final Scene3DLayer layer;
  final EditorController controller;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scene = layer.scene;
    final node = scene.nodes.where((n) => n.id == selected).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint(
            'Estrutura da cena. Cada objeto e uma malha de verdade — dois '
            'que se cruzam mostram a intersecao correta.'),
        for (final n in scene.nodes)
          _NodeRow(
            node: n,
            selected: n.id == selected,
            onTap: () => onSelect(n.id == selected ? null : n.id),
            onVisible: () {
              controller.updateSceneNode(layer.id, n.id,
                  (x) => x.copyWith(visible: !x.visible));
              onChanged();
            },
            onIsolate: () {
              controller.isolateSceneNode(layer.id, n.id);
              onChanged();
            },
            onDelete: () {
              controller.removeSceneNode(layer.id, n.id);
              if (selected == n.id) onSelect(null);
              onChanged();
            },
          ),
        const SizedBox(height: 8),

        // EXTRUDAR: a forma plana do projeto vira volume. E o caminho de
        // logo chapado para logo girando, sem modelar nada.
        Builder(builder: (context) {
          final project = ProviderScope.containerOf(context)
              .read(editorControllerProvider);
          final formas = project.layers.whereType<ShapeLayer>().toList();
          if (formas.isEmpty) {
            return const _Hint(
                'Desenhe uma camada de forma para poder extrudar ela em '
                '3D.');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle('Extrudar uma forma'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in formas)
                    GestureDetector(
                      onTap: () {
                        final id = controller.extrudeShapeIntoScene(
                            layer.id, f.id);
                        if (id != null) onSelect(id);
                        onChanged();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: AmColors.chip,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.cube,
                                size: 13, color: AmColors.accent),
                            const SizedBox(width: 6),
                            Text(f.name,
                                style: const TextStyle(
                                    fontSize: 11, color: AmColors.text)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (node?.outline != null) ...[
                const SizedBox(height: 6),
                _Num(
                  label: 'Espessura',
                  track: AnimatedDouble(node!.extrudeDepth),
                  min: 2,
                  max: 300,
                  onChanged: (v) {
                    controller.setExtrudeDepth(layer.id, node.id, v);
                    onChanged();
                  },
                ),
              ],
              const SizedBox(height: 10),
            ],
          );
        }),

        // NULO 3D e o rig que ele destrava. Sem nulo dentro da cena nao
        // ha rigging la dentro: nao da para girar um conjunto junto,
        // nem orbitar a camera interna.
        Row(
          children: [
            Expanded(
              child: _AcaoLarga(
                rotulo: 'Nulo 3D',
                onTap: () {
                  final id = controller.addSceneNull(layer.id);
                  if (id.isNotEmpty) onSelect(id);
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AcaoLarga(
                rotulo: 'Rig de orbita',
                onTap: () {
                  controller.addOrbitRig(layer.id);
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // PAI de cada no, e de quem a camera interna segue.
        if (node != null) ...[
          _Chips(
            label: 'Pai de "${node.name}"',
            options: [
              'Nenhum',
              for (final n in scene.nodes)
                if (n.id != node.id) n.name,
            ],
            index: node.parentId == null
                ? 0
                : (() {
                    final outros = [
                      for (final n in scene.nodes)
                        if (n.id != node.id) n
                    ];
                    final i =
                        outros.indexWhere((n) => n.id == node.parentId);
                    return i < 0 ? 0 : i + 1;
                  })(),
            onChanged: (i) {
              final outros = [
                for (final n in scene.nodes)
                  if (n.id != node.id) n
              ];
              controller.setSceneNodeParent(layer.id, node.id,
                  i == 0 ? null : outros[i - 1].id);
              onChanged();
            },
          ),
          const _Hint(
              'Girar o pai orbita o filho em torno do pivo dele. Um ciclo '
              '(A pai de B e B pai de A) e recusado.'),
          const SizedBox(height: 6),
        ],

        _Chips(
          label: 'Camera segue',
          options: [
            'Nada',
            for (final n in scene.nodes) n.name,
          ],
          index: scene.cameraParentId == null
              ? 0
              : (() {
                  final i = scene.nodes
                      .indexWhere((n) => n.id == scene.cameraParentId);
                  return i < 0 ? 0 : i + 1;
                })(),
          onChanged: (i) {
            controller.setSceneCameraParent(
                layer.id, i == 0 ? null : scene.nodes[i - 1].id);
            onChanged();
          },
        ),
        const _Hint(
            'A camera herda posicao e rotacao do pai — nunca escala. '
            'Camera nao tem escala, e herdar e o que faz o enquadramento '
            'explodir.'),
        const SizedBox(height: 10),

        // MODELO PRONTO: modelar em celular ninguem vai fazer; baixar um
        // .glb, sim. Sem isso a cena 3D fica presa nos oito solidos.
        _AcaoLarga(
          rotulo: 'Trazer modelo .glb',
          onTap: () async {
            final r = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['glb'],
            );
            final caminho = r?.files.single.path;
            if (caminho == null || !context.mounted) return;
            try {
              final modelo =
                  parseGlb(await File(caminho).readAsBytes());
              final id = controller.addGlbNode(layer.id, modelo);
              if (id.isNotEmpty) onSelect(id);
              onChanged();
              if (context.mounted && modelo.warning != null) {
                AureaSnack.show(context, modelo.warning!);
              }
            } on GlbException catch (e) {
              if (context.mounted) {
                AureaSnack.show(context, e.message);
              }
            } catch (_) {
              if (context.mounted) {
                AureaSnack.show(context, 'Nao consegui ler esse arquivo');
              }
            }
          },
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final kind in Element3DKind.values)
              GestureDetector(
                onTap: () {
                  controller.addSceneNode(layer.id, kind);
                  onChanged();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.plus,
                          size: 12, color: AmColors.accent),
                      const SizedBox(width: 5),
                      Text(element3DLabel(kind),
                          style: const TextStyle(
                              fontSize: 12, color: AmColors.accent)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (node != null) ...[
          const SizedBox(height: 16),
          _SectionTitle(node.name),
          _Num(
            label: 'Posicao X',
            track: node.x,
            min: -1500,
            max: 1500,
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(x: n.x.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Posicao Y',
            track: node.y,
            min: -1500,
            max: 1500,
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(y: n.y.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Posicao Z',
            track: node.z,
            min: -1500,
            max: 1500,
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(z: n.z.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Girar X',
            track: node.rotX,
            min: -360,
            max: 360,
            suffix: '°',
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(rotX: n.rotX.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Girar Y',
            track: node.rotY,
            min: -360,
            max: 360,
            suffix: '°',
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(rotY: n.rotY.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Girar Z',
            track: node.rotZ,
            min: -360,
            max: 360,
            suffix: '°',
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(rotZ: n.rotZ.withBase(v)));
              onChanged();
            },
          ),
          _Plain(
            label: 'Tamanho',
            value: node.size,
            min: 10,
            max: 600,
            onChanged: (v) {
              controller.updateSceneNode(
                  layer.id, node.id, (n) => n.copyWith(size: v));
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          _SectionTitle('Material'),
          _Chips(
            label: 'Tipo',
            options: const ['PBR', 'Sem luz', 'Vidro', 'Recorte'],
            index: node.material.kind.index,
            onChanged: (i) {
              controller.updateSceneNode(
                  layer.id,
                  node.id,
                  (n) => n.copyWith(
                      material: n.material
                          .copyWith(kind: MaterialKind.values[i])));
              onChanged();
            },
          ),
          _ColorRow(
            color: node.material.baseColor,
            onColor: (c) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(material: n.material.copyWith(baseColor: c)));
              onChanged();
            },
          ),
          _Plain(
            label: 'Metalico',
            value: node.material.metallic,
            min: 0,
            max: 1,
            decimals: 2,
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(material: n.material.copyWith(metallic: v)));
              onChanged();
            },
          ),
          _Plain(
            label: 'Rugosidade',
            value: node.material.roughness,
            min: 0,
            max: 1,
            decimals: 2,
            onChanged: (v) {
              controller.updateSceneNode(
                  layer.id,
                  node.id,
                  (n) => n.copyWith(
                      material: n.material.copyWith(roughness: v)));
              onChanged();
            },
          ),
          _Plain(
            label: 'Emissivo',
            value: node.material.emissive,
            min: 0,
            max: 2,
            decimals: 2,
            onChanged: (v) {
              controller.updateSceneNode(
                  layer.id,
                  node.id,
                  (n) => n.copyWith(
                      material: n.material.copyWith(emissive: v)));
              onChanged();
            },
          ),
          _Plain(
            label: 'Opacidade',
            value: node.material.opacity,
            min: 0,
            max: 1,
            decimals: 2,
            onChanged: (v) {
              controller.updateSceneNode(layer.id, node.id,
                  (n) => n.copyWith(material: n.material.copyWith(opacity: v)));
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _SectionTitle('Duplicar em array (Grade 3D)'),
          const _Hint(
              'Todas as copias sao INSTANCIAS da mesma malha: 200 objetos '
              'continuam sendo uma chamada de desenho.'),
          _ArrayControls(
            node: node,
            onApply: (x, y, z, spacing) {
              controller.arrayNodeInstances(
                layer.id,
                node.id,
                countX: x,
                countY: y,
                countZ: z,
                spacing: spacing,
              );
              onChanged();
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Action(
                icon: CupertinoIcons.viewfinder,
                label: 'Enquadrar',
                onTap: () {
                  controller.frameSceneNode(layer.id, node.id);
                  onChanged();
                },
              ),
              _Action(
                icon: CupertinoIcons.circle_lefthalf_fill,
                label: 'Focar aqui',
                onTap: () {
                  controller.focusCameraOnNode(layer.id, node.id);
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AcaoLarga extends StatelessWidget {
  const _AcaoLarga({required this.rotulo, required this.onTap});

  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AmColors.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(rotulo,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmColors.accent)),
        ),
      );
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.selected,
    required this.onTap,
    required this.onVisible,
    required this.onIsolate,
    required this.onDelete,
  });

  final SceneNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onVisible;
  final VoidCallback onIsolate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AmColors.accentDim : AmColors.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: CustomPaint(
                painter: Element3DPainter(
                  layer: Element3DLayer(
                    name: '',
                    startTime: Duration.zero,
                    duration: const Duration(seconds: 1),
                    kind: node.kind,
                    size: 9,
                    color: node.material.baseColor,
                  ),
                  rotXDeg: -20,
                  rotYDeg: 32,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: node.visible ? AmColors.text : AmColors.muted,
                ),
              ),
            ),
            if (node.instances.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text('${node.instances.length}x',
                    style: const TextStyle(
                        fontSize: 11, color: AmColors.accent)),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: onVisible,
              child: Icon(
                node.visible ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                size: 17,
                color: node.visible ? AmColors.text : AmColors.muted,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: onIsolate,
              child: const Icon(CupertinoIcons.rectangle_dock,
                  size: 16, color: AmColors.muted),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: onDelete,
              child: const Icon(CupertinoIcons.trash,
                  size: 15, color: AmColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrayControls extends StatefulWidget {
  const _ArrayControls({required this.node, required this.onApply});

  final SceneNode node;
  final void Function(int x, int y, int z, double spacing) onApply;

  @override
  State<_ArrayControls> createState() => _ArrayControlsState();
}

class _ArrayControlsState extends State<_ArrayControls> {
  int _x = 4;
  int _y = 1;
  int _z = 4;
  double _spacing = 160;

  @override
  Widget build(BuildContext context) {
    final total = _x * _y * _z;
    return Column(
      children: [
        _Plain(
          label: 'Colunas X',
          value: _x.toDouble(),
          min: 1,
          max: 20,
          decimals: 0,
          onChanged: (v) => setState(() => _x = v.round()),
        ),
        _Plain(
          label: 'Linhas Y',
          value: _y.toDouble(),
          min: 1,
          max: 20,
          decimals: 0,
          onChanged: (v) => setState(() => _y = v.round()),
        ),
        _Plain(
          label: 'Camadas Z',
          value: _z.toDouble(),
          min: 1,
          max: 20,
          decimals: 0,
          onChanged: (v) => setState(() => _z = v.round()),
        ),
        _Plain(
          label: 'Espaco',
          value: _spacing,
          min: 20,
          max: 600,
          onChanged: (v) => setState(() => _spacing = v),
        ),
        Row(
          children: [
            _Action(
              icon: CupertinoIcons.square_grid_3x2,
              label: 'Gerar $total',
              onTap: () => widget.onApply(_x, _y, _z, _spacing),
            ),
            const SizedBox(width: 8),
            _Action(
              icon: CupertinoIcons.clear,
              label: 'Limpar',
              onTap: () => widget.onApply(1, 1, 1, _spacing),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- luzes

class _LightsTab extends StatelessWidget {
  const _LightsTab({
    required this.layer,
    required this.controller,
    required this.onChanged,
  });

  final Scene3DLayer layer;
  final EditorController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lights = layer.scene.lights;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint(
            'Iluminacao direta com poucas luzes. Cada malha so recebe as '
            'luzes que a alcancam — luz fora do alcance nem entra na conta.'),
        _Plain(
          label: 'Ambiente',
          value: layer.scene.ambient,
          min: 0,
          max: 1,
          decimals: 2,
          onChanged: (v) {
            controller.updateScene3D(layer.id, (s) => s.copyWith(ambient: v));
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        for (final l in lights) ...[
          _SectionTitle(switch (l.kind) {
            Light3DKind.directional => 'Direcional',
            Light3DKind.point => 'Ponto',
            Light3DKind.ambient => 'Ambiente',
          }),
          _Num(
            label: 'Intensidade',
            track: l.intensity,
            min: 0,
            max: 4,
            decimals: 2,
            onChanged: (v) {
              controller.updateSceneLight(layer.id, l.id,
                  (x) => x.copyWith(intensity: x.intensity.withBase(v)));
              onChanged();
            },
          ),
          if (l.kind == Light3DKind.point)
            _Plain(
              label: 'Alcance',
              value: l.range,
              min: 100,
              max: 4000,
              onChanged: (v) {
                controller.updateSceneLight(
                    layer.id, l.id, (x) => x.copyWith(range: v));
                onChanged();
              },
            ),
          _ColorRow(
            color: l.color,
            onColor: (c) {
              controller.updateSceneLight(
                  layer.id, l.id, (x) => x.copyWith(color: c));
              onChanged();
            },
          ),
          Row(
            children: [
              _Toggle(
                label: 'Sombra',
                value: l.castsShadow,
                onChanged: (v) {
                  controller.updateSceneLight(
                      layer.id, l.id, (x) => x.copyWith(castsShadow: v));
                  onChanged();
                },
              ),
              const Spacer(),
              _Action(
                icon: CupertinoIcons.trash,
                label: 'Remover',
                onTap: () {
                  controller.removeSceneLight(layer.id, l.id);
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          children: [
            for (final k in Light3DKind.values)
              _Action(
                icon: CupertinoIcons.lightbulb,
                label: switch (k) {
                  Light3DKind.directional => 'Direcional',
                  Light3DKind.point => 'Ponto',
                  Light3DKind.ambient => 'Ambiente',
                },
                onTap: () {
                  controller.addSceneLight(layer.id, k);
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- camera

class _CameraTab extends StatelessWidget {
  const _CameraTab({
    required this.layer,
    required this.controller,
    required this.compWidth,
    required this.onChanged,
  });

  final Scene3DLayer layer;
  final EditorController controller;
  final double compWidth;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cam = layer.camera;
    final focal = cam.focalLength.base;
    final fov = cam.fovAt(Duration.zero);
    final zoom = cam.zoomAt(Duration.zero, compWidth);

    void setFocal(double mm) {
      controller.updateScene3DCamera(layer.id,
          (c) => c.copyWith(focalLength: c.focalLength.withBase(mm)));
      onChanged();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Chips(
          label: 'Tipo',
          options: const ['Dois nos', 'Um no'],
          index: cam.kind.index,
          onChanged: (i) {
            // Converter NUNCA pode fazer a cena pular: o enquadramento
            // atual vira ponto de interesse (ou orientacao) equivalente.
            controller.updateScene3DCamera(
                layer.id,
                (c) => c.convertedTo(
                    CameraKind.values[i], Duration.zero));
            onChanged();
          },
        ),
        const _Hint(
            'Dois nos olha sempre para o ponto de interesse. Um no e livre. '
            'Trocar preserva o enquadramento.'),
        const SizedBox(height: 6),
        _SectionTitle('Lente'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final mm in lensPresets)
              GestureDetector(
                onTap: () => setFocal(mm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (focal - mm).abs() < 0.5
                        ? AmColors.accentDim
                        : AmColors.chip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${mm.toInt()}mm',
                      style: const TextStyle(
                          fontSize: 12, color: AmColors.accent)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // OS TRES JEITOS DE VER A MESMA GRANDEZA, ao vivo. Mexer num
        // recalcula os outros dois — e o que faz a relacao ficar clara.
        _Plain(
          label: 'Focal (mm)',
          value: focal,
          min: 5,
          max: 400,
          decimals: 1,
          onChanged: setFocal,
        ),
        _Plain(
          label: 'Angulo (°)',
          value: fov,
          min: 4,
          max: 160,
          decimals: 1,
          onChanged: (v) =>
              setFocal(focalFromFov(v, filmWidth: layer.camera.filmWidth)),
        ),
        _Plain(
          label: 'Zoom (px)',
          value: zoom,
          min: 100,
          max: 20000,
          decimals: 0,
          onChanged: (v) => setFocal(focalFromZoom(v, compWidth,
              filmWidth: layer.camera.filmWidth)),
        ),
        _Plain(
          label: 'Filme (mm)',
          value: cam.filmWidth,
          min: 8,
          max: 70,
          decimals: 1,
          onChanged: (v) {
            controller.updateScene3DCamera(
                layer.id, (c) => c.copyWith(filmWidth: v));
            onChanged();
          },
        ),
        _Toggle(
          label: 'Ortografica',
          value: cam.orthographic,
          onChanged: (v) {
            controller.updateScene3DCamera(
                layer.id, (c) => c.copyWith(orthographic: v));
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        _SectionTitle('Posicao'),
        _Num(
          label: 'X',
          track: cam.posX,
          min: -3000,
          max: 3000,
          onChanged: (v) {
            controller.updateScene3DCamera(
                layer.id, (c) => c.copyWith(posX: c.posX.withBase(v)));
            onChanged();
          },
        ),
        _Num(
          label: 'Y',
          track: cam.posY,
          min: -3000,
          max: 3000,
          onChanged: (v) {
            controller.updateScene3DCamera(
                layer.id, (c) => c.copyWith(posY: c.posY.withBase(v)));
            onChanged();
          },
        ),
        _Num(
          label: 'Z',
          track: cam.posZ,
          min: -3000,
          max: 3000,
          onChanged: (v) {
            controller.updateScene3DCamera(
                layer.id, (c) => c.copyWith(posZ: c.posZ.withBase(v)));
            onChanged();
          },
        ),
        if (cam.kind == CameraKind.twoNode) ...[
          const SizedBox(height: 8),
          _SectionTitle('Ponto de interesse'),
          _Num(
            label: 'X',
            track: cam.poiX,
            min: -3000,
            max: 3000,
            onChanged: (v) {
              controller.updateScene3DCamera(
                  layer.id, (c) => c.copyWith(poiX: c.poiX.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Y',
            track: cam.poiY,
            min: -3000,
            max: 3000,
            onChanged: (v) {
              controller.updateScene3DCamera(
                  layer.id, (c) => c.copyWith(poiY: c.poiY.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Z',
            track: cam.poiZ,
            min: -3000,
            max: 3000,
            onChanged: (v) {
              controller.updateScene3DCamera(
                  layer.id, (c) => c.copyWith(poiZ: c.poiZ.withBase(v)));
              onChanged();
            },
          ),
        ] else ...[
          const SizedBox(height: 8),
          _SectionTitle('Orientacao (caminho curto)'),
          _Num(
            label: 'X',
            track: cam.orientX,
            min: -180,
            max: 180,
            suffix: '°',
            onChanged: (v) {
              controller.updateScene3DCamera(layer.id,
                  (c) => c.copyWith(orientX: c.orientX.withBase(v)));
              onChanged();
            },
          ),
          _Num(
            label: 'Y',
            track: cam.orientY,
            min: -180,
            max: 180,
            suffix: '°',
            onChanged: (v) {
              controller.updateScene3DCamera(layer.id,
                  (c) => c.copyWith(orientY: c.orientY.withBase(v)));
              onChanged();
            },
          ),
          _SectionTitle('Rotacao (aditiva, aceita varias voltas)'),
          _Num(
            label: 'Y',
            track: cam.rotY,
            min: -1080,
            max: 1080,
            suffix: '°',
            onChanged: (v) {
              controller.updateScene3DCamera(
                  layer.id, (c) => c.copyWith(rotY: c.rotY.withBase(v)));
              onChanged();
            },
          ),
        ],
        const SizedBox(height: 10),
        _Chips(
          label: 'Auto-orientar',
          options: const ['Desligado', 'Seguir caminho', 'Para o alvo'],
          index: cam.autoOrient.index,
          onChanged: (i) {
            controller.updateScene3DCamera(layer.id,
                (c) => c.copyWith(autoOrient: AutoOrient.values[i]));
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _SectionTitle('Rigs em um toque'),
        const _Hint(
            'Cada rig gera KEYFRAMES REAIS na camera, editaveis depois. '
            'Nenhum e caixa-preta.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rig in CameraRig.values)
              _Action(
                icon: switch (rig) {
                  CameraRig.orbit => CupertinoIcons.arrow_2_circlepath,
                  CameraRig.tripod => CupertinoIcons.arrow_left_right,
                  CameraRig.dolly => CupertinoIcons.arrow_up_right,
                  CameraRig.handheld => CupertinoIcons.hand_raised,
                  CameraRig.dollyZoom => CupertinoIcons.scope,
                },
                label: cameraRigLabel(rig),
                onTap: () {
                  controller.applyRigToScene(layer.id, rig);
                  onChanged();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionTitle('Comandos'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Action(
              icon: CupertinoIcons.fullscreen,
              label: 'Enquadrar tudo',
              onTap: () {
                controller.frameSceneAll(layer.id);
                onChanged();
              },
            ),
            _Action(
              icon: CupertinoIcons.camera_viewfinder,
              label: 'Alinhar a vista',
              onTap: () {
                controller.alignCameraToCurrentView(layer.id);
                onChanged();
              },
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- foco

class _DofTab extends StatelessWidget {
  const _DofTab({
    required this.layer,
    required this.controller,
    required this.onChanged,
  });

  final Scene3DLayer layer;
  final EditorController controller;
  final VoidCallback onChanged;

  void _dof(DepthOfField Function(DepthOfField) fn) {
    controller.updateScene3DCamera(
        layer.id, (c) => c.copyWith(dof: fn(c.dof)));
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = layer.camera.dof;
    final fStop =
        d.fStopFor(layer.camera.focalLength.base, Duration.zero);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Toggle(
          label: 'Profundidade de campo',
          value: d.enabled,
          onChanged: (v) => _dof((x) => x.copyWith(enabled: v)),
        ),
        const _Hint(
            'Usa a PROFUNDIDADE que a cena exporta — por isso o desfoque '
            'respeita a distancia real de cada objeto.'),
        _Num(
          label: 'Foco',
          track: d.focusDistance,
          min: 10,
          max: 5000,
          onChanged: (v) => _dof(
              (x) => x.copyWith(focusDistance: x.focusDistance.withBase(v))),
        ),
        _Toggle(
          label: 'Travar no zoom',
          value: d.lockToZoom,
          onChanged: (v) => _dof((x) => x.copyWith(lockToZoom: v)),
        ),
        _Num(
          label: 'Abertura',
          track: d.aperture,
          min: 1,
          max: 300,
          onChanged: (v) =>
              _dof((x) => x.copyWith(aperture: x.aperture.withBase(v))),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text('Diafragma f/${fStop.toStringAsFixed(1)}',
              style: const TextStyle(fontSize: 12, color: AmColors.muted)),
        ),
        _Num(
          label: 'Desfoque',
          track: d.blurLevel,
          min: 0,
          max: 200,
          suffix: '%',
          onChanged: (v) =>
              _dof((x) => x.copyWith(blurLevel: x.blurLevel.withBase(v))),
        ),
        const SizedBox(height: 10),
        _SectionTitle('Iris — a forma do bokeh'),
        _Chips(
          label: 'Formato',
          options: [for (final s in IrisShape.values) irisLabel(s)],
          index: d.irisShape.index,
          onChanged: (i) =>
              _dof((x) => x.copyWith(irisShape: IrisShape.values[i])),
        ),
        _Num(
          label: 'Girar iris',
          track: d.irisRotation,
          min: -180,
          max: 180,
          suffix: '°',
          onChanged: (v) => _dof(
              (x) => x.copyWith(irisRotation: x.irisRotation.withBase(v))),
        ),
        _Num(
          label: 'Arredondar',
          track: d.irisRoundness,
          min: -100,
          max: 100,
          onChanged: (v) => _dof(
              (x) => x.copyWith(irisRoundness: x.irisRoundness.withBase(v))),
        ),
        _Num(
          label: 'Proporcao',
          track: d.irisAspect,
          min: 0.3,
          max: 3,
          decimals: 2,
          onChanged: (v) =>
              _dof((x) => x.copyWith(irisAspect: x.irisAspect.withBase(v))),
        ),
        _Num(
          label: 'Franja',
          track: d.diffractionFringe,
          min: 0,
          max: 100,
          onChanged: (v) => _dof((x) =>
              x.copyWith(diffractionFringe: x.diffractionFringe.withBase(v))),
        ),
        const SizedBox(height: 10),
        _SectionTitle('Realce — o que separa lente de borrao'),
        const _Hint(
            'Sem ganho e limiar, luz fora de foco vira mancha cinza. Com '
            'eles, vira a bola brilhante que a gente reconhece como foto.'),
        _Num(
          label: 'Ganho',
          track: d.highlightGain,
          min: 0,
          max: 100,
          onChanged: (v) => _dof(
              (x) => x.copyWith(highlightGain: x.highlightGain.withBase(v))),
        ),
        _Num(
          label: 'Limiar',
          track: d.highlightThreshold,
          min: 0,
          max: 1,
          decimals: 2,
          onChanged: (v) => _dof((x) => x.copyWith(
              highlightThreshold: x.highlightThreshold.withBase(v))),
        ),
        _Num(
          label: 'Saturacao',
          track: d.highlightSaturation,
          min: 0,
          max: 2,
          decimals: 2,
          onChanged: (v) => _dof((x) => x.copyWith(
              highlightSaturation: x.highlightSaturation.withBase(v))),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- ajudas

class _HelpersTab extends StatelessWidget {
  const _HelpersTab({
    required this.layer,
    required this.controller,
    required this.onChanged,
  });

  final Scene3DLayer layer;
  final EditorController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = layer.scene;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Hint(
            'Nenhuma ajuda aparece na exportacao — grade, frustum, eixos e '
            'plano de foco existem so no preview.'),
        _Toggle(
          label: 'Ajudas de cena',
          value: layer.showHelpers,
          onChanged: (v) {
            controller.setScene3DHelpers(layer.id, v);
            onChanged();
          },
        ),
        _Toggle(
          label: 'Grade do chao',
          value: s.showFloorGrid,
          onChanged: (v) {
            controller.updateScene3D(
                layer.id, (x) => x.copyWith(showFloorGrid: v));
            onChanged();
          },
        ),
        _Toggle(
          label: 'Suavizacao (MSAA)',
          value: s.msaa,
          onChanged: (v) {
            controller.updateScene3D(layer.id, (x) => x.copyWith(msaa: v));
            onChanged();
          },
        ),
        _Toggle(
          label: 'Modo rascunho 3D',
          value: s.draftMode,
          onChanged: (v) {
            controller.updateScene3D(
                layer.id, (x) => x.copyWith(draftMode: v));
            onChanged();
          },
        ),
        const _Hint(
            'Rascunho desliga sombra, profundidade de campo e ambiente por '
            'imagem SO no preview. Liga sozinho durante o gesto no estudio.'),
        const SizedBox(height: 12),
        _SectionTitle('Vistas salvas'),
        if (s.savedViews.isEmpty)
          const _Hint('Nenhuma ainda. Salve enquadramentos no estudio.'),
        for (var i = 0; i < s.savedViews.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AmColors.chip,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Expanded(
                    child: Text(s.savedViews[i].name,
                        style: const TextStyle(
                            fontSize: 13, color: AmColors.text))),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(30, 30),
                  onPressed: () {
                    controller.applySavedView(layer.id, s.savedViews[i]);
                    onChanged();
                  },
                  child: const Icon(CupertinoIcons.camera_viewfinder,
                      size: 17, color: AmColors.accent),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(30, 30),
                  onPressed: () {
                    controller.removeSceneView(layer.id, i);
                    onChanged();
                  },
                  child: const Icon(CupertinoIcons.trash,
                      size: 15, color: AmColors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------- controles

class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onChanged(i),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: i == index ? AmColors.accentDim : AmColors.chip,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(labels[i],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: i == index ? FontWeight.w700 : FontWeight.w400,
                    color: i == index ? AmColors.accent : AmColors.muted)),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AmColors.text)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, height: 1.35, color: AmColors.muted)),
      );
}

/// Linha de parametro ANIMAVEL (tem base e keyframes).
class _Num extends StatelessWidget {
  const _Num({
    required this.label,
    required this.track,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
    this.suffix = '',
  });

  final String label;
  final AnimatedDouble track;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int decimals;
  final String suffix;

  @override
  Widget build(BuildContext context) => _Plain(
        label: label,
        value: track.base,
        min: min,
        max: max,
        decimals: decimals,
        suffix: suffix,
        animated: track.isAnimated,
        onChanged: onChanged,
      );
}

class _Plain extends StatelessWidget {
  const _Plain({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.decimals = 0,
    this.suffix = '',
    this.animated = false,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int decimals;
  final String suffix;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: animated ? AmColors.accent : AmColors.muted),
            ),
          ),
          Expanded(
            child: AmTickRuler(
              value: value,
              min: min,
              max: max,
              unitsPerPixel: (max - min) / 340,
              height: 40,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              '${value.toStringAsFixed(decimals)}$suffix',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AmColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.label,
    required this.options,
    required this.index,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 92,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AmColors.muted))),
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
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color:
                            i == index ? AmColors.accentDim : AmColors.chip,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(options[i],
                          style: const TextStyle(
                              fontSize: 11, color: AmColors.accent)),
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

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AmColors.text)),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AmColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AmColors.accent),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AmColors.accent)),
          ],
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.color, required this.onColor});

  final Color color;
  final ValueChanged<Color> onColor;

  static const _palette = <Color>[
    Color(0xFFB8FF3D),
    Color(0xFF7C62FF),
    Color(0xFF35C4E7),
    Color(0xFFFF6B6B),
    Color(0xFFFFB020),
    Color(0xFFE9EDF2),
    Color(0xFF2BE3A0),
    Color(0xFF8B94A3),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
              width: 92,
              child: Text('Cor',
                  style:
                      TextStyle(fontSize: 12, color: AmColors.muted))),
          // Espectro completo — qualquer cor, nao so a paleta.
          ColorWell(color: color, onChanged: onColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => onColor(c),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c.toARGB32() == color.toARGB32()
                              ? AmColors.text
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
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

/// SELO DISCRETO do orcamento (§10) — nunca um dialogo.
class _BudgetBadge extends StatelessWidget {
  const _BudgetBadge({required this.layer});

  final Scene3DLayer layer;

  @override
  Widget build(BuildContext context) {
    final frame = renderScene(
      layer.scene,
      layer.camera.renderAt(Duration.zero),
      const Size(1080, 1920),
      Duration.zero,
    );
    final over = frame.drawCalls > lowProfileBudget.maxDrawCalls ||
        frame.triangles > lowProfileBudget.maxTriangles;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: over ? const Color(0x33FF6B6B) : AmColors.chip,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '${frame.drawCalls} chamadas · ${frame.triangles} tri',
        style: TextStyle(
          fontSize: 10,
          color: over ? AmColors.pink : AmColors.muted,
        ),
      ),
    );
  }
}
