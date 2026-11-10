// ignore_for_file: depend_on_referenced_packages

import 'package:shared_preferences/shared_preferences.dart';

// The timezone of airing times is a contract preference now (`Preferences.content.timezone`);
// re-exported so the callers that only need the enum keep compiling.
export 'package:mywatchlist/user/preferences/content_preferences.dart' show TimezonePref;

/// MWL-only device settings (first launch, legacy theme flag, background, download folder,
/// cross-tracker sync). DailyAL preferences live in `lib/user/preferences/` and the language
/// in `LanguageBloc`.
class UserPreference {
  static const String _keyFirstTime = "first_time";
  static const String _keyTheme = "theme";
  static const String _keyBgImagePath = "bg_image_path";
  static const String _keyShowBg = "show_bg";
  static const String _keyDownloadPath = "download_path";
  static const String _keyCrossTracker = "cross_tracker_enabled";

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

  // Get custom download path (null = use default)
  Future<String?> getDownloadPath() async {
    final prefs = await _prefs;
    return prefs.getString(_keyDownloadPath);
  }

  // Set custom download path (null = reset to default)
  Future<void> setDownloadPath(String? path) async {
    final prefs = await _prefs;
    if (path != null) {
      await prefs.setString(_keyDownloadPath, path);
    } else {
      await prefs.remove(_keyDownloadPath);
    }
  }

  // Get cross-tracker sync preference (enabled by default)
  Future<bool> getCrossTrackerEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_keyCrossTracker) ?? true;
  }

  // Set cross-tracker sync preference
  Future<void> setCrossTrackerEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_keyCrossTracker, enabled);
  }
}