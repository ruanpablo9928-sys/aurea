import 'dart:math' as math;
import 'dart:ui';

import 'package:uuid/uuid.dart';

import 'layer.dart';

/// Propriedade animavel de camada (alvo de keyframes, curvas e vinculos).
/// [parent] nao e uma propriedade animavel: e o vinculo de parenting
/// (objeto nulo / camada pai) que arrasta posicao+rotacao+escala juntas.
enum LayerProp { position, scale, rotation, opacity, skew, pivot, parent }

/// Vinculo de propriedade (spec AM2-formas-3d D4, o "pickwhip"): a
/// propriedade alvo passa a seguir a fonte, com escala e offset capturados
/// no instante do vinculo (nao ha interpretador de expressao).
class PropertyLink {
  PropertyLink({
    String? id,
    required this.targetLayerId,
    required this.targetProp,
    required this.sourceLayerId,
    this.scale = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.baseRotation = 0.0,
    this.baseScale = 1.0,
    this.baseRotationX = 0.0,
    this.baseRotationY = 0.0,
    this.baseZ = 0.0,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String targetLayerId;
  final LayerProp targetProp;

  /// A fonte fornece a MESMA propriedade (posicao segue posicao, rotacao
  /// segue rotacao...).
  final String sourceLayerId;

  final double scale;

  /// Escalar (rotacao/opacidade/escala usam offsetX) ou vetor (posicao).
  /// Para [LayerProp.parent]: posicao do pai capturada no vinculo.
  final double offsetX;
  final double offsetY;

  /// So para [LayerProp.parent]: rotacao/escala do pai no instante do
  /// vinculo — o filho segue o DELTA (semantica AE: nada pula ao parear).
  final double baseRotation;
  final double baseScale;

  /// Rotacao 3D (X/Y) e profundidade do pai no instante do vinculo: o
  /// filho ORBITA o pai em 3D quando o nulo gira em X/Y.
  final double baseRotationX;
  final double baseRotationY;
  final double baseZ;
}

/// Projeto = composicao: pilha de camadas + configuracoes de saida.
/// Ordem da lista: indice 0 e a camada MAIS ACIMA (painel de camadas).
class VideoProject {
  VideoProject({
    String? id,
    required this.name,
    required this.createdAt,
    this.aspectRatio = 16 / 9,
    this.fps = 30,
    this.resolutionHeight = 1080,
    List<Layer>? layers,
    List<PropertyLink>? links,
  })  : id = id ?? const Uuid().v4(),
        layers = List.unmodifiable(layers ?? const <Layer>[]),
        links = List.unmodifiable(links ?? const <PropertyLink>[]);

  final String id;
  final String name;
  final DateTime createdAt;

  final double aspectRatio;
  final int fps;
  final int resolutionHeight;

  final List<Layer> layers;

  /// Vinculos de propriedade (pickwhip).
  final List<PropertyLink> links;

  factory VideoProject.empty(
    String name, {
    double aspectRatio = 16 / 9,
    int fps = 30,
    int resolutionHeight = 1080,
  }) {
    return VideoProject(
      name: name,
      createdAt: DateTime.now(),
      aspectRatio: aspectRatio,
      fps: fps,
      resolutionHeight: resolutionHeight,
    );
  }

  int get outputWidth => aspectRatio >= 1
      ? (resolutionHeight * aspectRatio).round()
      : resolutionHeight;

  int get outputHeight => aspectRatio >= 1
      ? resolutionHeight
      : (resolutionHeight / aspectRatio).round();

  Duration get duration {
    var end = Duration.zero;
    for (final l in layers) {
      if (l.endTime > end) end = l.endTime;
    }
    return end < const Duration(seconds: 5) ? const Duration(seconds: 5) : end;
  }

  Duration get frameDuration => Duration(microseconds: 1000000 ~/ fps);

  Layer? layerById(String id) {
    for (final l in layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  VideoLayer? get firstVideoLayer {
    for (final l in layers) {
      if (l is VideoLayer) return l;
    }
    return null;
  }

  PropertyLink? linkFor(String layerId, LayerProp prop) {
    for (final link in links) {
      if (link.targetLayerId == layerId && link.targetProp == prop) {
        return link;
      }
    }
    return null;
  }

  VideoProject copyWith({
    String? name,
    double? aspectRatio,
    int? fps,
    int? resolutionHeight,
    List<Layer>? layers,
    List<PropertyLink>? links,
  }) {
    return VideoProject(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      fps: fps ?? this.fps,
      resolutionHeight: resolutionHeight ?? this.resolutionHeight,
      layers: layers ?? this.layers,
      links: links ?? this.links,
    );
  }
}

/// Transform efetivo de uma camada apos resolver a CADEIA de parenting.
class LayerTransform {
  const LayerTransform({
    required this.pos,
    required this.rot,
    required this.rotX,
    required this.rotY,
    required this.scale,
    required this.z,
  });

  final Offset pos;
  final double rot;
  final double rotX;
  final double rotY;
  final double scale;
  final double z;
}

/// Resolve o transform EFETIVO da camada no tempo global [t], seguindo a
/// cadeia de parenting recursivamente (objeto -> nulo 1 -> nulo 2 -> ...),
/// com guarda de ciclo. Cada elo aplica o DELTA do pai desde o instante do
/// vinculo, com o offset girado em 3D (X/Y/Z) e escalado.
LayerTransform effectiveTransform(
  VideoProject project,
  Layer layer,
  Duration t, [
  Set<String>? visited,
]) {
  final local = layer.localTime(t);
  var pos = layer.position.valueAt(local);
  var rot = layer.rotation.valueAt(local);
  var rotX = layer.rotationX.valueAt(local);
  var rotY = layer.rotationY.valueAt(local);
  var scale = layer.scaleX.valueAt(local);
  var z = layer.positionZ.valueAt(local);

  final par = project.linkFor(layer.id, LayerProp.parent);
  if (par != null) {
    visited ??= <String>{};
    if (visited.add(layer.id)) {
      final pp = project.layerById(par.sourceLayerId);
      if (pp != null) {
        // RECURSIVO: o pai tambem pode ter pai (nulo linkado em nulo).
        final pe = effectiveTransform(project, pp, t, visited);
        final ratio =
            par.baseScale.abs() < 1e-6 ? 1.0 : pe.scale / par.baseScale;
        final vx = (pos.dx - par.offsetX) * ratio;
        final vy = (pos.dy - par.offsetY) * ratio;
        final vz = (z - par.baseZ) * ratio;

        // v' = Rz * Ry * Rx * v com os deltas do pai.
        final dRx = (pe.rotX - par.baseRotationX) * math.pi / 180;
        final dRy = (pe.rotY - par.baseRotationY) * math.pi / 180;
        final dRz = (pe.rot - par.baseRotation) * math.pi / 180;
        final cxr = math.cos(dRx), sxr = math.sin(dRx);
        final y1 = vy * cxr - vz * sxr;
        final z1 = vy * sxr + vz * cxr;
        final cyr = math.cos(dRy), syr = math.sin(dRy);
        final x1 = vx * cyr + z1 * syr;
        final z2 = -vx * syr + z1 * cyr;
        final czr = math.cos(dRz), szr = math.sin(dRz);

        // Projeta a POSICAO pela mesma focal do resto do motor (1200):
        // o lado proximo da orbita abre, o distante comprime — sem isso
        // a orbita fica "chapada" e o conjunto parece cisalhado.
        final persp =
            1200 / (1200 + (pe.z + z2).clamp(-1100.0, 100000.0));
        pos = pe.pos +
            Offset(x1 * czr - y1 * szr, x1 * szr + y1 * czr) * persp;
        z = pe.z + z2;
        rot += pe.rot - par.baseRotation;
        rotX += pe.rotX - par.baseRotationX;
        rotY += pe.rotY - par.baseRotationY;
        scale *= ratio;
      }
    }
  }
  return LayerTransform(
      pos: pos, rot: rot, rotX: rotX, rotY: rotY, scale: scale, z: z);
}

/// Ordena a lista JA em ordem de pintura (fundo primeiro) aplicando a
/// regra 3D (D2): trechos contiguos de camadas 3D sao ordenados por
/// profundidade (Z maior = mais longe = pintado antes); camadas 2D mantem
/// a ordem de empilhamento e funcionam como barreira.
List<Layer> depthSortPaintOrder(List<Layer> paintOrder, Duration t) {
  final out = <Layer>[];
  final run = <Layer>[];

  void flush() {
    if (run.isEmpty) return;
    // Desempate ESTAVEL por indice na pilha (triagem 3D §5 item 14):
    // profundidades empatadas nao podem piscar entre frames.
    final decorated = [
      for (var i = 0; i < run.length; i++) (run[i], i),
    ];
    decorated.sort((a, b) {
      final za = a.$1.positionZ.valueAt(a.$1.localTime(t));
      final zb = b.$1.positionZ.valueAt(b.$1.localTime(t));
      final c = zb.compareTo(za);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    out.addAll([for (final d in decorated) d.$1]);
    run.clear();
  }

  for (final layer in paintOrder) {
    if (layer.is3D) {
      run.add(layer);
    } else {
      flush();
      out.add(layer);
    }
  }
  flush();
  return out;
}
