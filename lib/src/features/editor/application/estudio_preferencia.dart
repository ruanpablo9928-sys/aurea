import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs.dart';

/// O QUE O ESTUDIO 3D LEMBRA ENTRE UMA ABERTURA E OUTRA.
///
/// Duas coisas: se a pessoa ligou o modo avancado, e se as dicas de
/// boas-vindas ja foram lidas. Sem SharedPreferences (as telas abertas
/// em teste, por exemplo) nada quebra — so nao fica guardado.
class EstudioPreferencia {
  const EstudioPreferencia(this._prefs);

  static const kAvancado = 'estudio3d_avancado';
  static const kDicasVistas = 'estudio3d_dicas_vistas';

  /// Pega as preferencias do provider, se ele foi sobrescrito.
  static EstudioPreferencia de(WidgetRef ref) {
    try {
      return EstudioPreferencia(ref.read(sharedPreferencesProvider));
    } catch (_) {
      return const EstudioPreferencia(null);
    }
  }

  final SharedPreferences? _prefs;

  bool get avancado => _prefs?.getBool(kAvancado) ?? false;
  bool get dicasVistas => _prefs?.getBool(kDicasVistas) ?? false;

  Future<void> definirAvancado(bool ligado) async {
    await _prefs?.setBool(kAvancado, ligado);
  }

  Future<void> marcarDicasVistas(bool vistas) async {
    await _prefs?.setBool(kDicasVistas, vistas);
  }
}
