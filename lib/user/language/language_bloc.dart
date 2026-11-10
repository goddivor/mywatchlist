import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language. The single source of truth is two SharedPreferences keys:
/// [keyLanguage] (ARB tag) and [keySystem] (follow the device). The state starts from the saved
/// value synchronously, so the very first frame is already in the right language.
class LanguageBloc extends Bloc<LanguageEvent, LanguageState> {
  static const String keyLanguage = 'language_code';
  static const String keySystem = 'use_system_language';

  /// Written by the old settings page through `UserPreference.setLanguage`; read once as a
  /// fallback so an existing pick survives the upgrade.
  static const String legacyKeyLanguage = 'language';

  final SharedPreferences prefs;

  /// Device locales, injectable for tests.
  final List<Locale> Function() deviceLocales;

  LanguageBloc({required this.prefs, List<Locale> Function()? deviceLocales})
      : deviceLocales = deviceLocales ?? (() => PlatformDispatcher.instance.locales),
        super(readSaved(prefs)) {
    on<LanguageLoadStarted>(_onLoadStarted);
    on<LanguageChanged>(_onChanged);
  }

  /// The saved language; follows the device when nothing was ever picked.
  static LanguageState readSaved(SharedPreferences prefs) {
    final saved = prefs.getString(keyLanguage) ?? prefs.getString(legacyKeyLanguage);
    return LanguageState(
      languageCode: SupportedLanguages.normalize(saved),
      useSystemLanguage: prefs.getBool(keySystem) ?? saved == null,
    );
  }

  /// Loads the strings of [code] into `S.current` and the date symbols used by `DateFormat`.
  static Future<void> apply(String code) async {
    await S.load(localeFromCode(code));
    await initializeDateFormatting();
  }

  /// Applies the current state; `main` awaits it before `runApp`.
  Future<void> applyCurrent() => apply(state.effectiveCode(deviceLocales()));

  Future<void> _onLoadStarted(LanguageLoadStarted event, Emitter<LanguageState> emit) async {
    final saved = readSaved(prefs);
    await apply(saved.effectiveCode(deviceLocales()));
    emit(saved);
  }

  Future<void> _onChanged(LanguageChanged event, Emitter<LanguageState> emit) async {
    final next = LanguageState(
      languageCode: SupportedLanguages.normalize(event.languageCode),
      useSystemLanguage: event.useSystemLanguage,
    );
    await prefs.setString(keyLanguage, next.languageCode);
    await prefs.setBool(keySystem, next.useSystemLanguage);
    await apply(next.effectiveCode(deviceLocales()));
    emit(next);
  }
}
