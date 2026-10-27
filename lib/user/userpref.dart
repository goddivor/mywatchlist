/// Legacy MAL-singleton preferences, reduced to the one field still referenced
/// (`UserMal.pref.bgImagePath`, written by `utils/sidebar_bg_manager.dart`).
///
/// It is never persisted. Every DailyAL preference lives in `lib/user/preferences/`
/// (`PreferencesBloc`, `Preferences.current`); the background is owned by `ThemeBloc`.
class UserPreferences {
  String? bgImagePath;

  UserPreferences({this.bgImagePath});
}
