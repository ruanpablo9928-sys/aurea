import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'dsp.dart';

class _Filter {
  _Filter(this.c);
  final Biquad c;
  double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  double tick(double x) {
    final y = c.b0 * x + c.b1 * x1 + c.b2 * x2 - c.a1 * y1 - c.a2 * y2;
    x2 = x1;
    x1 = x;
    y2 = y1;
    y1 = y;
    return y;
  }
}

/// Worker reads bounded PCM blocks. Memory grows with 100 peaks/second,
/// never with the 16,000 decoded samples/second or duplicate float buffers.
Future<({Float32List peaks, double? lufs})> scanMonoPcm(String path) async {
  const rate = 16000, bucket = 160, hop = 1600, window = 6400;
  final file = await File(path).open();
  final peaks = <double>[], energies = <double>[];
  final ring = Float64List(window);
  final shelf = _Filter(
    highShelf(
      rate,
      1681.974450955533,
      3.999843853973347,
      q: 0.7071752369554196,
    ),
  );
  final cut = _Filter(highPass(rate, 38.13547087602444, q: 0.5003270373238773));
  var n = 0, count = 0, peak = 0.0, energy = 0.0;
  try {
    while (true) {
      final bytes = await file.read(65536);
      if (bytes.isEmpty) break;
      final data = ByteData.sublistView(bytes);
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        final x = data.getInt16(i, Endian.little) / 32768.0;
        peak = math.max(peak, x.abs());
        if (++count == bucket) {
          peaks.add(peak);
          count = 0;
          peak = 0;
        }
        final y = cut.tick(shelf.tick(x));
        energy += y * y - ring[n % window];
        ring[n % window] = y * y;
        n++;
        if (n >= window && (n - window) % hop == 0) {
          energies.add(math.max(0, energy / window));
        }
      }
    }
  } finally {
    await file.close();
  }
  if (count > 0) peaks.add(peak);
  double db(double e) =>
      e <= 0 ? -double.infinity : -0.691 + 10 * math.log(e) / math.ln10;
  final absolute = energies.where((e) => db(e) > -70).toList();
  double? lufs;
  if (absolute.isNotEmpty) {
    final mean = absolute.reduce((a, b) => a + b) / absolute.length;
    final gated = absolute.where((e) => db(e) > db(mean) - 10).toList();
    lufs = db(gated.reduce((a, b) => a + b) / gated.length);
  }
  return (peaks: Float32List.fromList(peaks), lufs: lufs);
}
