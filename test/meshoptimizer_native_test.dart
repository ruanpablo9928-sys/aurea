import 'dart:math';

import 'package:flutter/foundation.dart';

import 'dart:typed_data';

import 'package:aurea_meshopt/aurea_meshopt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native optimizer preserves every triangle and reduces vertex cache misses',
    () {
      const side = 80;
      final triangles = <List<int>>[];
      for (var y = 0; y < side - 1; y++) {
        for (var x = 0; x < side - 1; x++) {
          final a = y * side + x;
          triangles.add([a, a + 1, a + side]);
          triangles.add([a + 1, a + side + 1, a + side]);
        }
      }
      triangles.shuffle(Random(42));
      final input = Uint32List.fromList(triangles.expand((t) => t).toList());
      final output = optimizeVertexCache(input, side * side);
      List<String> faces(Uint32List values) => [
        for (var i = 0; i < values.length; i += 3)
          '${values[i]},${values[i + 1]},${values[i + 2]}',
      ]..sort();
      int misses(Uint32List values) {
        final cache = <int>[];
        var misses = 0;
        for (final v in values) {
          if (!cache.remove(v)) misses++;
          cache.insert(0, v);
          if (cache.length > 16) cache.removeLast();
        }
        return misses;
      }

      expect(faces(output), faces(input));
      expect(misses(output), lessThan(misses(input) * .6));
      // Useful measurement, not a frame-rate claim.
      debugPrint('Vertex misses: ${misses(input)} -> ${misses(output)}');
      expect(optimizeVertexCache(Uint32List.fromList([0, 1, 90]), 3), [
        0,
        1,
        90,
      ]);
    },
  );
}
