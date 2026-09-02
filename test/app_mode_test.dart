import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurea/src/core/app_mode.dart';
import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/features/editor/presentation/widgets/add_layer_sheet.dart';

/// O INTERRUPTOR (AUREA-reset-ao-nucleo.md): padrao `core`, persiste em
/// SharedPreferences, e a interface obedece — a sheet de adicionar
/// camada e o primeiro lugar onde isso tem de valer.
void main() {
  Future<ProviderContainer> containerCom(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(sp)]);
    addTearDown(c.dispose);
    return c;
  }

  test('padrao e core; set persiste e o espelho sincrono segue', () async {
    final c = await containerCom({});
    expect(c.read(appModeProvider), AppMode.core);
    expect(AppModeSwitch.isCore, isTrue);

    c.read(appModeProvider.notifier).set(AppMode.full);
    expect(c.read(appModeProvider), AppMode.full);
    expect(AppModeSwitch.isFull, isTrue);
    final sp = c.read(sharedPreferencesProvider);
    expect(sp.getString('app.mode'), 'full');

    c.read(appModeProvider.notifier).toggle();
    expect(c.read(appModeProvider), AppMode.core);
    expect(AppModeSwitch.isCore, isTrue);
  });

  test('o modo salvo e lido na abertura', () async {
    final c = await containerCom({'app.mode': 'full'});
    expect(c.read(appModeProvider), AppMode.full);
    expect(AppModeSwitch.isFull, isTrue);
    AppModeSwitch.force(AppMode.core);
  });

  Future<void> abreSheet(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showAddLayerSheet(context, ref, Duration.zero),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('no nucleo, adicionar camada mostra so video, imagem e audio',
      (tester) async {
    final c = await containerCom({});
    await abreSheet(tester, c);
    expect(find.text('Video'), findsOneWidget);
    expect(find.text('Imagem'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    for (final oculto in [
      'Texto',
      'Forma',
      'Legendas',
      'Nulo 3D',
      'Particulas',
      'Icones',
      'Ajuste',
      'Elementos 3D',
      'Cena 3D',
    ]) {
      expect(find.text(oculto), findsNothing, reason: oculto);
    }
  });

  testWidgets('no estudio completo, o menu da AM volta com tudo',
      (tester) async {
    final c = await containerCom({'app.mode': 'full'});
    await abreSheet(tester, c);
    // Abas e trilho (nivel 1): as coisas ficam por aba, nao numa fileira.
    for (final aba in ['Forma', 'Midia', 'Audio', 'Objeto', 'Modelo']) {
      expect(find.text(aba), findsOneWidget, reason: aba);
    }
    expect(find.text('Texto'), findsOneWidget);
    await tester.tap(find.text('Midia'));
    await tester.pumpAndSettle();
    expect(find.text('Video'), findsOneWidget);
    await tester.tap(find.text('Objeto'));
    await tester.pumpAndSettle();
    for (final item in ['Particulas', 'Cena 3D', 'Nulo 3D']) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    AppModeSwitch.force(AppMode.core);
  });
}
