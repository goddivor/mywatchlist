// ignore_for_file: depend_on_referenced_packages

import 'package:shared_preferences/shared_preferences.dart';

class UserPreference {
  static const String _keyFirstTime = "first_time";
  static const String _keyLanguage = "language";
  static const String _keyTheme = "theme";

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Vérifier si c'est la première ouverture
  Future<bool> isFirstTime() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  // Définir la première ouverture à false après l'onboarding
  Future<void> setFirstTimeFalse() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFirstTime, false);
  }

  // Obtenir la langue préférée
  Future<String> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLanguage) ?? "fr";
  }

  // Définir la langue préférée
  Future<void> setLanguage(String language) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLanguage, language);
  }

  // Obtenir le thème (clair ou sombre)
  Future<bool> isDarkTheme() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyTheme) ?? false;
  }

  // Définir le thème
  Future<void> setTheme(bool isDark) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyTheme, isDark);
  }
}
