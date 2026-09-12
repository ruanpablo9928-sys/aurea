import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import 'estado_do_estudio.dart';
import 'folhas_do_estudio.dart';
import 'scene3d_theme.dart';

/// Abre a folha modal de Câmera (Tela 6 do mockup).
Future<void> abrirFolhaDeCameraNova(
  BuildContext context,
  WidgetRef ref, {
  required String layerId,
  required Duration tempo,
}) =>
    mostrarFolhaScene3D<void>(
      context,
      title: 'Câmera',
      body: FolhaDeCamera(layerId: layerId, tempo: tempo),
    );

class FolhaDeCamera extends ConsumerStatefulWidget {
  const FolhaDeCamera({
    super.key,
    required this.layerId,
    required this.tempo,
  });

  final String layerId;
  final Duration tempo;

  @override
  ConsumerState<FolhaDeCamera> createState() => _FolhaDeCameraState();
}

enum _ModoCamera { livre, orbita, fixa }

class _FolhaDeCameraState extends ConsumerState<FolhaDeCamera> {
  _ModoCamera _modo = _ModoCamera.livre;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) return const SizedBox.shrink();
    final camada = bruta;
    final c = ref.read(editorControllerProvider.notifier);
    final local = camada.localTime(widget.tempo);
    final cam = cameraNoAr(camada, local);

    final fov = cam.fovAt(local);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de Visualização da Câmera
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFF131821),
              border: Border.all(color: Scene3DTheme.border),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded, size: 36, color: Scene3DTheme.accent.withValues(alpha: 0.8)),
                      const SizedBox(height: 6),
                      Text(
                        cam.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Scene3DTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'FOV ${fov.round()}°',
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Pílulas de Modo: Livre, Órbita, Fixa
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildModePill('Livre', _ModoCamera.livre),
              const SizedBox(width: 8),
              _buildModePill('Órbita', _ModoCamera.orbita),
              const SizedBox(width: 8),
              _buildModePill('Fixa', _ModoCamera.fixa),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Posição: X, Y, Z com reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildVectorRow(
            label: 'Posição',
            x: cam.posX.base,
            y: cam.posY.base,
            z: cam.posZ.base,
            onReset: () {
              c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(
                posX: cm.posX.withBase(0.0),
                posY: cm.posY.withBase(0.0),
                posZ: cm.posZ.withBase(800.0),
              ));
            },
            onChangedX: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(posX: cm.posX.withBase(v))),
            onChangedY: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(posY: cm.posY.withBase(v))),
            onChangedZ: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(posZ: cm.posZ.withBase(v))),
          ),
        ),
        const SizedBox(height: 12),

        // Alvo (Target / LookAt): X, Y, Z com reset
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildVectorRow(
            label: 'Alvo',
            x: cam.poiX.base,
            y: cam.poiY.base,
            z: cam.poiZ.base,
            onReset: () {
              c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(
                poiX: cm.poiX.withBase(0.0),
                poiY: cm.poiY.withBase(0.0),
                poiZ: cm.poiZ.withBase(0.0),
              ));
            },
            onChangedX: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(poiX: cm.poiX.withBase(v))),
            onChangedY: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(poiY: cm.poiY.withBase(v))),
            onChangedZ: (v) => c.updateScene3DCamera(widget.layerId, (cm) => cm.copyWith(poiZ: cm.poiZ.withBase(v))),
          ),
        ),
        const SizedBox(height: 16),

        // Campo de visão (FOV)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Campo de visão (FOV)',
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
                      '${fov.round()}°',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Scene3DTheme.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Scene3DTheme.accent,
                  inactiveTrackColor: Scene3DTheme.border,
                  thumbColor: Scene3DTheme.accent,
                  overlayColor: Scene3DTheme.accent.withValues(alpha: 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: fov.clamp(10.0, 120.0),
                  min: 10.0,
                  max: 120.0,
                  onChanged: (v) {
                    c.updateScene3DCamera(widget.layerId, (cm) {
                      final fl = cm.filmWidth / (2 * math.tan(v * math.pi / 360));
                      return cm.copyWith(focalLength: cm.focalLength.withBase(fl));
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Botão Inferior: Redefinir
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Scene3DActionButton(
            label: 'Redefinir',
            icon: Icons.refresh_rounded,
            outlined: true,
            onPressed: () {
              c.updateScene3DCamera(widget.layerId, (cm) {
                final fl = cm.filmWidth / (2 * math.tan(45.0 * math.pi / 360));
                return cm.copyWith(
                  posX: cm.posX.withBase(0.0),
                  posY: cm.posY.withBase(0.0),
                  posZ: cm.posZ.withBase(800.0),
                  poiX: cm.poiX.withBase(0.0),
                  poiY: cm.poiY.withBase(0.0),
                  poiZ: cm.poiZ.withBase(0.0),
                  focalLength: cm.focalLength.withBase(fl),
                );
              });
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildModePill(String label, _ModoCamera modo) {
    final active = _modo == modo;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _modo = modo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          decoration: Scene3DTheme.pillDecoration(active: active),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Scene3DTheme.onAccent : Scene3DTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVectorRow({
    required String label,
    required double x,
    required double y,
    required double z,
    required VoidCallback onReset,
    required ValueChanged<double> onChangedX,
    required ValueChanged<double> onChangedY,
    required ValueChanged<double> onChangedZ,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Scene3DTheme.text,
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onReset,
              child: const Icon(Icons.sync_rounded, color: Scene3DTheme.textMuted, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildNumberInput('X', x, onChangedX)),
            const SizedBox(width: 8),
            Expanded(child: _buildNumberInput('Y', y, onChangedY)),
            const SizedBox(width: 8),
            Expanded(child: _buildNumberInput('Z', z, onChangedZ)),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberInput(String axis, double val, ValueChanged<double> onChanged) {
    return Container(
      height: 40,
      decoration: Scene3DTheme.cardDecoration(borderRadius: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Text(
            axis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Scene3DTheme.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              val.toStringAsFixed(2),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Scene3DTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
