import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/prefs.dart';
import 'translations.dart';

const appLanguages = <String, String>{
  'pt': 'Português', 'en': 'English', 'es': 'Español', 'ar': 'العربية',
  'ko': '한국어', 'ja': '日本語', 'zh': '简体中文', 'hi': 'हिन्दी',
  'id': 'Bahasa Indonesia', 'ru': 'Русский',
};
const languagePreferenceKey = 'settings.language';
final appLanguageProvider = NotifierProvider<AppLanguageController, String>(AppLanguageController.new);

class AppLanguageController extends Notifier<String> {
  @override
  String build() {
    final saved = ref.read(sharedPreferencesProvider).getString(languagePreferenceKey);
    return appLanguages.containsKey(saved) ? saved! : 'pt';
  }
  Future<void> select(String code) async {
    if (!appLanguages.containsKey(code)) return;
    await ref.read(sharedPreferencesProvider).setString(languagePreferenceKey, code);
    state = code;
  }
}

String translate(BuildContext context, String source) =>
    translateFor(Localizations.maybeLocaleOf(context)?.languageCode ?? 'pt', source);

String translateFor(String code, String source) {
  if (code == 'pt') return source;
  return appTranslations[source]?[code] ?? source;
}

/// Only application labels use this widget. User-authored content stays Text.
class AppText extends Text {
  const AppText(super.data, {super.key, super.style, super.strutStyle,
    super.textAlign, super.textDirection, super.locale, super.softWrap,
    super.overflow, super.textScaler, super.maxLines, super.semanticsLabel,
    super.textWidthBasis, super.textHeightBehavior});
  @override
  Widget build(BuildContext context) => Text(
    translate(context, data!), style: style, strutStyle: strutStyle,
    textAlign: textAlign, textDirection: textDirection, locale: locale,
    softWrap: softWrap, overflow: overflow, textScaler: textScaler,
    maxLines: maxLines, semanticsLabel: semanticsLabel == null ? null : translate(context, semanticsLabel!),
    textWidthBasis: textWidthBasis, textHeightBehavior: textHeightBehavior,
  ).build(context);
}
