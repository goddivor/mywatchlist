import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Tenrai/tenrai_api.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server answering the app's Jikan v4 requests.
enum DataSource {
  jikan,
  tenrai;

  /// Brand name of the server (never translated).
  String get label => switch (this) {
        DataSource.jikan => 'Jikan',
        DataSource.tenrai => 'Tenrai',
      };
}

/// How long Jikan stays muted after it did not answer (settings choices).
enum JikanMuteDuration {
  oneWeek(Duration(days: 7)),
  twoWeeks(Duration(days: 14)),
  oneMonth(Duration(days: 30)),
  threeMonths(Duration(days: 90));

  const JikanMuteDuration(this.duration);

  final Duration duration;

  static const JikanMuteDuration fallback = JikanMuteDuration.oneMonth;

  static JikanMuteDuration byName(String? name) =>
      values.where((d) => d.name == name).firstOrNull ?? fallback;
}

/// Which server answers the app's Jikan v4 requests: ONE at a time, never both.
///
/// Jikan (`api.jikan.moe/v4`) and Tenrai (`api.tenrai.org/v1`) serve the same
/// data with the same schema. [start] (called once from `main`, not awaited)
/// picks the source of the session: while Jikan is muted (date saved in the
/// preferences) it is Tenrai without asking Jikan; otherwise one light Jikan
/// request ([probe], [probeTimeout]) decides: an answer keeps Jikan, a
/// timeout, a network error or a 5xx selects Tenrai and mutes Jikan for
/// [muteDuration] (1 month by default, changed in Settings > Data sources).
/// Requests wait for that choice through [ready] (at most [readyTimeout]).
///
/// During the session [JikanClient] (lib/services/api/Jikan/jikan_client.dart)
/// sends every Jikan URL to [active] only. When Jikan fails at the network
/// level ([jikanFailed]) Tenrai takes over and Jikan is muted; when Tenrai
/// fails ([tenraiFailed]) Jikan takes over only if it is not muted. Endpoints
/// Tenrai lacks ([tenraiServes] false: `/users`, `/clubs`, `/watch`,
/// `/userupdates`, `/random/users`, forum topics other than episode threads)
/// fail at once while Tenrai is active, so their callers go straight to their
/// MyAnimeList-page / mwl-api fallbacks.
///
/// A [JikanSource] that was never [start]ed uses Jikan and does not wait.
class JikanSource extends ChangeNotifier {
  JikanSource({
    TenraiClient? tenrai,
    this.probeTimeout = const Duration(seconds: 4),
    this.readyTimeout = const Duration(seconds: 5),
    Future<bool> Function()? probe,
    http.Client? probeClient,
    DateTime Function()? now,
  })  : _tenrai = tenrai,
        _probe = probe,
        _probeClient = probeClient,
        _now = now ?? DateTime.now;

  /// The selector used by the app's [JikanClient.instance].
  static JikanSource instance = JikanSource();

  /// Jikan's base URL (no trailing slash).
  static const String jikanBase = 'https://api.jikan.moe/v4';
  static const String jikanHost = 'api.jikan.moe';

  /// Tenrai's base URL (no trailing slash).
  static const String tenraiBase = TenraiClient.baseUrl;

  /// The light request of the launch probe (a small, cached Jikan answer).
  static final Uri probeUrl = Uri.parse('$jikanBase/genres/anime?filter=demographics');

  /// Preference keys (device settings, not tracker-scoped).
  static const String mutedUntilKey = 'data_source_jikan_muted_until_v1';
  static const String mutedSinceKey = 'data_source_jikan_muted_since_v1';
  static const String muteDurationKey = 'data_source_jikan_mute_duration_v1';

  final TenraiClient? _tenrai;
  final Future<bool> Function()? _probe;
  final http.Client? _probeClient;
  final DateTime Function() _now;

  /// Longest wait for the probe's answer.
  final Duration probeTimeout;

  /// Longest wait of a request for the launch choice.
  final Duration readyTimeout;

  SharedPreferences? _prefs;
  Completer<void>? _ready;
  DataSource _active = DataSource.jikan;
  DateTime? _mutedUntil;
  DateTime? _mutedSince;
  JikanMuteDuration _muteDuration = JikanMuteDuration.fallback;
  bool _probing = false;

  TenraiClient get tenrai => _tenrai ?? TenraiClient.instance;

  /// The server every Jikan-shaped request goes to.
  DataSource get active => _active;

  /// True while a probe (launch or [testAgain]) is running.
  bool get probing => _probing;

  /// How long Jikan stays muted after a failure.
  JikanMuteDuration get muteDuration => _muteDuration;

  /// The date until which Jikan is not asked (null when it is not muted).
  DateTime? get jikanMutedUntil => jikanMuted ? _mutedUntil : null;

  bool get jikanMuted {
    final until = _mutedUntil;
    return until != null && _now().isBefore(until);
  }

  /// Completes once the launch choice is made (at once when [start] was never
  /// called), never after [readyTimeout]; never throws.
  Future<void> get ready {
    final ready = _ready;
    if (ready == null || ready.isCompleted) return Future<void>.value();
    return ready.future.timeout(readyTimeout, onTimeout: () {});
  }

  /// Reads the saved mute, then chooses the source of the session (see the
  /// class comment). Requests started meanwhile wait through [ready].
  Future<void> start(SharedPreferences prefs) async {
    _prefs = prefs;
    final ready = _ready = Completer<void>();
    try {
      _muteDuration = JikanMuteDuration.byName(prefs.getString(muteDurationKey));
      _mutedUntil = _readDate(prefs, mutedUntilKey);
      _mutedSince = _readDate(prefs, mutedSinceKey);
      if (jikanMuted) {
        _active = DataSource.tenrai;
      } else {
        await _runProbe();
      }
    } finally {
      if (!ready.isCompleted) ready.complete();
      notifyListeners();
    }
  }

  /// Asks Jikan again now (Settings > Data sources): an answer ends the mute
  /// and makes Jikan the source, a failure mutes it again from now.
  Future<DataSource> testAgain() async {
    if (_probing) return _active;
    await _runProbe();
    notifyListeners();
    return _active;
  }

  /// Changes and saves the mute duration; a running mute is recomputed from
  /// its start. The source of the session does not change.
  Future<void> setMuteDuration(JikanMuteDuration duration) async {
    _muteDuration = duration;
    final since = _mutedSince;
    if (since != null && _mutedUntil != null) _mutedUntil = since.add(duration.duration);
    notifyListeners();
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(muteDurationKey, duration.name);
    await _saveMute();
  }

  /// Jikan failed at the network level: Tenrai becomes the source and Jikan
  /// is muted (once, however many requests fail together).
  void jikanFailed() {
    if (_active == DataSource.tenrai) return;
    _active = DataSource.tenrai;
    _mute();
    notifyListeners();
  }

  /// Tenrai failed at the network level: Jikan becomes the source unless it is
  /// muted. Returns true when the source changed.
  bool tenraiFailed() {
    if (_active == DataSource.jikan || jikanMuted) return false;
    _active = DataSource.jikan;
    notifyListeners();
    return true;
  }

  Future<void> _runProbe() async {
    _probing = true;
    notifyListeners();
    bool up;
    try {
      up = await (_probe ?? _defaultProbe)().timeout(probeTimeout, onTimeout: () => false);
    } catch (e) {
      up = false;
    }
    _probing = false;
    if (up) {
      _active = DataSource.jikan;
      _mutedUntil = null;
      _mutedSince = null;
      unawaited(_saveMute());
    } else {
      _active = DataSource.tenrai;
      _mute();
    }
  }

  /// One light Jikan request: any answer below 500 (a 429 too) means Jikan
  /// is up.
  Future<bool> _defaultProbe() async {
    final client = _probeClient;
    final response = await (client != null ? client.get(probeUrl) : http.get(probeUrl))
        .timeout(probeTimeout);
    return response.statusCode < 500;
  }

  void _mute() {
    final now = _now();
    _mutedSince = now;
    _mutedUntil = now.add(_muteDuration.duration);
    unawaited(_saveMute());
  }

  Future<void> _saveMute() async {
    final prefs = _prefs;
    if (prefs == null) return;
    try {
      final until = _mutedUntil;
      final since = _mutedSince;
      if (until == null || since == null) {
        await prefs.remove(mutedUntilKey);
        await prefs.remove(mutedSinceKey);
      } else {
        await prefs.setString(mutedUntilKey, until.toIso8601String());
        await prefs.setString(mutedSinceKey, since.toIso8601String());
      }
    } catch (e) {
      debugPrint('JikanSource: mute not saved: $e');
    }
  }

  static DateTime? _readDate(SharedPreferences prefs, String key) =>
      DateTime.tryParse(prefs.getString(key) ?? '');

  /// The server a caller building its own URL should use for [path]
  /// (`/anime/1/full`): Tenrai while it is the source and has the path, else
  /// Jikan.
  String baseFor(String path) =>
      _active == DataSource.tenrai && tenraiServes(Uri.parse('$jikanBase$path'))
          ? tenraiBase
          : jikanBase;

  bool isJikan(Uri url) => url.host == jikanHost && url.path.startsWith('/v4');

  /// Whether Tenrai has the endpoint of the Jikan URL [url].
  bool tenraiServes(Uri url) {
    if (!isJikan(url)) return false;
    final path = _jikanPath(url);
    // Server-key-only paths (`/anime/ids`…) would match `/anime/{id}`.
    if (TenraiApi.keyOnlyPaths.contains(path)) return false;
    if (!_patterns.any((p) => p.hasMatch(path))) return false;
    // Tenrai's forum endpoints only list episode / chapter threads.
    if (path.endsWith('/forum')) return url.queryParameters['filter'] == 'episode';
    return true;
  }

  /// The Tenrai URL answering the Jikan URL [url] (same path and query).
  Uri toTenrai(Uri url) {
    final base = Uri.parse(tenraiBase);
    return url.replace(
      scheme: base.scheme,
      host: base.host,
      port: base.port,
      path: '${base.path}${_jikanPath(url)}',
    );
  }

  static String _jikanPath(Uri url) {
    var path = url.path.substring('/v4'.length);
    if (path.length > 1 && path.endsWith('/')) path = path.substring(0, path.length - 1);
    return path.isEmpty ? '/' : path;
  }

  static final List<RegExp> _patterns = [
    for (final template in TenraiApi.paths)
      RegExp('^${template.replaceAll(RegExp(r'\{[^}]+\}'), '[^/]+')}\$'),
  ];
}
