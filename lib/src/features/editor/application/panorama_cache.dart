import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../domain/panorama3d.dart';
import '../domain/scene3d.dart';

/// Cache de panorama importado. A imagem e reduzida, convertida em seis
/// faces e pre-filtrada em mipmaps uma vez; os quadros seguintes so amostram
/// o cubo pronto.
class PanoramaCache {
  PanoramaCache._();

  static final PanoramaCache instance = PanoramaCache._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final Map<String, _PanoramaCube> _ready = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  final Map<String, Future<void>> _pending = {};

  EnvironmentSampler? samplerFor(Panorama3D panorama) {
    final path = panorama.sourcePath;
    if (path == null || path.isEmpty) return null;
    final key = _key(panorama);
    final cube = _ready[key];
    if (cube == null) {
      if (!_failed.contains(key)) {
        unawaited(_loadOnce(key, path, panorama));
      }
      return null;
    }
    return cube.sample;
  }

  /// Garante que o panorama esteja pronto antes de uma captura determinista.
  /// Falhas de arquivo/codec devolvem false; o chamador decide se pode usar
  /// fallback ou se deve interromper a exportacao.
  Future<bool> prepare(Panorama3D panorama) async {
    final path = panorama.sourcePath;
    if (path == null || path.isEmpty) return true;
    final key = _key(panorama);
    if (_ready.containsKey(key)) return true;
    if (_failed.contains(key)) return false;
    await _loadOnce(key, path, panorama);
    return _ready.containsKey(key);
  }

  String _key(Panorama3D panorama) =>
      '${panorama.sourcePath}|'
      '${panorama.coverageDegrees.toStringAsFixed(2)}|'
      '${panorama.mirrorTo360}|${panorama.seamSoftness.toStringAsFixed(3)}|'
      '${panorama.fillZenithNadir}';

  Future<void> _loadOnce(String key, String path, Panorama3D panorama) {
    final running = _pending[key];
    if (running != null) return running;
    final future = _load(key, path, panorama);
    _pending[key] = future;
    return future.whenComplete(() {
      _pending.remove(key);
    });
  }

  Future<void> _load(String key, String path, Panorama3D panorama) async {
    _loading.add(key);
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 512,
        targetHeight: 256,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('Panorama sem pixels');
      final pixels = _PanoramaPixels(
        image.width,
        image.height,
        data.buffer.asUint8List(),
      );
      _ready[key] = _PanoramaCube.fromEquirectangular(pixels, panorama);
      image.dispose();
      revision.value++;
    } catch (_) {
      _failed.add(key);
    } finally {
      _loading.remove(key);
    }
  }

  void clear() {
    _ready.clear();
    _failed.clear();
    revision.value++;
  }
}

class _PanoramaPixels {
  _PanoramaPixels(this.width, this.height, this.rgba)
    : topAverage = _edgeAverage(width, height, rgba, top: true),
      bottomAverage = _edgeAverage(width, height, rgba, top: false);

  final int width;
  final int height;
  final Uint8List rgba;
  final EnvironmentSample topAverage;
  final EnvironmentSample bottomAverage;

  EnvironmentSample sampleDirection(Vec3 direction, Panorama3D panorama) {
    final n = direction.normalized;
    var u = math.atan2(n.x, n.z) / (2 * math.pi) + 0.5;
    var v = 0.5 - math.asin(n.y.clamp(-1.0, 1.0)) / math.pi;
    u -= u.floorToDouble();
    v = v.clamp(0.0, 1.0).toDouble();

    if (panorama.mirrorTo360) {
      final repeats =
          360 / panorama.coverageDegrees.clamp(1.0, 360.0).toDouble();
      final phase = ((u * repeats) % 2).toDouble();
      u = phase <= 1 ? phase : 2 - phase;
    }

    final base = _pixel(u, v);
    var r = base.r, g = base.g, b = base.b;

    if (panorama.fillZenithNadir) {
      if (v < 0.13) {
        final k = 1 - v / 0.13;
        r += (topAverage.r - r) * k;
        g += (topAverage.g - g) * k;
        b += (topAverage.b - b) * k;
      } else if (v > 0.87) {
        final k = (v - 0.87) / 0.13;
        r += (bottomAverage.r - r) * k;
        g += (bottomAverage.g - g) * k;
        b += (bottomAverage.b - b) * k;
      }
    }

    final seam = panorama.seamSoftness.clamp(0.0, 0.45).toDouble();
    final edge = math.min(u, 1 - u);
    if (seam > 0 && edge < seam) {
      final other = _pixel(1 - u, v);
      final k = (1 - edge / seam) * 0.5;
      r += (other.r - r) * k;
      g += (other.g - g) * k;
      b += (other.b - b) * k;
    }
    return (r: r, g: g, b: b);
  }

  EnvironmentSample _pixel(double u, double v) {
    u -= u.floorToDouble();
    v = v.clamp(0.0, 1.0).toDouble();
    final x = (u * (width - 1)).round().clamp(0, width - 1);
    final y = (v * (height - 1)).round().clamp(0, height - 1);
    final i = (y * width + x) * 4;
    return (r: rgba[i] / 255, g: rgba[i + 1] / 255, b: rgba[i + 2] / 255);
  }

  static EnvironmentSample _edgeAverage(
    int width,
    int height,
    Uint8List rgba, {
    required bool top,
  }) {
    final rows = math.max(1, (height * 0.04).round());
    final start = top ? 0 : height - rows;
    var r = 0.0, g = 0.0, b = 0.0, count = 0;
    for (var y = start; y < start + rows; y++) {
      for (var x = 0; x < width; x += 2) {
        final i = (y * width + x) * 4;
        r += rgba[i] / 255;
        g += rgba[i + 1] / 255;
        b += rgba[i + 2] / 255;
        count++;
      }
    }
    return (r: r / count, g: g / count, b: b / count);
  }
}

/// Cubo pre-filtrado. Cada nivel tem seis faces; a rugosidade escolhe e
/// interpola dois mips sem voltar a imagem equiretangular.
class _PanoramaCube {
  _PanoramaCube(this.levels, this.sizes);

  factory _PanoramaCube.fromEquirectangular(
    _PanoramaPixels source,
    Panorama3D panorama,
  ) {
    const side = 128;
    final base = [
      for (var face = 0; face < 6; face++) Float32List(side * side * 3),
    ];
    for (var face = 0; face < 6; face++) {
      final out = base[face];
      for (var y = 0; y < side; y++) {
        for (var x = 0; x < side; x++) {
          final u = (x + 0.5) / side * 2 - 1;
          final v = (y + 0.5) / side * 2 - 1;
          final color = source.sampleDirection(
            _faceDirection(face, u, v),
            panorama,
          );
          final index = (y * side + x) * 3;
          out[index] = color.r;
          out[index + 1] = color.g;
          out[index + 2] = color.b;
        }
      }
    }

    final levels = <List<Float32List>>[base];
    final sizes = <int>[side];
    var previous = base;
    var previousSize = side;
    while (previousSize > 1) {
      final size = math.max(1, previousSize ~/ 2);
      final next = [
        for (var face = 0; face < 6; face++) Float32List(size * size * 3),
      ];
      for (var face = 0; face < 6; face++) {
        for (var y = 0; y < size; y++) {
          for (var x = 0; x < size; x++) {
            for (var channel = 0; channel < 3; channel++) {
              var sum = 0.0;
              for (var oy = 0; oy < 2; oy++) {
                for (var ox = 0; ox < 2; ox++) {
                  final px = math.min(previousSize - 1, x * 2 + ox);
                  final py = math.min(previousSize - 1, y * 2 + oy);
                  sum += previous[face][(py * previousSize + px) * 3 + channel];
                }
              }
              next[face][(y * size + x) * 3 + channel] = sum / 4;
            }
          }
        }
      }
      levels.add(next);
      sizes.add(size);
      previous = next;
      previousSize = size;
    }
    return _PanoramaCube(levels, sizes);
  }

  final List<List<Float32List>> levels;
  final List<int> sizes;

  EnvironmentSample sample(Vec3 direction, double roughness) {
    final mip = roughnessMip(roughness, mipLevels: levels.length);
    final lo = mip.floor().clamp(0, levels.length - 1);
    final hi = mip.ceil().clamp(0, levels.length - 1);
    final a = _sampleLevel(lo, direction);
    if (lo == hi) return a;
    final b = _sampleLevel(hi, direction);
    final t = mip - lo;
    return (
      r: a.r + (b.r - a.r) * t,
      g: a.g + (b.g - a.g) * t,
      b: a.b + (b.b - a.b) * t,
    );
  }

  EnvironmentSample _sampleLevel(int level, Vec3 direction) {
    final mapped = _directionToFace(direction.normalized);
    final size = sizes[level];
    final x = (((mapped.u + 1) * 0.5) * (size - 1)).round().clamp(0, size - 1);
    final y = (((mapped.v + 1) * 0.5) * (size - 1)).round().clamp(0, size - 1);
    final index = (y * size + x) * 3;
    final face = levels[level][mapped.face];
    return (r: face[index], g: face[index + 1], b: face[index + 2]);
  }

  static Vec3 _faceDirection(int face, double u, double v) => switch (face) {
    0 => Vec3(1, -v, -u).normalized,
    1 => Vec3(-1, -v, u).normalized,
    2 => Vec3(u, 1, v).normalized,
    3 => Vec3(u, -1, -v).normalized,
    4 => Vec3(u, -v, 1).normalized,
    _ => Vec3(-u, -v, -1).normalized,
  };

  static ({int face, double u, double v}) _directionToFace(Vec3 direction) {
    if (direction.length < 1e-9) return (face: 4, u: 0, v: 0);
    final ax = direction.x.abs();
    final ay = direction.y.abs();
    final az = direction.z.abs();
    if (ax >= ay && ax >= az) {
      if (direction.x >= 0) {
        return (face: 0, u: -direction.z / ax, v: -direction.y / ax);
      }
      return (face: 1, u: direction.z / ax, v: -direction.y / ax);
    }
    if (ay >= ax && ay >= az) {
      if (direction.y >= 0) {
        return (face: 2, u: direction.x / ay, v: direction.z / ay);
      }
      return (face: 3, u: direction.x / ay, v: -direction.z / ay);
    }
    if (direction.z >= 0) {
      return (face: 4, u: direction.x / az, v: -direction.y / az);
    }
    return (face: 5, u: -direction.x / az, v: -direction.y / az);
  }
}
