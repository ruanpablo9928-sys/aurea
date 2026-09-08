import 'dart:math' as math;
import 'dart:typed_data';

import 'element3d.dart';

/// Static linear HDR radiance. Baking runs on an isolate, then the GPU builds
/// roughness mip levels once; camera movement only changes matrices.
Float32List environmentRadiance(EnvironmentKind kind, {int width = 512}) {
  final height = width ~/ 2, pixels = Float32List(width * (width ~/ 2) * 4);
  for (var y = 0; y < height; y++) {
    final latitude = math.pi * (y + 0.5) / height;
    final vertical = math.cos(latitude), ring = math.sin(latitude);
    for (var x = 0; x < width; x++) {
      final longitude = 2 * math.pi * ((x + 0.5) / width - 0.5);
      final color = environmentColor(
        kind,
        ring * math.sin(longitude),
        vertical,
        ring * math.cos(longitude),
      );
      final i = (y * width + x) * 4;
      pixels[i] = color.$1;
      pixels[i + 1] = color.$2;
      pixels[i + 2] = color.$3;
      pixels[i + 3] = 1;
    }
  }
  return pixels;
}
