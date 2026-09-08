import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:aurea/src/features/editor/domain/cut.dart';
import 'package:aurea/src/features/editor/domain/cut_ops.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';

class _MeasuredLayers extends ListBase<Layer> {
  _MeasuredLayers(this.items);
  final List<Layer> items;
  int reads = 0;
  @override
  int get length => items.length;
  @override
  set length(int value) => throw UnsupportedError('read only');
  @override
  Layer operator [](int i) {
    reads++;
    return items[i];
  }

  @override
  void operator []=(int i, Layer v) => throw UnsupportedError('read only');
}

void main() {
  test(
    '2000 cuts resolve in one timeline scan and retain both participants',
    () {
      final layers = _MeasuredLayers([
        for (var i = 0; i < 2000; i++)
          VideoLayer(
            id: '$i',
            name: '$i',
            sourcePath: 'fixture.mp4',
            startTime: Duration(seconds: i),
            duration: const Duration(seconds: 1),
            transitionIn: i == 0
                ? null
                : ClipTransition(outgoingLayerId: '${i - 1}'),
          ),
      ]);
      final contexts = transitionContextsAt(
        layers,
        const Duration(seconds: 1000),
      );
      expect(layers.reads, lessThanOrEqualTo(4000));
      expect(contexts, hasLength(1));
      expect(contexts.single.incoming.id, '1000');
      expect(contexts.single.outgoing.id, '999');
      expect(contexts.single.progress, closeTo(.5, .001));
      expect(
        visibleForCut(
          layers,
          layers[999],
          const Duration(seconds: 1000),
          contexts: contexts,
        ),
        isTrue,
      );
    },
  );
}
