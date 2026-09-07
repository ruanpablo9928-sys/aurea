import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/prefs.dart';
import '../../../projects/application/projects_controller.dart';

/// SIMPLES OU PRO (secao 5 do prompt).
///
/// Pro so ACRESCENTA itens; nunca muda o lugar de nada. Padrao Simples
/// para instalacao nova; Pro para quem ja tinha projeto salvo quando o
/// interruptor nasceu — o beta nao pode acordar sem as ferramentas.
class ProModeNotifier extends Notifier<bool> {
  static const kPro = 'editor.pro';

  @override
  bool build() {
    final prefs = _prefs;
    final salvo = prefs?.getBool(kPro);
    if (salvo != null) return salvo;
    var pro = false;
    try {
      pro = ref.read(projectsControllerProvider).isNotEmpty;
    } catch (_) {
      pro = false;
    }
    return pro;
  }

  dynamic get _prefs {
    try {
      return ref.read(sharedPreferencesProvider);
    } catch (_) {
      return null;
    }
  }

  void set(bool pro) {
    state = pro;
    _prefs?.setBool(kPro, pro);
  }

  void toggle() => set(!state);
}

final proModeProvider = NotifierProvider<ProModeNotifier, bool>(
  ProModeNotifier.new,
);
