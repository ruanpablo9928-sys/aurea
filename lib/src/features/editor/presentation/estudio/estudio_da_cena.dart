import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/camera3d.dart';
import '../../domain/estudio_ux.dart';
import '../../domain/layer.dart';
import 'estado_do_estudio.dart';
import 'ficha_do_selecionado.dart';
import 'folhas_do_estudio.dart';
import 'gizmo_de_vista.dart';
import 'scene3d_theme.dart';
import 'vista_da_cena.dart';

/// Abre o Estudio da Cena 3D por cima do editor.
Future<void> abrirEstudioDaCena(
  BuildContext context, {
  required String layerId,
  required PlaybackController playback,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EstudioDaCena(layerId: layerId, playback: playback),
      ),
    );

/// O ESTÚDIO DA CENA 3D (Tela 1 do mockup).
class EstudioDaCena extends ConsumerStatefulWidget {
  const EstudioDaCena({
    super.key,
    required this.layerId,
    required this.playback,
  });

  final String layerId;
  final PlaybackController playback;

  @override
  ConsumerState<EstudioDaCena> createState() => _EstudioDaCenaState();
}

class _EstudioDaCenaState extends ConsumerState<EstudioDaCena> {
  final _navegacao = NavegacaoDaVista();
  final _vista = GlobalKey<VistaDaCenaState>();

  @override
  void initState() {
    super.initState();
    widget.playback.pause();
  }

  @override
  void dispose() {
    _navegacao.dispose();
    super.dispose();
  }

  void _dizer(String texto) =>
      ref.read(recadoDoEstudioProvider.notifier).state = texto;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: Scene3DTheme.bg, body: SizedBox());
    }
    final camada = bruta;

    return Scaffold(
      backgroundColor: Scene3DTheme.bg,
      body: SafeArea(
        child: ValueListenableBuilder<Duration>(
          valueListenable: widget.playback.time,
          builder: (context, tempo, _) {
            final local = camada.localTime(tempo);
            return Column(
              children: [
                // Barra Superior: < Scene 3D | [Exportar]
                _BarraSuperiorScene3D(
                  camada: camada,
                  local: local,
                  navegacao: _navegacao,
                  playback: widget.playback,
                  aoVoltar: () => Navigator.of(context).maybePop(),
                  aoExportar: () => abrirFolhaDeExportar(
                    context,
                    ref,
                    layerId: widget.layerId,
                  ),
                ),

                // Viewport 3D com Overlays Flutuantes
                Expanded(
                  child: Stack(
                    children: [
                      // Renderizador e Interação 3D
                      Positioned.fill(
                        child: VistaDaCena(
                          key: _vista,
                          layerId: widget.layerId,
                          navegacao: _navegacao,
                          tempo: tempo,
                          aoTocarVazio: () {},
                        ),
                      ),

                      // Barra Lateral Flutuante Esquerda (8 Ferramentas)
                      Positioned(
                        left: 12,
                        top: 14,
                        child: _BarraLateralFlutuante(
                          layerId: widget.layerId,
                          tempo: tempo,
                          navegacao: _navegacao,
                          aoFocar: () => _vista.currentState?.focar(),
                          aoAvisar: _dizer,
                        ),
                      ),

                      // Cubo de Orientação de Vista (Top-Right)
                      Positioned(
                        right: 12,
                        top: 14,
                        child: GizmoDeVista(
                          navegacao: _navegacao,
                          camera: cameraNoAr(camada, local),
                          tempo: local,
                        ),
                      ),

                      // Gizmo 3D de Eixos (Bottom-Left)
                      const Positioned(
                        left: 14,
                        bottom: 14,
                        child: _Gizmo3DEixos(),
                      ),

                      // Pílula Indicadora de Projeção / Perspectiva (Bottom-Right)
                      Positioned(
                        right: 14,
                        bottom: 14,
                        child: _BadgePerspectiva(
                          navegacao: _navegacao,
                          camera: cameraNoAr(camada, local),
                          tempo: local,
                        ),
                      ),

                      // Recado de Feedback Rápido
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: _RecadoScene3D(),
                      ),
                    ],
                  ),
                ),

                // Barra de Scrub / Transporte com Linha de Tempo
                _FaixaDeTempoScene3D(
                  playback: widget.playback,
                  camada: camada,
                ),

                // Barra Inferior de Navegação (4 Abas)
                _BarraInferiorScene3D(
                  layerId: widget.layerId,
                  tempo: tempo,
                  navegacao: _navegacao,
                  playback: widget.playback,
                  aoAvisar: _dizer,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Barra Superior Moderna: `< Scene 3D` com botão pílula verde `[Exportar]`
class _BarraSuperiorScene3D extends ConsumerWidget {
  const _BarraSuperiorScene3D({
    required this.camada,
    required this.local,
    required this.navegacao,
    required this.playback,
    required this.aoVoltar,
    required this.aoExportar,
  });

  final Scene3DLayer camada;
  final Duration local;
  final NavegacaoDaVista navegacao;
  final PlaybackController playback;
  final VoidCallback aoVoltar;
  final VoidCallback aoExportar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Scene3DTheme.panel,
        border: Border(bottom: BorderSide(color: Scene3DTheme.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Botão Voltar com Ícone e Título
          GestureDetector(
            key: const ValueKey('estudio-voltar'),
            behavior: HitTestBehavior.opaque,
            onTap: aoVoltar,
            child: const Row(
              children: [
                Icon(Icons.chevron_left_rounded, color: Scene3DTheme.text, size: 28),
                SizedBox(width: 4),
                Text(
                  'Scene 3D',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Scene3DTheme.text,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Botão Pílula Verde Neon: [Exportar]
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoExportar,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Scene3DTheme.accent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Row(
                children: [
                  Icon(Icons.file_upload_outlined, color: Scene3DTheme.onAccent, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Exportar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Scene3DTheme.onAccent,
                    ),
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

/// Barra Lateral Flutuante com 8 Ferramentas Essenciais
class _BarraLateralFlutuante extends ConsumerWidget {
  const _BarraLateralFlutuante({
    required this.layerId,
    required this.tempo,
    required this.navegacao,
    required this.aoFocar,
    required this.aoAvisar,
  });

  final String layerId;
  final Duration tempo;
  final NavegacaoDaVista navegacao;
  final VoidCallback aoFocar;
  final void Function(String) aoAvisar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ferramentaAtual = ref.watch(ferramentaProvider);

    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Scene3DTheme.panel.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Scene3DTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Selecionar
          _buildToolButton(
            icon: Icons.near_me_rounded,
            isSelected: ferramentaAtual == FerramentaDoEstudio.selecionar,
            semanticLabel: 'Selecionar',
            onTap: () => ref.read(ferramentaProvider.notifier).state = FerramentaDoEstudio.selecionar,
          ),
          const SizedBox(height: 4),

          // 2. Mover
          _buildToolButton(
            icon: Icons.open_with_rounded,
            isSelected: ferramentaAtual == FerramentaDoEstudio.mover,
            semanticLabel: 'Mover',
            onTap: () => ref.read(ferramentaProvider.notifier).state = FerramentaDoEstudio.mover,
          ),
          const SizedBox(height: 4),

          // 3. Girar
          _buildToolButton(
            icon: Icons.rotate_right_rounded,
            isSelected: ferramentaAtual == FerramentaDoEstudio.girar,
            semanticLabel: 'Girar',
            onTap: () => ref.read(ferramentaProvider.notifier).state = FerramentaDoEstudio.girar,
          ),
          const SizedBox(height: 4),

          // 4. Escalar
          _buildToolButton(
            icon: Icons.aspect_ratio_rounded,
            isSelected: ferramentaAtual == FerramentaDoEstudio.escalar,
            semanticLabel: 'Escalar',
            onTap: () => ref.read(ferramentaProvider.notifier).state = FerramentaDoEstudio.escalar,
          ),
          const SizedBox(height: 4),

          // 5. Camadas / Malhas
          _buildToolButton(
            icon: Icons.layers_rounded,
            isSelected: false,
            semanticLabel: 'Camadas',
            onTap: () => abrirFolhaDaCena(context, ref, layerId: layerId, tempo: tempo),
          ),
          const SizedBox(height: 4),

          // 6. Material / Shaders
          _buildToolButton(
            icon: Icons.palette_outlined,
            isSelected: false,
            semanticLabel: 'Material',
            onTap: () => abrirFichaDoSelecionado(context, ref, layerId: layerId, tempo: tempo),
          ),
          const SizedBox(height: 4),

          // 7. Grade / Snapping
          _buildToolButton(
            icon: Icons.grid_4x4_rounded,
            isSelected: false,
            semanticLabel: 'Grade',
            onTap: () {
              final c = ref.read(editorControllerProvider.notifier);
              final camada = ref.read(editorControllerProvider).layerById(layerId);
              if (camada is Scene3DLayer) {
                c.setSceneFloorGrid(layerId, !camada.scene.showFloorGrid);
                aoAvisar(camada.scene.showFloorGrid ? 'Grade desativada.' : 'Grade ativada.');
              }
            },
          ),
          const SizedBox(height: 4),

          // 8. Foco / Enquadrar
          _buildToolButton(
            key: const ValueKey('estudio-focar'),
            icon: Icons.center_focus_strong_rounded,
            isSelected: false,
            semanticLabel: 'Focar',
            onTap: aoFocar,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    Key? key,
    required IconData icon,
    required bool isSelected,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      key: key,
      container: true,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? Scene3DTheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            icon,
            size: 19,
            color: isSelected ? Scene3DTheme.onAccent : Scene3DTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Gizmo 3D de Eixos (X vermelho, Y verde, Z azul) no canto inferior esquerdo
class _Gizmo3DEixos extends StatelessWidget {
  const _Gizmo3DEixos();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Scene3DTheme.panel.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Scene3DTheme.border),
      ),
      child: CustomPaint(
        painter: _GizmoEixosPainter(),
      ),
    );
  }
}

class _GizmoEixosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.35;
    final cy = size.height * 0.65;

    void drawAxis(Offset end, Color color, String label) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(cx, cy), end, paint);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(end.dx - 2, end.dy - 6));
    }

    // Eixo Y (verde, para cima)
    drawAxis(Offset(cx, cy - 20), Scene3DTheme.axisY, 'Y');
    // Eixo X (vermelho, para a direita)
    drawAxis(Offset(cx + 20, cy), Scene3DTheme.axisX, 'X');
    // Eixo Z (azul, diagonal perspectiva)
    drawAxis(Offset(cx - 12, cy + 12), Scene3DTheme.axisZ, 'Z');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pílula Indicadora de Projeção / Perspectiva
class _BadgePerspectiva extends StatelessWidget {
  const _BadgePerspectiva({
    required this.navegacao,
    required this.camera,
    required this.tempo,
  });

  final NavegacaoDaVista navegacao;
  final Camera3D camera;
  final Duration tempo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // Alterna entre perspectiva e vistas ortográficas
        final prox = switch (navegacao.vista) {
          SceneView.camera => SceneView.top,
          SceneView.top => SceneView.front,
          SceneView.front => SceneView.right,
          _ => SceneView.camera,
        };
        navegacao.verVista(prox, camera: camera, tempo: tempo);
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Scene3DTheme.panelElevated.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Scene3DTheme.border),
        ),
        child: Center(
          child: Text(
            navegacao.pelaCamera ? 'Perspectiva' : sceneViewLabel(navegacao.vista),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Scene3DTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de Transporte e Scrubbing com Marcador de Tempo
class _FaixaDeTempoScene3D extends ConsumerWidget {
  const _FaixaDeTempoScene3D({
    required this.playback,
    required this.camada,
  });

  final PlaybackController playback;
  final Scene3DLayer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dur = camada.duration.inMicroseconds.toDouble();
    final tempoAtual = playback.time.value;
    final local = camada.localTime(tempoAtual).inMicroseconds.toDouble();
    final fracao = dur > 0 ? (local / dur).clamp(0.0, 1.0) : 0.0;

    final segDecorridos = (local / 1e6).floor();
    final segTotal = dur > 0 ? (dur / 1e6).floor() : 10;
    final textoTempo =
        '00:${segDecorridos.toString().padLeft(2, '0')} / 00:${segTotal.toString().padLeft(2, '0')}';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Scene3DTheme.panel,
        border: Border(top: BorderSide(color: Scene3DTheme.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Botão Play / Pause
          ValueListenableBuilder<bool>(
            valueListenable: PlaybackController.tocandoAgora,
            builder: (_, tocando, _) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (tocando) {
                    playback.pause();
                  } else {
                    playback.play();
                  }
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Scene3DTheme.panelElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tocando ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),

          // Barra Slider Interativa de Scrub
          Expanded(
            child: Semantics(
              key: const ValueKey('scene-motion-time'),
              slider: true,
              value: textoTempo,
              child: LayoutBuilder(
                builder: (context, c) {
                  void irPara(double dx) {
                    final f = (dx / c.maxWidth).clamp(0.0, 1.0);
                    playback.seek(
                      camada.startTime + Duration(microseconds: (f * dur).round()),
                    );
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => irPara(d.localPosition.dx),
                    onHorizontalDragUpdate: (d) => irPara(d.localPosition.dx),
                    child: CustomPaint(
                      painter: _PinturaDoScrub(fracao: fracao),
                      child: const SizedBox(height: 24, width: double.infinity),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Texto de Tempo: 00:00 / 00:10
          Text(
            textoTempo,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Scene3DTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinturaDoScrub extends CustomPainter {
  const _PinturaDoScrub({required this.fracao});
  final double fracao;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    // Trilha inativa
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = Scene3DTheme.border
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Trilha ativa em verde neon
    final progX = fracao * size.width;
    canvas.drawLine(
      Offset(0, y),
      Offset(progX, y),
      Paint()
        ..color = Scene3DTheme.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Cabeçote circular verde
    canvas.drawCircle(
      Offset(progX, y),
      5,
      Paint()..color = Scene3DTheme.accent,
    );
  }

  @override
  bool shouldRepaint(_PinturaDoScrub old) => old.fracao != fracao;
}

/// Barra Inferior de Navegação do Scene 3D (4 Abas)
class _BarraInferiorScene3D extends StatelessWidget {
  const _BarraInferiorScene3D({
    required this.layerId,
    required this.tempo,
    required this.navegacao,
    required this.playback,
    required this.aoAvisar,
  });

  final String layerId;
  final Duration tempo;
  final NavegacaoDaVista navegacao;
  final PlaybackController playback;
  final void Function(String) aoAvisar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: const BoxDecoration(
        color: Scene3DTheme.panel,
        border: Border(top: BorderSide(color: Scene3DTheme.border, width: 0.8)),
      ),
      child: Consumer(
        builder: (context, ref, _) {
          return Row(
            children: [
              // Aba 1: Câmera (Tela 6)
              _buildNavTab(
                key: const ValueKey('estudio-camera'),
                icon: Icons.videocam_outlined,
                label: 'Câmera',
                onTap: () => abrirFolhaDeCameras(
                  context,
                  ref,
                  layerId: layerId,
                  navegacao: navegacao,
                  tempo: tempo,
                ),
              ),

              // Aba 2: Objetos (Tela 2)
              _buildNavTab(
                key: const ValueKey('estudio-cena'),
                icon: Icons.view_in_ar_outlined,
                label: 'Objetos',
                onTap: () => abrirFolhaDaCena(
                  context,
                  ref,
                  layerId: layerId,
                  tempo: tempo,
                ),
              ),

              // Aba 3: Animação (Tela 3)
              _buildNavTab(
                icon: Icons.auto_graph_outlined,
                label: 'Animação',
                onTap: () => abrirFolhaDeAnimacao(
                  context,
                  ref,
                  layerId: layerId,
                  playback: playback,
                ),
              ),

              // Aba 4: Cena / Luzes (Tela 7)
              _buildNavTab(
                key: const ValueKey('estudio-mais'),
                icon: Icons.tune_rounded,
                label: 'Cena',
                onTap: () => abrirFolhaDeLuzes(
                  context,
                  ref,
                  layerId: layerId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavTab({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: Scene3DTheme.text),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Scene3DTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recado Flutuante de Feedback
class _RecadoScene3D extends ConsumerWidget {
  const _RecadoScene3D();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = ref.watch(recadoDoEstudioProvider);
    if (texto == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Scene3DTheme.panelElevated.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Scene3DTheme.border),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 12, color: Scene3DTheme.text),
        ),
      ),
    );
  }
}
