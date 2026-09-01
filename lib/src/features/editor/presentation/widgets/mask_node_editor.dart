import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../domain/layer.dart';
import '../../domain/mask.dart';
import '../../domain/path_edit.dart';
import '../am/am_colors.dart';

/// Que mascara esta sendo editada no a no. Nulo = ninguem, e a camada
/// volta a se mover com o dedo normalmente.
class PathEditTarget {
  const PathEditTarget(this.layerId, this.maskId);

  final String layerId;
  final String maskId;

  @override
  bool operator ==(Object other) =>
      other is PathEditTarget &&
      other.layerId == layerId &&
      other.maskId == maskId;

  @override
  int get hashCode => Object.hash(layerId, maskId);
}

final pathEditTargetProvider =
    StateProvider<PathEditTarget?>((ref) => null);

/// Qual no esta selecionado (o unico que mostra alcas).
final pathEditSelectedProvider = StateProvider<int?>((ref) => null);

/// EDITOR DE NOS, EM CIMA DA COMPOSICAO.
///
/// Desenhar a mascara em volta de uma pessoa nao acontece num formulario
/// — acontece com o dedo, olhando a imagem. Por isso os nos vivem aqui,
/// sobrepostos ao preview, e nao numa tela separada onde nao da para ver
/// o que se esta recortando.
///
/// A mascara mora no espaco da CAMADA (origem no centro do conteudo); a
/// tela e o espaco da COMPOSICAO. As duas contas de ida e volta estao em
/// [_paraComp] e [_paraMascara] — sem elas, arrastar um no numa camada
/// girada puxaria para o lado errado.
class MaskNodeEditor extends ConsumerStatefulWidget {
  const MaskNodeEditor({
    super.key,
    required this.time,
    required this.stageScale,
  });

  final ValueListenable<Duration> time;

  /// Quanto a composicao esta encolhida na tela: o raio do dedo em
  /// pixels de tela vira raio em pixels de composicao.
  final double Function() stageScale;

  @override
  ConsumerState<MaskNodeEditor> createState() => _MaskNodeEditorState();
}

class _MaskNodeEditorState extends ConsumerState<MaskNodeEditor> {
  /// O que o dedo pegou no comeco do arrasto.
  int? _arrastandoNo;
  (int, Handle)? _arrastandoAlca;

  double get _raio => 22 / math.max(widget.stageScale(), 0.05);

  Layer? _camada(PathEditTarget alvo) =>
      ref.read(editorControllerProvider).layerById(alvo.layerId);

  LayerMask? _mascara(PathEditTarget alvo) {
    final l = _camada(alvo);
    if (l == null) return null;
    for (final m in l.masks) {
      if (m.id == alvo.maskId) return m;
    }
    return null;
  }

  /// (centro da camada na composicao, escala, giro em radianos).
  (Offset, double, double, double) _pose(Layer l, Duration t) {
    final local = l.localTime(t);
    return (
      l.position.valueAt(local),
      l.scaleX.valueAt(local),
      l.scaleY.valueAt(local),
      l.rotation.valueAt(local) * math.pi / 180,
    );
  }

  Offset _paraComp(Offset p, (Offset, double, double, double) pose) {
    final (centro, sx, sy, giro) = pose;
    final e = Offset(p.dx * sx, p.dy * sy);
    final c = math.cos(giro), s = math.sin(giro);
    return centro + Offset(e.dx * c - e.dy * s, e.dx * s + e.dy * c);
  }

  Offset _paraMascara(Offset p, (Offset, double, double, double) pose) {
    final (centro, sx, sy, giro) = pose;
    final d = p - centro;
    final c = math.cos(-giro), s = math.sin(-giro);
    final r = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    return Offset(
      sx.abs() < 1e-6 ? r.dx : r.dx / sx,
      sy.abs() < 1e-6 ? r.dy : r.dy / sy,
    );
  }

  void _editar(
      PathEditTarget alvo, BezierPath Function(BezierPath) fn) {
    ref.read(editorControllerProvider.notifier).editMaskPath(
        alvo.layerId, alvo.maskId, widget.time.value, fn);
  }

  @override
  Widget build(BuildContext context) {
    final alvo = ref.watch(pathEditTargetProvider);
    if (alvo == null) return const SizedBox.shrink();

    // Redesenha quando a mascara muda.
    ref.watch(editorControllerProvider);
    final selecionado = ref.watch(pathEditSelectedProvider);

    return ValueListenableBuilder<Duration>(
      valueListenable: widget.time,
      builder: (context, t, _) {
        final camada = _camada(alvo);
        final mascara = _mascara(alvo);
        if (camada == null || mascara == null) {
          return const SizedBox.shrink();
        }
        final pose = _pose(camada, t);
        final caminho = mascara.path.valueAt(camada.localTime(t));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final p = _paraMascara(d.localPosition, pose);
            final alca = handleAt(caminho, selecionado, p, _raio);
            if (alca != null) return;

            final no = vertexAt(caminho, p, _raio);
            if (no != null) {
              ref.read(pathEditSelectedProvider.notifier).state = no;
              return;
            }
            // Toque EM CIMA da linha insere um no ali — e como se
            // acrescenta detalhe sem recomecar a mascara.
            final hit = nearestOnPath(caminho, p);
            if (hit != null && hit.distance <= _raio) {
              _editar(alvo, (c) => insertVertex(c, hit.segment, hit.t));
              ref.read(pathEditSelectedProvider.notifier).state =
                  hit.segment + 1;
              return;
            }
            ref.read(pathEditSelectedProvider.notifier).state = null;
          },
          onPanStart: (d) {
            final p = _paraMascara(d.localPosition, pose);
            _arrastandoAlca = handleAt(caminho, selecionado, p, _raio);
            if (_arrastandoAlca != null) {
              _arrastandoNo = null;
              return;
            }
            _arrastandoNo = vertexAt(caminho, p, _raio);
            if (_arrastandoNo != null) {
              ref.read(pathEditSelectedProvider.notifier).state =
                  _arrastandoNo;
            }
          },
          onPanUpdate: (d) {
            final p = _paraMascara(d.localPosition, pose);
            final alca = _arrastandoAlca;
            if (alca != null) {
              _editar(alvo, (c) => moveHandle(c, alca.$1, alca.$2, p));
              return;
            }
            final no = _arrastandoNo;
            if (no != null) {
              _editar(alvo, (c) => moveVertex(c, no, p));
            }
          },
          onPanEnd: (_) {
            _arrastandoNo = null;
            _arrastandoAlca = null;
          },
          child: CustomPaint(
            painter: _NodePainter(
              path: caminho,
              selected: selecionado,
              toComp: (p) => _paraComp(p, pose),
              scale: widget.stageScale(),
            ),
          ),
        );
      },
    );
  }
}

class _NodePainter extends CustomPainter {
  const _NodePainter({
    required this.path,
    required this.selected,
    required this.toComp,
    required this.scale,
  });

  final BezierPath path;
  final int? selected;
  final Offset Function(Offset) toComp;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.vertices.isEmpty) return;
    // Espessuras em pixels de TELA: o no tem o mesmo tamanho aparente
    // com a composicao encolhida ou ampliada.
    final k = 1 / math.max(scale, 0.05);

    // O contorno, em duas passadas: escura embaixo para nao sumir sobre
    // imagem clara.
    final contorno = Path();
    final n = path.vertices.length;
    final v0 = toComp(path.vertices.first.p);
    contorno.moveTo(v0.dx, v0.dy);
    final total = path.closed ? n : n - 1;
    for (var i = 0; i < total; i++) {
      final a = path.vertices[i];
      final b = path.vertices[(i + 1) % n];
      final c1 = toComp(a.p + a.outT);
      final c2 = toComp(b.p + b.inT);
      final p3 = toComp(b.p);
      contorno.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy);
    }
    canvas.drawPath(
        contorno,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * k
          ..color = const Color(0xCC000000));
    canvas.drawPath(
        contorno,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * k
          ..color = AmColors.accent);

    // Alcas so do no selecionado — mostrar todas vira um monte de
    // bolinha sobreposta e nao da para pegar nenhuma.
    final sel = selected;
    if (sel != null && sel >= 0 && sel < n) {
      final v = path.vertices[sel];
      final centro = toComp(v.p);
      for (final rel in [v.inT, v.outT]) {
        if (rel == Offset.zero) continue;
        final ponta = toComp(v.p + rel);
        canvas.drawLine(
            centro,
            ponta,
            Paint()
              ..strokeWidth = 1.2 * k
              ..color = AmColors.tealBright);
        canvas.drawCircle(
            ponta, 6 * k, Paint()..color = AmColors.tealBright);
      }
    }

    for (var i = 0; i < n; i++) {
      final v = path.vertices[i];
      final p = toComp(v.p);
      final aceso = i == selected;
      final r = (aceso ? 7.5 : 5.5) * k;
      // Canto e quadrado, curva e redondo: a forma diz o tipo sem
      // precisar selecionar para descobrir.
      if (v.corner) {
        final quad = Rect.fromCenter(center: p, width: r * 2, height: r * 2);
        canvas.drawRect(quad, Paint()..color = const Color(0xCC000000));
        canvas.drawRect(quad.deflate(1.2 * k),
            Paint()..color = aceso ? AmColors.accent : Colors.white);
      } else {
        canvas.drawCircle(p, r, Paint()..color = const Color(0xCC000000));
        canvas.drawCircle(p, r - 1.2 * k,
            Paint()..color = aceso ? AmColors.accent : Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(_NodePainter old) => true;
}
