import 'package:aurea/src/core/l10n/app_language.dart';
import 'package:aurea/src/core/l10n/translations.dart';
import 'package:aurea/src/core/storage/prefs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('every label has all nine languages and preference persists', () async {
    for (final row in appTranslations.values) {
      expect(row.keys.toSet(), appLanguages.keys.where((c) => c != 'pt').toSet());
      expect(row.values.every((s) => s.isNotEmpty), isTrue);
    }
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await container.read(appLanguageProvider.notifier).select('ja');
    expect(prefs.getString(languagePreferenceKey), 'ja');
    container.invalidate(appLanguageProvider);
    expect(container.read(appLanguageProvider), 'ja');
    expect(translateFor('en', 'My project'), 'My project');
  });
  testWidgets('all locales render and Arabic uses RTL', (tester) async {
    for (final code in appLanguages.keys) {
      await tester.pumpWidget(MaterialApp(
        locale: Locale(code),
        supportedLocales: [for (final c in appLanguages.keys) Locale(c)],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: AppText('Idioma')),
      ));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppText));
      expect(Directionality.of(context), code == 'ar' ? TextDirection.rtl : TextDirection.ltr);
      expect(translate(context, 'Idioma'), code == 'pt' ? 'Idioma' : appTranslations['Idioma']![code]);
      expect(tester.takeException(), isNull);
    }
  });
}
