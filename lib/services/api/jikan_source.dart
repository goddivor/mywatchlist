import 'package:mywatchlist/services/api/Tenrai/tenrai_api.dart';
import 'package:mywatchlist/services/api/Tenrai/tenrai_client.dart';

/// Which server answers the app's Jikan v4 requests.
///
/// Jikan (`api.jikan.moe/v4`) is asked first. When it times out, fails at the
/// network level (DNS, refused connection) or answers 5xx, it is marked down
/// for [reprobeAfter] (circuit breaker) and the same request goes to Tenrai
/// (`api.tenrai.org/v1`, the same schema) when Tenrai has that endpoint
/// ([tenraiServes]). Endpoints Tenrai lacks (`/users`, `/clubs`, `/watch`,
/// `/userupdates`, `/random/users`, forum topics other than episode threads)
/// stay on Jikan and their callers keep their MyAnimeList-page fallbacks.
///
/// [JikanClient] (lib/services/api/Jikan/jikan_client.dart) applies this to
/// every Jikan URL of the app, so callers keep building `api.jikan.moe` URLs.
class JikanSource {
  JikanSource({
    TenraiClient? tenrai,
    this.reprobeAfter = const Duration(minutes: 5),
    this.hedgeAfter = const Duration(milliseconds: 2500),
    this.probeTimeout = const Duration(seconds: 4),
    DateTime Function()? now,
  })  : _tenrai = tenrai,
        _now = now ?? DateTime.now;

  /// The selector used by the app's [JikanClient.instance].
  static JikanSource instance = JikanSource();

  /// Jikan's base URL (no trailing slash).
  static const String jikanBase = 'https://api.jikan.moe/v4';
  static const String jikanHost = 'api.jikan.moe';

  /// Tenrai's base URL (no trailing slash).
  static const String tenraiBase = TenraiClient.baseUrl;

  final TenraiClient? _tenrai;

  /// How long Jikan stays marked down before a request tries it again.
  final Duration reprobeAfter;

  /// A Tenrai-served request also goes to Tenrai when Jikan has not answered
  /// by then (at once while Jikan is being re-probed).
  final Duration hedgeAfter;

  /// Longest wait for Jikan while it is being re-probed after a failure.
  final Duration probeTimeout;

  final DateTime Function() _now;

  DateTime? _downUntil;

  TenraiClient get tenrai => _tenrai ?? TenraiClient.instance;

  /// True while Jikan is marked down: Tenrai-served requests skip it.
  bool get jikanDown {
    final until = _downUntil;
    return until != null && _now().isBefore(until);
  }

  /// True after a Jikan failure until Jikan answers again (also during a
  /// re-probe, once [jikanDown] is over).
  bool get jikanSuspect => _downUntil != null;

  void markJikanDown() => _downUntil = _now().add(reprobeAfter);

  void markJikanUp() => _downUntil = null;

  /// Let the next request try Jikan again (a Retry button).
  void allowProbe() {
    if (_downUntil != null) _downUntil = _now();
  }

  /// The server a caller building its own URL should use for [path]
  /// (`/anime/1/full`): Tenrai while Jikan is down and Tenrai has the path,
  /// else Jikan.
  String baseFor(String path) =>
      jikanDown && tenraiServes(Uri.parse('$jikanBase$path')) ? tenraiBase : jikanBase;

  bool isJikan(Uri url) => url.host == jikanHost && url.path.startsWith('/v4');

  /// Whether Tenrai has the endpoint of the Jikan URL [url].
  bool tenraiServes(Uri url) {
    if (!isJikan(url)) return false;
    final path = _jikanPath(url);
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
