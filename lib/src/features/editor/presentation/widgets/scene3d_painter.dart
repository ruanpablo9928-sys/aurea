import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/camera3d.dart';
import '../../domain/scene3d.dart';

/// Pintor do CONTEINER CENA 3D. Faz os dois passes da spec §3:
///
///   passe opaco       — ordenado POR TRIANGULO, sem blend
///   passe transparente — depois, testando contra o opaco mas sem
///                        "escrever profundidade" (nao reordena o opaco)
///
/// A ordenacao por triangulo (e nao por objeto) e o que permite dois
/// cubos cruzados renderizarem a intersecao correta — exatamente o
/// teste que a spec define como aprovacao.
class Scene3DPainter extends CustomPainter {
  Scene3DPainter({
    required this.scene,
    required this.camera,
    this.resolvedCamera,
    required this.view,
    required this.time,
    this.showHelpers = false,
    this.overrideCamera,
    this.selectedNodeId,
    this.onMetrics,
  });

  final Scene3D scene;
  final Camera3D camera;
  final SceneView view;
  final Duration time;

  /// Ajudas de cena: grade do chao, frustum, eixos. NUNCA na exportacao.
  final bool showHelpers;

  /// Vista livre navegada no estudio: quando presente, substitui a
  /// camera derivada de [view].
  final RenderCamera? overrideCamera;

  /// Volume envolvente desenhado so para o objeto selecionado.
  final String? selectedNodeId;

  final void Function(SceneFrame frame)? onMetrics;

  /// Camera ja resolvida por quem monta a cena (tomadas e transicoes).
  /// Nula = usa [camera] direto.
  final RenderCamera? resolvedCamera;

  RenderCamera _renderCamera() =>
      overrideCamera ??
      (view == SceneView.camera
          // A camera ATIVA no instante: com tomadas, e a da tomada no
          // ar (ou a mistura, se ainda esta na transicao).
          ? (resolvedCamera ?? camera.renderAt(time))
          : orthoViewCamera(view));

  @override
  void paint(Canvas canvas, Size size) {
    final cam = _renderCamera();

    if (scene.background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = scene.background!);
    }

    if (showHelpers && scene.showFloorGrid) {
      _paintFloorGrid(canvas, size, cam);
    }

    final frame = renderScene(scene, cam, size, time);
    onMetrics?.call(frame);

    // Passe OPACO e passe TRANSPARENTE, nessa ordem.
    _paintTriangles(canvas, frame.opaque);
    _paintTriangles(canvas, frame.transparent);

    // PROFUNDIDADE DE CAMPO. No modo rascunho ela sai do caminho — e a
    // diferenca entre navegar a cena e sofrer num aparelho de entrada.
    if (camera.dof.enabled && !scene.draftMode &&
        view == SceneView.camera) {
      _paintBokeh(canvas, frame);
    }

    if (showHelpers && (view != SceneView.camera || overrideCamera != null)) {
      // Fora da vista da camera ativa: frustum e plano de foco.
      _paintFrustum(canvas, size, cam);
      _paintDepthLines(canvas, size, cam);
    }
    if (showHelpers && selectedNodeId != null) {
      _paintSelectionBox(canvas, size, cam);
    }
  }

  /// LINHAS DE PROFUNDIDADE ligando cada objeto ao plano do chao — e o
  /// que revela a altura de cada um numa vista ortografica.
  void _paintDepthLines(Canvas canvas, Size size, RenderCamera cam) {
    final paint = Paint()
      ..color = const Color(0x449F8CFF)
      ..strokeWidth = 1;
    for (final n in scene.nodes) {
      if (!n.visible) continue;
      final p = n.positionAt(time);
      final a = _project(p, size, cam);
      final b = _project(Vec3(p.x, 0, p.z), size, cam);
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  /// VOLUME ENVOLVENTE do objeto selecionado.
  void _paintSelectionBox(Canvas canvas, Size size, RenderCamera cam) {
    for (final n in scene.nodes) {
      if (n.id != selectedNodeId) continue;
      final p = n.positionAt(time);
      final c = _project(p, size, cam);
      if (c == null) continue;
      final r = n.size * n.scale.valueAt(time);
      final rel = p - cam.position;
      final z = rel.dot(cameraBasis(cam).forward);
      final k = cam.orthographic
          ? cam.orthoScale
          : (size.width / 2 / math.tan(cam.fovRadians / 2)) /
              math.max(1, z);
      canvas.drawRect(
        Rect.fromCenter(center: c, width: r * 2 * k, height: r * 2 * k),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0xCCB8FF3D),
      );
    }
  }

  Offset? _project(Vec3 world, Size size, RenderCamera cam) {
    final basis = cameraBasis(cam);
    final rel = world - cam.position;
    final z = rel.dot(basis.forward);
    if (z <= cam.near) return null;
    final x = rel.dot(basis.right);
    final y = rel.dot(basis.up);
    final halfW = size.width / 2;
    final halfH = size.height / 2;
    if (cam.orthographic) {
      return Offset(halfW + x * cam.orthoScale, halfH - y * cam.orthoScale);
    }
    final k = (halfW / math.tan(cam.fovRadians / 2)) / z;
    return Offset(halfW + x * k, halfH - y * k);
  }

  void _paintTriangles(Canvas canvas, List<RenderTri> tris) {
    if (tris.isEmpty) return;
    // Uma chamada de desenho por LOTE de mesma cor: drawVertices e o
    // mais proximo de instanciacao que o Canvas oferece.
    final paint = Paint()
      ..isAntiAlias = scene.msaa
      ..style = PaintingStyle.fill;

    var i = 0;
    while (i < tris.length) {
      final color = tris[i].color;
      final start = i;
      while (i < tris.length && tris[i].color == color) {
        i++;
      }
      final count = i - start;
      final positions = Float32List(count * 6);
      for (var k = 0; k < count; k++) {
        final t = tris[start + k];
        positions[k * 6] = t.a.dx;
        positions[k * 6 + 1] = t.a.dy;
        positions[k * 6 + 2] = t.b.dx;
        positions[k * 6 + 3] = t.b.dy;
        positions[k * 6 + 4] = t.c.dx;
        positions[k * 6 + 5] = t.c.dy;
      }
      paint.color = color;
      canvas.drawVertices(
        ui.Vertices.raw(ui.VertexMode.triangles, positions),
        BlendMode.srcOver,
        paint,
      );
    }
  }

  /// BOKEH: cada ponto de luz fora de foco vira o FORMATO DA IRIS.
  /// Sem ganho e limiar de realce isto seria um borrao cinza; com eles,
  /// vira a bola brilhante que a gente reconhece como fotografia.
  void _paintBokeh(Canvas canvas, SceneFrame frame) {
    final dof = camera.dof;
    final sprites = bokehSprites(frame, dof, time);
    if (sprites.isEmpty) return;

    final rot = dof.irisRotation.valueAt(time);
    final round = dof.irisRoundness.valueAt(time);
    final aspect = dof.irisAspect.valueAt(time);
    final fringe = dof.diffractionFringe.valueAt(time).clamp(0.0, 100.0);

    for (final s in sprites) {
      canvas.save();
      canvas.translate(s.center.dx, s.center.dy);
      final path = irisPath(
        dof.irisShape,
        s.radius,
        roundness: round,
        rotationDeg: rot,
        aspect: aspect,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color.withValues(alpha: 0.55)
          ..blendMode = BlendMode.plus
          ..isAntiAlias = scene.msaa,
      );
      // FRANJA DE DIFRACAO: o anel brilhante na borda da bola.
      if (fringe > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, s.radius * 0.12)
            ..color = s.color.withValues(alpha: 0.25 + fringe / 200)
            ..blendMode = BlendMode.plus,
        );
      }
      canvas.restore();
    }
  }

  /// GRADE DO CHAO no plano Y=0, com desvanecimento pela distancia —
  /// e o que da nocao de escala.
  void _paintFloorGrid(Canvas canvas, Size size, RenderCamera cam) {
    final basis = cameraBasis(cam);
    final halfW = size.width / 2;
    final halfH = size.height / 2;
    final focalPx = halfW / math.tan(cam.fovRadians / 2);

    Offset? project(Vec3 world) {
      final rel = world - cam.position;
      final z = rel.dot(basis.forward);
      if (z <= cam.near) return null;
      final x = rel.dot(basis.right);
      final y = rel.dot(basis.up);
      if (cam.orthographic) {
        return Offset(halfW + x * cam.orthoScale,
            halfH - y * cam.orthoScale);
      }
      final k = focalPx / z;
      return Offset(halfW + x * k, halfH - y * k);
    }

    const step = 120.0;
    const lines = 10;
    for (var i = -lines; i <= lines; i++) {
      final d = i * step;
      final fade =
          (1 - (i.abs() / lines)).clamp(0.0, 1.0) * 0.25;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..strokeWidth = 1;
      final a1 = project(Vec3(d, 0, -lines * step));
      final b1 = project(Vec3(d, 0, lines * step));
      if (a1 != null && b1 != null) canvas.drawLine(a1, b1, paint);
      final a2 = project(Vec3(-lines * step, 0, d));
      final b2 = project(Vec3(lines * step, 0, d));
      if (a2 != null && b2 != null) canvas.drawLine(a2, b2, paint);
    }
  }

  /// FRUSTUM da camera desenhado nas vistas ortograficas, com o plano
  /// de foco marcado quando a profundidade de campo esta ligada.
  void _paintFrustum(Canvas canvas, Size size, RenderCamera view) {
    final basis = cameraBasis(view);
    final halfW = size.width / 2;
    final halfH = size.height / 2;

    Offset? project(Vec3 world) {
      final rel = world - view.position;
      final z = rel.dot(basis.forward);
      if (z <= view.near) return null;
      final x = rel.dot(basis.right);
      final y = rel.dot(basis.up);
      return Offset(halfW + x * view.orthoScale,
          halfH - y * view.orthoScale);
    }

    final camPos = camera.positionAt(time);
    final camFwd = camera.forwardAt(time);
    final fov = camera.fovAt(time) * math.pi / 180;
    final spread = math.tan(fov / 2);
    final rightAxis = camFwd.cross(const Vec3(0, 1, 0)).normalized;
    final upAxis = rightAxis.cross(camFwd).normalized;

    final paint = Paint()
      ..color = const Color(0xAAB8FF3D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const far = 900.0;
    final center = camPos + camFwd * far;
    final corners = <Vec3>[
      center + rightAxis * (far * spread) + upAxis * (far * spread * 0.6),
      center - rightAxis * (far * spread) + upAxis * (far * spread * 0.6),
      center - rightAxis * (far * spread) - upAxis * (far * spread * 0.6),
      center + rightAxis * (far * spread) - upAxis * (far * spread * 0.6),
    ];
    final apex = project(camPos);
    final projected = [for (final c in corners) project(c)];
    if (apex != null) {
      for (final p in projected) {
        if (p != null) canvas.drawLine(apex, p, paint);
      }
      canvas.drawCircle(apex, 5, Paint()..color = const Color(0xFFB8FF3D));
    }
    for (var i = 0; i < 4; i++) {
      final a = projected[i];
      final b = projected[(i + 1) % 4];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }

    // PLANO DE FOCO: ajustar foco olhando para ele e muito mais facil
    // do que olhar numero.
    if (camera.dof.enabled) {
      final fd = camera.dof.focusDistance.valueAt(time);
      final fc = camPos + camFwd * fd;
      final w = fd * spread;
      final p1 = project(fc + rightAxis * w);
      final p2 = project(fc - rightAxis * w);
      if (p1 != null && p2 != null) {
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = const Color(0xCCFFB020)
            ..strokeWidth = 2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(Scene3DPainter old) =>
      old.scene != scene ||
      old.camera != camera ||
      old.resolvedCamera != resolvedCamera ||
      old.view != view ||
      old.time != time ||
      old.showHelpers != showHelpers ||
      old.overrideCamera != overrideCamera ||
      old.selectedNodeId != selectedNodeId;
}

/// MINI-VISTA (camera §3.3): numa tela de seis polegadas, quatro
/// janelas sao inuteis. Uma janelinha com a vista de TOPO — mostrando
/// onde a camera esta, para onde aponta e onde os objetos estao em
/// profundidade — resolve 90% do que as quatro vistas resolvem, em 25%
/// do espaco.
class MiniViewPainter extends CustomPainter {
  const MiniViewPainter({
    required this.scene,
    required this.camera,
    required this.time,
    this.view = SceneView.top,
  });

  final Scene3D scene;
  final Camera3D camera;
  final Duration time;
  final SceneView view;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(8)),
      Paint()..color = const Color(0xCC0B0E12),
    );

    // Enquadra a cena e a camera juntas, olhando de cima.
    final bounds = sceneBounds(scene, time);
    final camPos = camera.positionAt(time);
    var extent = math.max(bounds.radius * 1.4, 300.0);
    final camDist = Vec3(camPos.x - bounds.center.x, 0,
            camPos.z - bounds.center.z)
        .length;
    extent = math.max(extent, camDist * 1.2);
    final k = math.min(size.width, size.height) / (extent * 2);

    Offset toScreen(double x, double z) => Offset(
          size.width / 2 + (x - bounds.center.x) * k,
          size.height / 2 + (z - bounds.center.z) * k,
        );

    // Objetos como pontos.
    for (final n in scene.nodes) {
      final p = n.positionAt(time);
      canvas.drawCircle(
        toScreen(p.x, p.z),
        math.max(2, n.size * n.scale.valueAt(time) * k * 0.5),
        Paint()..color = n.material.baseColor.withValues(alpha: 0.9),
      );
    }

    // Camera e seu frustum, vistos de cima.
    final fwd = camera.forwardAt(time);
    final camPt = toScreen(camPos.x, camPos.z);
    final fov = camera.fovAt(time) * math.pi / 180;
    final dir = math.atan2(fwd.x, fwd.z);
    final len = math.max(size.width, size.height) * 0.5;
    final left = dir - fov / 2;
    final right = dir + fov / 2;
    final cone = Path()
      ..moveTo(camPt.dx, camPt.dy)
      ..lineTo(camPt.dx + math.sin(left) * len,
          camPt.dy + math.cos(left) * len)
      ..lineTo(camPt.dx + math.sin(right) * len,
          camPt.dy + math.cos(right) * len)
      ..close();
    canvas.drawPath(
        cone, Paint()..color = const Color(0x33B8FF3D));
    canvas.drawCircle(
        camPt, 4, Paint()..color = const Color(0xFFB8FF3D));
  }

  @override
  bool shouldRepaint(MiniViewPainter old) =>
      old.scene != scene ||
      old.camera != camera ||
      old.time != time ||
      old.view != view;
}

/// EIXOS DE REFERENCIA TOCAVEIS (camera §3.4): mostram a orientacao E
/// navegam — tocar no X vai para a vista lateral, no Y para o topo.
class AxisGizmo extends StatelessWidget {
  const AxisGizmo({
    super.key,
    required this.camera,
    required this.time,
    required this.onView,
    this.size = 62,
  });

  final Camera3D camera;
  final Duration time;
  final ValueChanged<SceneView> onView;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _AxisPainter(camera: camera, time: time),
          ),
          // Areas tocaveis por eixo.
          Positioned(
            left: 0,
            top: size / 2 - 11,
            child: _AxisTap(
                label: 'X',
                color: const Color(0xFFE85B81),
                onTap: () => onView(SceneView.right)),
          ),
          Positioned(
            left: size / 2 - 11,
            top: 0,
            child: _AxisTap(
                label: 'Y',
                color: const Color(0xFF2BE3A0),
                onTap: () => onView(SceneView.top)),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _AxisTap(
                label: 'Z',
                color: const Color(0xFF35C4E7),
                onTap: () => onView(SceneView.front)),
          ),
        ],
      ),
    );
  }
}

class _AxisTap extends StatelessWidget {
  const _AxisTap({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
    );
  }
}

class _AxisPainter extends CustomPainter {
  const _AxisPainter({required this.camera, required this.time});

  final Camera3D camera;
  final Duration time;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rc = camera.renderAt(time);
    final basis = cameraBasis(rc);
    final r = size.width / 2 - 12;

    void axis(Vec3 dir, Color color) {
      final x = dir.dot(basis.right);
      final y = dir.dot(basis.up);
      canvas.drawLine(
        center,
        center + Offset(x * r, -y * r),
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..strokeWidth = 2,
      );
    }

    axis(const Vec3(1, 0, 0), const Color(0xFFE85B81));
    axis(const Vec3(0, 1, 0), const Color(0xFF2BE3A0));
    axis(const Vec3(0, 0, 1), const Color(0xFF35C4E7));
  }

  @override
  bool shouldRepaint(_AxisPainter old) =>
      old.camera != camera || old.time != time;
}
