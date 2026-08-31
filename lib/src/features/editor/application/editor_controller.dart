import 'dart:io';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../media/application/media_import_service.dart';
import '../domain/caption.dart';
import '../domain/effect.dart';
import '../domain/element3d.dart';
import '../domain/grid_rig.dart';
import '../domain/keyframe.dart';
import '../domain/layer.dart';
import '../domain/mask.dart';
import '../domain/shape.dart';
import '../domain/text_animator.dart';
import '../domain/text_presets.dart';
import '../domain/video_project.dart';

export '../domain/video_project.dart' show LayerProp, PropertyLink;

/// Camada selecionada no editor (null = nada).
final selectedLayerProvider = StateProvider<String?>((ref) => null);

/// Selecao MULTIPLA (toque longo nas barras): a barra de acoes opera no
/// conjunto — agrupar, duplicar e excluir em lote.
final multiSelectProvider = StateProvider<Set<String>>((ref) => const {});

/// Estado central do editor: a composicao aberta e as operacoes sobre ela.
/// Toda mutacao passa por [_mutate], que alimenta o undo/redo.
class EditorController extends Notifier<VideoProject> {
  final List<VideoProject> _undoStack = [];
  final List<VideoProject> _redoStack = [];
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  VideoProject build() => VideoProject.empty('Novo projeto');

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Mutacoes continuas (arrasto de slider/regua) dentro desta janela sao
  /// coalescidas num unico passo de undo.
  void _mutate(VideoProject next) {
    final now = DateTime.now();
    if (now.difference(_lastPush) > const Duration(milliseconds: 450)) {
      _undoStack.add(state);
      if (_undoStack.length > 100) _undoStack.removeAt(0);
    }
    _lastPush = now;
    _redoStack.clear();
    state = next;
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(state);
    state = _undoStack.removeLast();
    _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(state);
    state = _redoStack.removeLast();
    _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  }

  void openProject(VideoProject project) {
    state = project;
    _undoStack.clear();
    _redoStack.clear();
    ref.read(selectedLayerProvider.notifier).state = null;
  }

  void renameProject(String name) => _mutate(state.copyWith(name: name));

  Offset get _center => Offset(state.outputWidth / 2, state.outputHeight / 2);

  // ---------------------------------------------------------------- camadas

  void _push(Layer layer) {
    _mutate(state.copyWith(layers: [layer, ...state.layers]));
    ref.read(selectedLayerProvider.notifier).state = layer.id;
  }

  void _replace(Layer layer) {
    _mutate(state.copyWith(layers: [
      for (final l in state.layers) l.id == layer.id ? layer : l,
    ]));
  }

  Layer? _layer(String id) => state.layerById(id);

  void addTextLayer(Duration at, {String text = 'Seu texto'}) {
    _push(TextLayer(
      name: text,
      startTime: at,
      duration: const Duration(seconds: 3),
      text: text,
      position: AnimatedOffset(_center),
    ));
  }

  void addShapeLayer(Duration at,
      {List<ShapeItem>? contents, String name = 'Forma'}) {
    final n = state.layers.whereType<ShapeLayer>().length + 1;
    _push(ShapeLayer(
      name: '$name $n',
      startTime: at,
      duration: const Duration(seconds: 3),
      contents: contents,
      position: AnimatedOffset(_center),
    ));
  }

  /// Insere um icone do Iconify como FORMA vetorial editavel (nunca
  /// imagem): Trim, Repeater, morph, gradiente e mascaras funcionam.
  void addIconLayer(Duration at, String pathData, String name) {
    _push(ShapeLayer(
      name: name,
      startTime: at,
      duration: const Duration(seconds: 3),
      contents: [
        ShapeSvgPath(pathData: pathData),
        ShapeFill(color: const Color(0xFFFFFFFF)),
      ],
      position: AnimatedOffset(_center),
    ));
  }

  void addImageLayer(Duration at, String path, String name) {
    _push(ImageLayer(
      name: name,
      startTime: at,
      duration: const Duration(seconds: 3),
      sourcePath: path,
      position: AnimatedOffset(_center),
    ));
  }

  String addVideoLayer(
      Duration at, String path, String name, Duration duration) {
    final layer = VideoLayer(
      name: name,
      startTime: at,
      duration: duration,
      sourcePath: path,
      position: AnimatedOffset(_center),
    );
    _push(layer);
    return layer.id;
  }

  Future<void> importVideoFromGallery(Duration at) async {
    final file =
        await ref.read(mediaImportServiceProvider).pickVideoFromGallery();
    if (file == null) return;
    // A camada entra NA HORA com duracao provisoria; a duracao real chega
    // do probe em background (inicializar um decoder travava o import).
    final id = addVideoLayer(at, file.path, file.name,
        const Duration(seconds: 4));
    _probeDuration(file.path).then((d) {
      final layer = _layer(id);
      if (layer is VideoLayer && d > Duration.zero) {
        _replace(layer.copyLayer(duration: d));
      }
    });
  }

  String addAudioLayer(
      Duration at, String path, String name, Duration duration) {
    final layer = AudioLayer(
      name: name,
      startTime: at,
      duration: duration,
      sourcePath: path,
      position: AnimatedOffset(_center),
    );
    _push(layer);
    return layer.id;
  }

  /// Importa AUDIO pelo seletor de arquivos; duracao real chega do probe
  /// em background (mesmo fluxo do video).
  Future<void> importAudioFile(Duration at) async {
    final file =
        await ref.read(mediaImportServiceProvider).pickAudioFile();
    if (file == null) return;
    final id = addAudioLayer(
        at, file.path, file.name, const Duration(seconds: 4));
    _probeDuration(file.path).then((d) {
      final layer = _layer(id);
      if (layer is AudioLayer && d > Duration.zero) {
        _replace(layer.copyLayer(duration: d));
      }
    });
  }

  /// Camada de ajuste: efeitos aplicados ao composto de tudo abaixo.
  void addAdjustmentLayer(Duration at) {
    final n = state.layers.whereType<AdjustmentLayer>().length + 1;
    _push(AdjustmentLayer(
      name: 'Ajuste $n',
      startTime: at,
      duration: const Duration(seconds: 5),
      position: AnimatedOffset(_center),
    ));
  }

  void addNullLayer(Duration at) {
    final n = state.layers.whereType<NullLayer>().length + 1;
    _push(NullLayer(
      name: 'Nulo $n',
      startTime: at,
      duration: const Duration(seconds: 5),
      is3D: true,
      position: AnimatedOffset(_center),
    ));
  }

  void addParticlesLayer(Duration at) {
    final n = state.layers.whereType<ParticlesLayer>().length + 1;
    _push(ParticlesLayer(
      name: 'Particulas $n',
      startTime: at,
      duration: const Duration(seconds: 5),
      is3D: true,
      position: AnimatedOffset(_center),
    ));
  }

  /// Edita parametros do sistema de particulas.
  void updateParticles(String id, ParticlesLayer Function(ParticlesLayer) fn) {
    final layer = _layer(id);
    if (layer is! ParticlesLayer) return;
    _replace(fn(layer));
  }

  /// Elemento 3D nativo (cubo, esfera, diamante...): solido girado de
  /// verdade no espaco, vinculavel a um nulo como qualquer camada.
  void addElement3DLayer(Duration at, Element3DKind kind) {
    final n = state.layers.whereType<Element3DLayer>().length + 1;
    _push(Element3DLayer(
      name: '${element3DLabel(kind)} $n',
      startTime: at,
      duration: const Duration(seconds: 5),
      kind: kind,
      is3D: true,
      position: AnimatedOffset(_center),
    ));
  }

  void updateElement3D(
      String id, Element3DLayer Function(Element3DLayer) fn) {
    final layer = _layer(id);
    if (layer is! Element3DLayer) return;
    _replace(fn(layer));
  }

  Future<void> importImageFromGallery(Duration at) async {
    final file =
        await ref.read(mediaImportServiceProvider).pickImageFromGallery();
    if (file == null) return;
    addImageLayer(at, file.path, file.name);
  }

  void removeLayer(String id) {
    _mutate(state.copyWith(
      layers: state.layers.where((l) => l.id != id).toList(),
    ));
    if (ref.read(selectedLayerProvider) == id) {
      ref.read(selectedLayerProvider.notifier).state = null;
    }
  }

  /// Exclui VARIAS camadas numa unica mutacao (um "Desfazer" restaura
  /// tudo — efeitos, keyframes e vinculos intactos).
  void removeLayers(Iterable<String> ids) {
    final set = ids.toSet();
    if (set.isEmpty) return;
    _mutate(state.copyWith(
      layers: state.layers.where((l) => !set.contains(l.id)).toList(),
    ));
    if (set.contains(ref.read(selectedLayerProvider))) {
      ref.read(selectedLayerProvider.notifier).state = null;
    }
    ref.read(multiSelectProvider.notifier).state = const {};
  }

  void duplicateLayer(String id) {
    final layer = _layer(id);
    if (layer == null) return;
    final copy = layer.duplicated();
    final idx = state.layers.indexWhere((l) => l.id == id);
    final layers = [...state.layers]..insert(idx, copy);
    _mutate(state.copyWith(layers: layers));
    ref.read(selectedLayerProvider.notifier).state = copy.id;
  }

  void reorderLayer(String id, int delta) {
    final layers = [...state.layers];
    final idx = layers.indexWhere((l) => l.id == id);
    if (idx < 0) return;
    final to = (idx + delta).clamp(0, layers.length - 1);
    if (to == idx) return;
    final layer = layers.removeAt(idx);
    layers.insert(to, layer);
    _mutate(state.copyWith(layers: layers));
  }

  void selectNeighbor(int delta) {
    final id = ref.read(selectedLayerProvider);
    if (id == null || state.layers.isEmpty) return;
    final idx = state.layers.indexWhere((l) => l.id == id);
    final to = (idx + delta).clamp(0, state.layers.length - 1);
    ref.read(selectedLayerProvider.notifier).state = state.layers[to].id;
  }

  // ------------------------------------------------------------- tempo/trim

  void moveLayer(String id, Duration newStart) {
    final layer = _layer(id);
    if (layer == null) return;
    final start = newStart < Duration.zero ? Duration.zero : newStart;
    _replace(layer.copyLayer(startTime: start));
  }

  void trimLayerStart(String id, Duration newStart) {
    final layer = _layer(id);
    if (layer == null) return;
    var start = newStart < Duration.zero ? Duration.zero : newStart;
    final maxStart = layer.endTime - const Duration(milliseconds: 100);
    if (start > maxStart) start = maxStart;
    final delta = start - layer.startTime;
    if (layer is VideoLayer) {
      var offset = layer.sourceOffset + delta;
      if (offset < Duration.zero) offset = Duration.zero;
      _replace(layer.copyLayer(
        startTime: start,
        duration: layer.endTime - start,
        sourceOffset: offset,
      ));
    } else {
      _replace(layer.copyLayer(
        startTime: start,
        duration: layer.endTime - start,
      ));
    }
  }

  void trimLayerEnd(String id, Duration newEnd) {
    final layer = _layer(id);
    if (layer == null) return;
    var duration = newEnd - layer.startTime;
    if (duration < const Duration(milliseconds: 100)) {
      duration = const Duration(milliseconds: 100);
    }
    _replace(layer.copyLayer(duration: duration));
  }

  void splitLayer(String id, Duration at) {
    final layer = _layer(id);
    if (layer == null || !layer.activeAt(at)) return;
    final firstDur = at - layer.startTime;
    final secondDur = layer.endTime - at;
    if (firstDur < const Duration(milliseconds: 100) ||
        secondDur < const Duration(milliseconds: 100)) {
      return;
    }

    final first = layer.copyLayer(duration: firstDur);
    Layer second = layer.duplicated().copyLayer(
          startTime: at,
          duration: secondDur,
        );
    if (second is VideoLayer && layer is VideoLayer) {
      second = second.copyLayer(sourceOffset: layer.sourceOffset + firstDur);
    }

    final layers = <Layer>[];
    for (final l in state.layers) {
      if (l.id == id) {
        layers.add(second);
        layers.add(first);
      } else {
        layers.add(l);
      }
    }
    _mutate(state.copyWith(layers: layers));
    ref.read(selectedLayerProvider.notifier).state = second.id;
  }

  // -------------------------------------------------- transform + keyframes

  void editPosition(String id, Duration globalTime, Offset value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      position: layer.position.edited(layer.localTime(globalTime), value),
    ));
  }

  void editScaleUniform(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final t = layer.localTime(globalTime);
    _replace(layer.copyLayer(
      scaleX: layer.scaleX.edited(t, value),
      scaleY: layer.scaleY.edited(t, value),
    ));
  }

  void editScaleX(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      scaleX: layer.scaleX.edited(layer.localTime(globalTime), value),
    ));
  }

  void editScaleY(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      scaleY: layer.scaleY.edited(layer.localTime(globalTime), value),
    ));
  }

  /// Rotacao e uma propriedade GLOBAL de 3 eixos: com animacao ligada,
  /// editar qualquer eixo (X, Y ou Z) marca keyframe nos TRES ao mesmo
  /// tempo — os eixos ficam sempre sincronizados na timeline.
  void _editRotationAxis(String id, Duration globalTime,
      {double? z, double? x, double? y}) {
    final layer = _layer(id);
    if (layer == null) return;
    final t = layer.localTime(globalTime);
    final anyAnimated = layer.rotation.isAnimated ||
        layer.rotationX.isAnimated ||
        layer.rotationY.isAnimated;
    if (!anyAnimated) {
      _replace(layer.copyLayer(
        rotation: z == null ? null : layer.rotation.withBase(z),
        rotationX: x == null ? null : layer.rotationX.withBase(x),
        rotationY: y == null ? null : layer.rotationY.withBase(y),
      ));
      return;
    }
    AnimatedDouble key(AnimatedDouble track, double? v) =>
        track.withKeyframe(t, v ?? track.valueAt(t), track.easeAt(t));
    _replace(layer.copyLayer(
      rotation: key(layer.rotation, z),
      rotationX: key(layer.rotationX, x),
      rotationY: key(layer.rotationY, y),
    ));
  }

  void editRotation(String id, Duration globalTime, double value) =>
      _editRotationAxis(id, globalTime, z: value);

  void editRotationX(String id, Duration globalTime, double value) =>
      _editRotationAxis(id, globalTime, x: value);

  void editRotationY(String id, Duration globalTime, double value) =>
      _editRotationAxis(id, globalTime, y: value);

  void editOpacity(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      opacity:
          layer.opacity.edited(layer.localTime(globalTime), value.clamp(0, 1)),
    ));
  }

  void editSkewX(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      skewX: layer.skewX.edited(layer.localTime(globalTime), value),
    ));
  }

  void editSkewY(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      skewY: layer.skewY.edited(layer.localTime(globalTime), value),
    ));
  }

  void editPivot(String id, Duration globalTime, Offset value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      pivot: layer.pivot.edited(layer.localTime(globalTime), value),
    ));
  }

  void setBlendMode(String id, BlendMode mode) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(blendMode: mode));
  }

  /// Reseta a propriedade: limpa keyframes e volta ao valor padrao.
  void resetProp(String id, LayerProp prop) {
    final layer = _layer(id);
    if (layer == null) return;
    switch (prop) {
      case LayerProp.position:
        _replace(layer.copyLayer(position: AnimatedOffset(_center)));
      case LayerProp.scale:
        _replace(layer.copyLayer(
            scaleX: AnimatedDouble(1), scaleY: AnimatedDouble(1)));
      case LayerProp.rotation:
        _replace(layer.copyLayer(
          rotation: AnimatedDouble(0),
          rotationX: AnimatedDouble(0),
          rotationY: AnimatedDouble(0),
        ));
      case LayerProp.opacity:
        _replace(layer.copyLayer(opacity: AnimatedDouble(1)));
      case LayerProp.skew:
        _replace(layer.copyLayer(
            skewX: AnimatedDouble(0), skewY: AnimatedDouble(0)));
      case LayerProp.pivot:
        _replace(layer.copyLayer(pivot: AnimatedOffset(Offset.zero)));
      case LayerProp.parent:
        break;
    }
  }

  /// Tempos locais de keyframe da propriedade (para ‹◆›).
  List<Duration> propKeyframeTimes(Layer layer, LayerProp prop) {
    final us = switch (prop) {
      LayerProp.position => layer.positionTimesUs,
      LayerProp.scale => layer.scaleTimesUs,
      LayerProp.rotation => layer.rotationTimesUs,
      LayerProp.opacity => layer.opacityTimesUs,
      LayerProp.skew => layer.skewTimesUs,
      LayerProp.pivot => layer.pivotTimesUs,
      LayerProp.parent => const <int>{},
    };
    final list = us.toList()..sort();
    return [for (final u in list) Duration(microseconds: u)];
  }

  void toggleKeyframe(String id, Duration globalTime, LayerProp prop) {
    final layer = _layer(id);
    if (layer == null) return;
    final t = layer.localTime(globalTime);

    AnimatedDouble tog(AnimatedDouble track) => track.hasKeyframeAt(t)
        ? track.withoutKeyframe(t)
        : track.withKeyframe(t, track.valueAt(t));
    AnimatedOffset togO(AnimatedOffset track) => track.hasKeyframeAt(t)
        ? track.withoutKeyframe(t)
        : track.withKeyframe(t, track.valueAt(t));

    switch (prop) {
      case LayerProp.position:
        _replace(layer.copyLayer(position: togO(layer.position)));
      case LayerProp.scale:
        _replace(layer.copyLayer(
            scaleX: tog(layer.scaleX), scaleY: tog(layer.scaleY)));
      case LayerProp.rotation:
        // Keyframe de rotacao e GLOBAL: marca/desmarca X, Y e Z juntos,
        // seja qual for o eixo que o usuario esta usando.
        _replace(layer.copyLayer(
          rotation: tog(layer.rotation),
          rotationX: tog(layer.rotationX),
          rotationY: tog(layer.rotationY),
        ));
      case LayerProp.opacity:
        _replace(layer.copyLayer(opacity: tog(layer.opacity)));
      case LayerProp.skew:
        _replace(
            layer.copyLayer(skewX: tog(layer.skewX), skewY: tog(layer.skewY)));
      case LayerProp.pivot:
        _replace(layer.copyLayer(pivot: togO(layer.pivot)));
      case LayerProp.parent:
        break;
    }
  }

  void setSegmentEase(
      String id, LayerProp prop, Duration segStartLocal, Easing ease) {
    final layer = _layer(id);
    if (layer == null) return;
    switch (prop) {
      case LayerProp.position:
        _replace(layer.copyLayer(
            position: layer.position.withEase(segStartLocal, ease)));
      case LayerProp.scale:
        _replace(layer.copyLayer(
          scaleX: layer.scaleX.withEase(segStartLocal, ease),
          scaleY: layer.scaleY.withEase(segStartLocal, ease),
        ));
      case LayerProp.rotation:
        _replace(layer.copyLayer(
          rotation: layer.rotation.withEase(segStartLocal, ease),
          rotationX: layer.rotationX.withEase(segStartLocal, ease),
          rotationY: layer.rotationY.withEase(segStartLocal, ease),
        ));
      case LayerProp.opacity:
        _replace(layer.copyLayer(
            opacity: layer.opacity.withEase(segStartLocal, ease)));
      case LayerProp.skew:
        _replace(layer.copyLayer(
          skewX: layer.skewX.withEase(segStartLocal, ease),
          skewY: layer.skewY.withEase(segStartLocal, ease),
        ));
      case LayerProp.pivot:
        _replace(
            layer.copyLayer(pivot: layer.pivot.withEase(segStartLocal, ease)));
      case LayerProp.parent:
        break;
    }
  }

  void applyEaseToAllSegments(String id, LayerProp prop, Easing ease) {
    final layer = _layer(id);
    if (layer == null) return;
    switch (prop) {
      case LayerProp.position:
        _replace(layer.copyLayer(position: layer.position.withEaseAll(ease)));
      case LayerProp.scale:
        _replace(layer.copyLayer(
          scaleX: layer.scaleX.withEaseAll(ease),
          scaleY: layer.scaleY.withEaseAll(ease),
        ));
      case LayerProp.rotation:
        _replace(layer.copyLayer(
          rotation: layer.rotation.withEaseAll(ease),
          rotationX: layer.rotationX.withEaseAll(ease),
          rotationY: layer.rotationY.withEaseAll(ease),
        ));
      case LayerProp.opacity:
        _replace(layer.copyLayer(opacity: layer.opacity.withEaseAll(ease)));
      case LayerProp.skew:
        _replace(layer.copyLayer(
          skewX: layer.skewX.withEaseAll(ease),
          skewY: layer.skewY.withEaseAll(ease),
        ));
      case LayerProp.pivot:
        _replace(layer.copyLayer(pivot: layer.pivot.withEaseAll(ease)));
      case LayerProp.parent:
        break;
    }
  }

  // --------------------------------------------------------------- efeitos

  void addEffect(String layerId, EffectType type) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(
      effects: [...layer.effects, EffectInstance(type: type)],
    ));
  }

  void removeEffect(String layerId, String effectId) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(
      effects: layer.effects.where((e) => e.id != effectId).toList(),
    ));
  }

  void reorderEffect(String layerId, String effectId, int delta) {
    final layer = _layer(layerId);
    if (layer == null) return;
    final effects = [...layer.effects];
    final idx = effects.indexWhere((e) => e.id == effectId);
    if (idx < 0) return;
    final to = (idx + delta).clamp(0, effects.length - 1);
    if (to == idx) return;
    final e = effects.removeAt(idx);
    effects.insert(to, e);
    _replace(layer.copyLayer(effects: effects));
  }

  void toggleEffectEnabled(String layerId, String effectId) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(effects: [
      for (final e in layer.effects)
        e.id == effectId ? e.copyWith(enabled: !e.enabled) : e,
    ]));
  }

  /// Edita valor do parametro no tempo global (auto-keyframe se anima).
  void editEffectParam(String layerId, String effectId, String key,
      Duration globalTime, double value) {
    final layer = _layer(layerId);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _replace(layer.copyLayer(effects: [
      for (final e in layer.effects)
        e.id == effectId ? e.withParamEdited(key, local, value) : e,
    ]));
  }

  /// Diamante do parametro do efeito.
  void toggleEffectParamKeyframe(
      String layerId, String effectId, String key, Duration globalTime) {
    final layer = _layer(layerId);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _replace(layer.copyLayer(effects: [
      for (final e in layer.effects)
        e.id == effectId ? e.withParamKeyframeToggled(key, local) : e,
    ]));
  }

  void setEffectColor(String layerId, String effectId, Color color) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(effects: [
      for (final e in layer.effects)
        e.id == effectId ? e.copyWith(color: color) : e,
    ]));
  }

  // ---------------------------------------------------------- modulo grid

  /// Define os assets da grade do nulo (cria o rig se preciso).
  void setGridAssets(String nullId, List<String> assetIds) {
    final layer = _layer(nullId);
    if (layer is! NullLayer) return;
    final rig = (layer.grid ?? GridRig()).copyWith(assets: assetIds);
    _replace(layer.withGrid(rig));
  }

  void removeGrid(String nullId) {
    final layer = _layer(nullId);
    if (layer is! NullLayer) return;
    _replace(layer.withGrid(null));
  }

  void updateGrid(String nullId, GridRig Function(GridRig) fn) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    _replace(layer.withGrid(fn(layer.grid!)));
  }

  /// Easing do SEGMENTO de uma trilha da grade (curve editor por
  /// parametro — inclui 'transition', o morph).
  void setGridSegmentEase(
      String nullId, String key, Duration segStartLocal, Easing ease) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final track = gridTrackOf(layer.grid!, key);
    if (track == null) return;
    _replace(layer.withGrid(gridWithTrack(
        layer.grid!, key, track.withEase(segStartLocal, ease))));
  }

  void applyEaseToAllGridSegments(String nullId, String key, Easing ease) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final track = gridTrackOf(layer.grid!, key);
    if (track == null) return;
    _replace(layer
        .withGrid(gridWithTrack(layer.grid!, key, track.withEaseAll(ease))));
  }

  /// Nulo CONTROLADOR da grade: o transform dele modula os parametros
  /// (escala -> espacamento/raio, rotZ -> rotacao, rotY -> twist).
  void setGridController(String nullId, String? controllerId) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    _replace(layer.withGrid(controllerId == null
        ? layer.grid!.copyWith(clearController: true)
        : layer.grid!.copyWith(controllerId: controllerId)));
  }

  AnimatedDouble? _gridTrack(GridRig g, String key) => switch (key) {
        'spacingX' => g.spacingX,
        'spacingY' => g.spacingY,
        'radius' => g.radius,
        'rotation' => g.gridRotationDeg,
        'twist' => g.twistDeg,
        'stagger' => g.staggerDeg,
        'zDepth' => g.zDepth,
        'scaleFront' => g.scaleFront,
        'scaleBack' => g.scaleBack,
        'randomOffset' => g.randomOffset,
        _ => null,
      };

  GridRig _gridWith(GridRig g, String key, AnimatedDouble v) =>
      switch (key) {
        'spacingX' => g.copyWith(spacingX: v),
        'spacingY' => g.copyWith(spacingY: v),
        'radius' => g.copyWith(radius: v),
        'rotation' => g.copyWith(gridRotationDeg: v),
        'twist' => g.copyWith(twistDeg: v),
        'stagger' => g.copyWith(staggerDeg: v),
        'zDepth' => g.copyWith(zDepth: v),
        'scaleFront' => g.copyWith(scaleFront: v),
        'scaleBack' => g.copyWith(scaleBack: v),
        'randomOffset' => g.copyWith(randomOffset: v),
        _ => g,
      };

  /// Edita um parametro da grade com AUTO-KEYFRAME quando ja anima —
  /// cada parametro tem sua propria trilha.
  void editGridParam(
      String nullId, String key, Duration globalTime, double value) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final local = layer.localTime(globalTime);
    final track = _gridTrack(layer.grid!, key);
    if (track == null) return;
    _replace(layer.withGrid(
        _gridWith(layer.grid!, key, track.edited(local, value))));
  }

  /// Diamante do parametro da grade: liga/desliga keyframe no playhead.
  void toggleGridParamKeyframe(
      String nullId, String key, Duration globalTime) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final local = layer.localTime(globalTime);
    final track = _gridTrack(layer.grid!, key);
    if (track == null) return;
    _replace(layer.withGrid(_gridWith(
      layer.grid!,
      key,
      track.hasKeyframeAt(local)
          ? track.withoutKeyframe(local)
          : track.withKeyframe(local, track.valueAt(local)),
    )));
  }

  /// Morph da grade: [transition] anima entre layouts pelo SEGMENTO de
  /// keyframe (1 -> 3 vai direto, sem passar pelo 2).
  void editGridTransition(String nullId, Duration globalTime, double v) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final local = layer.localTime(globalTime);
    _replace(layer.withGrid(layer.grid!
        .copyWith(transition: layer.grid!.transition.edited(local, v))));
  }

  void toggleGridTransitionKeyframe(String nullId, Duration globalTime) {
    final layer = _layer(nullId);
    if (layer is! NullLayer || layer.grid == null) return;
    final local = layer.localTime(globalTime);
    final track = layer.grid!.transition;
    _replace(layer.withGrid(layer.grid!.copyWith(
      transition: track.hasKeyframeAt(local)
          ? track.withoutKeyframe(local)
          : track.withKeyframe(local, track.valueAt(local)),
    )));
  }

  // -------------------------------------------------------------- mascaras

  void addMask(String layerId, LayerMask mask) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(masks: [...layer.masks, mask]));
  }

  void removeMask(String layerId, String maskId) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(
      masks: layer.masks.where((m) => m.id != maskId).toList(),
    ));
  }

  void updateMask(
      String layerId, String maskId, LayerMask Function(LayerMask) fn) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(masks: [
      for (final m in layer.masks) m.id == maskId ? fn(m) : m,
    ]));
  }

  void cycleMaskMode(String layerId, String maskId) {
    updateMask(layerId, maskId, (m) {
      final next =
          MaskMode.values[(m.mode.index + 1) % MaskMode.values.length];
      return m.copyWith(mode: next);
    });
  }

  void toggleMaskInverted(String layerId, String maskId) {
    updateMask(layerId, maskId, (m) => m.copyWith(inverted: !m.inverted));
  }

  /// Edita feather/expansao/opacidade da mascara com auto-keyframe.
  void editMaskParam(String layerId, String maskId, String param,
      Duration globalTime, double value) {
    final layer = _layer(layerId);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    updateMask(layerId, maskId, (m) {
      return switch (param) {
        'feather' => m.copyWith(feather: m.feather.edited(local, value)),
        'expansion' =>
          m.copyWith(expansion: m.expansion.edited(local, value)),
        'opacity' => m.copyWith(opacity: m.opacity.edited(local, value)),
        _ => m,
      };
    });
  }

  /// Keyframe do CAMINHO da mascara no tempo atual (PR-M1 aplicado).
  void toggleMaskPathKeyframe(
      String layerId, String maskId, Duration globalTime) {
    final layer = _layer(layerId);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    updateMask(layerId, maskId, (m) {
      return m.copyWith(
        path: m.path.hasKeyframeAt(local)
            ? m.path.withoutKeyframe(local)
            : m.path.withKeyframe(local, m.path.valueAt(local)),
      );
    });
  }

  // ----------------------------------------------------------------- matte

  /// Define o matte da camada (PR-M5): [sourceId] pode ser QUALQUER
  /// camada da cena; a fonte fica oculta automaticamente no render.
  void setMatte(String layerId, MatteMode mode, String? sourceId) {
    final layer = _layer(layerId);
    if (layer == null) return;
    _replace(layer.copyLayer(
      matteMode: mode,
      matteSourceId: sourceId,
    ));
  }

  /// Modo do Trim Paths: individual (cascata) ou continuo (PR-M8).
  void setTrimMode(String layerId, String itemId, bool individually) {
    _updateShape(layerId, (items) => [
          for (final i in items)
            if (i.id == itemId && i is TrimOperator)
              i.copyWith(individually: individually)
            else
              i,
        ]);
  }

  // -------------------------------------------------------------- legendas

  /// Cria uma camada de legendas: UMA camada, muitos cues.
  int addCaptionLayer(List<Cue> cues) {
    if (cues.isEmpty) return 0;
    final end = cues.last.end + const Duration(milliseconds: 300);
    _push(CaptionLayer(
      name: 'Legendas',
      startTime: Duration.zero,
      duration: end,
      cues: cues,
      position: AnimatedOffset(
          Offset(state.outputWidth / 2, state.outputHeight * 0.88)),
    ));
    return cues.length;
  }

  /// Camada de legendas a partir de um SRT colado/importado.
  void addCaptionLayerFromSrt(String srt) {
    addCaptionLayer(normalizeCues(parseSrt(srt)));
  }

  /// Primeira midia com audio do projeto (fonte da transcricao).
  String? firstTranscribableMediaPath() {
    for (final l in state.layers) {
      if (l is VideoLayer) return l.sourcePath;
      if (l is AudioLayer) return l.sourcePath;
    }
    return null;
  }

  /// Corrige o TEXTO de um cue (edicao manual trava o cue: uma nova
  /// transcricao nao sobrescreve o que voce corrigiu).
  void updateCueText(String layerId, String cueId, String text) {
    final layer = _layer(layerId);
    if (layer is! CaptionLayer) return;
    _replace(layer.copyLayer(cues: [
      for (final c in layer.cues)
        c.id == cueId
            ? c.copyWith(text: wrapCaptionText(text), locked: true)
            : c,
    ]));
  }

  void removeCue(String layerId, String cueId) {
    final layer = _layer(layerId);
    if (layer is! CaptionLayer) return;
    _replace(layer.copyLayer(
        cues: layer.cues.where((c) => c.id != cueId).toList()));
  }

  String? exportCaptionsSrt(String layerId) {
    final layer = _layer(layerId);
    if (layer is! CaptionLayer) return null;
    return serializeSrt(layer.cues);
  }

  // ------------------------------------------------ animadores de texto

  void _updateTextLayer(String id, TextLayer Function(TextLayer) fn) {
    final layer = _layer(id);
    if (layer is! TextLayer) return;
    _replace(fn(layer));
  }

  void _updateAnimator(
      String id, String animatorId, TextAnimator Function(TextAnimator) fn) {
    _updateTextLayer(id, (l) {
      return l.copyLayer(animators: [
        for (final a in l.animators) a.id == animatorId ? fn(a) : a,
      ]);
    });
  }

  /// Aplica um preset substituindo a pilha de animadores.
  void applyTextPreset(String id, TextPreset preset) {
    _updateTextLayer(
        id, (l) => l.copyLayer(animators: preset.build()));
  }

  void addTextAnimator(String id) {
    _updateTextLayer(id, (l) {
      final n = l.animators.length + 1;
      return l.copyLayer(animators: [
        ...l.animators,
        TextAnimator(name: 'Animador $n'),
      ]);
    });
  }

  void removeTextAnimator(String id, String animatorId) {
    _updateTextLayer(id, (l) {
      return l.copyLayer(animators: [
        for (final a in l.animators)
          if (a.id != animatorId) a,
      ]);
    });
  }

  void toggleTextAnimator(String id, String animatorId) {
    _updateAnimator(id, animatorId, (a) => a.copyWith(enabled: !a.enabled));
  }

  /// Chip de propriedade: adiciona se falta, remove se presente.
  void toggleAnimatorPropType(
      String id, String animatorId, TextAnimProp type) {
    _updateAnimator(id, animatorId, (a) {
      final has = a.properties.any((p) => p.type == type);
      return a.copyWith(
        properties: has
            ? [
                for (final p in a.properties)
                  if (p.type != type) p,
              ]
            : [...a.properties, AnimatorProperty(type: type)],
      );
    });
  }

  void editAnimatorPropValue(String id, String animatorId, String propId,
      Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateAnimator(id, animatorId, (a) {
      return a.copyWith(properties: [
        for (final p in a.properties)
          p.id == propId
              ? p.copyWith(value: p.value.edited(local, value))
              : p,
      ]);
    });
  }

  void toggleAnimatorPropKeyframe(
      String id, String animatorId, String propId, Duration globalTime) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateAnimator(id, animatorId, (a) {
      return a.copyWith(properties: [
        for (final p in a.properties)
          p.id == propId
              ? p.copyWith(
                  value: p.value.hasKeyframeAt(local)
                      ? p.value.withoutKeyframe(local)
                      : p.value.withKeyframe(local, p.value.valueAt(local)),
                )
              : p,
      ]);
    });
  }

  void addTextSelector(String id, String animatorId, {bool wiggly = false}) {
    _updateAnimator(id, animatorId, (a) {
      return a.copyWith(selectors: [
        ...a.selectors,
        if (wiggly) WigglySelector() else RangeSelector(),
      ]);
    });
  }

  void removeTextSelector(String id, String animatorId, String selectorId) {
    _updateAnimator(id, animatorId, (a) {
      final rest = [
        for (final s in a.selectors)
          if (s.id != selectorId) s,
      ];
      // Animador sem seletor nao seleciona nada; mantem ao menos um.
      return a.copyWith(
          selectors: rest.isEmpty ? [RangeSelector()] : rest);
    });
  }

  void _updateSelector(String id, String animatorId, String selectorId,
      TextSelector Function(TextSelector) fn) {
    _updateAnimator(id, animatorId, (a) {
      return a.copyWith(selectors: [
        for (final s in a.selectors) s.id == selectorId ? fn(s) : s,
      ]);
    });
  }

  void cycleSelectorMode(String id, String animatorId, String selectorId) {
    _updateSelector(id, animatorId, selectorId, (s) {
      final next = SelectorMode
          .values[(s.mode.index + 1) % SelectorMode.values.length];
      return switch (s) {
        RangeSelector r => r.copyWith(mode: next),
        WigglySelector w => w.copyWith(mode: next),
      };
    });
  }

  void setRangeSelectorShape(
      String id, String animatorId, String selectorId, SelectorShape shape) {
    _updateSelector(id, animatorId, selectorId, (s) {
      return s is RangeSelector ? s.copyWith(shape: shape) : s;
    });
  }

  /// Edita um parametro do seletor (auto-key se ja anima).
  /// Range: start, end, offset, amount. Wiggly: freq, correlation, min, max.
  void editSelectorParam(String id, String animatorId, String selectorId,
      String param, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateSelector(id, animatorId, selectorId, (s) {
      if (s is RangeSelector) {
        return switch (param) {
          'start' => s.copyWith(start: s.start.edited(local, value)),
          'end' => s.copyWith(end: s.end.edited(local, value)),
          'offset' => s.copyWith(offset: s.offset.edited(local, value)),
          'amount' => s.copyWith(amount: s.amount.edited(local, value)),
          _ => s,
        };
      }
      if (s is WigglySelector) {
        return switch (param) {
          'freq' => s.copyWith(
              wigglesPerSecond: s.wigglesPerSecond.edited(local, value)),
          'correlation' =>
            s.copyWith(correlation: s.correlation.edited(local, value)),
          'min' => s.copyWith(minAmount: s.minAmount.edited(local, value)),
          'max' => s.copyWith(maxAmount: s.maxAmount.edited(local, value)),
          _ => s,
        };
      }
      return s;
    });
  }

  // ------------------------------------------------------------- conteudo

  void editTextLayer(String id,
      {String? text, double? fontSize, Color? color}) {
    final layer = _layer(id);
    if (layer is! TextLayer) return;
    _replace(layer.copyLayer(
      text: text,
      name: text ?? layer.name,
      fontSize: fontSize,
      color: color,
    ));
  }

  // ------------------------------------------------------ forma vetorial

  void _updateShape(String id, List<ShapeItem> Function(List<ShapeItem>) fn) {
    final layer = _layer(id);
    if (layer is! ShapeLayer) return;
    _replace(layer.copyLayer(contents: fn(layer.contents)));
  }

  /// Primeira geometria PARAMETRICA da forma (painel de parametros).
  ShapeParametric? shapeParametricOf(String id) {
    final layer = _layer(id);
    if (layer is! ShapeLayer) return null;
    for (final item in layer.contents) {
      if (item is ShapeParametric) return item;
    }
    return null;
  }

  void _updateParametric(
      String id, ShapeParametric Function(ShapeParametric) fn) {
    _updateShape(id, (items) {
      var done = false;
      return [
        for (final item in items)
          if (!done && item is ShapeParametric)
            (() {
              done = true;
              return fn(item);
            })()
          else
            item,
      ];
    });
  }

  /// Edita um parametro da geometria (auto-key quando a trilha ja anima).
  void editShapeParam(
      String id, String key, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateParametric(id, (s) {
      final track = shapeParamTrackOf(s, key);
      if (track == null) return s;
      return shapeParamWithTrack(s, key, track.edited(local, value));
    });
  }

  void toggleShapeParamKeyframe(
      String id, String key, Duration globalTime) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateParametric(id, (s) {
      final track = shapeParamTrackOf(s, key);
      if (track == null) return s;
      return shapeParamWithTrack(
        s,
        key,
        track.hasKeyframeAt(local)
            ? track.withoutKeyframe(local)
            : track.withKeyframe(local, track.valueAt(local)),
      );
    });
  }

  void setShapeParamSegmentEase(
      String id, String key, Duration segStartLocal, Easing ease) {
    _updateParametric(id, (s) {
      final track = shapeParamTrackOf(s, key);
      if (track == null) return s;
      return shapeParamWithTrack(
          s, key, track.withEase(segStartLocal, ease));
    });
  }

  void applyEaseToAllShapeParamSegments(
      String id, String key, Easing ease) {
    _updateParametric(id, (s) {
      final track = shapeParamTrackOf(s, key);
      if (track == null) return s;
      return shapeParamWithTrack(s, key, track.withEaseAll(ease));
    });
  }

  /// Troca o TIPO da primitiva mantendo as trilhas (rect -> star etc.).
  void setShapeParamKind(String id, ParamShapeKind kind) {
    _updateParametric(id, (s) => s.copyWith(kind: kind));
  }

  /// Alternador de unidade do arredondamento (px ou % do menor lado).
  void setShapeRoundnessUnit(String id, {required bool percent}) {
    _updateParametric(id, (s) => s.copyWith(roundnessPercent: percent));
  }

  /// Converte o primeiro caminho COZIDO em geometria parametrica
  /// equivalente (formas antigas ganham os parametros novos).
  void convertShapeToParametric(String id) {
    _updateShape(id, (items) {
      var done = false;
      return [
        for (final item in items)
          if (!done && item is ShapePath && _paramFromLegacy(item) != null)
            (() {
              done = true;
              return _paramFromLegacy(item)!;
            })()
          else
            item,
      ];
    });
  }

  ShapeParametric? _paramFromLegacy(ShapePath p) => switch (p.primitive) {
        ShapePrimitive.rectangle => ShapeParametric(
            kind: ParamShapeKind.rect,
            sizeX: AnimatedDouble(p.width),
            sizeY: AnimatedDouble(p.height),
            roundness: AnimatedDouble(0)),
        ShapePrimitive.roundedRectangle => ShapeParametric(
            kind: ParamShapeKind.rect,
            sizeX: AnimatedDouble(p.width),
            sizeY: AnimatedDouble(p.height),
            roundnessPercent: false,
            roundness: AnimatedDouble(p.cornerRadius)),
        ShapePrimitive.ellipse => ShapeParametric(
            kind: ParamShapeKind.ellipse,
            sizeX: AnimatedDouble(p.width),
            sizeY: AnimatedDouble(p.height)),
        ShapePrimitive.polygon => ShapeParametric(
            kind: ParamShapeKind.polygon,
            points: AnimatedDouble(p.points.toDouble()),
            outerRadius: AnimatedDouble(p.width / 2)),
        ShapePrimitive.star => ShapeParametric(
            kind: ParamShapeKind.star,
            points: AnimatedDouble(p.points.toDouble()),
            outerRadius: AnimatedDouble(p.width / 2),
            innerRadius:
                AnimatedDouble(p.width / 2 * p.innerRadiusRatio)),
        ShapePrimitive.ring => ShapeParametric(
            kind: ParamShapeKind.sector,
            outerRadius: AnimatedDouble(p.width / 2),
            sectorInner:
                AnimatedDouble((p.width / 2 - p.thickness).clamp(0, 1e9)),
            sweep: AnimatedDouble(360)),
        ShapePrimitive.arc => ShapeParametric(
            kind: ParamShapeKind.sector,
            outerRadius: AnimatedDouble(p.width / 2),
            sectorInner:
                AnimatedDouble((p.width / 2 - p.thickness).clamp(0, 1e9)),
            startAngle: AnimatedDouble(p.startAngle),
            sweep: AnimatedDouble(p.sweepAngle)),
        _ => null,
      };

  /// Troca a cor do primeiro fill/stroke (painel Cor e preenchimento).
  void setShapePrimaryColor(String id, Color color) {
    _updateShape(id, (items) {
      var done = false;
      return [
        for (final item in items)
          if (!done && item is ShapeFill)
            (() {
              done = true;
              return item.copyWith(color: color);
            })()
          else if (!done && item is ShapeStroke)
            (() {
              done = true;
              return item.copyWith(color: color);
            })()
          else
            item,
      ];
    });
  }

  /// Adiciona um operador ao FIM da lista (afeta tudo que veio antes).
  void addShapeOperator(String id, {required bool repeater}) {
    _updateShape(id, (items) {
      // Operador entra antes das pinturas para afetar os caminhos.
      final paintIdx = items.indexWhere((i) =>
          i is ShapeFill || i is ShapeStroke || i is ShapeGradientFill);
      final op = repeater
          ? RepeaterOperator()
          : TrimOperator(end: AnimatedDouble(0.6));
      final out = [...items];
      out.insert(paintIdx < 0 ? out.length : paintIdx, op);
      return out;
    });
  }

  /// Transforma a forma num MORPH: a primeira ShapePath (ou o destino do
  /// morph atual) vira a origem, e [target] o destino. O progresso (0..1)
  /// anima por keyframe como qualquer propriedade.
  void convertShapeToMorph(String id, ShapePath target) {
    _updateShape(id, (items) {
      final idx =
          items.indexWhere((i) => i is ShapePath || i is ShapeMorph);
      if (idx < 0) return items;
      final out = [...items];
      final current = out[idx];
      final fromPath = switch (current) {
        ShapePath p => p,
        ShapeMorph m => m.to,
        _ => null,
      };
      if (fromPath == null) return items;
      out[idx] = ShapeMorph(from: fromPath, to: target);
      return out;
    });
  }

  /// Desfaz o morph mantendo a forma de ORIGEM.
  void removeMorph(String id, String itemId) {
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id == itemId && i is ShapeMorph) i.from else i,
        ]);
  }

  void editMorphProgress(
      String id, String itemId, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id == itemId && i is ShapeMorph)
              i.copyWith(progress: i.progress.edited(local, value))
            else
              i,
        ]);
  }

  void toggleMorphKeyframe(String id, String itemId, Duration globalTime) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id == itemId && i is ShapeMorph)
              i.copyWith(
                progress: i.progress.hasKeyframeAt(local)
                    ? i.progress.withoutKeyframe(local)
                    : i.progress
                        .withKeyframe(local, i.progress.valueAt(local)),
              )
            else
              i,
        ]);
  }

  void removeShapeItem(String id, String itemId) {
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id != itemId) i,
        ]);
  }

  /// Edita parametro de Trim (start/end/offset) com auto-keyframe.
  void editTrim(String id, String itemId, String param, Duration globalTime,
      double value) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id == itemId && i is TrimOperator)
              switch (param) {
                'start' => i.copyWith(start: i.start.edited(local, value)),
                'end' => i.copyWith(end: i.end.edited(local, value)),
                'offset' =>
                  i.copyWith(offset: i.offset.edited(local, value)),
                _ => i,
              }
            else
              i,
        ]);
  }

  void editRepeater(String id, String itemId, Duration globalTime,
      {int? copies, double? dx, double? dy, double? rotationDeg}) {
    final layer = _layer(id);
    if (layer == null) return;
    final local = layer.localTime(globalTime);
    _updateShape(id, (items) => [
          for (final i in items)
            if (i.id == itemId && i is RepeaterOperator)
              i.copyWith(
                copies: copies,
                dx: dx,
                dy: dy,
                rotation: rotationDeg == null
                    ? null
                    : i.rotation.edited(local, rotationDeg),
              )
            else
              i,
        ]);
  }

  // ------------------------------------------------------------ precomp/3D

  /// Agrupa VARIAS camadas num precomp: o grupo cobre do inicio mais cedo
  /// ao fim mais tarde; os filhos entram com tempo local ao grupo, na
  /// mesma ordem de empilhamento da composicao.
  void groupLayers(List<String> ids) {
    final picked = [
      for (final l in state.layers)
        if (ids.contains(l.id)) l,
    ];
    if (picked.isEmpty) return;
    if (picked.length == 1) {
      groupLayer(picked.first.id);
      return;
    }
    var start = picked.first.startTime;
    var end = picked.first.endTime;
    for (final l in picked) {
      if (l.startTime < start) start = l.startTime;
      if (l.endTime > end) end = l.endTime;
    }
    final group = GroupLayer(
      name: 'Grupo',
      startTime: start,
      duration: end - start,
      position: AnimatedOffset(_center),
      children: [
        for (final l in picked)
          l.copyLayer(startTime: l.startTime - start),
      ],
    );
    final layers = <Layer>[];
    var placed = false;
    for (final l in state.layers) {
      if (ids.contains(l.id)) {
        if (!placed) {
          layers.add(group);
          placed = true;
        }
      } else {
        layers.add(l);
      }
    }
    _mutate(state.copyWith(layers: layers));
    ref.read(selectedLayerProvider.notifier).state = group.id;
  }

  /// Agrupa a camada num precomp (tempo dos filhos vira local ao grupo).
  void groupLayer(String id) {
    final layer = _layer(id);
    if (layer == null || layer is GroupLayer) return;
    final group = GroupLayer(
      name: 'Grupo',
      startTime: layer.startTime,
      duration: layer.duration,
      position: AnimatedOffset(_center),
      children: [layer.copyLayer(startTime: Duration.zero)],
    );
    _mutate(state.copyWith(layers: [
      for (final l in state.layers)
        if (l.id == id) group else l,
    ]));
    ref.read(selectedLayerProvider.notifier).state = group.id;
  }

  /// Desfaz o grupo devolvendo os filhos com tempo absoluto.
  void ungroupLayer(String id) {
    final layer = _layer(id);
    if (layer is! GroupLayer) return;
    final children = [
      for (final c in layer.children)
        c.copyLayer(startTime: layer.startTime + c.startTime),
    ];
    final layers = <Layer>[];
    for (final l in state.layers) {
      if (l.id == id) {
        layers.addAll(children);
      } else {
        layers.add(l);
      }
    }
    _mutate(state.copyWith(layers: layers));
    ref.read(selectedLayerProvider.notifier).state =
        children.isEmpty ? null : children.first.id;
  }

  void toggle3D(String id) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(is3D: !layer.is3D));
  }

  void editPositionZ(String id, Duration globalTime, double value) {
    final layer = _layer(id);
    if (layer == null) return;
    _replace(layer.copyLayer(
      positionZ: layer.positionZ.edited(layer.localTime(globalTime), value),
    ));
  }

  // ------------------------------------------------------------- pickwhip

  /// Vincula a propriedade da camada alvo a MESMA propriedade da fonte,
  /// capturando o offset do instante (a relacao espacial nao pula).
  void linkProperty(
      String targetId, LayerProp prop, String sourceId, Duration globalTime) {
    final target = _layer(targetId);
    final source = _layer(sourceId);
    if (target == null || source == null || targetId == sourceId) return;
    final tLocal = target.localTime(globalTime);
    final sLocal = source.localTime(globalTime);

    double ox = 0, oy = 0;
    switch (prop) {
      case LayerProp.position:
        final d = target.position.valueAt(tLocal) -
            source.position.valueAt(sLocal);
        ox = d.dx;
        oy = d.dy;
      case LayerProp.rotation:
        ox = target.rotation.valueAt(tLocal) -
            source.rotation.valueAt(sLocal);
      case LayerProp.opacity:
        ox = target.opacity.valueAt(tLocal) - source.opacity.valueAt(sLocal);
      case LayerProp.scale:
        final s = source.scaleX.valueAt(sLocal);
        ox = s == 0 ? 1 : target.scaleX.valueAt(tLocal) / s;
      case LayerProp.parent:
        // Parenting: captura o transform EFETIVO do pai (a cadeia dele ja
        // resolvida — o pai pode estar linkado a outro nulo) no instante
        // do vinculo; o filho segue o delta (nada pula ao parear).
        final pe = effectiveTransform(state, source, globalTime);
        final links = [
          for (final l in state.links)
            if (!(l.targetLayerId == targetId &&
                l.targetProp == LayerProp.parent))
              l,
          PropertyLink(
            targetLayerId: targetId,
            targetProp: LayerProp.parent,
            sourceLayerId: sourceId,
            offsetX: pe.pos.dx,
            offsetY: pe.pos.dy,
            baseRotation: pe.rot,
            baseScale: pe.scale,
            baseRotationX: pe.rotX,
            baseRotationY: pe.rotY,
            baseZ: pe.z,
          ),
        ];
        _mutate(state.copyWith(links: links));
        return;
      case LayerProp.skew:
      case LayerProp.pivot:
        return; // sem vinculo para estes por enquanto
    }

    final links = [
      for (final l in state.links)
        if (!(l.targetLayerId == targetId && l.targetProp == prop)) l,
      PropertyLink(
        targetLayerId: targetId,
        targetProp: prop,
        sourceLayerId: sourceId,
        offsetX: ox,
        offsetY: oy,
      ),
    ];
    _mutate(state.copyWith(links: links));
  }

  void unlinkProperty(String targetId, LayerProp prop) {
    _mutate(state.copyWith(links: [
      for (final l in state.links)
        if (!(l.targetLayerId == targetId && l.targetProp == prop)) l,
    ]));
  }

  void editVideoVolume(String id, double volume) {
    final layer = _layer(id);
    if (layer is! VideoLayer) return;
    _replace(layer.copyLayer(volume: volume.clamp(0, 1)));
  }

  Future<Duration> _probeDuration(String path) async {
    final probe = VideoPlayerController.file(File(path));
    try {
      await probe.initialize();
      return probe.value.duration;
    } catch (_) {
      return const Duration(seconds: 5);
    } finally {
      await probe.dispose();
    }
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, VideoProject>(EditorController.new);
