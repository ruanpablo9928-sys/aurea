import 'package:shared_preferences/shared_preferences.dart';

/// QUAL API DESENHA O APP NO ANDROID — e a migalha que protege a troca.
///
/// O Flutter desenha com o Impeller, que no Android escolhe o Vulkan
/// quando o aparelho diz que tem. Em algumas GPUs Mali (os MediaTek de
/// entrada, como o Helio G81 do Moto G05) o driver de Vulkan e onde
/// aparecem cores erradas e mesclas quebradas — no preview e, por
/// consequencia, na captura que vira exportacao, que passa pela mesma
/// GPU. O OpenGL ES e o caminho antigo e mais rodado dessas GPUs.
///
/// Nao da para saber daqui qual dos dois esta certo em cada aparelho.
/// Por isso e uma escolha, desligada por padrao, que a pessoa liga para
/// TESTAR. A API e escolhida antes de o motor subir — a MainActivity le
/// esta mesma chave —, entao a troca so vale depois de reabrir o app.
///
/// A migalha: a MainActivity grava "tentando" antes de subir em OpenGL;
/// o primeiro quadro desenhado apaga. Se o app abrir e a migalha ainda
/// estiver la, a sessao anterior nao voltou — a escolha e desfeita
/// sozinha e Ajustes conta por que. Sem isso, um OpenGL que nao sobe
/// deixaria a pessoa sem conseguir chegar em Ajustes para desligar.
class GraficoPreferencia {
  GraficoPreferencia._(this._prefs);

  // As mesmas chaves que MainActivity.kt le, com o prefixo "flutter."
  // que o shared_preferences poe no Android.
  static const kOpenGl = 'grafico_opengl';
  static const kTentando = 'grafico_tentando';
  static const kCaiu = 'grafico_caiu';

  static GraficoPreferencia? _instancia;
  static GraficoPreferencia? get instancia => _instancia;

  /// Chamar uma vez, no inicio do app. A migalha e resolvida do lado
  /// nativo (e ele quem decide a API antes de o Dart existir); aqui so
  /// se le o resultado.
  static Future<GraficoPreferencia> carregar(SharedPreferences prefs) async {
    final p = GraficoPreferencia._(prefs);
    _instancia = p;
    return p;
  }

  final SharedPreferences _prefs;

  bool get openGl => _prefs.getBool(kOpenGl) ?? false;

  /// A ultima abertura em OpenGL ES nao desenhou nem um quadro.
  bool get caiu => _prefs.getBool(kCaiu) ?? false;

  Future<void> definirOpenGl(bool ligado) async {
    await _prefs.setBool(kOpenGl, ligado);
    // Escolher de novo e uma nova chance: a queda antiga nao vale mais.
    await _prefs.setBool(kCaiu, false);
  }

  /// O primeiro quadro saiu: a sessao esta viva nesta API.
  Future<void> confirmarVivo() => _prefs.setBool(kTentando, false);
}
