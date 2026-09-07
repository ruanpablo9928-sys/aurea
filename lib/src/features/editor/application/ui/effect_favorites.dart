import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/prefs.dart';

/// EFEITOS FAVORITOS (Fase 4): um conjunto de ids de `EffectSpec`,
/// lembrado por aparelho — nao e do projeto. A galeria mostra a estrela
/// e o chip "Favoritos".
class EffectFavoritesNotifier extends Notifier<Set<String>> {
  static const kChave = 'efeitos.favoritos';

  @override
  Set<String> build() {
    try {
      final lista = ref.read(sharedPreferencesProvider).getStringList(kChave);
      return {...?lista};
    } catch (_) {
      return const {};
    }
  }

  bool isFavorite(String effectId) => state.contains(effectId);

  void toggle(String effectId) {
    final novo = {...state};
    if (!novo.add(effectId)) novo.remove(effectId);
    state = novo;
    try {
      ref
          .read(sharedPreferencesProvider)
          .setStringList(kChave, novo.toList()..sort());
    } catch (_) {}
  }
}

final effectFavoritesProvider =
    NotifierProvider<EffectFavoritesNotifier, Set<String>>(
      EffectFavoritesNotifier.new,
    );
