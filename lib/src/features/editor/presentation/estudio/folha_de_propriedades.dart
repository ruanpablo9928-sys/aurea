import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/scene3d.dart';
import 'estado_do_estudio.dart';
import 'folhas_do_estudio.dart';
import 'scene3d_theme.dart';

/// Abre a folha modal de Propriedades (Inspector - Tela 4 do mockup).
Future<void> abrirFolhaDePropriedadesNova(
  BuildContext context,
  WidgetRef ref, {
  required String layerId,
  required Duration tempo,
}) =>
    mostrarFolhaScene3D<void>(
      context,
      title: 'Propriedades',
      body: FolhaDePropriedades(layerId: layerId, tempo: tempo),
    );

class FolhaDePropriedades extends ConsumerStatefulWidget {
  const FolhaDePropriedades({
    super.key,
    required this.layerId,
    required this.tempo,
  });

  final String layerId;
  final Duration tempo;

  @override
  ConsumerState<FolhaDePropriedades> createState() => _FolhaDePropriedadesState();
}

class _FolhaDePropriedadesState extends ConsumerState<FolhaDePropriedades> {
  bool _transformacaoAberta = true;
  bool _materialAberto = true;
  bool _texturaAberta = true;
  bool _sombras = true;
  bool _renderizacao = true;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) return const SizedBox.shrink();
    final camada = bruta;
    final c = ref.read(editorControllerProvider.notifier);

    final noId = ref.watch(noSelecionadoProvider);
    final luzId = ref.watch(luzSelecionadaProvider);
    final camId = ref.watch(cameraSelecionadaProvider);

    final node = noId != null ? camada.scene.nodeById(noId) : null;
    final light = luzId != null ? camada.scene.lights.where((l) => l.id == luzId).firstOrNull : null;
    final camera = camId != null ? camada.allCameras.where((k) => k.id == camId).firstOrNull : null;

    final lightName = light != null
        ? switch (light.kind) {
            Light3DKind.directional => 'Luz Direcional',
            Light3DKind.point => 'Luz Pontual',
            Light3DKind.ambient => 'Luz Ambiente',
            Light3DKind.spot => 'Luz Spot',
          }
        : null;
    final nomeItem = node?.name ?? lightName ?? camera?.name ?? 'Casa Principal';
    final tipoItem = node != null
        ? (node.modelAsset != null ? 'Modelo 3D' : 'Objeto 3D')
        : (light != null ? 'Luz 3D' : (camera != null ? 'Câmera 3D' : 'Elemento 3D'));

    final posX = node?.x.base ?? light?.position.x ?? camera?.posX.base ?? 0.0;
    final posY = node?.y.base ?? light?.position.y ?? camera?.posY.base ?? 0.0;
    final posZ = node?.z.base ?? light?.position.z ?? camera?.posZ.base ?? 0.0;

    final rotX = node?.rotX.base ?? camera?.rotX.base ?? 0.0;
    final rotY = node?.rotY.base ?? camera?.rotY.base ?? 0.0;
    final rotZ = node?.rotZ.base ?? camera?.rotZ.base ?? 0.0;

    final escX = node?.scale.base ?? 1.0;
    final escY = node?.scale.base ?? 1.0;
    final escZ = node?.scale.base ?? 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card de Identificação do Item Selecionado
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 64,
            decoration: Scene3DTheme.cardDecoration(borderRadius: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF242C37),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Scene3DTheme.border),
                  ),
                  child: const Icon(
                    Icons.view_in_ar_rounded,
                    color: Scene3DTheme.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nomeItem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Scene3DTheme.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tipoItem,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Scene3DTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Seção Colapsável: Transformação
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(
                title: 'Transformação',
                isOpen: _transformacaoAberta,
                onToggle: () => setState(() => _transformacaoAberta = !_transformacaoAberta),
              ),
              if (_transformacaoAberta) ...[
                const SizedBox(height: 10),
                _buildTransformRow('Posição', posX, posY, posZ, (axis, val) {
                  if (node != null) {
                    c.updateSceneNode(widget.layerId, node.id, (n) {
                      if (axis == 'X') return n.copyWith(x: n.x.withBase(val));
                      if (axis == 'Y') return n.copyWith(y: n.y.withBase(val));
                      return n.copyWith(z: n.z.withBase(val));
                    });
                  } else if (camera != null) {
                    c.updateScene3DCamera(widget.layerId, (cam) {
                      if (axis == 'X') return cam.copyWith(posX: cam.posX.withBase(val));
                      if (axis == 'Y') return cam.copyWith(posY: cam.posY.withBase(val));
                      return cam.copyWith(posZ: cam.posZ.withBase(val));
                    });
                  } else if (light != null) {
                    c.updateSceneLight(widget.layerId, light.id, (l) {
                      final p = l.position;
                      return l.copyWith(
                        position: Vec3(
                          axis == 'X' ? val : p.x,
                          axis == 'Y' ? val : p.y,
                          axis == 'Z' ? val : p.z,
                        ),
                      );
                    });
                  }
                }),
                const SizedBox(height: 10),
                _buildTransformRow('Rotação', rotX, rotY, rotZ, (axis, val) {
                  if (node != null) {
                    c.updateSceneNode(widget.layerId, node.id, (n) {
                      if (axis == 'X') return n.copyWith(rotX: n.rotX.withBase(val));
                      if (axis == 'Y') return n.copyWith(rotY: n.rotY.withBase(val));
                      return n.copyWith(rotZ: n.rotZ.withBase(val));
                    });
                  } else if (camera != null) {
                    c.updateScene3DCamera(widget.layerId, (cam) {
                      if (axis == 'X') return cam.copyWith(rotX: cam.rotX.withBase(val));
                      if (axis == 'Y') return cam.copyWith(rotY: cam.rotY.withBase(val));
                      return cam.copyWith(rotZ: cam.rotZ.withBase(val));
                    });
                  }
                }),
                const SizedBox(height: 10),
                _buildTransformRow('Escala', escX, escY, escZ, (axis, val) {
                  if (node != null) {
                    c.updateSceneNode(widget.layerId, node.id, (n) {
                      return n.copyWith(scale: n.scale.withBase(val));
                    });
                  }
                }),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Seção Colapsável: Material
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(
                title: 'Material',
                isOpen: _materialAberto,
                onToggle: () => setState(() => _materialAberto = !_materialAberto),
              ),
              if (_materialAberto) ...[
                const SizedBox(height: 10),
                Container(
                  height: 52,
                  decoration: Scene3DTheme.cardDecoration(borderRadius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFFE2E8F0), Color(0xFF64748B), Color(0xFF1E293B)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Material Padrão',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Scene3DTheme.text,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Scene3DTheme.textSubtle, size: 20),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Seção Colapsável: Textura
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader(
                title: 'Textura',
                isOpen: _texturaAberta,
                onToggle: () => setState(() => _texturaAberta = !_texturaAberta),
              ),
              if (_texturaAberta) ...[
                const SizedBox(height: 10),
                Container(
                  height: 52,
                  decoration: Scene3DTheme.cardDecoration(borderRadius: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: const Color(0xFF263238),
                          border: Border.all(color: Scene3DTheme.border),
                        ),
                        child: const Icon(Icons.image_outlined, size: 18, color: Scene3DTheme.accent),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'BaseColor.png',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Scene3DTheme.text,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Scene3DTheme.textSubtle, size: 20),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Toggles de Sombras e Renderização
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildToggleRow(
                title: 'Sombras',
                value: _sombras,
                onChanged: (v) => setState(() => _sombras = v),
              ),
              const SizedBox(height: 10),
              _buildToggleRow(
                title: 'Renderização',
                value: _renderizacao,
                onChanged: (v) {
                  setState(() => _renderizacao = v);
                  if (node != null) {
                    c.setSceneNodeVisible(widget.layerId, node.id, v);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required bool isOpen,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
            color: Scene3DTheme.textMuted,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Scene3DTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransformRow(
    String label,
    double x,
    double y,
    double z,
    void Function(String axis, double val) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Scene3DTheme.textMuted,
            ),
          ),
        ),
        Expanded(child: _buildAxisField('X', x, (v) => onChanged('X', v))),
        const SizedBox(width: 6),
        Expanded(child: _buildAxisField('Y', y, (v) => onChanged('Y', v))),
        const SizedBox(width: 6),
        Expanded(child: _buildAxisField('Z', z, (v) => onChanged('Z', v))),
      ],
    );
  }

  Widget _buildAxisField(String axis, double val, ValueChanged<double> onChanged) {
    return Container(
      height: 38,
      decoration: Scene3DTheme.cardDecoration(borderRadius: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            axis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Scene3DTheme.textSubtle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              val.toStringAsFixed(3),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Scene3DTheme.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      height: 50,
      decoration: Scene3DTheme.cardDecoration(borderRadius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          const Icon(Icons.chevron_right_rounded, color: Scene3DTheme.textSubtle, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Scene3DTheme.text,
              ),
            ),
          ),
          Scene3DSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
