import 'dart:ui';

import 'caption.dart';
import 'effect.dart';
import 'element3d.dart';
import 'grid_rig.dart';
import 'keyframe.dart';
import 'layer.dart';
import 'layer_meta.dart';
import 'mask.dart';
import 'shape.dart';
import 'text_animator.dart';
import 'video_project.dart';

/// Serializacao JSON do projeto inteiro (persistencia em disco).
/// Regra: toda propriedade animavel vira {b: base, k: [keyframes]};
/// duracoes em microssegundos; cores em ARGB int.

// ------------------------------------------------------------ primitivos

int _dur(Duration d) => d.inMicroseconds;
Duration _asDur(dynamic v) => Duration(microseconds: (v as num).toInt());

int _col(Color c) => c.toARGB32();
Color _asCol(dynamic v) => Color((v as num).toInt());

Map<String, dynamic> _easing(Easing e) => {
      't': e.type.index,
      'x1': e.x1, 'y1': e.y1, 'x2': e.x2, 'y2': e.y2,
      'c': e.count, 's': e.smooth, 'i': e.intensity,
    };

Easing _asEasing(Map<String, dynamic> m) => Easing(
      type: EasingType.values[(m['t'] as num).toInt()],
      x1: (m['x1'] as num).toDouble(),
      y1: (m['y1'] as num).toDouble(),
      x2: (m['x2'] as num).toDouble(),
      y2: (m['y2'] as num).toDouble(),
      count: (m['c'] as num).toInt(),
      smooth: (m['s'] as num).toDouble(),
      intensity: (m['i'] as num).toDouble(),
    );

Map<String, dynamic> _ad(AnimatedDouble a) => {
      'b': a.base,
      if (a.keyframes.isNotEmpty)
        'k': [
          for (final k in a.keyframes)
            {'t': _dur(k.time), 'v': k.value, 'e': _easing(k.ease)},
        ],
      if (a.loop.active)
        'loop': {
          'm': a.loop.mode.index,
          'w': a.loop.when.index,
          'n': a.loop.count,
        },
    };

AnimatedDouble _asAd(dynamic v) {
  final m = v as Map<String, dynamic>;
  final loopMap = m['loop'] as Map<String, dynamic>?;
  return AnimatedDouble(
    (m['b'] as num).toDouble(),
    [
      for (final k in (m['k'] as List? ?? const []))
        Keyframe<double>(
          time: _asDur(k['t']),
          value: (k['v'] as num).toDouble(),
          ease: _asEasing(k['e'] as Map<String, dynamic>),
        ),
    ],
    loopMap == null
        ? LoopSpec.none
        : LoopSpec(
            mode: LoopMode.values[(loopMap['m'] as num).toInt()],
            when: LoopWhen.values[(loopMap['w'] as num).toInt()],
            count: (loopMap['n'] as num).toInt(),
          ),
  );
}

Map<String, dynamic> _ao(AnimatedOffset a) => {
      'x': a.base.dx,
      'y': a.base.dy,
      if (a.keyframes.isNotEmpty)
        'k': [
          for (final k in a.keyframes)
            {
              't': _dur(k.time),
              'x': k.value.dx,
              'y': k.value.dy,
              'e': _easing(k.ease),
            },
        ],
    };

AnimatedOffset _asAo(dynamic v) {
  final m = v as Map<String, dynamic>;
  return AnimatedOffset(
    Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble()),
    [
      for (final k in (m['k'] as List? ?? const []))
        Keyframe<Offset>(
          time: _asDur(k['t']),
          value:
              Offset((k['x'] as num).toDouble(), (k['y'] as num).toDouble()),
          ease: _asEasing(k['e'] as Map<String, dynamic>),
        ),
    ],
  );
}

// -------------------------------------------------------------- mascaras

Map<String, dynamic> _bezier(BezierPath p) => {
      'closed': p.closed,
      'v': [
        for (final v in p.vertices)
          {
            'x': v.p.dx, 'y': v.p.dy,
            'ix': v.inT.dx, 'iy': v.inT.dy,
            'ox': v.outT.dx, 'oy': v.outT.dy,
            'c': v.corner,
          },
      ],
    };

BezierPath _asBezier(Map<String, dynamic> m) => BezierPath(
      closed: m['closed'] as bool,
      vertices: [
        for (final v in (m['v'] as List))
          PathVertex(
            p: Offset((v['x'] as num).toDouble(), (v['y'] as num).toDouble()),
            inT: Offset(
                (v['ix'] as num).toDouble(), (v['iy'] as num).toDouble()),
            outT: Offset(
                (v['ox'] as num).toDouble(), (v['oy'] as num).toDouble()),
            corner: v['c'] as bool,
          ),
      ],
    );

Map<String, dynamic> _apath(AnimatedPath a) => {
      'base': _bezier(a.base),
      if (a.keyframes.isNotEmpty)
        'k': [
          for (final k in a.keyframes)
            {'t': _dur(k.time), 'v': _bezier(k.value), 'e': _easing(k.ease)},
        ],
    };

AnimatedPath _asApath(Map<String, dynamic> m) => AnimatedPath(
      _asBezier(m['base'] as Map<String, dynamic>),
      [
        for (final k in (m['k'] as List? ?? const []))
          Keyframe<BezierPath>(
            time: _asDur(k['t']),
            value: _asBezier(k['v'] as Map<String, dynamic>),
            ease: _asEasing(k['e'] as Map<String, dynamic>),
          ),
      ],
    );

Map<String, dynamic> _mask(LayerMask m) => {
      'id': m.id,
      'name': m.name,
      'mode': m.mode.index,
      'inv': m.inverted,
      'path': _apath(m.path),
      'feather': _ad(m.feather),
      'op': _ad(m.opacity),
      'exp': _ad(m.expansion),
    };

LayerMask _asMask(Map<String, dynamic> m) => LayerMask(
      id: m['id'] as String,
      name: m['name'] as String,
      mode: MaskMode.values[(m['mode'] as num).toInt()],
      inverted: m['inv'] as bool,
      path: _asApath(m['path'] as Map<String, dynamic>),
      feather: _asAd(m['feather']),
      opacity: _asAd(m['op']),
      expansion: _asAd(m['exp']),
    );

// ------------------------------------------------------------------ grid

/// Compat: rigs antigos salvavam numeros crus; agora todo parametro e
/// uma trilha animavel.
AnimatedDouble _adCompat(dynamic v) =>
    v is num ? AnimatedDouble(v.toDouble()) : _asAd(v);

Map<String, dynamic> _rig(GridRig g) => {
      'assets': g.assets,
      'cols': g.columns,
      'sx': _ad(g.spacingX),
      'sy': _ad(g.spacingY),
      'radius': _ad(g.radius),
      'spread': g.spread,
      'rot': _ad(g.gridRotationDeg),
      'twist': _ad(g.twistDeg),
      'stagger': _ad(g.staggerDeg),
      'zd': _ad(g.zDepth),
      'sf': _ad(g.scaleFront),
      'sb': _ad(g.scaleBack),
      'gop': g.globalOpacity,
      'ro': _ad(g.randomOffset),
      'seed': g.seed,
      'shuffle': g.shuffle,
      'trans': _ad(g.transition),
      if (g.controllerId != null) 'ctrl': g.controllerId,
      if (g.proximity != null)
        'prox': {
          'on': g.proximity!.enabled,
          'e': _ao(g.proximity!.effector),
          'ez': _ad(g.proximity!.effectorZ),
          'r': _ad(g.proximity!.radius),
          'f': _ad(g.proximity!.falloff),
          'smin': g.proximity!.scaleMin,
          'smax': g.proximity!.scaleMax,
          'omin': g.proximity!.opacityMin,
          'omax': g.proximity!.opacityMax,
          'att': _ad(g.proximity!.attract),
        },
    };

GridRig _asRig(Map<String, dynamic> m) => GridRig(
      assets: [for (final a in (m['assets'] as List)) a as String],
      columns: (m['cols'] as num).toInt(),
      spacingX: _adCompat(m['sx']),
      spacingY: _adCompat(m['sy']),
      radius: _adCompat(m['radius']),
      spread: (m['spread'] as num).toDouble(),
      gridRotationDeg: _adCompat(m['rot']),
      twistDeg: _adCompat(m['twist']),
      staggerDeg: _adCompat(m['stagger']),
      zDepth: _adCompat(m['zd']),
      scaleFront: _adCompat(m['sf']),
      scaleBack: _adCompat(m['sb']),
      globalOpacity: (m['gop'] as num).toDouble(),
      randomOffset: _adCompat(m['ro']),
      seed: (m['seed'] as num).toInt(),
      shuffle: m['shuffle'] as bool,
      transition: _asAd(m['trans']),
      controllerId: m['ctrl'] as String?,
      proximity: m['prox'] == null
          ? null
          : ProximityGroup(
              enabled: (m['prox'] as Map)['on'] as bool,
              effector: _asAo((m['prox'] as Map)['e']),
              effectorZ: _asAd((m['prox'] as Map)['ez']),
              radius: _asAd((m['prox'] as Map)['r']),
              falloff: _asAd((m['prox'] as Map)['f']),
              scaleMin: ((m['prox'] as Map)['smin'] as num).toDouble(),
              scaleMax: ((m['prox'] as Map)['smax'] as num).toDouble(),
              opacityMin: ((m['prox'] as Map)['omin'] as num).toDouble(),
              opacityMax: ((m['prox'] as Map)['omax'] as num).toDouble(),
              attract: _asAd((m['prox'] as Map)['att']),
            ),
    );

// -------------------------------------------------------------- efeitos

Map<String, dynamic> _effect(EffectInstance e) => {
      'id': e.id,
      'type': e.type.index,
      'color': _col(e.color),
      'enabled': e.enabled,
      'params': {for (final p in e.params.entries) p.key: _ad(p.value)},
    };

EffectInstance _asEffect(Map<String, dynamic> m) => EffectInstance(
      id: m['id'] as String,
      type: EffectType.values[(m['type'] as num).toInt()],
      color: _asCol(m['color']),
      enabled: m['enabled'] as bool,
      params: {
        for (final p in (m['params'] as Map<String, dynamic>).entries)
          p.key: _asAd(p.value),
      },
    );

// --------------------------------------------------------------- formas

Map<String, dynamic> _shapeItem(ShapeItem s) => switch (s) {
      ShapePath p => {
          'kind': 'path',
          'id': p.id,
          'prim': p.primitive.index,
          'w': p.width, 'h': p.height, 'cr': p.cornerRadius,
          'pts': p.points, 'irr': p.innerRadiusRatio,
          'sa': p.startAngle, 'sw': p.sweepAngle, 'th': p.thickness,
          'amp': p.amplitude, 'fq': p.frequency,
        },
      ShapeParametric sp => {
          'kind': 'param',
          'id': sp.id,
          'pk': sp.kind.index,
          'sx': _ad(sp.sizeX),
          'sy': _ad(sp.sizeY),
          'round': _ad(sp.roundness),
          'roundPct': sp.roundnessPercent,
          'pts': _ad(sp.points),
          'ro': _ad(sp.outerRadius),
          'ri': _ad(sp.innerRadius),
          'rdo': _ad(sp.outerRoundness),
          'rdi': _ad(sp.innerRoundness),
          'srot': _ad(sp.shapeRotation),
          'sa': _ad(sp.startAngle),
          'sw': _ad(sp.sweep),
          'si': _ad(sp.sectorInner),
        },
      ShapeFill f => {
          'kind': 'fill',
          'id': f.id,
          'color': _col(f.color),
          'op': f.opacity,
          'eo': f.evenOdd,
        },
      ShapeStroke st => {
          'kind': 'stroke',
          'id': st.id,
          'color': _col(st.color),
          'w': st.width,
          'cap': st.cap.index,
          'join': st.join.index,
          'miter': st.miterLimit,
          'op': st.opacity,
          'dash': st.dashLength,
          'gap': st.gapLength,
          'doff': _ad(st.dashOffset),
        },
      ShapeGradientFill g => {
          'kind': 'gfill',
          'id': g.id,
          'ca': _col(g.colorA),
          'cb': _col(g.colorB),
          'ang': g.angleDeg,
          'radial': g.radial,
          'op': g.opacity,
        },
      ShapeSvgPath p => {
          'kind': 'svg',
          'id': p.id,
          'd': p.pathData,
          'size': p.size,
        },
      ShapeMorph m => {
          'kind': 'morph',
          'id': m.id,
          'from': _shapeItem(m.from),
          'to': _shapeItem(m.to),
          'prog': _ad(m.progress),
        },
      TrimOperator t => {
          'kind': 'trim',
          'id': t.id,
          'start': _ad(t.start),
          'end': _ad(t.end),
          'offset': _ad(t.offset),
          'ind': t.individually,
        },
      RepeaterOperator r => {
          'kind': 'repeater',
          'id': r.id,
          'copies': r.copies,
          'dx': r.dx, 'dy': r.dy,
          'rot': _ad(r.rotation),
          'step': r.scaleStep,
        },
    };

ShapeItem _asShapeItem(Map<String, dynamic> m) => switch (m['kind']) {
      'path' => ShapePath(
          id: m['id'] as String,
          primitive: ShapePrimitive.values[(m['prim'] as num).toInt()],
          width: (m['w'] as num).toDouble(),
          height: (m['h'] as num).toDouble(),
          cornerRadius: (m['cr'] as num).toDouble(),
          points: (m['pts'] as num).toInt(),
          innerRadiusRatio: (m['irr'] as num).toDouble(),
          startAngle: (m['sa'] as num).toDouble(),
          sweepAngle: (m['sw'] as num).toDouble(),
          thickness: (m['th'] as num).toDouble(),
          amplitude: (m['amp'] as num).toDouble(),
          frequency: (m['fq'] as num).toDouble(),
        ),
      'param' => ShapeParametric(
          id: m['id'] as String,
          kind: ParamShapeKind.values[(m['pk'] as num).toInt()],
          sizeX: _asAd(m['sx']),
          sizeY: _asAd(m['sy']),
          roundness: _asAd(m['round']),
          roundnessPercent: m['roundPct'] as bool? ?? true,
          points: _asAd(m['pts']),
          outerRadius: _asAd(m['ro']),
          innerRadius: _asAd(m['ri']),
          outerRoundness: _asAd(m['rdo']),
          innerRoundness: _asAd(m['rdi']),
          shapeRotation: _asAd(m['srot']),
          startAngle: _asAd(m['sa']),
          sweep: _asAd(m['sw']),
          sectorInner: _asAd(m['si']),
        ),
      'fill' => ShapeFill(
          id: m['id'] as String,
          color: _asCol(m['color']),
          opacity: (m['op'] as num).toDouble(),
          evenOdd: m['eo'] as bool? ?? false,
        ),
      'stroke' => ShapeStroke(
          id: m['id'] as String,
          color: _asCol(m['color']),
          width: (m['w'] as num).toDouble(),
          cap: StrokeCap.values[(m['cap'] as num).toInt()],
          join: m['join'] == null
              ? StrokeJoin.round
              : StrokeJoin.values[(m['join'] as num).toInt()],
          miterLimit: (m['miter'] as num?)?.toDouble() ?? 4,
          opacity: (m['op'] as num?)?.toDouble() ?? 1,
          dashLength: (m['dash'] as num).toDouble(),
          gapLength: (m['gap'] as num).toDouble(),
          dashOffset:
              m['doff'] == null ? AnimatedDouble(0) : _asAd(m['doff']),
        ),
      'gfill' => ShapeGradientFill(
          id: m['id'] as String,
          colorA: _asCol(m['ca']),
          colorB: _asCol(m['cb']),
          angleDeg: (m['ang'] as num).toDouble(),
          radial: m['radial'] as bool,
          opacity: (m['op'] as num).toDouble(),
        ),
      'svg' => ShapeSvgPath(
          id: m['id'] as String,
          pathData: m['d'] as String,
          size: (m['size'] as num).toDouble(),
        ),
      'morph' => ShapeMorph(
          id: m['id'] as String,
          from: _asShapeItem(m['from'] as Map<String, dynamic>) as ShapePath,
          to: _asShapeItem(m['to'] as Map<String, dynamic>) as ShapePath,
          progress: _asAd(m['prog']),
        ),
      'trim' => TrimOperator(
          id: m['id'] as String,
          start: _asAd(m['start']),
          end: _asAd(m['end']),
          offset: _asAd(m['offset']),
          individually: m['ind'] as bool? ?? true,
        ),
      'repeater' => RepeaterOperator(
          id: m['id'] as String,
          copies: (m['copies'] as num).toInt(),
          dx: (m['dx'] as num).toDouble(),
          dy: (m['dy'] as num).toDouble(),
          rotation: _asAd(m['rot']),
          scaleStep: (m['step'] as num).toDouble(),
        ),
      _ => throw FormatException('ShapeItem desconhecido: ${m['kind']}'),
    };

// ----------------------------------------------------- animadores de texto

Map<String, dynamic> _selector(TextSelector s) => switch (s) {
      RangeSelector r => {
          'kind': 'range',
          'id': r.id,
          'mode': r.mode.index,
          'basedOn': r.basedOn.index,
          'units': r.units.index,
          'start': _ad(r.start),
          'end': _ad(r.end),
          'offset': _ad(r.offset),
          'shape': r.shape.index,
          'amount': _ad(r.amount),
          'smooth': _ad(r.smoothness),
          'easeHigh': _ad(r.easeHigh),
          'easeLow': _ad(r.easeLow),
          'rand': r.randomizeOrder,
          'seed': r.randomSeed,
          'order': r.order.index,
          'hold': r.holdBeyond,
        },
      WigglySelector w => {
          'kind': 'wiggly',
          'id': w.id,
          'mode': w.mode.index,
          'basedOn': w.basedOn.index,
          'max': _ad(w.maxAmount),
          'min': _ad(w.minAmount),
          'wps': _ad(w.wigglesPerSecond),
          'corr': _ad(w.correlation),
          'tph': _ad(w.temporalPhase),
          'sph': _ad(w.spatialPhase),
          'lock': w.lockDimensions,
          'seed': w.randomSeed,
        },
    };

TextSelector _asSelector(Map<String, dynamic> m) => switch (m['kind']) {
      'range' => RangeSelector(
          id: m['id'] as String,
          mode: SelectorMode.values[(m['mode'] as num).toInt()],
          basedOn: SelectorBasedOn.values[(m['basedOn'] as num).toInt()],
          units: SelectorUnits.values[(m['units'] as num).toInt()],
          start: _asAd(m['start']),
          end: _asAd(m['end']),
          offset: _asAd(m['offset']),
          shape: SelectorShape.values[(m['shape'] as num).toInt()],
          amount: _asAd(m['amount']),
          smoothness: _asAd(m['smooth']),
          easeHigh: _asAd(m['easeHigh']),
          easeLow: _asAd(m['easeLow']),
          randomizeOrder: m['rand'] as bool,
          randomSeed: (m['seed'] as num).toInt(),
          order: m['order'] == null
              ? SelectorOrder.identity
              : SelectorOrder.values[(m['order'] as num).toInt()],
          holdBeyond: m['hold'] as bool? ?? false,
        ),
      'wiggly' => WigglySelector(
          id: m['id'] as String,
          mode: SelectorMode.values[(m['mode'] as num).toInt()],
          basedOn: SelectorBasedOn.values[(m['basedOn'] as num).toInt()],
          maxAmount: _asAd(m['max']),
          minAmount: _asAd(m['min']),
          wigglesPerSecond: _asAd(m['wps']),
          correlation: _asAd(m['corr']),
          temporalPhase: _asAd(m['tph']),
          spatialPhase: _asAd(m['sph']),
          lockDimensions: m['lock'] as bool,
          randomSeed: (m['seed'] as num).toInt(),
        ),
      _ => throw FormatException('Seletor desconhecido: ${m['kind']}'),
    };

Map<String, dynamic> _animator(TextAnimator a) => {
      'id': a.id,
      'name': a.name,
      'enabled': a.enabled,
      'overshoot': a.allowOvershoot,
      'selectors': [for (final s in a.selectors) _selector(s)],
      'props': [
        for (final p in a.properties)
          {'id': p.id, 'type': p.type.index, 'value': _ad(p.value)},
      ],
    };

TextAnimator _asAnimator(Map<String, dynamic> m) => TextAnimator(
      id: m['id'] as String,
      name: m['name'] as String,
      enabled: m['enabled'] as bool,
      allowOvershoot: m['overshoot'] as bool,
      selectors: [
        for (final s in (m['selectors'] as List))
          _asSelector(s as Map<String, dynamic>),
      ],
      properties: [
        for (final p in (m['props'] as List))
          AnimatorProperty(
            id: p['id'] as String,
            type: TextAnimProp.values[(p['type'] as num).toInt()],
            value: _asAd(p['value']),
          ),
      ],
    );

// -------------------------------------------------------------- legendas

Map<String, dynamic> _cue(Cue c) => {
      'id': c.id,
      's': _dur(c.start),
      'e': _dur(c.end),
      't': c.text,
      'l': c.locked,
    };

Cue _asCue(Map<String, dynamic> m) => Cue(
      id: m['id'] as String,
      start: _asDur(m['s']),
      end: _asDur(m['e']),
      text: m['t'] as String,
      locked: m['l'] as bool,
    );

Map<String, dynamic> _capStyle(CaptionStyle s) => {
      'size': s.fontSize,
      'color': _col(s.color),
      'bg': _col(s.backgroundColor),
      'bgOp': s.backgroundOpacity,
      'bold': s.bold,
    };

CaptionStyle _asCapStyle(Map<String, dynamic> m) => CaptionStyle(
      fontSize: (m['size'] as num).toDouble(),
      color: _asCol(m['color']),
      backgroundColor: _asCol(m['bg']),
      backgroundOpacity: (m['bgOp'] as num).toDouble(),
      bold: m['bold'] as bool,
    );

// --------------------------------------------------------------- camadas

Map<String, dynamic> layerToJson(Layer l) {
  final base = <String, dynamic>{
    'id': l.id,
    'name': l.name,
    'start': _dur(l.startTime),
    'dur': _dur(l.duration),
    'pos': _ao(l.position),
    'sx': _ad(l.scaleX),
    'sy': _ad(l.scaleY),
    'rot': _ad(l.rotation),
    'rotX': _ad(l.rotationX),
    'rotY': _ad(l.rotationY),
    'op': _ad(l.opacity),
    'skx': _ad(l.skewX),
    'sky': _ad(l.skewY),
    'pivot': _ao(l.pivot),
    'blend': l.blendMode.index,
    'is3D': l.is3D,
    'z': _ad(l.positionZ),
    'effects': [for (final e in l.effects) _effect(e)],
    if (l.masks.isNotEmpty) 'masks': [for (final m in l.masks) _mask(m)],
    if (l.matteMode != MatteMode.none) 'matte': l.matteMode.index,
    if (l.matteSourceId != null) 'matteSrc': l.matteSourceId,
  };
  switch (l) {
    case VideoLayer v:
      base['kind'] = 'video';
      base['src'] = v.sourcePath;
      base['srcOffset'] = _dur(v.sourceOffset);
      base['volume'] = v.volume;
    case ImageLayer i:
      base['kind'] = 'image';
      base['src'] = i.sourcePath;
    case TextLayer t:
      base['kind'] = 'text';
      base['text'] = t.text;
      base['fontSize'] = t.fontSize;
      base['color'] = _col(t.color);
      base['bold'] = t.bold;
      base['animators'] = [for (final a in t.animators) _animator(a)];
    case ShapeLayer s:
      base['kind'] = 'shape';
      base['contents'] = [for (final i in s.contents) _shapeItem(i)];
    case GroupLayer g:
      base['kind'] = 'group';
      base['children'] = [for (final c in g.children) layerToJson(c)];
    case CaptionLayer c:
      base['kind'] = 'caption';
      base['cues'] = [for (final q in c.cues) _cue(q)];
      base['style'] = _capStyle(c.style);
    case AudioLayer a:
      base['kind'] = 'audio';
      base['src'] = a.sourcePath;
      base['volume'] = a.volume;
    case NullLayer nl:
      base['kind'] = 'null';
      if (nl.grid != null) base['grid'] = _rig(nl.grid!);
    case AdjustmentLayer _:
      base['kind'] = 'adjust';
    case ParticlesLayer p:
      base['kind'] = 'particles';
      base['count'] = p.count;
      base['seed'] = p.seed;
      base['speed'] = p.speed;
      base['spread'] = p.spreadDeg;
      base['dir'] = p.directionDeg;
      base['gravity'] = p.gravity;
      base['size'] = p.size;
      base['life'] = p.lifetimeMs;
      base['depth'] = p.depth;
      base['emitW'] = p.emitW;
      base['emitH'] = p.emitH;
      base['twinkle'] = p.twinkle;
      base['color'] = _col(p.color);
      base['star'] = p.star;
    case Element3DLayer e:
      base['kind'] = 'el3d';
      base['el'] = e.kind.index;
      base['size'] = e.size;
      base['color'] = _col(e.color);
      base['edges'] = e.edges;
  }
  return base;
}

Layer layerFromJson(Map<String, dynamic> m) {
  final id = m['id'] as String;
  final name = m['name'] as String;
  final start = _asDur(m['start']);
  final dur = _asDur(m['dur']);
  final pos = _asAo(m['pos']);
  final sx = _asAd(m['sx']);
  final sy = _asAd(m['sy']);
  final rot = _asAd(m['rot']);
  final rotX = m['rotX'] == null ? AnimatedDouble(0) : _asAd(m['rotX']);
  final rotY = m['rotY'] == null ? AnimatedDouble(0) : _asAd(m['rotY']);
  final op = _asAd(m['op']);
  final skx = _asAd(m['skx']);
  final sky = _asAd(m['sky']);
  final pivot = _asAo(m['pivot']);
  final blend = BlendMode.values[(m['blend'] as num).toInt()];
  final is3D = m['is3D'] as bool;
  final z = _asAd(m['z']);
  final effects = [
    for (final e in (m['effects'] as List))
      _asEffect(e as Map<String, dynamic>),
  ];
  final masks = [
    for (final k in (m['masks'] as List? ?? const []))
      _asMask(k as Map<String, dynamic>),
  ];
  final matte = m['matte'] == null
      ? MatteMode.none
      : MatteMode.values[(m['matte'] as num).toInt()];
  final matteSrc = m['matteSrc'] as String?;

  switch (m['kind']) {
    case 'video':
      return VideoLayer(
        id: id, name: name, startTime: start, duration: dur,
        sourcePath: m['src'] as String,
        sourceOffset: _asDur(m['srcOffset']),
        volume: (m['volume'] as num).toDouble(),
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'image':
      return ImageLayer(
        id: id, name: name, startTime: start, duration: dur,
        sourcePath: m['src'] as String,
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'text':
      return TextLayer(
        id: id, name: name, startTime: start, duration: dur,
        text: m['text'] as String,
        fontSize: (m['fontSize'] as num).toDouble(),
        color: _asCol(m['color']),
        bold: m['bold'] as bool,
        animators: [
          for (final a in (m['animators'] as List))
            _asAnimator(a as Map<String, dynamic>),
        ],
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'shape':
      return ShapeLayer(
        id: id, name: name, startTime: start, duration: dur,
        contents: [
          for (final i in (m['contents'] as List))
            _asShapeItem(i as Map<String, dynamic>),
        ],
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'group':
      return GroupLayer(
        id: id, name: name, startTime: start, duration: dur,
        children: [
          for (final c in (m['children'] as List))
            layerFromJson(c as Map<String, dynamic>),
        ],
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'caption':
      return CaptionLayer(
        id: id, name: name, startTime: start, duration: dur,
        cues: [
          for (final c in (m['cues'] as List))
            _asCue(c as Map<String, dynamic>),
        ],
        style: _asCapStyle(m['style'] as Map<String, dynamic>),
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'audio':
      return AudioLayer(
        id: id, name: name, startTime: start, duration: dur,
        sourcePath: m['src'] as String,
        volume: (m['volume'] as num).toDouble(),
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'adjust':
      return AdjustmentLayer(
        id: id, name: name, startTime: start, duration: dur,
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'null':
      return NullLayer(
        id: id, name: name, startTime: start, duration: dur,
        grid: m['grid'] == null
            ? null
            : _asRig(m['grid'] as Map<String, dynamic>),
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'particles':
      return ParticlesLayer(
        id: id, name: name, startTime: start, duration: dur,
        count: (m['count'] as num).toInt(),
        seed: (m['seed'] as num).toInt(),
        speed: (m['speed'] as num).toDouble(),
        spreadDeg: (m['spread'] as num).toDouble(),
        directionDeg: (m['dir'] as num).toDouble(),
        gravity: (m['gravity'] as num).toDouble(),
        size: (m['size'] as num).toDouble(),
        lifetimeMs: (m['life'] as num).toInt(),
        depth: (m['depth'] as num).toDouble(),
        emitW: (m['emitW'] as num?)?.toDouble() ?? 0,
        emitH: (m['emitH'] as num?)?.toDouble() ?? 0,
        twinkle: m['twinkle'] as bool? ?? false,
        color: _asCol(m['color']),
        star: m['star'] as bool,
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    case 'el3d':
      return Element3DLayer(
        id: id, name: name, startTime: start, duration: dur,
        kind: Element3DKind.values[(m['el'] as num).toInt()],
        size: (m['size'] as num).toDouble(),
        color: _asCol(m['color']),
        edges: m['edges'] as bool? ?? true,
        position: pos, scaleX: sx, scaleY: sy, rotation: rot,
        rotationX: rotX, rotationY: rotY, opacity: op,
        skewX: skx, skewY: sky, pivot: pivot, blendMode: blend,
        is3D: is3D, positionZ: z, effects: effects,
        masks: masks, matteMode: matte, matteSourceId: matteSrc,
      );
    default:
      throw FormatException('Camada desconhecida: ${m['kind']}');
  }
}

// --------------------------------------------------------------- projeto

// ------------------------------------------------- camada de oficio

Map<String, dynamic> _shadow(ShadowStyle s) => {
      'on': s.enabled,
      'c': _col(s.color),
      'op': _ad(s.opacity),
      'ang': _ad(s.angleDeg),
      'dist': _ad(s.distance),
      'size': _ad(s.size),
    };

ShadowStyle _asShadow(Map<String, dynamic> m) => ShadowStyle(
      enabled: m['on'] as bool? ?? true,
      color: _asCol(m['c']),
      opacity: _asAd(m['op']),
      angleDeg: _asAd(m['ang']),
      distance: _asAd(m['dist']),
      size: _asAd(m['size']),
    );

Map<String, dynamic> _styles(LayerStyles s) => {
      if (s.dropShadow != null) 'ds': _shadow(s.dropShadow!),
      if (s.innerShadow != null) 'is': _shadow(s.innerShadow!),
      if (s.outerGlow != null)
        'og': {
          'on': s.outerGlow!.enabled,
          'c': _col(s.outerGlow!.color),
          'op': _ad(s.outerGlow!.opacity),
          'size': _ad(s.outerGlow!.size),
        },
      if (s.colorOverlay != null)
        'co': {
          'on': s.colorOverlay!.enabled,
          'c': _col(s.colorOverlay!.color),
          'op': _ad(s.colorOverlay!.opacity),
          'bm': s.colorOverlay!.blend.index,
        },
      if (s.gradientOverlay != null)
        'go': {
          'on': s.gradientOverlay!.enabled,
          'ca': _col(s.gradientOverlay!.colorA),
          'cb': _col(s.gradientOverlay!.colorB),
          'ang': _ad(s.gradientOverlay!.angleDeg),
          'op': _ad(s.gradientOverlay!.opacity),
        },
      if (s.stroke != null)
        'st': {
          'on': s.stroke!.enabled,
          'c': _col(s.stroke!.color),
          'w': _ad(s.stroke!.width),
          'op': _ad(s.stroke!.opacity),
        },
    };

LayerStyles _asStyles(Map<String, dynamic> m) => LayerStyles(
      dropShadow: m['ds'] == null
          ? null
          : _asShadow(m['ds'] as Map<String, dynamic>),
      innerShadow: m['is'] == null
          ? null
          : _asShadow(m['is'] as Map<String, dynamic>),
      outerGlow: m['og'] == null
          ? null
          : GlowStyle(
              enabled: (m['og'] as Map)['on'] as bool? ?? true,
              color: _asCol((m['og'] as Map)['c']),
              opacity: _asAd((m['og'] as Map)['op']),
              size: _asAd((m['og'] as Map)['size']),
            ),
      colorOverlay: m['co'] == null
          ? null
          : OverlayStyle(
              enabled: (m['co'] as Map)['on'] as bool? ?? true,
              color: _asCol((m['co'] as Map)['c']),
              opacity: _asAd((m['co'] as Map)['op']),
              blend: BlendMode
                  .values[((m['co'] as Map)['bm'] as num).toInt()],
            ),
      gradientOverlay: m['go'] == null
          ? null
          : GradientOverlayStyle(
              enabled: (m['go'] as Map)['on'] as bool? ?? true,
              colorA: _asCol((m['go'] as Map)['ca']),
              colorB: _asCol((m['go'] as Map)['cb']),
              angleDeg: _asAd((m['go'] as Map)['ang']),
              opacity: _asAd((m['go'] as Map)['op']),
            ),
      stroke: m['st'] == null
          ? null
          : StrokeStyle(
              enabled: (m['st'] as Map)['on'] as bool? ?? true,
              color: _asCol((m['st'] as Map)['c']),
              width: _asAd((m['st'] as Map)['w']),
              opacity: _asAd((m['st'] as Map)['op']),
            ),
    );

Map<String, dynamic> _meta(LayerMeta m) => {
      if (m.label != null)
        'label': {'c': _col(m.label!.color), 'n': m.label!.name},
      if (m.solo) 'solo': true,
      if (m.shy) 'shy': true,
      if (m.locked) 'lock': true,
      if (m.folder != null) 'folder': m.folder,
      if (!m.styles.isEmpty) 'styles': _styles(m.styles),
      if (m.textBox != null)
        'box': {
          'mode': m.textBox!.mode.index,
          'w': m.textBox!.width,
          'h': m.textBox!.height,
          'anchor': m.textBox!.anchor.index,
        },
      if (m.container != null)
        'cont': {
          'target': m.container!.targetLayerId,
          'pl': m.container!.padLeft,
          'pr': m.container!.padRight,
          'pt': m.container!.padTop,
          'pb': m.container!.padBottom,
          'min': m.container!.minWidth,
          'max': m.container!.maxWidth,
          'anchor': m.container!.anchor.index,
          'follow': m.container!.follow,
        },
      if (m.stack != null)
        'stack': {
          'dir': m.stack!.direction.index,
          'gap': m.stack!.gap,
          'align': m.stack!.align.index,
          'pad': m.stack!.padding,
          'dist': m.stack!.distribution.index,
          'ext': m.stack!.extent,
        },
      if (m.counter != null)
        'counter': {
          'v': _ad(m.counter!.value),
          'f': _numFmt(m.counter!.format),
        },
      if (m.colorRef != null) 'colorRef': m.colorRef,
      if (m.textStyleRef != null) 'styleRef': m.textStyleRef,
      if (m.motionBlur) 'mb': true,
    };

Map<String, dynamic> _numFmt(NumberFormatSpec f) => {
      'd': f.decimals,
      't': f.thousands,
      'p': f.prefix,
      's': f.suffix,
      'pc': f.percent,
    };

NumberFormatSpec _asNumFmt(Map<String, dynamic> m) => NumberFormatSpec(
      decimals: (m['d'] as num).toInt(),
      thousands: m['t'] as bool? ?? true,
      prefix: m['p'] as String? ?? '',
      suffix: m['s'] as String? ?? '',
      percent: m['pc'] as bool? ?? false,
    );

LayerMeta _asMeta(Map<String, dynamic> m) => LayerMeta(
      label: m['label'] == null
          ? null
          : LayerLabel(
              color: _asCol((m['label'] as Map)['c']),
              name: (m['label'] as Map)['n'] as String? ?? ''),
      solo: m['solo'] as bool? ?? false,
      shy: m['shy'] as bool? ?? false,
      locked: m['lock'] as bool? ?? false,
      folder: m['folder'] as String?,
      styles: m['styles'] == null
          ? const LayerStyles()
          : _asStyles(m['styles'] as Map<String, dynamic>),
      textBox: m['box'] == null
          ? null
          : TextBoxSpec(
              mode: TextBoxMode
                  .values[((m['box'] as Map)['mode'] as num).toInt()],
              width: ((m['box'] as Map)['w'] as num).toDouble(),
              height: ((m['box'] as Map)['h'] as num).toDouble(),
              anchor: GrowAnchor
                  .values[((m['box'] as Map)['anchor'] as num).toInt()],
            ),
      container: m['cont'] == null
          ? null
          : ContainerSpec(
              targetLayerId: (m['cont'] as Map)['target'] as String,
              padLeft: ((m['cont'] as Map)['pl'] as num).toDouble(),
              padRight: ((m['cont'] as Map)['pr'] as num).toDouble(),
              padTop: ((m['cont'] as Map)['pt'] as num).toDouble(),
              padBottom: ((m['cont'] as Map)['pb'] as num).toDouble(),
              minWidth: ((m['cont'] as Map)['min'] as num).toDouble(),
              maxWidth: ((m['cont'] as Map)['max'] as num).toDouble(),
              anchor: GrowAnchor
                  .values[((m['cont'] as Map)['anchor'] as num).toInt()],
              follow: (m['cont'] as Map)['follow'] as bool? ?? true,
            ),
      stack: m['stack'] == null
          ? null
          : StackSpec(
              direction: StackDirection
                  .values[((m['stack'] as Map)['dir'] as num).toInt()],
              gap: ((m['stack'] as Map)['gap'] as num).toDouble(),
              align: StackAlign
                  .values[((m['stack'] as Map)['align'] as num).toInt()],
              padding: ((m['stack'] as Map)['pad'] as num).toDouble(),
              distribution: StackDistribution
                  .values[((m['stack'] as Map)['dist'] as num).toInt()],
              extent: ((m['stack'] as Map)['ext'] as num).toDouble(),
            ),
      counter: m['counter'] == null
          ? null
          : CounterSpec(
              value: _asAd((m['counter'] as Map)['v']),
              format: _asNumFmt(
                  (m['counter'] as Map)['f'] as Map<String, dynamic>),
            ),
      colorRef: m['colorRef'] as String?,
      textStyleRef: m['styleRef'] as String?,
      motionBlur: m['mb'] as bool? ?? false,
    );

Map<String, dynamic> projectToJson(VideoProject p) => {
      'v': 1,
      'id': p.id,
      'name': p.name,
      'createdAt': p.createdAt.toIso8601String(),
      'aspect': p.aspectRatio,
      'fps': p.fps,
      'resH': p.resolutionHeight,
      if (p.meta.isNotEmpty)
        'meta': {
          for (final e in p.meta.entries)
            if (!e.value.isEmpty) e.key: _meta(e.value),
        },
      'palette': {
        for (final e in p.palette.entries.entries) e.key: _col(e.value),
      },
      if (p.textStyles.isNotEmpty)
        'textStyles': [
          for (final s in p.textStyles)
            {
              'n': s.name,
              'fs': s.fontSize,
              'b': s.bold,
              'c': _col(s.color),
              if (s.colorRef != null) 'cr': s.colorRef,
              'tr': s.tracking,
              'lh': s.lineHeight,
            },
        ],
      if (p.exposed.isNotEmpty)
        'exposed': [
          for (final e in p.exposed)
            {
              'id': e.id,
              'layer': e.layerId,
              'prop': e.property,
              'label': e.label,
              'type': e.type.index,
              'group': e.group,
              if (e.min != null) 'min': e.min,
              if (e.max != null) 'max': e.max,
              if (e.step != null) 'step': e.step,
              if (e.options.isNotEmpty) 'options': e.options,
            },
        ],
      'guides': {
        'v': p.guides.vertical,
        'h': p.guides.horizontal,
        'cols': p.guides.columns,
        'gut': p.guides.gutter,
        'mar': p.guides.margin,
        'safe': p.guides.showSafeAreas,
        if (p.guides.framePreview != null) 'fp': p.guides.framePreview,
      },
      'mblur': {
        'on': p.motionBlur.enabled,
        'ang': p.motionBlur.shutterAngle,
        'ph': p.motionBlur.shutterPhase,
        'smp': p.motionBlur.samples,
        'lim': p.motionBlur.adaptiveLimit,
      },
      if (p.lottieMode) 'lottieMode': true,
      if (p.data != null)
        'data': {
          'n': p.data!.name,
          'cols': p.data!.columns,
          'rows': p.data!.rows,
        },
      if (p.bindings.isNotEmpty)
        'bindings': [
          for (final b in p.bindings)
            {
              'layer': b.layerId,
              'col': b.column,
              'prop': b.property,
              'row': b.row,
              'f': _numFmt(b.format),
            },
        ],
      'layers': [for (final l in p.layers) layerToJson(l)],
      'links': [
        for (final l in p.links)
          {
            'id': l.id,
            'target': l.targetLayerId,
            'prop': l.targetProp.index,
            'source': l.sourceLayerId,
            'scale': l.scale,
            'ox': l.offsetX,
            'oy': l.offsetY,
            'bRot': l.baseRotation,
            'bScale': l.baseScale,
            'bRotX': l.baseRotationX,
            'bRotY': l.baseRotationY,
            'bZ': l.baseZ,
          },
      ],
    };

VideoProject projectFromJson(Map<String, dynamic> m) => VideoProject(
      id: m['id'] as String,
      name: m['name'] as String,
      createdAt: DateTime.parse(m['createdAt'] as String),
      aspectRatio: (m['aspect'] as num).toDouble(),
      fps: (m['fps'] as num).toInt(),
      resolutionHeight: (m['resH'] as num).toInt(),
      layers: [
        for (final l in (m['layers'] as List))
          layerFromJson(l as Map<String, dynamic>),
      ],
      links: [
        for (final l in (m['links'] as List? ?? const []))
          PropertyLink(
            id: l['id'] as String,
            targetLayerId: l['target'] as String,
            targetProp: LayerProp.values[(l['prop'] as num).toInt()],
            sourceLayerId: l['source'] as String,
            scale: (l['scale'] as num).toDouble(),
            offsetX: (l['ox'] as num).toDouble(),
            offsetY: (l['oy'] as num).toDouble(),
            baseRotation: (l['bRot'] as num?)?.toDouble() ?? 0,
            baseScale: (l['bScale'] as num?)?.toDouble() ?? 1,
            baseRotationX: (l['bRotX'] as num?)?.toDouble() ?? 0,
            baseRotationY: (l['bRotY'] as num?)?.toDouble() ?? 0,
            baseZ: (l['bZ'] as num?)?.toDouble() ?? 0,
          ),
      ],
      meta: {
        for (final e in (m['meta'] as Map<String, dynamic>? ?? const {})
            .entries)
          e.key: _asMeta(e.value as Map<String, dynamic>),
      },
      palette: m['palette'] == null
          ? Palette.aurea
          : Palette(entries: {
              for (final e in (m['palette'] as Map<String, dynamic>).entries)
                e.key: _asCol(e.value),
            }),
      textStyles: [
        for (final s in (m['textStyles'] as List? ?? const []))
          TextStyleDef(
            name: s['n'] as String,
            fontSize: (s['fs'] as num).toDouble(),
            bold: s['b'] as bool? ?? true,
            color: _asCol(s['c']),
            colorRef: s['cr'] as String?,
            tracking: (s['tr'] as num?)?.toDouble() ?? 0,
            lineHeight: (s['lh'] as num?)?.toDouble() ?? 1.2,
          ),
      ],
      exposed: [
        for (final e in (m['exposed'] as List? ?? const []))
          ExposedProperty(
            id: e['id'] as String,
            layerId: e['layer'] as String,
            property: e['prop'] as String,
            label: e['label'] as String,
            type: ExposedType.values[(e['type'] as num).toInt()],
            group: e['group'] as String? ?? 'Geral',
            min: (e['min'] as num?)?.toDouble(),
            max: (e['max'] as num?)?.toDouble(),
            step: (e['step'] as num?)?.toDouble(),
            options: [
              for (final o in (e['options'] as List? ?? const []))
                o as String,
            ],
          ),
      ],
      guides: m['guides'] == null
          ? const GuidesSpec()
          : GuidesSpec(
              vertical: [
                for (final v in ((m['guides'] as Map)['v'] as List? ??
                    const []))
                  (v as num).toDouble(),
              ],
              horizontal: [
                for (final v in ((m['guides'] as Map)['h'] as List? ??
                    const []))
                  (v as num).toDouble(),
              ],
              columns: ((m['guides'] as Map)['cols'] as num?)?.toInt() ?? 0,
              gutter:
                  ((m['guides'] as Map)['gut'] as num?)?.toDouble() ?? 24,
              margin:
                  ((m['guides'] as Map)['mar'] as num?)?.toDouble() ?? 48,
              showSafeAreas:
                  (m['guides'] as Map)['safe'] as bool? ?? false,
              framePreview:
                  ((m['guides'] as Map)['fp'] as num?)?.toDouble(),
            ),
      motionBlur: m['mblur'] == null
          ? const MotionBlurSpec()
          : MotionBlurSpec(
              enabled: (m['mblur'] as Map)['on'] as bool? ?? false,
              shutterAngle:
                  ((m['mblur'] as Map)['ang'] as num?)?.toDouble() ?? 180,
              shutterPhase:
                  ((m['mblur'] as Map)['ph'] as num?)?.toDouble() ?? -90,
              samples: ((m['mblur'] as Map)['smp'] as num?)?.toInt() ?? 16,
              adaptiveLimit:
                  ((m['mblur'] as Map)['lim'] as num?)?.toInt() ?? 32,
            ),
      lottieMode: m['lottieMode'] as bool? ?? false,
      data: m['data'] == null
          ? null
          : DataSource(
              name: (m['data'] as Map)['n'] as String? ?? 'dados',
              columns: [
                for (final c in ((m['data'] as Map)['cols'] as List))
                  c as String,
              ],
              rows: [
                for (final r in ((m['data'] as Map)['rows'] as List))
                  [for (final c in (r as List)) c as String],
              ],
            ),
      bindings: [
        for (final b in (m['bindings'] as List? ?? const []))
          DataBinding(
            layerId: b['layer'] as String,
            column: b['col'] as String,
            property: b['prop'] as String? ?? 'text',
            row: (b['row'] as num?)?.toInt() ?? 0,
            format: _asNumFmt(b['f'] as Map<String, dynamic>),
          ),
      ],
    );
