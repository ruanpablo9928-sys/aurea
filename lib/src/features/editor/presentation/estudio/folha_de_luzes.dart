import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/scene3d.dart';
import '../am/color_picker_sheet.dart';
import 'folhas_do_estudio.dart';
import 'scene3d_theme.dart';

/// Abre a folha modal de Luzes (Tela 7 do mockup).
Future<void> abrirFolhaDeLuzes(
  BuildContext context,
  WidgetRef ref, {
  required String layerId,
}) =>
    mostrarFolhaScene3D<void>(
      context,
      title: 'Luzes',
      body: FolhaDeLuzes(layerId: layerId),
    );

class FolhaDeLuzes extends ConsumerStatefulWidget {
  const FolhaDeLuzes({super.key, required this.layerId});

  final String layerId;

  @override
  ConsumerState<FolhaDeLuzes> createState() => _FolhaDeLuzesState();
}

class _FolhaDeLuzesState extends ConsumerState<FolhaDeLuzes> {
  int _luzSelecionadaIndex = 0;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) return const SizedBox.shrink();
    final camada = bruta;
    final c = ref.read(editorControllerProvider.notifier);
    final lights = camada.scene.lights;

    // Garante que existam as luzes padrão caso a cena não tenha
    final dirLight = lights.where((l) => l.kind == Light3DKind.directional).firstOrNull;
    final pointLight = lights.where((l) => l.kind == Light3DKind.point).firstOrNull;
    final ambientLight = lights.where((l) => l.kind == Light3DKind.ambient).firstOrNull;

    final activeLight = lights.isNotEmpty
        ? lights[_luzSelecionadaIndex.clamp(0, lights.length - 1)]
        : null;

    final double intensidade = activeLight?.intensity.base ?? 1.0;
    final cor = activeLight?.color ?? Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Lista de Tipos de Luz com Switches
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildLightSwitchRow(
                icon: Icons.wb_sunny_rounded,
                title: 'Luz Direcional',
                isOn: dirLight != null && dirLight.intensity.base > 0,
                isSelected: activeLight?.kind == Light3DKind.directional,
                onSelect: () {
                  if (dirLight != null) {
                    setState(() => _luzSelecionadaIndex = lights.indexOf(dirLight));
                  }
                },
                onToggle: (v) {
                  if (dirLight != null) {
                    c.updateSceneLight(
                      widget.layerId,
                      dirLight.id,
                      (l) => l.copyWith(
                        intensity: l.intensity.withBase(v ? 1.0 : 0.0),
                      ),
                    );
                  } else if (v) {
                    c.addSceneLight(widget.layerId, Light3DKind.directional);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildLightSwitchRow(
                icon: Icons.lightbulb_rounded,
                title: 'Luz Pontual',
                isOn: pointLight != null && pointLight.intensity.base > 0,
                isSelected: activeLight?.kind == Light3DKind.point,
                onSelect: () {
                  if (pointLight != null) {
                    setState(() => _luzSelecionadaIndex = lights.indexOf(pointLight));
                  }
                },
                onToggle: (v) {
                  if (pointLight != null) {
                    c.updateSceneLight(
                      widget.layerId,
                      pointLight.id,
                      (l) => l.copyWith(
                        intensity: l.intensity.withBase(v ? 1.0 : 0.0),
                      ),
                    );
                  } else if (v) {
                    c.addSceneLight(widget.layerId, Light3DKind.point);
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildLightSwitchRow(
                icon: Icons.public_rounded,
                title: 'Luz Ambiente',
                isOn: (ambientLight != null && ambientLight.intensity.base > 0) || camada.scene.ambient > 0,
                isSelected: activeLight?.kind == Light3DKind.ambient,
                onSelect: () {
                  if (ambientLight != null) {
                    setState(() => _luzSelecionadaIndex = lights.indexOf(ambientLight));
                  }
                },
                onToggle: (v) {
                  if (ambientLight != null) {
                    c.updateSceneLight(
                      widget.layerId,
                      ambientLight.id,
                      (l) => l.copyWith(
                        intensity: l.intensity.withBase(v ? 1.0 : 0.0),
                      ),
                    );
                  } else {
                    c.setSceneAmbient(widget.layerId, v ? 0.6 : 0.0);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Propriedades da Luz Selecionada
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cor
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cor',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Scene3DTheme.text,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (activeLight != null) {
                        showColorPicker(
                          context,
                          initial: cor,
                          withAlpha: false,
                          onChanged: (newCor) {
                            c.updateSceneLight(
                              widget.layerId,
                              activeLight.id,
                              (l) => l.copyWith(color: newCor),
                            );
                          },
                        );
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Scene3DTheme.border, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Intensidade
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Intensidade',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Scene3DTheme.text,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Scene3DTheme.panelElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Scene3DTheme.border),
                    ),
                    child: Text(
                      intensidade.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Scene3DTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Scene3DTheme.accent,
                  inactiveTrackColor: Scene3DTheme.border,
                  thumbColor: Scene3DTheme.accent,
                  overlayColor: Scene3DTheme.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: intensidade.clamp(0.0, 3.0),
                  min: 0.0,
                  max: 3.0,
                  onChanged: (v) {
                    if (activeLight != null) {
                      c.updateSceneLight(
                        widget.layerId,
                        activeLight.id,
                        (l) => l.copyWith(
                          intensity: l.intensity.withBase(v),
                        ),
                      );
                    } else {
                      c.setSceneAmbient(widget.layerId, v);
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Ângulo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ângulo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Scene3DTheme.text,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Scene3DTheme.panelElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Scene3DTheme.border),
                    ),
                    child: const Text(
                      '45°',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Scene3DTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Scene3DTheme.accent,
                  inactiveTrackColor: Scene3DTheme.border,
                  thumbColor: Scene3DTheme.accent,
                  overlayColor: Scene3DTheme.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: 45.0,
                  min: 0.0,
                  max: 90.0,
                  onChanged: (v) {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Botão de Ação Inferior: Redefinir
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Scene3DActionButton(
            label: 'Redefinir',
            icon: Icons.refresh_rounded,
            outlined: true,
            onPressed: () {
              if (activeLight != null) {
                c.updateSceneLight(
                  widget.layerId,
                  activeLight.id,
                  (l) => l.copyWith(
                    intensity: l.intensity.withBase(1.0),
                    color: Colors.white,
                  ),
                );
              }
              c.setSceneAmbient(widget.layerId, 0.4);
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildLightSwitchRow({
    required IconData icon,
    required String title,
    required bool isOn,
    required bool isSelected,
    required VoidCallback onSelect,
    required ValueChanged<bool> onToggle,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      child: Container(
        height: 52,
        decoration: Scene3DTheme.cardDecoration(
          borderRadius: 14,
          isSelected: isSelected,
          color: isSelected ? const Color(0xFF162520) : Scene3DTheme.panelElevated,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Scene3DTheme.accent : Scene3DTheme.textMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Scene3DTheme.accent : Scene3DTheme.text,
                ),
              ),
            ),
            Scene3DSwitch(
              value: isOn,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}
