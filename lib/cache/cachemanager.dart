import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/models/search_result.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheManager {
  static const String homepageService = 'homepage';

  static CacheManager instance = new CacheManager();
  static SharedPreferences? pref;

  CacheManager() {
    SharedPreferences.getInstance().then((value) => pref = value);
  }

  Future<SharedPreferences> get _pref async =>
      pref ?? await SharedPreferences.getInstance();

  Future<bool> checkIfExists(String url) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      return pref!.containsKey(url);
    } catch (e) {
      // logDal(e);
    }
    return false;
  }

  Future<dynamic> getCachedContent(String url) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      if (!(await checkIfExists(url))) {
        return null;
      }
      Map<String, dynamic> _map = jsonDecode(pref?.getString(url) ?? "{}");
      return _map.isEmpty ? null : _map;
    } catch (e) {
      // logDal(e);
    }
    return null;
  }

  Future<bool> setCachedJson(String url, dynamic result,
      {SharedPreferences? pref}) async {
    try {
      pref = pref ?? await SharedPreferences.getInstance();
      return await pref.setString(url, jsonEncode(result));
    } catch (e) {
      // logDal(e);
    }
    return false;
  }

  Future<void> resetData() async {
    pref = pref ?? await SharedPreferences.getInstance();
    await pref?.clear();
  }

  Future<String?> getValue(String key) async {
    return (pref ?? await SharedPreferences.getInstance()).getString(key);
  }

  Future<void> setValue(String key, String value) async {
    (pref ?? await SharedPreferences.getInstance()).setString(key, value);
  }

  Future<String?> getValueForService(String serviceName, String key) async {
    return getValue("$serviceName - $key");
  }

  Future<String?> getValueForServiceAutoExpire(
    String serviceName,
    String key, [
    int expiresIn = 60 * 60 * 24,
  ]) async {
    final value = await getValue("$serviceName - $key");
    if (value != null) {
      final map = jsonDecode(value);
      if (map is Map) {
        final time = map["time"];
        if (time is int) {
          final now = DateTime.now().millisecondsSinceEpoch;
          expiresIn *= 1000;
          if ((now - time) < expiresIn) {
            return map['value'];
          }
        }
      }
    }
    return null;
  }

  Future<void> setValueForServiceAutoExpireIn(
      String serviceName, String key, String? value) async {
    if (value == null) {
      await pref?.remove("$serviceName - $key");
    } else {
      await setValueForService(
          serviceName,
          key,
          jsonEncode({
            "time": DateTime.now().millisecondsSinceEpoch,
            "value": value,
          }));
    }
  }

  Future<void> setValueForService(
      String serviceName, String key, String value) async {
    setValue("$serviceName - $key", value);
  }

  Future<String?> getUserImage(String? username) async {
    if (username == null) return null;
    return await CacheManager.instance
        .getValueForService("cached-user-image", username);
  }

  Future<void> setUserImage(String? username, String? url) async {
    if (username != null && url != null)
      await CacheManager.instance
          .setValueForService("cached-user-image", username, url);
  }

  /// The whole backup as a JSON string (settings, bookmarks, private notes); see
  /// [BackupService]. Kept under its old name for existing callers.
  Future<String> getBackUpData({String? appVersion}) =>
      BackupService.create(appVersion: appVersion);

  /// Restores a backup string without asking anything (merge, every section). Screens
  /// preview first with [BackupService.parse] and call [BackupService.restore] themselves.
  Future<bool> restoreData(String data) async {
    try {
      await BackupService.restore(BackupService.parse(data));
      return true;
    } catch (e) {
      debugPrint('Restore failed: $e');
      return false;
    }
  }

  Future<bool> isFirstTime(String key) async {
    final value = await getValue(key);
    if (value == null) {
      setValue(key, "true");
      return true;
    }
    return false;
  }

  void setFirstTime(String s) {
    setValue(s, "true");
  }

  // --- Homepage cache helpers ---

  Future<void> cacheAnimeList(String sectionKey, List<Anime> animeList) async {
    final jsonList = animeList.map((a) => a.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  Future<List<Anime>?> getCachedAnimeList(
      String sectionKey, [int expiresInSeconds = 7200]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => Anime.fromMAlJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Cache error (anime) $sectionKey: $e');
      return null;
    }
  }

  Future<void> cacheNewsList(
      String sectionKey, List<Map<String, String>> news) async {
    final jsonString = jsonEncode(news);
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  Future<List<Map<String, String>>?> getCachedNewsList(
      String sectionKey, [int expiresInSeconds = 28800]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('Cache error (news) $sectionKey: $e');
      return null;
    }
  }

  /// Cache a SearchResult with auto-expiry.
  Future<void> cacheSearchResult(String sectionKey, SearchResult result) async {
    final jsonString = jsonEncode(result.toJson());
    await setValueForServiceAutoExpireIn(homepageService, sectionKey, jsonString);
  }

  /// Get a cached SearchResult.
  Future<SearchResult?> getCachedSearchResult(
      String sectionKey, [int expiresInSeconds = 7200]) async {
    final jsonString = await getValueForServiceAutoExpire(
        homepageService, sectionKey, expiresInSeconds);
    if (jsonString == null) return null;
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return SearchResult.fromJson(jsonMap);
    } catch (e) {
      debugPrint('Cache error (searchResult) $sectionKey: $e');
      return null;
    }
  }

  Future<void> clearHomepageCache() async {
    pref = pref ?? await SharedPreferences.getInstance();
    final keys =
        pref!.getKeys().where((key) => key.startsWith('$homepageService - '));
    for (final key in keys.toList()) {
      await pref!.remove(key);
    }
  }

  /// Prefixes of the SharedPreferences entries that are only a cache of something that
  /// can be fetched again (home sections, avatars, profiles, list statuses).
  static const List<String> dataCachePrefixes = [
    'homepage - ',
    'cached-user-image - ',
    'cached_user_profile_v1_',
    'list_status_cache_v1',
  ];

  /// True for an entry that [clearDataCaches] removes.
  static bool isDataCacheKey(String key) =>
      dataCachePrefixes.any(key.startsWith);

  /// How many cache entries are stored and roughly how many bytes they take.
  Future<({int entries, int bytes})> dataCacheStats() async {
    final prefs = await _pref;
    var entries = 0;
    var bytes = 0;
    for (final key in prefs.getKeys()) {
      if (!isDataCacheKey(key)) continue;
      entries++;
      bytes += key.length + (prefs.getString(key)?.length ?? 0);
    }
    return (entries: entries, bytes: bytes);
  }

  /// Removes every cache entry of [isDataCacheKey]; settings, bookmarks and notes stay.
  Future<int> clearDataCaches() async {
    final prefs = await _pref;
    var removed = 0;
    for (final key in prefs.getKeys().toList()) {
      if (!isDataCacheKey(key)) continue;
      await prefs.remove(key);
      removed++;
    }
    return removed;
  }
}

/// A backup file read and checked, not yet applied: what the restore preview shows.
class BackupBundle {
  final int version;
  final DateTime? createdAt;
  final String? appVersion;

  /// SharedPreferences entries (key to String, bool, int, double or List of String).
  final Map<String, Object> settings;

  /// `PrivateNotesStore.export()` payload, or null when the file has no notes.
  final Map<String, dynamic>? notes;

  /// `Bookmarks.export()` payload, or null when the file has no bookmarks.
  final Map<String, dynamic>? bookmarks;

  const BackupBundle({
    required this.version,
    this.createdAt,
    this.appVersion,
    this.settings = const {},
    this.notes,
    this.bookmarks,
  });

  int get settingsCount => settings.length;
  int get notesCount => (notes?['notes'] as Map?)?.length ?? 0;
  int get bookmarksCount => (bookmarks?['bookmarks'] as List?)?.length ?? 0;

  bool get isEmpty => settingsCount == 0 && notesCount == 0 && bookmarksCount == 0;
}

/// The parts of a backup.
enum BackupSection { settings, bookmarks, notes }

/// What a restore wrote.
class BackupRestoreResult {
  final int settings;
  final int bookmarks;
  final int notes;
  const BackupRestoreResult({this.settings = 0, this.bookmarks = 0, this.notes = 0});
}

/// Builds, checks and applies the JSON backup: preferences, bookmarks and private notes.
///
/// File shape: `{"app": "mywatchlist", "format": 1, "createdAt": iso, "appVersion": "...",
/// "settings": {key: value}, "bookmarks": {...}, "notes": {...}}`. Account tokens live in
/// secure storage and are never part of it; neither are device paths (background pictures,
/// download folder) nor caches.
abstract final class BackupService {
  static const int format = 1;
  static const String appId = 'mywatchlist';

  /// Settings that travel with a backup (exact keys).
  static const Set<String> settingsKeys = {
    'prefs_general_v1',
    'prefs_content_v1',
    'prefs_list_v1',
    'prefs_notifications_v1',
    'seed_color',
    'dynamic_color_v1',
    'custom_seed_colors_v1',
    'font_family',
    'theme_mode_name',
    'show_bg',
    'language_code',
    'use_system_language',
    'mal_home_preferences',
    'cross_tracker_enabled',
  };

  /// Settings that travel with a backup (key prefixes): list views, seasonal views and
  /// cross-tracker links.
  static const List<String> settingsPrefixes = [
    'user_list_view_v1:',
    'user_list_place_v1:',
    'seasonal_view_v1:',
    'tracker_link_',
  ];

  /// Largest file a restore accepts.
  static const int maxBytes = 20 * 1024 * 1024;

  static bool isSettingsKey(String key) =>
      settingsKeys.contains(key) || settingsPrefixes.any(key.startsWith);

  static bool _validValue(Object? v) =>
      v is String ||
      v is bool ||
      v is int ||
      v is double ||
      (v is List && v.every((e) => e is String));

  /// The settings of this device that a backup carries.
  static Map<String, Object> collectSettings(SharedPreferences prefs) {
    final out = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!isSettingsKey(key)) continue;
      final value = prefs.get(key);
      if (value is List) {
        out[key] = value.cast<String>().toList();
      } else if (value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  /// The backup text.
  static Future<String> create({
    String? appVersion,
    DateTime? now,
    SharedPreferences? prefs,
    PrivateNotesStore? notesStore,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    final notes = await (notesStore ?? PrivateNotesStore.instance).export();
    final bookmarks = await Bookmarks.export();
    return jsonEncode({
      'app': appId,
      'format': format,
      'createdAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      if (appVersion != null) 'appVersion': appVersion,
      'settings': collectSettings(prefs),
      'bookmarks': bookmarks,
      'notes': notes,
    });
  }

  /// Reads and checks [raw]; throws a [FormatException] when it is not a MyWatchList
  /// backup or comes from a newer format. Unknown settings and malformed values are
  /// dropped (counted nowhere), so the preview shows only what a restore can write.
  /// Top-level friendly for `compute`.
  static BackupBundle parse(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const FormatException('Not a JSON file');
    }
    if (decoded is! Map || decoded['app'] != appId) {
      throw const FormatException('Not a MyWatchList backup');
    }
    final Map<dynamic, dynamic> root = decoded;
    final version = root['format'];
    if (version is! int || version < 1) {
      throw const FormatException('Missing backup format');
    }
    if (version > format) {
      throw FormatException('Backup format $version is newer than this app');
    }
    final settings = <String, Object>{};
    final rawSettings = root['settings'];
    if (rawSettings is Map) {
      rawSettings.forEach((key, value) {
        if (key is String && isSettingsKey(key) && _validValue(value)) {
          settings[key] = value is List ? value.cast<String>().toList() : value as Object;
        }
      });
    }
    Map<String, dynamic>? section(String name, String listKey, bool Function(Object?) ok) {
      final v = root[name];
      if (v is! Map || !ok(v[listKey])) return null;
      return Map<String, dynamic>.from(v);
    }

    final createdRaw = root['createdAt'];
    return BackupBundle(
      version: version,
      createdAt: createdRaw is String ? DateTime.tryParse(createdRaw)?.toLocal() : null,
      appVersion: root['appVersion'] is String ? root['appVersion'] as String : null,
      settings: settings,
      bookmarks: section('bookmarks', 'bookmarks', (v) => v is List),
      notes: section('notes', 'notes', (v) => v is Map),
    );
  }

  /// What this device holds now, for the "N here, M in the file" lines.
  static Future<BackupBundle> current({SharedPreferences? prefs, PrivateNotesStore? notesStore}) async {
    prefs ??= await SharedPreferences.getInstance();
    return BackupBundle(
      version: format,
      settings: collectSettings(prefs),
      bookmarks: await Bookmarks.export(),
      notes: await (notesStore ?? PrivateNotesStore.instance).export(),
    );
  }

  /// Writes the chosen [sections] of [bundle]. With [replace] each chosen section first
  /// loses what the device holds; otherwise the file's entries are added or overwrite the
  /// same keys and nothing else is removed. The caller shows the preview and asks first.
  static Future<BackupRestoreResult> restore(
    BackupBundle bundle, {
    Set<BackupSection> sections = const {
      BackupSection.settings,
      BackupSection.bookmarks,
      BackupSection.notes,
    },
    bool replace = false,
    SharedPreferences? prefs,
    PrivateNotesStore? notesStore,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    var settings = 0, bookmarks = 0, notes = 0;
    if (sections.contains(BackupSection.settings) && bundle.settings.isNotEmpty) {
      if (replace) {
        for (final key in prefs.getKeys().toList()) {
          if (isSettingsKey(key) && !bundle.settings.containsKey(key)) {
            await prefs.remove(key);
          }
        }
      }
      for (final entry in bundle.settings.entries) {
        final v = entry.value;
        if (v is String) {
          await prefs.setString(entry.key, v);
        } else if (v is bool) {
          await prefs.setBool(entry.key, v);
        } else if (v is int) {
          await prefs.setInt(entry.key, v);
        } else if (v is double) {
          await prefs.setDouble(entry.key, v);
        } else if (v is List<String>) {
          await prefs.setStringList(entry.key, v);
        } else {
          continue;
        }
        settings++;
      }
    }
    if (sections.contains(BackupSection.bookmarks) && bundle.bookmarks != null) {
      bookmarks = await Bookmarks.import(bundle.bookmarks!, replace: replace);
    }
    if (sections.contains(BackupSection.notes) && bundle.notes != null) {
      notes = await (notesStore ?? PrivateNotesStore.instance).import(bundle.notes!, replace: replace);
    }
    return BackupRestoreResult(settings: settings, bookmarks: bookmarks, notes: notes);
  }
}
