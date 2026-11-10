import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LanguageBloc> _bloc(Map<String, Object> saved,
    {List<Locale> device = const [Locale('en', 'US')]}) async {
  SharedPreferences.setMockInitialValues(saved);
  final prefs = await SharedPreferences.getInstance();
  return LanguageBloc(prefs: prefs, deviceLocales: () => device);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => LanguageBloc.apply('en'));

  test('the picker lists exactly the generated locales', () {
    final generated = S.delegate.supportedLocales.map((l) => l.toString()).toSet();
    final picker = SupportedLanguages.languages.map((l) => l.locale.toString()).toSet();
    expect(picker, generated);
    expect(picker, containsAll(['ar_EG', 'id_ID', 'tr_TR']));
  });

  test('nothing saved: follows the device language', () async {
    final bloc = await _bloc({}, device: const [Locale('fr', 'CA')]);
    expect(bloc.state.useSystemLanguage, isTrue);
    await bloc.applyCurrent();
    expect(Intl.defaultLocale, 'fr_FR');
    // Key from the l10n-pipeline unit fragment, translated in its fr_FR file.
    expect(S.current.Language_Available, 'Langues disponibles');
    await bloc.close();
  });

  test('picking French applies it at once and survives a restart', () async {
    final bloc = await _bloc({});
    bloc.add(const LanguageChanged(languageCode: 'fr_FR', useSystemLanguage: false));
    await bloc.stream.first;
    expect(S.current.Language_settings, 'Paramètres de langue');
    expect(S.current.Language_Changed_To('Français'), 'Langue définie : Français');
    await bloc.close();

    await LanguageBloc.apply('en');
    final prefs = await SharedPreferences.getInstance();
    final restarted = LanguageBloc(prefs: prefs, deviceLocales: () => const [Locale('en')]);
    expect(restarted.state.languageCode, 'fr_FR');
    expect(restarted.state.useSystemLanguage, isFalse);
    await restarted.applyCurrent();
    expect(S.current.Language_settings, 'Paramètres de langue');
    await restarted.close();
  });

  test('legacy short codes and the old storage key are migrated', () async {
    expect((await _bloc({'language': 'fr'})).state.languageCode, 'fr_FR');
    expect((await _bloc({'language_code': 'pt'})).state.languageCode, 'pt_BR');
    expect((await _bloc({'language_code': 'it'})).state.languageCode, 'en');
    expect((await _bloc({'language_code': 'ja'})).state.useSystemLanguage, isFalse);
  });

  test('a fragment key missing in a locale falls back to English', () async {
    await LanguageBloc.apply('de_DE');
    expect(S.current.Language_settings, isNot('Language Settings'));
    expect(S.current.Language_Available, 'Available languages');
  });

  test('a device language the app lacks falls back to English', () {
    expect(SupportedLanguages.resolveSystem(const [Locale('it', 'IT')]), 'en');
    expect(SupportedLanguages.resolveSystem(const [Locale('it'), Locale('ar', 'MA')]), 'ar_EG');
  });
}
