// ignore_for_file: depend_on_referenced_packages

import 'package:shared_preferences/shared_preferences.dart';

class UserPreference {
  static const String _keyFirstTime = "first_time";
  static const String _keyLanguage = "language";
  static const String _keyTheme = "theme";
  static const String _keyBgImagePath = "bg_image_path";
  static const String _keyShowBg = "show_bg";

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Check if it's the first app launch
  Future<bool> isFirstTime() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  // Set first launch to false after onboarding
  Future<void> setFirstTimeFalse() async {
    final prefs = await _prefs;
    await prefs.setBool(_keyFirstTime, false);
  }

  // Get preferred language
  Future<String> getLanguage() async {
    final prefs = await _prefs;
    return prefs.getString(_keyLanguage) ?? "en";
  }

  // Set preferred language
  Future<void> setLanguage(String language) async {
    final prefs = await _prefs;
    await prefs.setString(_keyLanguage, language);
  }

  // Get theme preference (light or dark)
  Future<bool> isDarkTheme() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyTheme) ?? false;
  }

  // Set theme preference
  Future<void> setTheme(bool isDark) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyTheme, isDark);
  }
  
  // Get background image path
  Future<String?> getBackgroundImagePath() async {
    final prefs = await _prefs;
    return prefs.getString(_keyBgImagePath);
  }
  
  // Set background image path
  Future<void> setBackgroundImagePath(String? path) async {
    final prefs = await _prefs;
    if (path != null) {
      await prefs.setString(_keyBgImagePath, path);
    } else {
      await prefs.remove(_keyBgImagePath);
    }
  }
  
  // Get show background preference
  Future<bool> getShowBackground() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyShowBg) ?? true;
  }
  
  // Set show background preference
  Future<void> setShowBackground(bool show) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyShowBg, show);
  }
}