import 'dart:math' as math;
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'estado_do_estudio.dart';
import 'folhas_do_estudio.dart';
import 'scene3d_theme.dart';

/// Abre a folha modal de Animação com curvas Bézier e keyframes (Tela 3 do mockup).
Future<void> abrirFolhaDeAnimacao(
  BuildContext context,
  WidgetRef ref, {
  required String layerId,
  required PlaybackController playback,
}) =>
    mostrarFolhaScene3D<void>(
      context,
      title: 'Animação',
      body: FolhaDeAnimacao(layerId: layerId, playback: playback),
    );

class FolhaDeAnimacao extends ConsumerStatefulWidget {
  const FolhaDeAnimacao({
    super.key,
    required this.layerId,
    required this.playback,
  });

  final String layerId;
  final PlaybackController playback;

  @override
  ConsumerState<FolhaDeAnimacao> createState() => _FolhaDeAnimacaoState();
}

enum _ModoPropriedade { posicao, rotacao, escala }

class _FolhaDeAnimacaoState extends ConsumerState<FolhaDeAnimacao> {
  _ModoPropriedade _modo = _ModoPropriedade.posicao;
  bool _mostrarX = true;
  bool _mostrarY = true;
  bool _mostrarZ = true;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final camada = projeto.layerById(widget.layerId);
    if (camada is! Scene3DLayer) return const SizedBox.shrink();

    final noSelecionadoId = ref.watch(noSelecionadoProvider);
    final no = noSelecionadoId != null ? camada.scene.nodeById(noSelecionadoId) : null;
    final camera = camada.camera;

    final alvoNome = no != null ? no.name : camera.name;
    final isCamera = no == null;

    final duracaoTotal = camada.duration.inMicroseconds > 0
        ? camada.duration.inMicroseconds / 1e6
        : 10.0;
    final tempoLocal = camada.localTime(widget.playback.time.value).inMicroseconds / 1e6;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Seletor do elemento alvo
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: Scene3DTheme.cardDecoration(borderRadius: 14),
          child: Row(
            children: [
              Icon(
                isCamera ? Icons.videocam_rounded : Icons.view_in_ar_rounded,
                color: Scene3DTheme.accent,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                alvoNome,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Scene3DTheme.text,
                ),
              ),
              const Spacer(),
              const Icon(Icons.expand_more_rounded, color: Scene3DTheme.textMuted, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Abas de Modo: Posição, Rotação, Escala
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildPillTab('Posição', _ModoPropriedade.posicao),
              const SizedBox(width: 8),
              _buildPillTab('Rotação', _ModoPropriedade.rotacao),
              const SizedBox(width: 8),
              _buildPillTab('Escala', _ModoPropriedade.escala),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Gráfico de Curvas Bézier Interativo
        Container(
          height: 160,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: Scene3DTheme.cardDecoration(
            color: const Color(0xFF11161D),
            borderRadius: 14,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CustomPaint(
              painter: _GraficoDeCurvasPainter(
                modo: _modo,
                mostrarX: _mostrarX,
                mostrarY: _mostrarY,
                mostrarZ: _mostrarZ,
                tempoAtual: tempoLocal,
                duracao: duracaoTotal,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Lista de Canais (Posição X, Y, Z com cores características)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _buildChannelRow(
                cor: Scene3DTheme.axisY, // Verde X
                rotulo: switch (_modo) {
                  _ModoPropriedade.posicao => 'Posição X',
                  _ModoPropriedade.rotacao => 'Rotação X',
                  _ModoPropriedade.escala => 'Escala X',
                },
                visivel: _mostrarX,
                onToggle: () => setState(() => _mostrarX = !_mostrarX),
              ),
              const Divider(color: Scene3DTheme.border, height: 12),
              _buildChannelRow(
                cor: Scene3DTheme.axisZ, // Azul Y
                rotulo: switch (_modo) {
                  _ModoPropriedade.posicao => 'Posição Y',
                  _ModoPropriedade.rotacao => 'Rotação Y',
                  _ModoPropriedade.escala => 'Escala Y',
                },
                visivel: _mostrarY,
                onToggle: () => setState(() => _mostrarY = !_mostrarY),
              ),
              const Divider(color: Scene3DTheme.border, height: 12),
              _buildChannelRow(
                cor: Scene3DTheme.axisX, // Vermelho Z
                rotulo: switch (_modo) {
                  _ModoPropriedade.posicao => 'Posição Z',
                  _ModoPropriedade.rotacao => 'Rotação Z',
                  _ModoPropriedade.escala => 'Escala Z',
                },
                visivel: _mostrarZ,
                onToggle: () => setState(() => _mostrarZ = !_mostrarZ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Ações Inferiores: + Adicionar, Ajustar, Excluir
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_rounded,
                  label: 'Adicionar',
                  onTap: () {
                    // Adiciona marcação de keyframe no tempo atual
                    final controller = ref.read(editorControllerProvider.notifier);
                    final tempo = widget.playback.time.value;
                    if (no != null) {
                      final prop = switch (_modo) {
                        _ModoPropriedade.posicao => PropDoNo.x,
                        _ModoPropriedade.rotacao => PropDoNo.giroX,
                        _ModoPropriedade.escala => PropDoNo.escala,
                      };
                      controller.toggleSceneNodeKeyframe(widget.layerId, no.id, prop, tempo);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.auto_graph_rounded,
                  label: 'Ajustar',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Excluir',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPillTab(String label, _ModoPropriedade modo) {
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

  Widget _buildChannelRow({
    required Color cor,
    required String rotulo,
    required bool visivel,
    required VoidCallback onToggle,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
        ),
        const SizedBox(width: 10),
        Text(
          rotulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Scene3DTheme.text,
          ),
        ),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(
              visivel ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: visivel ? Scene3DTheme.textMuted : Scene3DTheme.textSubtle,
              size: 20,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Scene3DTheme.textSubtle, size: 20),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: Scene3DTheme.cardDecoration(borderRadius: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: Scene3DTheme.text),
            const SizedBox(height: 2),
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

/// CustomPainter para desenhar as curvas Bézier e a grade de tempo
class _GraficoDeCurvasPainter extends CustomPainter {
  const _GraficoDeCurvasPainter({
    required this._modo,
    required this.mostrarX,
    required this.mostrarY,
    required this.mostrarZ,
    required this.tempoAtual,
    required this.duracao,
  });

  final _ModoPropriedade _modo;
  final bool mostrarX;
  final bool mostrarY;
  final bool mostrarZ;
  final double tempoAtual;
  final double duracao;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fundo da grade com linhas horizontais e verticais
    final gridPaint = Paint()
      ..color = Scene3DTheme.border.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    final centerY = h * 0.5;
    canvas.drawLine(Offset(0, centerY), Offset(w, centerY), gridPaint);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), gridPaint);
    canvas.drawLine(Offset(0, h * 0.8), Offset(w, h * 0.8), gridPaint);

    // Linhas verticais de tempo (0s, 2s, 4s, 6s, 8s, 10s)
    const passos = 5;
    for (var i = 0; i <= passos; i++) {
      final x = (w / passos) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // Textos de régua de tempo
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    void desenharRotulo(String texto, Offset offset) {
      textPainter.text = TextSpan(
        text: texto,
        style: const TextStyle(color: Scene3DTheme.textSubtle, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset);
    }

    desenharRotulo('1.0', const Offset(4, 4));
    desenharRotulo('0.0', Offset(4, centerY - 10));
    desenharRotulo('-1.0', Offset(4, h - 14));

    for (var i = 0; i <= passos; i++) {
      final seg = ((duracao / passos) * i).toStringAsFixed(0);
      desenharRotulo('${seg}s', Offset((w / passos) * i - 8, 4));
    }

    // Desenha as 3 curvas suaves (Verde X, Azul Y, Vermelho Z)
    void desenharCurva(Color cor, double fase, double amplitude) {
      final path = Path();
      final points = <Offset>[];
      for (var x = 0.0; x <= w; x += 3.0) {
        final f = x / w;
        final y = centerY - math.sin(f * math.pi * 2 + fase) * (h * 0.3 * amplitude);
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        if ((x % (w / 4)).abs() < 2.0) {
          points.add(Offset(x, y));
        }
      }

      final curvePaint = Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawPath(path, curvePaint);

      // Pontos de keyframe na curva
      final dotPaint = Paint()..color = cor;
      final dotBorder = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (final p in points) {
        canvas.drawCircle(p, 4.0, dotPaint);
        canvas.drawCircle(p, 4.0, dotBorder);
      }
    }

    if (mostrarX) desenharCurva(Scene3DTheme.axisY, 0.0, 0.8); // Verde
    if (mostrarY) desenharCurva(Scene3DTheme.axisZ, 1.2, 0.6); // Azul
    if (mostrarZ) desenharCurva(Scene3DTheme.axisX, 2.5, 0.7); // Vermelho

    // Linha de cabeçote de reprodução vertical no tempo atual
    final progresso = duracao > 0 ? (tempoAtual / duracao).clamp(0.0, 1.0) : 0.0;
    final cursorX = progresso * w;

    final cursorPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(cursorX, 0), Offset(cursorX, h), cursorPaint);
    canvas.drawCircle(Offset(cursorX, centerY), 4.5, Paint()..color = Scene3DTheme.accent);
  }

  @override
  bool shouldRepaint(_GraficoDeCurvasPainter old) =>
      old._modo != _modo ||
      old.mostrarX != mostrarX ||
      old.mostrarY != mostrarY ||
      old.mostrarZ != mostrarZ ||
      old.tempoAtual != tempoAtual ||
      old.duracao != duracao;
}
