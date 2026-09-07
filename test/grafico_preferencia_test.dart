import 'dart:io';

import 'package:aurea/src/features/settings/application/grafico_preferencia.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// O INTERRUPTOR VULKAN/OPENGL ES E A MIGALHA QUE O PROTEGE.
///
/// A decisao acontece no Kotlin, antes de o Dart existir; o Dart so
/// escolhe e confirma. O que pode quebrar em silencio e o COMBINADO
/// entre os dois lados: o nome das chaves. Por isso o teste le a
/// MainActivity e confere que ela fala das mesmas chaves, com o prefixo
/// que o shared_preferences poe no Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('escolher OpenGL grava a chave e perdoa a queda antiga', () async {
    SharedPreferences.setMockInitialValues({GraficoPreferencia.kCaiu: true});
    final prefs = await SharedPreferences.getInstance();
    final pref = await GraficoPreferencia.carregar(prefs);
    expect(pref.openGl, isFalse);
    expect(pref.caiu, isTrue);

    await pref.definirOpenGl(true);
    expect(pref.openGl, isTrue);
    expect(pref.caiu, isFalse, reason: 'escolher de novo e uma nova chance');
    expect(GraficoPreferencia.instancia, same(pref));
  });

  test('o primeiro quadro desarma a migalha', () async {
    SharedPreferences.setMockInitialValues({GraficoPreferencia.kTentando: true});
    final prefs = await SharedPreferences.getInstance();
    final pref = await GraficoPreferencia.carregar(prefs);
    await pref.confirmarVivo();
    expect(prefs.getBool(GraficoPreferencia.kTentando), isFalse);
  });

  test('a MainActivity le as mesmas chaves e pede o OpenGL ES ao motor', () {
    final kt = File('android/app/src/main/kotlin/com/aurea/aurea/MainActivity.kt')
        .readAsStringSync();
    expect(kt, contains('"FlutterSharedPreferences"'));
    for (final chave in [
      GraficoPreferencia.kOpenGl,
      GraficoPreferencia.kTentando,
      GraficoPreferencia.kCaiu,
    ]) {
      expect(kt, contains('"flutter.$chave"'), reason: 'a chave $chave nao esta na MainActivity');
    }
    expect(kt, contains('--impeller-backend=opengles'));
    expect(kt, contains('override fun getFlutterShellArgs()'));
    // A migalha e resolvida ANTES de pedir o OpenGL: quem nao voltou
    // nao tenta de novo.
    final resolve = kt.indexOf('putBoolean("flutter.grafico_caiu", true)');
    final pede = kt.indexOf('--impeller-backend=opengles');
    expect(resolve, greaterThan(-1));
    expect(resolve, lessThan(pede));
  });

  test('o IPA do beta nao liga o Filament no preview', () {
    // Dois motores (Filament no preview, flutter_scene na exportacao)
    // sao duas cores. O beta desenha com um so.
    final yml = File('.github/workflows/build-ipa.yml').readAsStringSync();
    expect(yml, isNot(contains('--dart-define=AUREA_FILAMENT=true')));
  });
}
