import 'dart:ui';

import 'caption.dart';
import 'effect.dart';
import 'element3d.dart';
import 'grid_rig.dart';
import 'keyframe.dart';
import 'layer.dart';
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
    };

AnimatedDouble _asAd(dynamic v) {
  final m = v as Map<String, dynamic>;
  return AnimatedDouble((m['b'] as num).toDouble(), [
    for (final k in (m['k'] as List? ?? const []))
      Keyframe<double>(
        time: _asDur(k['t']),
        value: (k['v'] as num).toDouble(),
        ease: _asEasing(k['e'] as Map<String, dynamic>),
      ),
  ]);
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

Map<String, dynamic> projectToJson(VideoProject p) => {
      'v': 1,
      'id': p.id,
      'name': p.name,
      'createdAt': p.createdAt.toIso8601String(),
      'aspect': p.aspectRatio,
      'fps': p.fps,
      'resH': p.resolutionHeight,
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
    );
