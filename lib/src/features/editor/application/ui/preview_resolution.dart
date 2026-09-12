import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PreviewResolution {
  full('Full', 1),
  half('1/2', .5),
  quarter('1/4', .25),
  eighth('1/8', .125);

  const PreviewResolution(this.label, this.scale);
  final String label;
  final double scale;
}

/// Session preference only: never changes project dimensions or export settings.
final previewResolutionProvider = StateProvider<PreviewResolution>(
  (ref) => PreviewResolution.full,
);

/// Guides from the transform pad, in composition coordinates.
final transformGuidesProvider = StateProvider<({double? x, double? y})>(
  (ref) => (x: null, y: null),
);
