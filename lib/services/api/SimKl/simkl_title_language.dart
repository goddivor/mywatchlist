import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';

/// The title language of the Simkl profile (`anime_title_language` of `GET /users/settings`).
enum SimklTitleLanguage {
  /// Simkl's default title (English when the title has one).
  english,

  /// The romanised Japanese title.
  romaji,

  /// The title in its original script.
  original;

  /// Reads the setting tolerantly (Simkl documents no value list): unknown or empty = [english].
  static SimklTitleLanguage parse(Object? value) {
    final v = value is String ? value.trim().toLowerCase() : '';
    if (v.contains('romaji') || v.contains('romaj')) return romaji;
    if (v == 'ja' || v == 'jp' || v.contains('native') || v.contains('original') || v.contains('japan')) {
      return original;
    }
    return english;
  }
}

/// The title language kept for the session: set when the settings are read, applied to the
/// titles of the CDN feeds and of the title page.
abstract final class SimklTitlePreference {
  static SimklTitleLanguage language = SimklTitleLanguage.english;
  static bool _asked = false;

  /// Reads `GET /users/settings` once per app run (settings are set-and-forget: Simkl asks not
  /// to refetch on a timer) and keeps the language. A failure keeps the default; [force] asks again.
  static Future<void> ensureLoaded({SimklUser? user, bool force = false}) async {
    if (_asked && !force) return;
    _asked = true;
    try {
      final UserProfSimkl info = await (user ?? SimklUser()).getUserInfo().timeout(const Duration(seconds: 4));
      language = info.titleLanguage;
    } catch (_) {
      _asked = false; // signed out or offline: try again at the next open
    }
  }

  /// Forgets the language (sign out, another account).
  static void reset() {
    language = SimklTitleLanguage.english;
    _asked = false;
  }

  /// [title] (Simkl's default), [romaji] and [original] picked by [lang]; missing ones fall back
  /// to [title].
  static String pick(SimklTitleLanguage lang, String title, {String? romaji, String? original}) =>
      switch (lang) {
        SimklTitleLanguage.english => title,
        SimklTitleLanguage.romaji => romaji ?? title,
        SimklTitleLanguage.original => original ?? romaji ?? title,
      };
}
