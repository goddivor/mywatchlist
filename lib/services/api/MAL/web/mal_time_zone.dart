import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// The time zone of the signed-in MyAnimeList account (its profile setting, `time_zone` of
/// `/users/@me`, an IANA name such as `America/Los_Angeles`).
///
/// MAL writes the absolute dates of its pages (`Nov 20, 2026 7:27 AM`, `Yesterday, 7:27 AM`)
/// in that zone, not in the phone's: [location] lets them be read as the real instant.
/// Kept on the device (`mal_time_zone`) and asked again at most once a day.
class MalTimeZone {
  MalTimeZone({
    Future<String?> Function()? fetch,
    Future<SharedPreferences> Function()? storage,
    DateTime Function()? clock,
  })  : _fetch = fetch ?? _fetchOwn,
        _storage = storage ?? SharedPreferences.getInstance,
        _clock = clock ?? DateTime.now;

  static final MalTimeZone instance = MalTimeZone();

  static const String _nameKey = 'mal_time_zone';
  static const String _askedKey = 'mal_time_zone_asked';
  static const Duration refreshEvery = Duration(days: 1);

  final Future<String?> Function() _fetch;
  final Future<SharedPreferences> Function() _storage;
  final DateTime Function() _clock;

  String? _name;
  tz.Location? _location;
  Future<void>? _loading;

  /// The account's zone, null while unknown (dates are then read as the phone's time).
  tz.Location? get location => _location;

  /// The IANA name of the account's zone, null while unknown.
  String? get name => _name;

  /// Loads the kept zone, then asks MAL when it is unknown or a day old. Never throws.
  Future<void> ensure() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    try {
      final prefs = await _storage();
      if (_name == null) _set(prefs.getString(_nameKey));
      final asked = prefs.getInt(_askedKey);
      final now = _clock();
      if (_name != null && asked != null && now.difference(DateTime.fromMillisecondsSinceEpoch(asked)) < refreshEvery) {
        return;
      }
      final fetched = await _fetch();
      await prefs.setInt(_askedKey, now.millisecondsSinceEpoch);
      if (fetched != null && fetched.trim().isNotEmpty) await remember(fetched, prefs: prefs);
    } catch (e) {
      debugPrint('MAL time zone unavailable ($e)');
    }
  }

  /// Keeps [name] (the own profile was read elsewhere with its `time_zone`).
  Future<void> remember(String? name, {SharedPreferences? prefs}) async {
    if (name == null || name.trim().isEmpty || name == _name) return;
    if (!_set(name)) return;
    try {
      await (prefs ?? await _storage()).setString(_nameKey, name);
    } catch (_) {}
  }

  /// Forgets the zone (sign out, another account).
  Future<void> clear() async {
    _name = null;
    _location = null;
    try {
      final prefs = await _storage();
      await prefs.remove(_nameKey);
      await prefs.remove(_askedKey);
    } catch (_) {}
  }

  /// Test hook: uses [name] without storing it.
  @visibleForTesting
  void setForTest(String? name) {
    _name = null;
    _location = null;
    _set(name);
  }

  bool _set(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final location = locationOf(name.trim());
    if (location == null) return false;
    _name = name.trim();
    _location = location;
    return true;
  }

  static bool _dataLoaded = false;

  /// The zone named [name], null when the name is unknown.
  static tz.Location? locationOf(String name) {
    if (!_dataLoaded) {
      tz_data.initializeTimeZones();
      _dataLoaded = true;
    }
    try {
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchOwn() async => (await MalUser().getUserInfo(fields: const ['time_zone'])).timezone;
}
