import 'package:flutter/widgets.dart';

const supportedLanguageCodes = [
  'en',
  'tr',
  'es',
  'de',
  'fr',
  'pt',
  'ja',
  'ko',
  'zh',
  'ar',
];

const defaultLanguageCode = 'en';

class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  final String code;
  final String nativeName;
  final String englishName;
}

const supportedLanguageOptions = <AppLanguageOption>[
  AppLanguageOption(code: 'en', nativeName: 'English', englishName: 'English'),
  AppLanguageOption(code: 'tr', nativeName: 'Türkçe', englishName: 'Turkish'),
  AppLanguageOption(code: 'es', nativeName: 'Español', englishName: 'Spanish'),
  AppLanguageOption(code: 'de', nativeName: 'Deutsch', englishName: 'German'),
  AppLanguageOption(code: 'fr', nativeName: 'Français', englishName: 'French'),
  AppLanguageOption(
    code: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
  ),
  AppLanguageOption(code: 'ja', nativeName: '日本語', englishName: 'Japanese'),
  AppLanguageOption(code: 'ko', nativeName: '한국어', englishName: 'Korean'),
  AppLanguageOption(code: 'zh', nativeName: '中文', englishName: 'Chinese'),
  AppLanguageOption(code: 'ar', nativeName: 'العربية', englishName: 'Arabic'),
];

final supportedLocales = [
  for (final code in supportedLanguageCodes) localeForLanguageCode(code),
];

Locale localeForLanguageCode(String code) {
  return switch (normalizeLanguageCode(code) ?? defaultLanguageCode) {
    'zh' => const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    'pt' => const Locale('pt', 'BR'),
    final normalized => Locale(normalized),
  };
}

String speechLocaleIdForLanguageCode(String code) {
  return switch (normalizeLanguageCode(code) ?? defaultLanguageCode) {
    'tr' => 'tr_TR',
    'es' => 'es_ES',
    'de' => 'de_DE',
    'fr' => 'fr_FR',
    'pt' => 'pt_BR',
    'ja' => 'ja_JP',
    'ko' => 'ko_KR',
    'zh' => 'zh_CN',
    'ar' => 'ar_SA',
    _ => 'en_US',
  };
}

String? normalizeLanguageCode(String? code) {
  if (code == null || code.trim().isEmpty) return null;
  final lower = code.trim().toLowerCase().replaceAll('_', '-');
  final primary = lower.split('-').first;
  if (primary == 'zh') return 'zh';
  if (primary == 'pt') return 'pt';
  if (supportedLanguageCodes.contains(primary)) return primary;
  return null;
}

String resolveAppLanguage({
  required String? savedOverride,
  required Locale deviceLocale,
}) {
  final saved = normalizeLanguageCode(savedOverride);
  if (saved != null) return saved;
  final fromDevice =
      normalizeLanguageCode(deviceLocale.languageCode) ??
      normalizeLanguageCode(deviceLocale.toLanguageTag());
  return fromDevice ?? defaultLanguageCode;
}

Locale deviceLocale() {
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  return dispatcher.locale;
}
