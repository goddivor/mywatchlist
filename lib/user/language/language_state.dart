import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';

class LanguageState extends Equatable {
  /// The language picked in the settings: an ARB tag from [SupportedLanguages] (`fr_FR`, `ja`…).
  /// Kept while [useSystemLanguage] is on, so turning it off restores the last pick.
  final String languageCode;

  /// Follow the device language instead of [languageCode].
  final bool useSystemLanguage;

  const LanguageState({
    required this.languageCode,
    required this.useSystemLanguage,
  });

  const LanguageState.initial()
      : languageCode = SupportedLanguages.defaultCode,
        useSystemLanguage = true;

  /// Locale forced on `MaterialApp`; `null` lets it follow the device (system mode).
  Locale? get appLocale => useSystemLanguage ? null : localeFromCode(languageCode);

  /// The ARB tag actually displayed, given the device's preferred [deviceLocales].
  String effectiveCode(List<Locale> deviceLocales) => useSystemLanguage
      ? SupportedLanguages.resolveSystem(deviceLocales)
      : languageCode;

  LanguageState copyWith({
    String? languageCode,
    bool? useSystemLanguage,
  }) {
    return LanguageState(
      languageCode: languageCode ?? this.languageCode,
      useSystemLanguage: useSystemLanguage ?? this.useSystemLanguage,
    );
  }

  @override
  List<Object> get props => [languageCode, useSystemLanguage];
}
