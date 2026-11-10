import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// What MyDubList knows about one anime for the chosen dub language.
enum DubStatus { none, partial, dubbed }

/// Where the dub data of the current language stands.
enum DubLoadState { idle, loading, ready, failed }

/// The ids MyDubList lists for one language and confidence level.
@immutable
class DubData {
  final Set<int> dubbed;
  final Set<int> partial;
  const DubData({this.dubbed = const {}, this.partial = const {}});

  static const empty = DubData();
  int get total => dubbed.length + partial.length;
}

/// Reads the JSON file of MyDubList (`{"dubbed": [...], "partial": [...]}`). Ids may be
/// numbers or numeric strings; anything unexpected gives empty data, never an error.
/// Top-level shape so that it can run in a background isolate.
DubData parseDubJson(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return DubData.empty;
    Set<int> ids(Object? value) {
      final out = <int>{};
      if (value is List) {
        for (final e in value) {
          final id = e is int ? e : (e is String ? int.tryParse(e) : null);
          if (id != null) out.add(id);
        }
      }
      return out;
    }

    return DubData(dubbed: ids(decoded['dubbed']), partial: ids(decoded['partial']));
  } catch (_) {
    return DubData.empty;
  }
}

/// Dub languages offered by MyDubList (the value is the file name part).
const List<String> dubLanguages = [
  'english', 'spanish', 'german', 'french', 'italian', 'portuguese', 'korean', 'tagalog',
  'chinese', 'arabic', 'polish', 'hungarian', 'swedish', 'norwegian', 'hebrew', 'dutch',
  'russian', 'indonesian', 'danish', 'thai', 'hindi', 'finnish', 'turkish', 'catalan',
  'vietnamese', 'lithuanian',
];

/// Dub information from MyDubList (github.com/Joelis57/MyDubList), shared by every card.
///
/// Settings come from the preferences contract (`showDubStatus`, `dubLanguage`,
/// `dubMinSourceCount`, `dubIconStyle`). The singleton notifies when a setting that changes
/// what a card shows changes, or when the data arrives; cards listen to it and nothing else.
/// Data is cached for one hour; when the network cannot be reached the last copy is used
/// even if it is older, and only an empty cache ends in [DubLoadState.failed].
class DubInfo extends ChangeNotifier {
  static DubInfo instance = DubInfo();

  static const String baseUrl =
      'https://raw.githubusercontent.com/Joelis57/MyDubList/main/dubs/confidence';
  static const String reportUrl = 'https://github.com/Joelis57/MyDubList/issues/new';
  static const String supportUrl = 'https://ko-fi.com/joelis';
  static const String _service = 'mydublist';
  static const int _freshSeconds = 60 * 60;
  static const Duration timeout = Duration(seconds: 12);

  /// Reads a URL; null on any failure. Replaced in tests.
  final Future<String?> Function(Uri url) _fetch;
  final Future<String?> Function(String key, {required bool allowStale}) _readCache;
  final Future<void> Function(String key, String body) _writeCache;
  final Future<DubData> Function(String body) _parse;

  DubInfo({
    Future<String?> Function(Uri url)? fetch,
    Future<String?> Function(String key, {required bool allowStale})? readCache,
    Future<void> Function(String key, String body)? writeCache,
    Future<DubData> Function(String body)? parse,
  })  : _fetch = fetch ?? _httpFetch,
        _readCache = readCache ?? _storeRead,
        _writeCache = writeCache ?? _storeWrite,
        _parse = parse ?? ((body) => compute(parseDubJson, body));

  DubData _data = DubData.empty;
  DubLoadState _state = DubLoadState.idle;
  String? _loadedKey;
  Future<void>? _inFlight;
  String? _inFlightKey;
  StreamSubscription<AppPreferences>? _subscription;
  GeneralPreferences _seen = const GeneralPreferences();

  DubLoadState get state => _state;
  DubData get data => _data;

  // -- settings ---------------------------------------------------------------

  GeneralPreferences get _general => Preferences.general;

  /// Whether the dub icon is shown at all.
  bool get enabled => _general.showDubStatus;

  /// Icon style 0..3.
  int get iconStyle => _general.dubIconStyle.clamp(0, 3);

  String get language {
    final value = _general.dubLanguage.toLowerCase();
    return value.isEmpty ? 'english' : value;
  }

  /// File folder of the confidence level implied by the minimum source count.
  static String confidenceSlug(int minSourceCount) {
    if (minSourceCount <= 1) return 'low';
    if (minSourceCount == 2) return 'normal';
    if (minSourceCount == 3) return 'high';
    return 'very-high';
  }

  String get _key => '${language}_${confidenceSlug(_general.dubMinSourceCount)}';

  // -- queries ----------------------------------------------------------------

  DubStatus statusOf(int? id) {
    if (id == null || !enabled) return DubStatus.none;
    if (_data.dubbed.contains(id)) return DubStatus.dubbed;
    if (_data.partial.contains(id)) return DubStatus.partial;
    return DubStatus.none;
  }

  // -- lifecycle --------------------------------------------------------------

  /// Starts following the preferences (idempotent, safe to call from `initState`). Loads the
  /// data when the icon is enabled. Does nothing before the preferences bloc exists (tests).
  void attach() {
    final bloc = Preferences.bloc;
    if (bloc == null) return;
    if (_subscription == null) {
      _seen = bloc.state.general;
      _subscription = bloc.stream.listen(_onPreferences);
    }
    if (enabled) unawaited(ensureLoaded());
  }

  void _onPreferences(AppPreferences next) {
    final before = _seen;
    final now = next.general;
    _seen = now;
    final dataChanged = before.dubLanguage != now.dubLanguage ||
        before.dubMinSourceCount != now.dubMinSourceCount;
    if (before.showDubStatus != now.showDubStatus ||
        before.dubIconStyle != now.dubIconStyle ||
        dataChanged) {
      notifyListeners();
    }
    if (now.showDubStatus && (dataChanged || !before.showDubStatus)) {
      unawaited(ensureLoaded());
    }
  }

  /// Loads the data for the current language and confidence. Concurrent calls share one
  /// request; [force] skips the one-hour cache (the Retry button).
  Future<void> ensureLoaded({bool force = false}) {
    final key = _key;
    if (!force && _loadedKey == key && _state == DubLoadState.ready) {
      return Future.value();
    }
    if (_inFlight != null && _inFlightKey == key && !force) return _inFlight!;
    _inFlightKey = key;
    final run = _load(key, force);
    _inFlight = run;
    return run.whenComplete(() {
      if (identical(_inFlight, run)) _inFlight = null;
    });
  }

  Future<void> _load(String key, bool force) async {
    _setState(DubLoadState.loading);
    final slug = key.substring(key.indexOf('_') + 1);
    final lang = key.substring(0, key.indexOf('_'));
    final cacheKey = 'dubInfo_${lang}_$slug.json';
    String? body;
    if (!force) body = await _readCache(cacheKey, allowStale: false);
    if (body == null) {
      body = await _fetch(Uri.parse('$baseUrl/$slug/dubbed_$lang.json'));
      if (body != null) {
        unawaited(_writeCache(cacheKey, body));
      } else {
        body = await _readCache(cacheKey, allowStale: true);
      }
    }
    if (key != _key) return; // the language changed while loading: the newer load wins
    if (body == null) {
      _loadedKey = null;
      _data = DubData.empty;
      _setState(DubLoadState.failed);
      return;
    }
    _data = await _parse(body);
    if (key != _key) return;
    _loadedKey = key;
    _setState(DubLoadState.ready);
  }

  void _setState(DubLoadState next) {
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // -- default storage and network ---------------------------------------------

  static Future<String?> _httpFetch(Uri url) async {
    try {
      final response = await http.get(url).timeout(timeout);
      return response.statusCode == 200 ? response.body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _storeRead(String key, {required bool allowStale}) async {
    try {
      final cache = CacheManager.instance;
      if (!allowStale) {
        return await cache.getValueForServiceAutoExpire(_service, key, _freshSeconds);
      }
      final raw = await cache.getValueForService(_service, key);
      if (raw == null) return null;
      final map = jsonDecode(raw);
      return map is Map && map['value'] is String ? map['value'] as String : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _storeWrite(String key, String body) async {
    try {
      await CacheManager.instance.setValueForServiceAutoExpireIn(_service, key, body);
    } catch (_) {}
  }
}
