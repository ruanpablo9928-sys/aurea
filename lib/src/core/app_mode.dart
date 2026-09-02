import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/prefs.dart';

/// O INTERRUPTOR GLOBAL (AUREA-reset-ao-nucleo.md, secao 1).
///
/// `core` e o app minimo: projeto, importar video/imagem/audio, timeline
/// com corte/ripple/juntar, preview, transporte, marcadores, keyframes
/// em posicao/escala/rotacao/opacidade, exportar. `full` e o estudio
/// inteiro. O codigo das duas e o MESMO — o interruptor so decide o que
/// a interface mostra. Nada e apagado; os testes continuam cobrindo
/// tudo, com o modo que cada um precisa.
///
/// Padrao: `core`. A pessoa liga o estudio em Ajustes.
enum AppMode { core, full }

extension AppModeX on AppMode {
  bool get isCore => this == AppMode.core;
  bool get isFull => this == AppMode.full;
}

/// Espelho SINCRONO do modo, para codigo fora da arvore de widgets (o
/// controller, um pintor). A fonte de verdade e o [appModeProvider];
/// este valor segue ele.
class AppModeSwitch {
  AppModeSwitch._();

  static AppMode current = AppMode.core;

  static bool get isCore => current.isCore;
  static bool get isFull => current.isFull;

  /// Para testes: forca um modo sem passar pelo provider.
  @visibleForTesting
  static void force(AppMode mode) => current = mode;
}

class AppModeController extends Notifier<AppMode> {
  static const _chave = 'app.mode';

  @override
  AppMode build() {
    AppMode modo;
    try {
      final salvo = ref.read(sharedPreferencesProvider).getString(_chave);
      modo = salvo == 'full' ? AppMode.full : AppMode.core;
    } catch (_) {
      // Sem preferencias (testes, container cru): padrao.
      modo = AppMode.core;
    }
    AppModeSwitch.current = modo;
    return modo;
  }

  void set(AppMode modo) {
    state = modo;
    AppModeSwitch.current = modo;
    try {
      ref.read(sharedPreferencesProvider).setString(_chave, modo.name);
    } catch (_) {}
  }

  void toggle() => set(state.isCore ? AppMode.full : AppMode.core);
}

final appModeProvider =
    NotifierProvider<AppModeController, AppMode>(AppModeController.new);
