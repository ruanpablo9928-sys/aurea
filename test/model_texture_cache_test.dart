import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/application/texture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'textura embutida decodifica antes de liberar descriptor e buffer',
    () async {
      final recorder = PictureRecorder(), canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 8, 4),
        Paint()..color = const Color(0xFFFF4000),
      );
      final picture = recorder.endRecording(),
          image = await picture.toImage(8, 4);
      final png = await image.toByteData(format: ImageByteFormat.png);
      final uri =
          'data:image/png;base64,${base64Encode(png!.buffer.asUint8List())}';
      image.dispose();
      picture.dispose();
      final cache = TextureCache.instance;
      cache.clear();
      addTearDown(cache.clear);
      expect(await cache.prepare(uri), isTrue);
      final decoded = cache.imageFor(uri)!;
      expect(decoded.width, 8);
      expect(decoded.height, 4);
      expect(await decoded.toByteData(), isNotNull);
    },
  );
}
