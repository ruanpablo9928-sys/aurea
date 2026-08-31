import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../application/preview_stats.dart';
import '../../application/video_layer_manager.dart';
import '../../domain/effect.dart';
import '../../domain/fx.dart';
import '../../domain/gear.dart';
import '../../domain/grid_rig.dart';
import '../../domain/layer.dart';
import '../../domain/mask.dart';
import '../../domain/shape.dart';
import '../../domain/video_project.dart';
import 'animated_text.dart';
import 'blend_mask.dart';
import 'element3d_painter.dart';
import 'masked_box.dart';
import 'particles_painter.dart';

/// Palco: composicao renderizada em coordenadas logicas, escalada para
/// caber. Gestos editam a camada selecionada.
class PreviewStage extends ConsumerStatefulWidget {
  const PreviewStage({
    super.key,
    required this.playback,
    required this.videos,
  });

  final PlaybackController playback;
  final VideoLayerManager videos;

  @override
  ConsumerState<PreviewStage> createState() => _PreviewStageState();
}

class _PreviewStageState extends ConsumerState<PreviewStage> {
  double _startScale = 1;
  double _startRotation = 0;
  double _stageScale = 1;
  Offset _dragStartPos = Offset.zero;
  Offset _dragAccum = Offset.zero;

  void _onScaleStart(ScaleStartDetails d) {
    final id = ref.read(selectedLayerProvider);
    if (id == null) return;
    final layer = ref.read(editorControllerProvider).layerById(id);
    if (layer == null) return;
    final t = layer.localTime(widget.playback.time.value);
    _startScale = layer.scaleX.valueAt(t);
    _startRotation = layer.rotation.valueAt(t);
    _dragStartPos = layer.position.valueAt(t);
    _dragAccum = Offset.zero;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final id = ref.read(selectedLayerProvider);
    if (id == null) return;
    final controller = ref.read(editorControllerProvider.notifier);
    final project = ref.read(editorControllerProvider);
    final t = widget.playback.time.value;

    if (d.pointerCount >= 2) {
      controller.editScaleUniform(
          id, t, (_startScale * d.scale).clamp(0.05, 8.0));
      controller.editRotation(
          id, t, _startRotation + d.rotation * 180 / math.pi);
      return;
    }
    final deltaLogical = d.focalPointDelta / _stageScale;
    if (deltaLogical == Offset.zero) return;
    _dragAccum += deltaLogical;

    // Alinhamento: se o gesto e claramente horizontal/vertical, trava o
    // outro eixo — o arrasto nao "sai torto".
    var target = _dragStartPos + _dragAccum;
    final adx = _dragAccum.dx.abs();
    final ady = _dragAccum.dy.abs();
    if (adx > 24 || ady > 24) {
      if (adx > ady * 2.5) {
        target = Offset(target.dx, _dragStartPos.dy);
      } else if (ady > adx * 2.5) {
        target = Offset(_dragStartPos.dx, target.dy);
      }
    }

    // Guias inteligentes: gruda no centro da composicao.
    final cx = project.outputWidth / 2;
    final cy = project.outputHeight / 2;
    final snap = 16 / _stageScale;
    if ((target.dx - cx).abs() < snap) target = Offset(cx, target.dy);
    if ((target.dy - cy).abs() < snap) target = Offset(target.dx, cy);

    controller.editPosition(id, t, target);
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    final selectedId = ref.watch(selectedLayerProvider);
    final compW = project.outputWidth.toDouble();
    final compH = project.outputHeight.toDouble();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      child: ColoredBox(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = math.min(constraints.maxWidth / compW,
                constraints.maxHeight / compH);
            _stageScale = scale;
            return Center(
              child: SizedBox(
                width: compW * scale,
                height: compH * scale,
                child: ClipRect(
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topLeft,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: compW,
                      maxWidth: compW,
                      minHeight: compH,
                      maxHeight: compH,
                      child: _CompositionView(
                        playback: widget.playback,
                        videos: widget.videos,
                        selectedId: selectedId,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Estado do portao de recomposicao — um por app (ha um preview). Vive
/// fora do widget porque _CompositionView e recriado a cada build do
/// pai; widgets sao configuracoes imutaveis e reusa-los e valido.
class _CompositionGate {
  VideoProject? project;
  GearDecision? decision;
  bool needsClock = true;
  String? signature;
  String? selectedId;
  List<Widget>? kids;
}

final _gate = _CompositionGate();

/// Reconstroi por tick do clock; midia isolada em RepaintBoundary.
class _CompositionView extends ConsumerWidget {
  const _CompositionView({
    required this.playback,
    required this.videos,
    required this.selectedId,
  });

  final PlaybackController playback;
  final VideoLayerManager videos;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(editorControllerProvider);

    return ValueListenableBuilder<Duration>(
      valueListenable: playback.time,
      builder: (context, t, _) {
        // ARQUITETURA DE MARCHAS (PR-G1 + portao): o classificador roda
        // quando a CENA muda (identidade do projeto), nunca por frame; e
        // uma cena SEM nada evoluindo no tempo reusa a arvore composta
        // (o video atualiza sozinho pela Texture, a legenda troca por
        // assinatura de cue). "Compoe X/s" cai a ~0 em cena estatica —
        // o analogo Flutter de "o player nao compoe, so toca".
        if (!identical(project, _gate.project)) {
          _gate.project = project;
          _gate.decision = classifyGear(project);
          _gate.needsClock = projectNeedsClockRebuild(project);
          _gate.kids = null;
          PreviewStats.setGear(_gate.decision!);
        }
        final sig = compositionSignature(project, t);
        if (!_gate.needsClock &&
            _gate.kids != null &&
            sig == _gate.signature &&
            selectedId == _gate.selectedId) {
          PreviewStats.idle();
          return Stack(
              clipBehavior: Clip.none, children: _gate.kids!);
        }
        final kids = _buildLayers(project, project.layers, t,
            resolveLinks: true);
        _gate.kids = kids;
        _gate.signature = sig;
        _gate.selectedId = selectedId;
        PreviewStats.tick(kids.length);
        return Stack(clipBehavior: Clip.none, children: kids);
      },
    );
  }

  /// Constroi as camadas em ordem de pintura, com ordenacao 3D por trecho
  /// (D2) e vinculos de propriedade resolvidos (D4).
  List<Widget> _buildLayers(
    VideoProject project,
    List<Layer> layers,
    Duration t, {
    required bool resolveLinks,
  }) {
    // Camadas usadas como MATTE ficam ocultas na composicao (PR-M5).
    final matteSourceIds = <String>{
      for (final l in layers)
        if (l.matteMode != MatteMode.none && l.matteSourceId != null)
          l.matteSourceId!,
    };
    final paintOrder = [
      for (final layer in layers.reversed)
        if (layer is! AudioLayer &&
            layer.activeAt(t) &&
            !matteSourceIds.contains(layer.id))
          layer,
    ];
    final sorted = depthSortPaintOrder(paintOrder, t);

    // Modulo Grid: mapeia assetId -> (nulo, rig, indice, total) neste
    // escopo de camadas (funciona tambem dentro de grupos).
    final rigMembers = <String, (NullLayer, GridRig, int, int)>{};
    for (final l in layers) {
      if (l is NullLayer && l.grid != null && l.grid!.assets.isNotEmpty) {
        final ids = l.grid!.assets;
        for (var i = 0; i < ids.length; i++) {
          rigMembers[ids[i]] = (l, l.grid!, i, ids.length);
        }
      }
    }

    final children = <Widget>[];
    for (final layer in sorted) {
      // CAMADA DE AJUSTE (AUREA-2 §1): aplica a pilha dela ao COMPOSTO
      // de tudo abaixo; mascaras recortam a regiao (na posicao da
      // camada), opacidade dosa a mistura e o blend devolve o resultado.
      // Pilha vazia nao muda um pixel (I2).
      if (layer is AdjustmentLayer) {
        final local = layer.localTime(t);
        final hasWork = layer.effects.any((e) => e.enabled);
        if (!hasWork || children.isEmpty) continue;

        Widget adjusted = Stack(
          clipBehavior: Clip.none,
          children: List<Widget>.of(children),
        );
        adjusted = _applyEffects(layer.effects, adjusted, local);
        if (layer.masks.isNotEmpty) {
          final pos = layer.position.valueAt(local);
          final compCenter = Offset(
              project.outputWidth / 2, project.outputHeight / 2);
          final shift = pos - compCenter;
          adjusted = MaskedBox(
            specs: [
              for (final m in layer.masks)
                MaskSpec(
                  path: m.path.valueAt(local).build().shift(shift),
                  mode: m.mode,
                  inverted: m.inverted,
                  opacity: m.opacity.valueAt(local).clamp(0.0, 1.0),
                  feather: m.feather.valueAt(local),
                  expansion: m.expansion.valueAt(local),
                ),
            ],
            child: adjusted,
          );
        }
        final op = layer.opacity.valueAt(local).clamp(0.0, 1.0);
        final plain = layer.masks.isEmpty &&
            op >= 0.999 &&
            layer.blendMode == BlendMode.srcOver;
        if (plain) {
          // O ajustado SUBSTITUI o acumulado (como no AE) — empilhar por
          // cima duplicava o conteudo no preview.
          children
            ..clear()
            ..add(Positioned.fill(
                child: IgnorePointer(child: adjusted)));
        } else {
          // Com mascara/opacidade/blend, o ajustado mistura POR CIMA do
          // original (dentro da mascara ele cobre o mesmo conteudo).
          children.add(Positioned.fill(
            child: IgnorePointer(
              child: BlendMask(
                blendMode: layer.blendMode,
                child: Opacity(opacity: op, child: adjusted),
              ),
            ),
          ));
        }
        continue;
      }

      // Eco/rastro: re-renderiza a camada INTEIRA em tempos anteriores
      // (deterministico — trilha de movimento dos keyframes), atras da
      // copia atual e com opacidade decaindo.
      EffectInstance? echoFx;
      for (final e in layer.effects) {
        if (e.enabled && e.type == EffectType.echo) echoFx = e;
      }
      if (echoFx != null) {
        final local = layer.localTime(t);
        final n = echoFx.paramAt('ecos', local).round().clamp(1, 8);
        final gapUs = (echoFx.paramAt('intervalo', local) * 1e6).round();
        final decay =
            echoFx.paramAt('decaimento', local).clamp(0.05, 0.95);
        final hueStep = echoFx.paramAt('matiz', local);
        for (var i = n; i >= 1; i--) {
          final et = t - Duration(microseconds: gapUs * i);
          if (!layer.activeAt(et)) continue;
          Widget copy = _buildLayer(project, layer, et, resolveLinks,
              rig: rigMembers,
              opacityMul: math.pow(decay, i).toDouble());
          // Rastro COLORIDO (item 16): cada copia com matiz proprio.
          if (hueStep > 0.5) {
            copy = Positioned.fill(
              child: ColorFiltered(
                colorFilter:
                    ColorFilter.matrix(hueRotateMatrix(hueStep * i)),
                child: Stack(
                    clipBehavior: Clip.none, children: [copy]),
              ),
            );
          }
          children.add(copy);
        }
      }

      var w = _buildLayer(project, layer, t, resolveLinks, rig: rigMembers);

      // Matte: a fonte recorta esta camada, num grupo isolado.
      if (layer.matteMode != MatteMode.none &&
          layer.matteSourceId != null) {
        Layer? src;
        for (final l in layers) {
          if (l.id == layer.matteSourceId) src = l;
        }
        if (src != null && src.activeAt(t)) {
          final matte = _matteFiltered(
            layer.matteMode,
            _buildLayer(project, src, t, resolveLinks, rig: rigMembers),
          );
          w = Positioned.fill(
            child: BlendMask(
              blendMode: BlendMode.srcOver,
              child: Stack(
                clipBehavior: Clip.none,
                children: [w, matte],
              ),
            ),
          );
        }
      }
      children.add(w);
    }
    return children;
  }

  /// Converte a fonte do matte no canal certo e composita com dstIn.
  Widget _matteFiltered(MatteMode mode, Widget matte) {
    const lumaM = <double>[
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0.299, 0.587, 0.114, 0, 0,
    ];
    const lumaInvM = <double>[
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      -0.299, -0.587, -0.114, 0, 255,
    ];
    const alphaInvM = <double>[
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0, 0, 0, 0, 0, //
      0, 0, 0, -1, 255,
    ];
    // O widget do matte e um Positioned: ele precisa ser filho DIRETO de
    // um Stack — o filtro de cor envolve o Stack, nunca o Positioned.
    Widget content = Stack(clipBehavior: Clip.none, children: [matte]);
    switch (mode) {
      case MatteMode.alpha:
      case MatteMode.none:
        break;
      case MatteMode.alphaInvert:
        content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(alphaInvM),
            child: content);
      case MatteMode.luma:
        content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(lumaM), child: content);
      case MatteMode.lumaInvert:
        content = ColorFiltered(
            colorFilter: const ColorFilter.matrix(lumaInvM),
            child: content);
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: BlendMask(
          blendMode: BlendMode.dstIn,
          child: content,
        ),
      ),
    );
  }

  Widget _buildLayer(
      VideoProject project, Layer layer, Duration t, bool resolveLinks,
      {double opacityMul = 1,
      Map<String, (NullLayer, GridRig, int, int)>? rig}) {
    final local = layer.localTime(t);

    // ---- propriedades efetivas (com pickwhip quando ha vinculo) ----
    var pos = layer.position.valueAt(local);
    var rotationDeg = layer.rotation.valueAt(local);
    var opacityV = layer.opacity.valueAt(local);
    var sx = layer.scaleX.valueAt(local);
    var sy = layer.scaleY.valueAt(local);
    var extraZ = 0.0;
    var extraRotX = 0.0;
    var extraRotY = 0.0;

    if (resolveLinks) {
      Layer? src(PropertyLink? l) =>
          l == null ? null : project.layerById(l.sourceLayerId);

      final pl = project.linkFor(layer.id, LayerProp.position);
      final ps = src(pl);
      if (pl != null && ps != null) {
        pos = ps.position.valueAt(ps.localTime(t)) +
            Offset(pl.offsetX, pl.offsetY);
      }
      final rl = project.linkFor(layer.id, LayerProp.rotation);
      final rs = src(rl);
      if (rl != null && rs != null) {
        rotationDeg =
            rs.rotation.valueAt(rs.localTime(t)) * rl.scale + rl.offsetX;
      }
      final ol = project.linkFor(layer.id, LayerProp.opacity);
      final os = src(ol);
      if (ol != null && os != null) {
        opacityV =
            (os.opacity.valueAt(os.localTime(t)) + ol.offsetX).clamp(0, 1);
      }
      final sl = project.linkFor(layer.id, LayerProp.scale);
      final ss = src(sl);
      if (sl != null && ss != null) {
        final f = ss.scaleX.valueAt(ss.localTime(t)) * sl.offsetX;
        sx = f;
        sy = f;
      }

      // Parenting (objeto nulo / camada pai): resolve a CADEIA inteira
      // (objeto -> nulo 1 -> nulo 2 -> ...) recursivamente. O filho segue
      // o delta de posicao/rotacao(3D)/escala acumulado — semantica AE:
      // nada pula ao parear, e girar o nulo em X/Y/Z orbita o filho.
      final par = project.linkFor(layer.id, LayerProp.parent);
      if (par != null) {
        final eff = effectiveTransform(project, layer, t);
        final rawScale = layer.scaleX.valueAt(local);
        final ratio =
            rawScale.abs() < 1e-6 ? 1.0 : eff.scale / rawScale;
        pos = eff.pos;
        rotationDeg = eff.rot;
        extraRotX = eff.rotX - layer.rotationX.valueAt(local);
        extraRotY = eff.rotY - layer.rotationY.valueAt(local);
        extraZ = eff.z - layer.positionZ.valueAt(local);
        sx *= ratio;
        sy *= ratio;
      }
    }

    // ---- Modulo Grid: a camada e ASSET de uma grade num nulo ----
    // O rig calcula posicao/rotacao/escala base; a transform propria da
    // camada e aplicada POR CIMA como offset — mover uma camada
    // manualmente nunca desloca as outras.
    final rigInfo = rig?[layer.id];
    if (rigInfo != null) {
      final (nullL, g, idx, count) = rigInfo;
      if (nullL.activeAt(t)) {
        // Nulo CONTROLADOR (alem do dono): o transform dele modula os
        // parametros — escala x espacamento/raio, rotZ + rotacao da
        // grade, rotY + twist. Animar o nulo anima a grade.
        var spacingMul = 1.0, rotationAdd = 0.0, twistAdd = 0.0;
        final ctrlId = g.controllerId;
        if (ctrlId != null) {
          final ctrl = project.layerById(ctrlId);
          if (ctrl != null && ctrl.activeAt(t)) {
            final ce = effectiveTransform(project, ctrl, t);
            spacingMul = ce.scale;
            rotationAdd = ce.rot;
            twistAdd = ce.rotY;
          }
        }
        final place = gridPlacementAt(g, idx, count, nullL.localTime(t),
            spacingMul: spacingMul,
            rotationAdd: rotationAdd,
            twistAdd: twistAdd);
        final ne = effectiveTransform(project, nullL, t);

        // Layout girado/escalado pelo transform 3D do nulo controlador.
        final vx = place.pos.dx * ne.scale;
        final vy = place.pos.dy * ne.scale;
        final vz = place.z * ne.scale;
        final dRx = ne.rotX * math.pi / 180;
        final dRy = ne.rotY * math.pi / 180;
        final dRz = ne.rot * math.pi / 180;
        final cxr = math.cos(dRx), sxr = math.sin(dRx);
        final y1 = vy * cxr - vz * sxr;
        final z1 = vy * sxr + vz * cxr;
        final cyr = math.cos(dRy), syr = math.sin(dRy);
        final x1 = vx * cyr + z1 * syr;
        final z2 = -vx * syr + z1 * cyr;
        final czr = math.cos(dRz), szr = math.sin(dRz);

        final compCenter = Offset(
            project.outputWidth / 2, project.outputHeight / 2);
        final authoredOffset = pos - compCenter;
        // Mesma projecao de posicao do parenting: orbita 3D de verdade.
        final perspPos =
            1200 / (1200 + (ne.z + z2).clamp(-1100.0, 100000.0));
        pos = ne.pos +
            Offset(x1 * czr - y1 * szr, x1 * szr + y1 * czr) * perspPos +
            authoredOffset;
        extraZ = ne.z + z2 - layer.positionZ.valueAt(local);
        rotationDeg += place.rotationDeg + ne.rot;
        extraRotX += ne.rotX;
        extraRotY += ne.rotY;
        sx *= place.scale * ne.scale;
        sy *= place.scale * ne.scale;
        opacityV *= place.opacity;
      }
    }

    // ---- 3D: perspectiva simples pela profundidade ----
    if (layer.is3D || extraZ != 0) {
      final z = (layer.positionZ.valueAt(local) + extraZ)
          .clamp(-1100.0, 100000.0);
      final persp = 1200 / (1200 + z);
      sx *= persp;
      sy *= persp;
    }

    final rotation = rotationDeg * math.pi / 180;
    final skewX = layer.skewX.valueAt(local) * math.pi / 180;
    final skewY = layer.skewY.valueAt(local) * math.pi / 180;
    final pivot = layer.pivot.valueAt(local);
    final opacity = (opacityV * opacityMul).clamp(0.0, 1.0);

    // Particulas vivem em espaco 3D proprio: a rotacao do sistema (da
    // camada + herdada do nulo pai) e resolvida DENTRO do simulador — a
    // nuvem gira no espaco, nada de inclinar o canvas como um cartao.
    final isParticles =
        layer is ParticlesLayer || layer is Element3DLayer;
    Widget content = _LayerContent(
      layer: layer,
      project: project,
      compWidth: project.outputWidth.toDouble(),
      videos: videos,
      localTime: local,
      particlesRotX:
          isParticles ? layer.rotationX.valueAt(local) + extraRotX : 0,
      particlesRotY:
          isParticles ? layer.rotationY.valueAt(local) + extraRotY : 0,
      buildChildren: (childLayers, childT) =>
          _buildLayers(project, childLayers, childT, resolveLinks: false),
    );

    // Mascaras cortam o alfa da propria camada ANTES dos efeitos (AE).
    if (layer.masks.isNotEmpty) {
      content = MaskedBox(
        specs: [
          for (final m in layer.masks)
            MaskSpec(
              path: m.path.valueAt(local).build(),
              mode: m.mode,
              inverted: m.inverted,
              opacity: m.opacity.valueAt(local).clamp(0.0, 1.0),
              feather: m.feather.valueAt(local),
              expansion: m.expansion.valueAt(local),
            ),
        ],
        child: content,
      );
    }

    content = _applyEffects(layer.effects, content, local);

    // Selecao desenhada DEPOIS dos efeitos: blur/glow nao pegam a borda.
    // Copias de eco (opacityMul < 1) nao ganham borda de selecao.
    if (layer.id == selectedId && opacityMul == 1) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Rotacao 3D (eixos X/Y) — inclui o delta herdado do pai 3D.
    // Particulas NAO entram aqui: a rotacao delas e 3D real no painter.
    final rx = (layer.rotationX.valueAt(local) + extraRotX) * math.pi / 180;
    final ry = (layer.rotationY.valueAt(local) + extraRotY) * math.pi / 180;
    final tilt3D = (rx != 0 || ry != 0) && !isParticles;

    // ORDEM CONSISTENTE (triagem 3D §5 itens 7/11): o vetor recebe
    // S -> Skew -> Rx -> Ry -> Rz — a MESMA ordem da matematica de
    // orbita (Rz*Ry*Rx). Misturar ordens era o que cisalhava as formas
    // ao girar o nulo. Com tilt 3D, o Rz sobe para a matriz de
    // perspectiva; sem tilt, tudo segue no caminho 2D de sempre.
    final m = Matrix4.identity()
      ..translateByDouble(pivot.dx, pivot.dy, 0, 1);
    if (!tilt3D) m.rotateZ(rotation);
    m
      ..multiply(Matrix4.skew(skewX, skewY))
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);

    Widget composed = Transform(
      transform: m,
      alignment: Alignment.center,
      child: Opacity(opacity: opacity, child: content),
    );

    if (tilt3D) {
      final pm = Matrix4.identity()
        ..setEntry(3, 2, -1 / 1200)
        ..rotateZ(rotation)
        ..rotateY(ry)
        ..rotateX(rx);
      composed = Transform(
        transform: pm,
        alignment: Alignment.center,
        child: composed,
      );
    }

    if (layer.blendMode != BlendMode.srcOver) {
      composed = BlendMask(blendMode: layer.blendMode, child: composed);
    }

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: composed,
      ),
    );
  }

  Widget _applyEffects(
      List<EffectInstance> effects, Widget child, Duration local) {
    var out = child;
    for (final effect in effects) {
      if (!effect.enabled) continue;
      switch (effect.type) {
        case EffectType.gaussianBlur:
          final sigma = effect.paramAt('amount', local) * 40;
          if (sigma > 0.01) {
            out = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
              child: out,
            );
          }
        case EffectType.lightGlow:
          final sigma = 4 + effect.paramAt('diffusion', local) * 60;
          final intensity =
              effect.paramAt('intensity', local).clamp(0.0, 1.0);
          out = Stack(
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: intensity,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                      sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
                  child: ColorFiltered(
                    colorFilter:
                        ColorFilter.mode(effect.color, BlendMode.srcATop),
                    child: out,
                  ),
                ),
              ),
              out,
            ],
          );
        case EffectType.tint:
          out = ColorFiltered(
            colorFilter: ColorFilter.mode(
              effect.color.withValues(
                  alpha: effect.paramAt('strength', local).clamp(0.0, 1.0)),
              BlendMode.srcATop,
            ),
            child: out,
          );

        case EffectType.glowVol:
          // Piramide de 3 niveis com pesos normalizados; aberracao = raio
          // por canal RGB; tonalizacao opcional (PR-FX2 aproximado).
          final intensity =
              effect.paramAt('intensidade', local).clamp(0.0, 2.0);
          if (intensity > 0.01) {
            final r = effect.paramAt('raio', local).clamp(0.02, 1.0);
            final aberr =
                effect.paramAt('aberracao', local).clamp(0.0, 1.0);
            final tintAmt =
                effect.paramAt('tonalizar', local).clamp(0.0, 1.0);
            final base = 6 + r * 90;

            Widget source = out;
            if (tintAmt > 0.01) {
              source = ColorFiltered(
                colorFilter: ColorFilter.mode(
                    effect.color.withValues(alpha: tintAmt),
                    BlendMode.srcATop),
                child: source,
              );
            }

            Widget level(double sigma, double weight) {
              Widget blurred(Widget c, double s) => ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                        sigmaX: s, sigmaY: s, tileMode: TileMode.decal),
                    child: c,
                  );
              Widget w;
              if (aberr > 0.01) {
                w = Stack(clipBehavior: Clip.none, children: [
                  blurred(_channelIso(source, 0), sigma * (1 - aberr * 0.35)),
                  BlendMask(
                      blendMode: BlendMode.plus,
                      child: blurred(_channelIso(source, 1), sigma)),
                  BlendMask(
                      blendMode: BlendMode.plus,
                      child: blurred(
                          _channelIso(source, 2), sigma * (1 + aberr * 0.5))),
                ]);
              } else {
                w = blurred(source, sigma);
              }
              return Opacity(
                  opacity: (weight * intensity).clamp(0.0, 1.0), child: w);
            }

            out = Stack(clipBehavior: Clip.none, children: [
              level(base * 2.2, 0.18),
              level(base, 0.30),
              level(base * 0.45, 0.42),
              out,
            ]);
          }

        case EffectType.tremor:
          // Tremor aleatorio-mas-repetivel (PR-FX3) com fase integrada.
          final amp = effect.paramAt('amplitude', local);
          final zoom = effect.paramAt('zoom', local).clamp(0.0, 1.0);
          final tilt = effect.paramAt('inclinacao', local);
          final rgbAmt = effect.paramAt('rgb', local).clamp(0.0, 1.0);
          final style =
              effect.paramAt('estilo', local).round().clamp(0, 2);
          final seed = effect.paramAt('semente', local).round();
          final phase =
              integratedPhase(effect.track('frequencia'), local);

          TremorSample sampleAt(double shift) => tremorSample(
                amplitudePx: amp,
                phase: phase + shift,
                style: style,
                seed: seed,
                zoom: zoom,
                tiltDeg: tilt,
              );
          Widget shaken(TremorSample s, Widget c) => Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(s.dx, s.dy, 0, 1)
                  ..rotateZ(s.rotationDeg * math.pi / 180)
                  ..scaleByDouble(s.scale, s.scale, 1, 1),
                alignment: Alignment.center,
                child: c,
              );

          final s0 = sampleAt(0);
          if (!s0.isNeutral || rgbAmt > 0.01) {
            if (rgbAmt > 0.01) {
              // Fase por canal: o vermelho se move ANTES, os outros
              // seguem — franja cromatica organica.
              final delta = 0.05 + rgbAmt * 0.12;
              out = Stack(clipBehavior: Clip.none, children: [
                shaken(sampleAt(-delta), _channelIso(out, 0)),
                BlendMask(
                    blendMode: BlendMode.plus,
                    child: shaken(s0, _channelIso(out, 1))),
                BlendMask(
                    blendMode: BlendMode.plus,
                    child: shaken(sampleAt(delta), _channelIso(out, 2))),
              ]);
            } else {
              out = shaken(s0, out);
            }
          }

        case EffectType.glitch:
          // Modulador mestre + operadores com tiques puros (PR-FX4).
          final master =
              effect.paramAt('quantidade', local).clamp(0.0, 2.0);
          if (master > 0.001) {
            final tau = integratedPhase(effect.track('velocidade'), local);
            final st = glitchState(
              master: master,
              tau: tau,
              intervalSec: effect.paramAt('intervalo', local),
              seed: effect.paramAt('semente', local).round(),
              slide: effect.paramAt('deslize', local),
              scaleAmt: effect.paramAt('escala', local),
              colorAmt: effect.paramAt('cor', local),
              lightAmt: effect.paramAt('luz', local),
              blurAmt: effect.paramAt('desfoque', local),
              rgbAmt: effect.paramAt('rgb', local),
            );
            if (!st.isNeutral) {
              var g = out;
              if (st.hueDeg.abs() > 0.5) {
                g = ColorFiltered(
                    colorFilter:
                        ColorFilter.matrix(hueRotateMatrix(st.hueDeg)),
                    child: g);
              }
              if (st.brightness > 0.01) {
                final b = 1 + st.brightness;
                g = ColorFiltered(
                    colorFilter: ColorFilter.matrix(<double>[
                      b, 0, 0, 0, 0, //
                      0, b, 0, 0, 0, //
                      0, 0, b, 0, 0, //
                      0, 0, 0, 1, 0,
                    ]),
                    child: g);
              }
              if (st.blurSigma > 0.2) {
                g = ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                      sigmaX: st.blurSigma,
                      sigmaY: st.blurSigma * 0.4,
                      tileMode: TileMode.decal),
                  child: g,
                );
              }
              Widget moved(double extraDx, Widget c) => Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(st.dx + extraDx, st.dy, 0, 1)
                      ..scaleByDouble(st.scale, st.scale, 1, 1),
                    alignment: Alignment.center,
                    child: c,
                  );
              if (st.rgbSep > 0.2) {
                out = Stack(clipBehavior: Clip.none, children: [
                  moved(-st.rgbSep, _channelIso(g, 0)),
                  BlendMask(
                      blendMode: BlendMode.plus,
                      child: moved(0, _channelIso(g, 1))),
                  BlendMask(
                      blendMode: BlendMode.plus,
                      child: moved(st.rgbSep, _channelIso(g, 2))),
                ]);
              } else {
                out = moved(0, g);
              }
            }
          }

        case EffectType.rgbSplit:
          final d =
              effect.paramAt('deslocamento', local).clamp(0.0, 100.0);
          if (d > 0.2) {
            final ang =
                effect.paramAt('angulo', local) * math.pi / 180;
            final off = Offset(math.cos(ang) * d, math.sin(ang) * d);
            out = Stack(clipBehavior: Clip.none, children: [
              Transform.translate(
                  offset: -off, child: _channelIso(out, 0)),
              BlendMask(
                  blendMode: BlendMode.plus, child: _channelIso(out, 1)),
              BlendMask(
                  blendMode: BlendMode.plus,
                  child: Transform.translate(
                      offset: off, child: _channelIso(out, 2))),
            ]);
          }

        case EffectType.echo:
          // Tratado no nivel da camada (_buildLayers): aqui e neutro.
          break;

        case EffectType.spatialEcho:
          // Repeticao no ESPACO com transformacao progressiva (item 28).
          final n =
              effect.paramAt('copias', local).round().clamp(1, 12);
          if (n > 1) {
            final dx = effect.paramAt('dx', local);
            final dy = effect.paramAt('dy', local);
            final scaleStep =
                effect.paramAt('escala', local) / 100.0;
            final rotStep =
                effect.paramAt('rotacao', local) * math.pi / 180;
            final decay =
                effect.paramAt('decaimento', local).clamp(0.05, 1.0);
            final hueStep = effect.paramAt('matiz', local);
            final copies = <Widget>[];
            for (var c = n - 1; c >= 0; c--) {
              Widget w = out;
              if (hueStep > 0.5 && c > 0) {
                w = ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                        hueRotateMatrix(hueStep * c)),
                    child: w);
              }
              copies.add(Opacity(
                opacity: math.pow(decay, c).toDouble().clamp(0.0, 1.0),
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(dx * c, dy * c, 0, 1)
                    ..rotateZ(rotStep * c)
                    ..scaleByDouble(
                        math.pow(scaleStep, c).toDouble(),
                        math.pow(scaleStep, c).toDouble(),
                        1,
                        1),
                  alignment: Alignment.center,
                  child: w,
                ),
              ));
            }
            out = Stack(clipBehavior: Clip.none, children: copies);
          }

        case EffectType.radialAberration:
          // Cresce do centro para a borda, como lente real (item 14):
          // cada canal amostrado com uma ESCALA levemente diferente.
          final amt =
              effect.paramAt('quantidade', local).clamp(0.0, 1.0);
          if (amt > 0.01) {
            final spread = amt * 0.06;
            Widget scaled(double s, int ch) => Transform.scale(
                  scale: s,
                  alignment: Alignment.center,
                  child: _channelIso(out, ch),
                );
            out = Stack(clipBehavior: Clip.none, children: [
              scaled(1 - spread, 0),
              BlendMask(
                  blendMode: BlendMode.plus, child: scaled(1.0, 1)),
              BlendMask(
                  blendMode: BlendMode.plus,
                  child: scaled(1 + spread, 2)),
            ]);
          }
      }
    }
    return out;
  }

  /// Isola um canal (0=R, 1=G, 2=B) preservando o alfa — base da franja
  /// cromatica, da separacao RGB e da aberracao do glow.
  Widget _channelIso(Widget child, int channel) {
    const zeros = [0.0, 0.0, 0.0, 0.0, 0.0];
    final rows = [
      channel == 0
          ? const [1.0, 0.0, 0.0, 0.0, 0.0]
          : zeros,
      channel == 1
          ? const [0.0, 1.0, 0.0, 0.0, 0.0]
          : zeros,
      channel == 2
          ? const [0.0, 0.0, 1.0, 0.0, 0.0]
          : zeros,
      const [0.0, 0.0, 0.0, 1.0, 0.0],
    ];
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(
          [for (final r in rows) ...r]),
      child: child,
    );
  }
}

class _LayerContent extends StatelessWidget {
  const _LayerContent({
    required this.layer,
    required this.project,
    required this.compWidth,
    required this.videos,
    required this.localTime,
    required this.buildChildren,
    this.particlesRotX = 0,
    this.particlesRotY = 0,
  });

  final Layer layer;
  final VideoProject project;
  final double compWidth;
  final VideoLayerManager videos;
  final Duration localTime;

  /// Rotacao 3D do sistema de particulas (graus), ja com o delta do pai.
  final double particlesRotX;
  final double particlesRotY;

  /// Recursao do precomp: constroi as camadas filhas no tempo local.
  final List<Widget> Function(List<Layer> layers, Duration t) buildChildren;

  @override
  Widget build(BuildContext context) {
    Widget child = switch (layer) {
      // Caminho rapido sem animador ativo (I2: linha inteira, com kerning).
      TextLayer l when l.animators
              .any((a) => a.enabled && a.properties.isNotEmpty) =>
        AnimatedTextView(layer: l, localTime: localTime),
      TextLayer l => Text(
          l.text,
          textAlign: TextAlign.center,
          style: AnimatedTextView.styleFor(l),
        ),
      // Forma vetorial: arvore avaliada no tempo local, pintada por Path.
      ShapeLayer l => _ShapeView(layer: l, localTime: localTime),
      // Precomp: filhos compostos no tempo local do grupo.
      GroupLayer l => SizedBox(
          width: compWidth,
          height: project.outputHeight.toDouble(),
          child: Stack(
            clipBehavior: Clip.none,
            children: buildChildren(l.children, localTime),
          ),
        ),
      ImageLayer l => RepaintBoundary(
          child: Image.file(
            File(l.sourcePath),
            width: compWidth,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _brokenMedia(),
          ),
        ),
      VideoLayer l => RepaintBoundary(
          child: ValueListenableBuilder<int>(
            valueListenable: videos.revision,
            builder: (context, _, _) {
              final controller = videos.controllerFor(l.id);
              if (controller == null || !controller.value.isInitialized) {
                return SizedBox(
                  width: compWidth,
                  height: compWidth * 9 / 16,
                  child: const Center(
                    child: Icon(CupertinoIcons.film,
                        size: 60, color: Colors.white24),
                  ),
                );
              }
              return SizedBox(
                width: compWidth,
                height: compWidth / controller.value.aspectRatio,
                child: VideoPlayer(controller),
              );
            },
          ),
        ),
      AudioLayer _ => const SizedBox.shrink(),
      // Objeto nulo: wireframe so no editor (nao sai na exportacao).
      NullLayer _ => const IgnorePointer(
          child: CustomPaint(
            size: Size(220, 220),
            painter: NullGizmoPainter(),
          ),
        ),
      // Ajuste nao tem conteudo proprio: age no composto (interceptado
      // em _buildLayers); aqui rende so o gizmo de selecao.
      AdjustmentLayer _ => const SizedBox(width: 220, height: 220),
      // Particulas em espaco 3D: simulacao + projecao por particula.
      ParticlesLayer l => CustomPaint(
          size: const Size(420, 420),
          painter: ParticlesPainter(
            layer: l,
            time: localTime,
            rotXDeg: particlesRotX,
            rotYDeg: particlesRotY,
          ),
        ),
      // Elemento 3D: vertices girados no espaco dentro do pintor (como
      // as particulas) — nada de inclinar o canvas como um cartao.
      Element3DLayer l => CustomPaint(
          size: const Size(620, 620),
          painter: Element3DPainter(
            layer: l,
            rotXDeg: particlesRotX,
            rotYDeg: particlesRotY,
          ),
        ),
      CaptionLayer l => Builder(builder: (context) {
          final cue = l.cueAt(localTime);
          if (cue == null) return const SizedBox.shrink();
          return Container(
            constraints: BoxConstraints(maxWidth: compWidth * 0.86),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: l.style.backgroundColor
                  .withValues(alpha: l.style.backgroundOpacity),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              cue.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: l.style.color,
                fontSize: l.style.fontSize,
                fontWeight:
                    l.style.bold ? FontWeight.w700 : FontWeight.w400,
                height: 1.2,
              ),
            ),
          );
        }),
    };

    return child;
  }

  Widget _brokenMedia() => Container(
        width: 400,
        height: 300,
        color: Colors.white10,
        child: const Icon(CupertinoIcons.exclamationmark_triangle,
            color: Colors.white38),
      );
}

/// Pinta a arvore da forma (vetorial: nitida em qualquer escala).
class _ShapeView extends StatelessWidget {
  const _ShapeView({required this.layer, required this.localTime});

  final ShapeLayer layer;
  final Duration localTime;

  @override
  Widget build(BuildContext context) {
    final draws = evaluateShape(layer.contents, localTime);
    final bounds = shapeBounds(draws);
    return CustomPaint(
      size: bounds.size,
      painter: _ShapePainter(draws: draws, bounds: bounds),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.draws, required this.bounds});

  final List<ShapeDraw> draws;
  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(-bounds.left, -bounds.top);
    for (final d in draws) {
      canvas.drawPath(d.path, d.paint);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => true;
}
