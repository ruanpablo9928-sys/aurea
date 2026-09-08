import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The complete editor is available on every installation. Keep this provider
/// as a migration seam for existing callers; an old saved false cannot hide UI.
class ProModeNotifier extends Notifier<bool> {
  static const kPro = 'editor.pro';

  @override
  bool build() => true;

  void set(bool pro) {
    state = true;
  }

  void toggle() => set(!state);
}

final proModeProvider = NotifierProvider<ProModeNotifier, bool>(
  ProModeNotifier.new,
);
