import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'camera3d.dart';
import 'caption.dart';
import 'effect.dart';
import 'element3d.dart';
import 'grid_rig.dart';
import 'blend_extra.dart';
import 'keyframe.dart';
import 'mask.dart';
import 'scene3d.dart';
import 'shape.dart';
import 'text_anim.dart';
import 'text_path.dart';
import 'text_animator.dart';

/// Camada da composicao (compositor por camadas: tudo tem transform
/// animavel). Coordenadas em pixels logicos; posicao e o centro; o pivo e
/// um deslocamento a partir do centro, em torno do qual gira/escala/skew.
///
/// 3D (spec AM2-formas-3d D2): com [is3D] ligado, [positionZ] participa da
/// ordenacao por profundidade — mas SO entre camadas 3D vizinhas; camadas
/// 2D preservam a ordem de empilhamento.
sealed class Layer {
  Layer({
    String? id,
    required this.name,
    required this.startTime,
    required this.duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    this.blendMode = BlendMode.srcOver,
    this.customBlend,
    this.is3D = false,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    this.matteSourceId,
  })  : id = id ?? const Uuid().v4(),
        position = position ?? AnimatedOffset(Offset.zero),
        scaleX = scaleX ?? AnimatedDouble(1),
        scaleY = scaleY ?? AnimatedDouble(1),
        rotation = rotation ?? AnimatedDouble(0),
        rotationX = rotationX ?? AnimatedDouble(0),
        rotationY = rotationY ?? AnimatedDouble(0),
        opacity = opacity ?? AnimatedDouble(1),
        skewX = skewX ?? AnimatedDouble(0),
        skewY = skewY ?? AnimatedDouble(0),
        pivot = pivot ?? AnimatedOffset(Offset.zero),
        positionZ = positionZ ?? AnimatedDouble(0),
        effects = List.unmodifiable(effects ?? const <EffectInstance>[]),
        masks = List.unmodifiable(masks ?? const <LayerMask>[]),
        matteMode = matteMode ?? MatteMode.none;

  final String id;
  final String name;

  final Duration startTime;
  final Duration duration;

  final AnimatedOffset position;
  final AnimatedDouble scaleX;
  final AnimatedDouble scaleY;
  final AnimatedDouble rotation;

  /// Rotacao 3D (graus) em torno dos eixos X e Y — so tem efeito visivel
  /// com [is3D] ligado (perspectiva).
  final AnimatedDouble rotationX;
  final AnimatedDouble rotationY;

  final AnimatedDouble opacity;
  final AnimatedDouble skewX;
  final AnimatedDouble skewY;

  /// Ponto de giro/escala, deslocamento a partir do centro da camada.
  final AnimatedOffset pivot;

  final BlendMode blendMode;

  /// MESCLA PROPRIA: os modos que o Flutter nao tem (Linear Burn, Vivid
  /// Light, Hard Mix, Dissolver...). Quando existe, manda no lugar de
  /// [blendMode] — e a camada passa pelo compositor de dois andares, que
  /// e mais caro. Nulo = usa o modo nativo, que e o caminho rapido.
  final AureaBlend? customBlend;

  /// Profundidade (so tem efeito com [is3D]).
  final bool is3D;
  final AnimatedDouble positionZ;

  /// Efeitos aplicados em ordem (de cima para baixo da pilha).
  final List<EffectInstance> effects;

  /// Mascaras da camada (modelo AE): cortam o alfa DESTA camada, na
  /// ordem da pilha. Aplicadas ANTES dos efeitos.
  final List<LayerMask> masks;

  /// Matte (modelo Alight): outra camada da cena recorta esta. A camada
  /// fonte fica oculta automaticamente na composicao.
  final MatteMode matteMode;
  final String? matteSourceId;

  Duration get endTime => startTime + duration;

  bool activeAt(Duration t) => t >= startTime && t < endTime;

  Duration localTime(Duration global) => global - startTime;

  bool get hasAnimation =>
      position.isAnimated ||
      scaleX.isAnimated ||
      scaleY.isAnimated ||
      rotation.isAnimated ||
      rotationX.isAnimated ||
      rotationY.isAnimated ||
      opacity.isAnimated ||
      skewX.isAnimated ||
      skewY.isAnimated ||
      pivot.isAnimated ||
      positionZ.isAnimated ||
      effects.any((e) => e.hasAnimation) ||
      masks.any((m) => m.hasAnimation) ||
      moduleTimesUs.isNotEmpty;

  Set<int> _times(Iterable<Keyframe<dynamic>> kfs) =>
      {for (final k in kfs) k.time.inMicroseconds};

  Set<int> get positionTimesUs =>
      {..._times(position.keyframes), ..._times(positionZ.keyframes)};
  Set<int> get scaleTimesUs =>
      {..._times(scaleX.keyframes), ..._times(scaleY.keyframes)};
  Set<int> get rotationTimesUs => {
        ..._times(rotation.keyframes),
        ..._times(rotationX.keyframes),
        ..._times(rotationY.keyframes),
      };
  Set<int> get opacityTimesUs => _times(opacity.keyframes);
  Set<int> get skewTimesUs =>
      {..._times(skewX.keyframes), ..._times(skewY.keyframes)};
  Set<int> get pivotTimesUs => _times(pivot.keyframes);
  Set<int> get effectTimesUs =>
      {for (final e in effects) ...e.keyframeTimes.map((t) => t.inMicroseconds)};

  /// Keyframes das mascaras (caminho, feather, opacidade, expansao).
  Set<int> get maskTimesUs => {
        for (final m in masks) ...[
          ..._times(m.path.keyframes),
          ..._times(m.feather.keyframes),
          ..._times(m.opacity.keyframes),
          ..._times(m.expansion.keyframes),
        ],
      };

  /// Keyframes dos MODULOS da camada (grade do nulo, operadores da
  /// forma...); subclasses somam os seus. Sem isto, o diamante do modulo
  /// grava mas NADA aparece na timeline — parece quebrado.
  Set<int> get moduleTimesUs => const <int>{};

  List<Duration> get keyframeTimes {
    final set = <int>{
      ...positionTimesUs,
      ...scaleTimesUs,
      ...rotationTimesUs,
      ...opacityTimesUs,
      ...skewTimesUs,
      ...pivotTimesUs,
      ...effectTimesUs,
      ...maskTimesUs,
      ...moduleTimesUs,
    };
    final list = set.toList()..sort();
    return [for (final us in list) Duration(microseconds: us)];
  }

  Layer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  });

  Layer duplicated();
}

/// AJUSTES DE SOM de uma camada que carrega audio.
///
/// Vive fora da camada porque video e audio compartilham exatamente os
/// mesmos controles — e porque assim o valor todo entra e sai numa
/// atribuicao so, sem espalhar seis campos por dois lugares.
class AudioSpec {
  const AudioSpec({
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.gain = 1.0,
    this.muted = false,
    this.duckAgainstId,
    this.duckAmount = 0.7,
  });

  /// Fade de entrada e de saida, em tempo de clipe.
  final Duration fadeIn;
  final Duration fadeOut;

  /// Ganho aplicado por cima do volume (normalizar mexe aqui).
  final double gain;

  final bool muted;

  /// ABAIXAR PELA VOZ: id da camada que manda nesta. A musica desce
  /// quando a narracao fala, e volta quando ela para.
  final String? duckAgainstId;

  /// 0..1 — quanto desce no meio da voz.
  final double duckAmount;

  bool get isNeutral =>
      fadeIn == Duration.zero &&
      fadeOut == Duration.zero &&
      gain == 1.0 &&
      !muted &&
      duckAgainstId == null;

  AudioSpec copyWith({
    Duration? fadeIn,
    Duration? fadeOut,
    double? gain,
    bool? muted,
    String? duckAgainstId,
    bool clearDuck = false,
    double? duckAmount,
  }) =>
      AudioSpec(
        fadeIn: fadeIn ?? this.fadeIn,
        fadeOut: fadeOut ?? this.fadeOut,
        gain: gain ?? this.gain,
        muted: muted ?? this.muted,
        duckAgainstId:
            clearDuck ? null : (duckAgainstId ?? this.duckAgainstId),
        duckAmount: duckAmount ?? this.duckAmount,
      );
}

class VideoLayer extends Layer {
  VideoLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    required this.sourcePath,
    this.sourceOffset = Duration.zero,
    this.volume = 1.0,
    this.audio = const AudioSpec(),
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  final String sourcePath;
  final Duration sourceOffset;
  final double volume;

  /// Fade, ganho, mudo e ducking do som deste clipe.
  final AudioSpec audio;

  @override
  VideoLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    Duration? sourceOffset,
    AudioSpec? audio,
    double? volume,
  }) {
    return VideoLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      sourcePath: sourcePath,
      sourceOffset: sourceOffset ?? this.sourceOffset,
      volume: volume ?? this.volume,
      audio: audio ?? this.audio,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  VideoLayer duplicated() => VideoLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        sourcePath: sourcePath,
        sourceOffset: sourceOffset,
        volume: volume,
        audio: audio,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

class ImageLayer extends Layer {
  ImageLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    required this.sourcePath,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  final String sourcePath;

  @override
  ImageLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return ImageLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      sourcePath: sourcePath,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  ImageLayer duplicated() => ImageLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        sourcePath: sourcePath,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

class TextLayer extends Layer {
  TextLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    required this.text,
    this.fontSize = 120,
    this.color = const Color(0xFFFFFFFF),
    this.bold = true,
    this.fontFamily,
    this.textPath = const TextPathSpec(),
    List<TextAnim>? anims,
    List<TextAnimator>? animators,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  })  : anims = List.unmodifiable(anims ?? const <TextAnim>[]),
        animators = List.unmodifiable(animators ?? const <TextAnimator>[]);

  final String text;
  final double fontSize;
  final Color color;
  final bool bold;

  /// FONTE IMPORTADA pela pessoa. Nulo = a do aplicativo. Guarda-se o
  /// NOME da familia, nao o caminho: o arquivo mora dentro do
  /// aplicativo, e o projeto continua abrindo mesmo se o .ttf original
  /// sumir da pasta de Downloads.
  final String? fontFamily;

  /// TEXTO EM CAMINHO: selo circular, arco, ou seguindo outra forma.
  final TextPathSpec textPath;

  /// ANIMACOES do catalogo (modelo Alight Motion): escolhe-se a animacao
  /// e mexe-se em seis controles. E o caminho normal.
  final List<TextAnim> anims;

  /// Animadores CRUS (modelo After Effects): seletor + propriedades na
  /// mao. Continuam existindo para quem quer montar do zero.
  final List<TextAnimator> animators;

  /// O que o render usa: as animacoes do catalogo compiladas, e por cima
  /// delas os animadores montados a mao.
  List<TextAnimator> effectiveAnimators(int unitCount) => [
        ...compileTextAnims(anims,
            layerDuration: duration, unitCount: unitCount),
        ...animators,
      ];

  /// Quando o render precisa do pintor POR UNIDADE em vez do Text
  /// simples: ha animacao, ou o texto segue um caminho.
  bool get hasTextAnimation =>
      textPath.active ||
      anims.any((a) => a.enabled) ||
      animators.any((a) => a.enabled && a.properties.isNotEmpty);

  @override
  TextLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    String? text,
    double? fontSize,
    Color? color,
    bool? bold,
    String? fontFamily,
    bool clearFont = false,
    TextPathSpec? textPath,
    List<TextAnim>? anims,
    List<TextAnimator>? animators,
  }) {
    return TextLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      bold: bold ?? this.bold,
      fontFamily: clearFont ? null : (fontFamily ?? this.fontFamily),
      textPath: textPath ?? this.textPath,
      anims: anims ?? this.anims,
      animators: animators ?? this.animators,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  TextLayer duplicated() => TextLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        text: text,
        fontSize: fontSize,
        color: color,
        bold: bold,
        fontFamily: fontFamily,
        textPath: textPath,
        anims: anims,
        animators: animators,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Camada de forma: arvore vetorial (spec AM2-formas-3d §1). Nada de
/// bitmap: os caminhos ficam nitidos em qualquer escala e os operadores
/// (Trim Paths, Repeater) sao animaveis.
class ShapeLayer extends Layer {
  ShapeLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    List<ShapeItem>? contents,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  }) : contents = List.unmodifiable(contents ?? ShapePresets.circle());

  /// Itens avaliados de baixo para cima (operador afeta o que veio antes).
  final List<ShapeItem> contents;

  /// Keyframes dos operadores da forma (morph, trim, repeater, dash)
  /// aparecem na barra da camada na timeline.
  @override
  Set<int> get moduleTimesUs {
    final out = <int>{};
    for (final item in contents) {
      switch (item) {
        case TrimOperator t:
          out
            ..addAll(_times(t.start.keyframes))
            ..addAll(_times(t.end.keyframes))
            ..addAll(_times(t.offset.keyframes));
        case RepeaterOperator r:
          out.addAll(_times(r.rotation.keyframes));
        case ShapeMorph m:
          out.addAll(_times(m.progress.keyframes));
        case ShapeStroke s:
          out.addAll(_times(s.dashOffset.keyframes));
        // Geometria parametrica: TODAS as trilhas viram diamantes na
        // barra da camada.
        case ShapeParametric p:
          out
            ..addAll(_times(p.sizeX.keyframes))
            ..addAll(_times(p.sizeY.keyframes))
            ..addAll(_times(p.roundness.keyframes))
            ..addAll(_times(p.points.keyframes))
            ..addAll(_times(p.outerRadius.keyframes))
            ..addAll(_times(p.innerRadius.keyframes))
            ..addAll(_times(p.outerRoundness.keyframes))
            ..addAll(_times(p.innerRoundness.keyframes))
            ..addAll(_times(p.shapeRotation.keyframes))
            ..addAll(_times(p.startAngle.keyframes))
            ..addAll(_times(p.sweep.keyframes))
            ..addAll(_times(p.sectorInner.keyframes));
        default:
          break;
      }
    }
    return out;
  }

  /// Primeira cor de fill (para a miniatura e o painel de cor).
  Color get primaryColor {
    for (final item in contents) {
      if (item is ShapeFill) return item.color;
      if (item is ShapeStroke) return item.color;
    }
    return const Color(0xFFB97A5E);
  }

  @override
  ShapeLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    List<ShapeItem>? contents,
  }) {
    return ShapeLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      contents: contents ?? this.contents,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  ShapeLayer duplicated() => ShapeLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        contents: contents,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Precomp (spec AM2-formas-3d D3): grupo com camadas proprias e tempo
/// proprio (filhos usam tempo local ao grupo). Transform, opacidade,
/// blend e efeitos do grupo aplicam ao conjunto ja composto.
class GroupLayer extends Layer {
  GroupLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    List<Layer>? children,
    this.sourceDuration,
    this.timeRemap,
    this.collapse = false,
    this.clipToComp = true,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  }) : children = List.unmodifiable(children ?? const <Layer>[]);

  /// Ordem: indice 0 e a camada mais acima (como na composicao raiz).
  final List<Layer> children;

  /// PRECOMP — a duracao INTERNA, que pode ser diferente da barra na
  /// linha do tempo de fora. Uma animacao de 10 s pode aparecer numa
  /// barra de 3 s (e ai so os 3 primeiros segundos entram) ou de 30 s
  /// (e o resto fica congelado no ultimo quadro).
  final Duration? sourceDuration;

  /// REMAPEAR TEMPO da precomp: anima QUAL instante do conteudo aparece
  /// agora. Congelar, voltar de tras para frente, rampa de velocidade —
  /// tudo com keyframe de tempo, como no After Effects.
  final AnimatedDouble? timeRemap;

  /// COLAPSAR TRANSFORMACOES: a precomp deixa de ter quadro proprio e os
  /// filhos passam a compor direto com o pai. E o que evita a forma
  /// vetorial pixelar quando a precomp e ampliada.
  final bool collapse;

  /// Recorta no tamanho da composicao. Desligado, o que passa da borda
  /// continua aparecendo.
  final bool clipToComp;

  /// Duracao interna efetiva.
  Duration get innerDuration => sourceDuration ?? duration;

  /// Que instante do CONTEUDO aparece no instante local [local].
  ///
  /// Sem remapeamento e a identidade. Com remapeamento, o valor da
  /// trilha em segundos — e nunca negativo, porque nao existe conteudo
  /// antes do comeco.
  Duration contentTimeAt(Duration local) {
    final r = timeRemap;
    if (r == null) return local;
    final us = (r.valueAt(local) * 1000000).round();
    return Duration(microseconds: us < 0 ? 0 : us);
  }

  @override
  GroupLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    List<Layer>? children,
    Duration? sourceDuration,
    AnimatedDouble? timeRemap,
    bool? collapse,
    bool? clipToComp,
  }) {
    return GroupLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      children: children ?? this.children,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      timeRemap: timeRemap ?? this.timeRemap,
      collapse: collapse ?? this.collapse,
      clipToComp: clipToComp ?? this.clipToComp,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  GroupLayer duplicated() => GroupLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        children: [for (final c in children) c.duplicated()],
        sourceDuration: sourceDuration,
        timeRemap: timeRemap,
        collapse: collapse,
        clipToComp: clipToComp,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Camada de legendas: UMA camada com muitos cues (spec NLE §6.5).
class CaptionLayer extends Layer {
  CaptionLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    List<Cue>? cues,
    this.style = const CaptionStyle(),
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  }) : cues = List.unmodifiable(cues ?? const <Cue>[]);

  final List<Cue> cues;
  final CaptionStyle style;

  Cue? cueAt(Duration local) => activeCueAt(cues, local);

  @override
  CaptionLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    List<Cue>? cues,
    CaptionStyle? style,
  }) {
    return CaptionLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      cues: cues ?? this.cues,
      style: style ?? this.style,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  CaptionLayer duplicated() => CaptionLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        cues: cues,
        style: style,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

class AudioLayer extends Layer {
  AudioLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    required this.sourcePath,
    this.sourceOffset = Duration.zero,
    this.volume = 1.0,
    this.audio = const AudioSpec(),
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  final String sourcePath;

  /// PONTO DE ENTRADA no arquivo. Cortar um trecho do meio de uma
  /// locucao move o inicio da fonte do pedaco de tras — sem isso o
  /// pedaco repete o mesmo audio em vez de continuar de onde parou.
  final Duration sourceOffset;

  final double volume;

  /// Fade, ganho, mudo e ducking desta trilha.
  final AudioSpec audio;

  @override
  AudioLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
    double? volume,
    AudioSpec? audio,
    Duration? sourceOffset,
  }) {
    return AudioLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      sourcePath: sourcePath,
      sourceOffset: sourceOffset ?? this.sourceOffset,
      volume: volume ?? this.volume,
      audio: audio ?? this.audio,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  AudioLayer duplicated() => AudioLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        sourcePath: sourcePath,
        sourceOffset: sourceOffset,
        volume: volume,
        audio: audio,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Objeto nulo (como no AE): camada invisivel na exportacao, desenhada como
/// wireframe no editor. Vire "pai" de outras camadas (vinculo de parenting)
/// para mover TUDO junto — inclusive em 3D.
class NullLayer extends Layer {
  NullLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    this.grid,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  @override
  NullLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return NullLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      grid: grid,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  /// Modulo Grid (spec AM2-modulo-grid): rig de grade que vive no nulo.
  final GridRig? grid;

  /// Keyframes do modulo Grade aparecem na barra do nulo na timeline —
  /// TODAS as trilhas (cada parametro tem a sua).
  @override
  Set<int> get moduleTimesUs {
    final g = grid;
    if (g == null) return const <int>{};
    final p = g.proximity;
    return {
      ..._times(g.transition.keyframes),
      ..._times(g.spacingX.keyframes),
      ..._times(g.spacingY.keyframes),
      ..._times(g.radius.keyframes),
      ..._times(g.gridRotationDeg.keyframes),
      ..._times(g.twistDeg.keyframes),
      ..._times(g.staggerDeg.keyframes),
      ..._times(g.zDepth.keyframes),
      ..._times(g.scaleFront.keyframes),
      ..._times(g.scaleBack.keyframes),
      ..._times(g.randomOffset.keyframes),
      if (p != null) ...{
        ..._times(p.effector.keyframes),
        ..._times(p.effectorZ.keyframes),
        ..._times(p.radius.keyframes),
        ..._times(p.falloff.keyframes),
        ..._times(p.attract.keyframes),
      },
    };
  }

  /// Substitui o rig (aceita null para remover a grade).
  NullLayer withGrid(GridRig? grid) => NullLayer(
        id: id,
        name: name,
        startTime: startTime,
        duration: duration,
        grid: grid,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: effects,
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );

  @override
  NullLayer duplicated() => NullLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        grid: grid,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Sistema de particulas 3D (estilo CC Particle World do AE): o emissor e a
/// propria camada; a simulacao e funcao PURA de (seed, indice, tempo) —
/// scrub-estavel, nada acumula estado entre frames. Cada particula nasce
/// com velocidade/fase/profundidade proprias derivadas do seed; a camada
/// inteira pode ser movida individualmente ou por um objeto nulo 3D (pai).
class ParticlesLayer extends Layer {
  ParticlesLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    this.count = 90,
    this.seed = 7,
    this.speed = 40,
    this.spreadDeg = 360,
    this.directionDeg = -90,
    this.gravity = 0,
    this.size = 26,
    this.lifetimeMs = 4000,
    this.depth = 1400,
    this.emitW = 980,
    this.emitH = 980,
    this.twinkle = true,
    this.color = const Color(0xFFFF3B52),
    this.star = true,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  /// Numero de particulas vivas por ciclo.
  final int count;
  final int seed;

  /// Velocidade inicial (px/s), direcao media e abertura do cone (graus).
  final double speed;
  final double spreadDeg;
  final double directionDeg;

  /// Gravidade (px/s^2, positivo = para baixo).
  final double gravity;

  /// Tamanho base da particula (px) e vida (ms).
  final double size;
  final int lifetimeMs;

  /// Espalhamento em Z: cada particula nasce com profundidade propria e
  /// ganha perspectiva (3D de verdade na ordenacao visual).
  final double depth;

  /// Area do emissor (estilo CC Particle World): 0 = ponto; maior = as
  /// particulas nascem espalhadas num retangulo em volta do centro.
  final double emitW;
  final double emitH;

  /// Cintilar: alfa oscila por particula (fase propria, deterministica).
  final bool twinkle;

  final Color color;

  /// true = sparkles de 4 pontas; false = pontos.
  final bool star;

  ParticlesLayer copyParticles({
    int? count,
    int? seed,
    double? speed,
    double? spreadDeg,
    double? directionDeg,
    double? gravity,
    double? size,
    int? lifetimeMs,
    double? depth,
    double? emitW,
    double? emitH,
    bool? twinkle,
    Color? color,
    bool? star,
  }) {
    return ParticlesLayer(
      id: id,
      name: name,
      startTime: startTime,
      duration: duration,
      count: count ?? this.count,
      seed: seed ?? this.seed,
      speed: speed ?? this.speed,
      spreadDeg: spreadDeg ?? this.spreadDeg,
      directionDeg: directionDeg ?? this.directionDeg,
      gravity: gravity ?? this.gravity,
      size: size ?? this.size,
      lifetimeMs: lifetimeMs ?? this.lifetimeMs,
      depth: depth ?? this.depth,
      emitW: emitW ?? this.emitW,
      emitH: emitH ?? this.emitH,
      twinkle: twinkle ?? this.twinkle,
      color: color ?? this.color,
      star: star ?? this.star,
      position: position,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
      rotationX: rotationX,
      rotationY: rotationY,
      opacity: opacity,
      skewX: skewX,
      skewY: skewY,
      pivot: pivot,
      blendMode: blendMode,
      is3D: is3D,
      positionZ: positionZ,
      effects: effects,
    );
  }

  @override
  ParticlesLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return ParticlesLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      count: count,
      seed: seed,
      speed: speed,
      spreadDeg: spreadDeg,
      directionDeg: directionDeg,
      gravity: gravity,
      size: size,
      lifetimeMs: lifetimeMs,
      depth: depth,
      emitW: emitW,
      emitH: emitH,
      twinkle: twinkle,
      color: color,
      star: star,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  ParticlesLayer duplicated() => ParticlesLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        count: count,
        seed: seed,
        speed: speed,
        spreadDeg: spreadDeg,
        directionDeg: directionDeg,
        gravity: gravity,
        size: size,
        lifetimeMs: lifetimeMs,
        depth: depth,
        emitW: emitW,
        emitH: emitH,
        twinkle: twinkle,
        color: color,
        star: star,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Elemento 3D nativo: um solido (cubo, esfera, diamante...) gerado por
/// codigo e girado DE VERDADE no espaco — os vertices sao rotacionados e
/// projetados por face dentro do pintor, como as particulas. Vinculado a
/// um nulo 3D (pai), herda a rotacao da cadeia inteira.
class Element3DLayer extends Layer {
  Element3DLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    this.kind = Element3DKind.cube,
    this.size = 200,
    this.color = const Color(0xFF7C62FF),
    this.edges = true,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  final Element3DKind kind;

  /// Meia-extensao do solido em px logicos (a malha e unitaria).
  final double size;

  final Color color;

  /// Tracar as arestas das faces (look tecnico).
  final bool edges;

  Element3DLayer copyElement3D({
    Element3DKind? kind,
    double? size,
    Color? color,
    bool? edges,
  }) {
    return Element3DLayer(
      id: id,
      name: name,
      startTime: startTime,
      duration: duration,
      kind: kind ?? this.kind,
      size: size ?? this.size,
      color: color ?? this.color,
      edges: edges ?? this.edges,
      position: position,
      scaleX: scaleX,
      scaleY: scaleY,
      rotation: rotation,
      rotationX: rotationX,
      rotationY: rotationY,
      opacity: opacity,
      skewX: skewX,
      skewY: skewY,
      pivot: pivot,
      blendMode: blendMode,
      is3D: is3D,
      positionZ: positionZ,
      effects: effects,
      masks: masks,
      matteMode: matteMode,
      matteSourceId: matteSourceId,
    );
  }

  @override
  Element3DLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return Element3DLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      kind: kind,
      size: size,
      color: color,
      edges: edges,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  Element3DLayer duplicated() => Element3DLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        kind: kind,
        size: size,
        color: color,
        edges: edges,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// CONTEINER CENA 3D (spec AUREA-cena-3d): por FORA e uma camada do
/// compositor; por DENTRO tem grafo de cena, camera e um renderizador
/// proprio que ordena por triangulo — o que resolve interpenetracao,
/// impossivel com o algoritmo do pintor por camada.
///
/// A camada 3D comum (planos no espaco) continua existindo para 2.5D:
/// esta nao a substitui.
class Scene3DLayer extends Layer {
  Scene3DLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    Scene3D? scene,
    Camera3D? camera,
    this.view = SceneView.camera,
    this.showHelpers = true,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  })  : scene = scene ?? const Scene3D(),
        camera = camera ?? _defaultCamera();

  static Camera3D _defaultCamera() => Camera3D();

  final Scene3D scene;
  final Camera3D camera;

  /// Vista mostrada no preview (camera ativa ou ortografica).
  final SceneView view;

  /// Ajudas de cena: grade do chao, frustum, eixos. NUNCA renderizam na
  /// exportacao.
  final bool showHelpers;

  Scene3DLayer withScene(Scene3D s) => copyScene(scene: s);
  Scene3DLayer withCamera(Camera3D c) => copyScene(camera: c);

  Scene3DLayer copyScene({
    Scene3D? scene,
    Camera3D? camera,
    SceneView? view,
    bool? showHelpers,
  }) =>
      Scene3DLayer(
        id: id,
        name: name,
        startTime: startTime,
        duration: duration,
        scene: scene ?? this.scene,
        camera: camera ?? this.camera,
        view: view ?? this.view,
        showHelpers: showHelpers ?? this.showHelpers,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: effects,
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );

  /// Keyframes da cena e da camera aparecem na barra da camada.
  @override
  Set<int> get moduleTimesUs {
    final out = <int>{};
    for (final n in scene.nodes) {
      out
        ..addAll(_times(n.x.keyframes))
        ..addAll(_times(n.y.keyframes))
        ..addAll(_times(n.z.keyframes))
        ..addAll(_times(n.rotX.keyframes))
        ..addAll(_times(n.rotY.keyframes))
        ..addAll(_times(n.rotZ.keyframes))
        ..addAll(_times(n.scale.keyframes));
    }
    out
      ..addAll(_times(camera.posX.keyframes))
      ..addAll(_times(camera.posY.keyframes))
      ..addAll(_times(camera.posZ.keyframes))
      ..addAll(_times(camera.poiX.keyframes))
      ..addAll(_times(camera.poiY.keyframes))
      ..addAll(_times(camera.poiZ.keyframes))
      ..addAll(_times(camera.focalLength.keyframes))
      ..addAll(_times(camera.rotY.keyframes));
    return out;
  }

  @override
  Scene3DLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return Scene3DLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      scene: scene,
      camera: camera,
      view: view,
      showHelpers: showHelpers,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  Scene3DLayer duplicated() => Scene3DLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        scene: scene,
        camera: camera,
        view: view,
        showHelpers: showHelpers,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}

/// Camada de AJUSTE (spec AUREA-atualizacao-2 §1): aplica sua pilha de
/// efeitos ao COMPOSTO de tudo que esta abaixo dela na pilha. Com
/// mascaras proprias corrige so uma regiao (com feather); a opacidade
/// dosa a mistura entre ajustado e original; o blend devolve o resultado
/// em Multiply/Screen/etc. Dentro de um grupo, afeta so o grupo.
/// Pilha vazia nao muda um pixel (I2).
class AdjustmentLayer extends Layer {
  AdjustmentLayer({
    super.id,
    required super.name,
    required super.startTime,
    required super.duration,
    super.position,
    super.scaleX,
    super.scaleY,
    super.rotation,
    super.rotationX,
    super.rotationY,
    super.opacity,
    super.skewX,
    super.skewY,
    super.pivot,
    super.blendMode,
    super.customBlend,
    super.is3D,
    super.positionZ,
    super.effects,
    super.masks,
    super.matteMode,
    super.matteSourceId,
  });

  @override
  AdjustmentLayer copyLayer({
    String? name,
    Duration? startTime,
    Duration? duration,
    AnimatedOffset? position,
    AnimatedDouble? scaleX,
    AnimatedDouble? scaleY,
    AnimatedDouble? rotation,
    AnimatedDouble? rotationX,
    AnimatedDouble? rotationY,
    AnimatedDouble? opacity,
    AnimatedDouble? skewX,
    AnimatedDouble? skewY,
    AnimatedOffset? pivot,
    BlendMode? blendMode,
    AureaBlend? customBlend,
    bool clearCustomBlend = false,
    bool? is3D,
    AnimatedDouble? positionZ,
    List<EffectInstance>? effects,
    List<LayerMask>? masks,
    MatteMode? matteMode,
    String? matteSourceId,
  }) {
    return AdjustmentLayer(
      id: id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      position: position ?? this.position,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      opacity: opacity ?? this.opacity,
      skewX: skewX ?? this.skewX,
      skewY: skewY ?? this.skewY,
      pivot: pivot ?? this.pivot,
      blendMode: blendMode ?? this.blendMode,
      customBlend:
          clearCustomBlend ? null : (customBlend ?? this.customBlend),
      is3D: is3D ?? this.is3D,
      positionZ: positionZ ?? this.positionZ,
      effects: effects ?? this.effects,
      masks: masks ?? this.masks,
      matteMode: matteMode ?? this.matteMode,
      matteSourceId: matteSourceId ?? this.matteSourceId,
    );
  }

  @override
  AdjustmentLayer duplicated() => AdjustmentLayer(
        name: name,
        startTime: startTime,
        duration: duration,
        position: position,
        scaleX: scaleX,
        scaleY: scaleY,
        rotation: rotation,
        rotationX: rotationX,
        rotationY: rotationY,
        opacity: opacity,
        skewX: skewX,
        skewY: skewY,
        pivot: pivot,
        blendMode: blendMode,
        customBlend: customBlend,
        is3D: is3D,
        positionZ: positionZ,
        effects: [for (final e in effects) e.duplicated()],
        masks: masks,
        matteMode: matteMode,
        matteSourceId: matteSourceId,
      );
}
