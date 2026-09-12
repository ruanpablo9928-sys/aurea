import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

@Native<Int32 Function(Pointer<Uint32>, Uint32, Uint32)>(
  symbol: 'aurea_meshopt_cache',
)
external int _optimize(Pointer<Uint32> indices, int count, int vertices);

/// Preserves vertex data, triangle membership, winding and degenerates.
/// Only suitable for opaque geometry: transparency may depend on draw order.
Uint32List optimizeVertexCache(Uint32List indices, int vertices) {
  if (indices.isEmpty || indices.length % 3 != 0 || vertices <= 0) {
    return indices;
  }
  final memory = calloc<Uint32>(indices.length);
  try {
    memory.asTypedList(indices.length).setAll(0, indices);
    if (_optimize(memory, indices.length, vertices) == 0) return indices;
    return Uint32List.fromList(memory.asTypedList(indices.length));
  } finally {
    calloc.free(memory);
  }
}
