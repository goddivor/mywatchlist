import 'dart:ui';

import 'package:mywatchlist/generated/l10n.dart';

/// One language the app ships translations for.
///
/// [code] is the ARB locale tag (`lib/l10n/intl_<code>.arb`), which is also the value stored
/// in the preferences. [nativeName] is the language's own name (an endonym, the same in every
/// UI language, so it is data rather than translatable text).
class SupportedLanguage {
  final String code;
  final String nativeName;
  final String Function() localizedName;
  final bool isRtl;

  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.localizedName,
    this.isRtl = false,
  });

  Locale get locale => localeFromCode(code);
}

/// Builds a [Locale] from an ARB tag such as `fr_FR` or `ja`.
Locale localeFromCode(String code) {
  final parts = code.split(RegExp('[_-]'));
  return Locale.fromSubtags(
    languageCode: parts.first,
    countryCode: parts.length > 1 ? parts[1] : null,
  );
}

class SupportedLanguages {
  static const String defaultCode = 'en';

  /// Must list exactly the locales of `lib/l10n/intl_*.arb` (checked by a unit test).
  static final List<SupportedLanguage> languages = [
    SupportedLanguage(code: 'en', nativeName: 'English', localizedName: () => S.current.English),
    SupportedLanguage(code: 'fr_FR', nativeName: 'Français', localizedName: () => S.current.French),
    SupportedLanguage(code: 'es_ES', nativeName: 'Español', localizedName: () => S.current.Spanish),
    SupportedLanguage(
        code: 'pt_BR', nativeName: 'Português (Brasil)', localizedName: () => S.current.Portuguese),
    SupportedLanguage(code: 'de_DE', nativeName: 'Deutsch', localizedName: () => S.current.German),
    SupportedLanguage(
        code: 'id_ID', nativeName: 'Bahasa Indonesia', localizedName: () => S.current.Indonesian),
    SupportedLanguage(code: 'tr_TR', nativeName: 'Türkçe', localizedName: () => S.current.Turkish),
    SupportedLanguage(code: 'ru_RU', nativeName: 'Русский', localizedName: () => S.current.Russian),
    SupportedLanguage(
        code: 'ar_EG', nativeName: 'العربية', localizedName: () => S.current.Arabic, isRtl: true),
    SupportedLanguage(code: 'ja', nativeName: '日本語', localizedName: () => S.current.Japanese),
    SupportedLanguage(code: 'ko_KR', nativeName: '한국어', localizedName: () => S.current.Korean),
  ];

  static SupportedLanguage? byCode(String code) {
    for (final language in languages) {
      if (language.code == code) return language;
    }
    return null;
  }

  /// Maps any stored or device value (`fr`, `fr_CA`, `fr-FR`, `fr_FR`) to a supported ARB tag,
  /// matching the full tag first, then the language code; unknown languages fall back to English.
  static String normalize(String? value) {
    if (value == null || value.isEmpty) return defaultCode;
    final wanted = value.replaceAll('-', '_');
    if (byCode(wanted) != null) return wanted;
    final languageCode = wanted.split('_').first.toLowerCase();
    for (final language in languages) {
      if (language.locale.languageCode == languageCode) return language.code;
    }
    return defaultCode;
  }

  /// Picks the supported language closest to the device's preferred [locales].
  static String resolveSystem(List<Locale> locales) {
    for (final locale in locales) {
      final languageCode = locale.languageCode;
      final exact = byCode('${languageCode}_${locale.countryCode ?? ''}') ?? byCode(languageCode);
      if (exact != null) return exact.code;
      for (final language in languages) {
        if (language.locale.languageCode == languageCode) return language.code;
      }
    }
    return defaultCode;
  }
}
