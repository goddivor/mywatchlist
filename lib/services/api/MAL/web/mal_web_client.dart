import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/auth/mal_web_session.dart';

/// There is no MAL website session (the user never connected it, or signed out).
class MalWebNoSession implements Exception {
  const MalWebNoSession();
  @override
  String toString() => 'MalWebNoSession';
}

/// MAL refused the stored website session (it sent the request to the login page).
class MalWebSessionExpired implements Exception {
  const MalWebSessionExpired();
  @override
  String toString() => 'MalWebSessionExpired';
}

/// MAL answered a write with an error; [message] is MAL's own text when it gave one.
class MalWebActionFailed implements Exception {
  final String? message;
  final int? statusCode;
  const MalWebActionFailed({this.message, this.statusCode});
  @override
  String toString() => 'MalWebActionFailed($statusCode, $message)';
}

final RegExp _csrfMeta = RegExp(
  r'''<meta\s+name\s*=\s*["']csrf_token["']\s+content\s*=\s*["']([^"']+)["']''',
  caseSensitive: false,
);
final RegExp _csrfMetaReversed = RegExp(
  r'''<meta\s+content\s*=\s*["']([^"']+)["']\s+name\s*=\s*["']csrf_token["']''',
  caseSensitive: false,
);

/// The `<meta name='csrf_token' content='…'>` of a MAL page (single or double quotes).
String? parseCsrfToken(String html) =>
    _csrfMeta.firstMatch(html)?.group(1) ?? _csrfMetaReversed.firstMatch(html)?.group(1);

/// True when [location] (a redirect target) is MAL's login page.
bool isLoginRedirect(String? location) =>
    location != null && location.contains('login.php');

/// HTTP client of the MAL website, as MALClient used it: the website session's cookies on
/// every request, the page's `csrf_token` added to every POST form (MAL's own scripts do the
/// same for each non-GET request), a desktop User-Agent (MAL serves the desktop markup the
/// parsers read), one request at a time with a short gap.
class MalWebClient {
  MalWebClient({
    MalWebSession? session,
    http.Client Function()? clientFactory,
    this.minGap = const Duration(milliseconds: 300),
    this.timeout = const Duration(seconds: 15),
  })  : _sessionOverride = session,
        _clientFactory = clientFactory ?? http.Client.new;

  static MalWebClient instance = MalWebClient();

  static const String host = 'myanimelist.net';
  static const String base = 'https://$host';

  /// A desktop browser: MAL serves the desktop markup the parsers read. The login WebView
  /// keeps the phone's own User-Agent (MAL does not bind the session to it, MALClient did
  /// the same).
  static const String userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

  /// The page MALClient used to test a session: 200 when logged in, 303 to login otherwise.
  static const String sessionCheckPath = '/editprofile.php?go=myoptions';

  final MalWebSession? _sessionOverride;
  final http.Client Function() _clientFactory;
  final Duration minGap;
  final Duration timeout;

  MalWebSession get session => _sessionOverride ?? MalWebSession.instance;

  String? _csrf;
  DateTime? _checkedAt;
  Future<void> _queue = Future.value();
  DateTime? _last;

  @visibleForTesting
  String? get cachedCsrf => _csrf;

  Uri _uri(String pathOrUrl) =>
      pathOrUrl.startsWith('http') ? Uri.parse(pathOrUrl) : Uri.parse('$base$pathOrUrl');

  /// Runs [task] after the previous request and at least [minGap] after it.
  Future<T> _serial<T>(Future<T> Function() task) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      final last = _last;
      if (last != null) {
        final wait = minGap - DateTime.now().difference(last);
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      try {
        done.complete(await task());
      } catch (e, st) {
        done.completeError(e, st);
      } finally {
        _last = DateTime.now();
      }
    });
    return done.future;
  }

  Map<String, String> _headers({required bool withSession, String? referer, bool ajax = false}) {
    final headers = <String, String>{
      'User-Agent': userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
      if (referer != null) 'Referer': referer,
      if (ajax) 'X-Requested-With': 'XMLHttpRequest',
      if (ajax) 'Origin': base,
    };
    final cookie = withSession ? session.cookieHeader : null;
    if (cookie != null) headers['Cookie'] = cookie;
    return headers;
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    final client = _clientFactory();
    try {
      final streamed = await client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed).timeout(timeout);
      await session.applySetCookie(response.headers['set-cookie']);
      return response;
    } finally {
      client.close();
    }
  }

  /// GETs a MAL page. With [withSession] (and a connected session) the cookies are sent;
  /// a redirect to the login page then means the session is dead ([MalWebSessionExpired]).
  /// Redirects inside myanimelist.net are followed (at most 3).
  Future<http.Response> get(String pathOrUrl, {bool withSession = true}) {
    return _serial(() async {
      await session.ensureLoaded();
      final sending = withSession && session.isConnected;
      var uri = _uri(pathOrUrl);
      for (var hop = 0; hop < 4; hop++) {
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers.addAll(_headers(withSession: sending));
        final response = await _send(request);
        if (!response.isRedirect && (response.statusCode < 300 || response.statusCode >= 400)) {
          if (sending) _rememberCsrf(response.body);
          return response;
        }
        final location = response.headers['location'];
        if (sending && isLoginRedirect(location)) {
          await _expire();
          throw const MalWebSessionExpired();
        }
        if (location == null) return response;
        final next = uri.resolve(location);
        if (next.host != host) return response;
        uri = next;
      }
      throw http.ClientException('Too many redirects', uri);
    });
  }

  void _rememberCsrf(String body) {
    final token = parseCsrfToken(body);
    if (token != null) _csrf = token;
  }

  Future<void> _expire() async {
    _csrf = null;
    _checkedAt = null;
    await session.markExpired();
  }

  /// Whether MAL still accepts the session. Checked at most every [maxAge] unless [force].
  /// Throws [MalWebNoSession] without a session; network errors are rethrown (a network
  /// failure never drops the session).
  Future<bool> checkSession({bool force = false, Duration maxAge = const Duration(minutes: 30)}) async {
    await session.ensureLoaded();
    if (!session.isConnected) throw const MalWebNoSession();
    final checked = _checkedAt;
    if (!force && checked != null && DateTime.now().difference(checked) < maxAge) return true;
    try {
      final response = await get(sessionCheckPath);
      if (response.statusCode == 200) {
        _checkedAt = DateTime.now();
        return true;
      }
      return false;
    } on MalWebSessionExpired {
      return false;
    }
  }

  /// The page token for POST forms, read from MAL's home page when not known yet.
  Future<String> csrfToken({bool refresh = false}) async {
    if (!refresh && _csrf != null) return _csrf!;
    final response = await get('/');
    final token = parseCsrfToken(response.body);
    if (token == null) {
      throw MalWebActionFailed(statusCode: response.statusCode, message: null);
    }
    _csrf = token;
    return token;
  }

  /// POSTs a form to MAL with the session and `csrf_token`. A refused token (400/403) is
  /// fetched again and the form sent once more (MAL did not apply it). A redirect to the
  /// login page is [MalWebSessionExpired]; other redirects are returned as they are.
  Future<http.Response> postForm(
    String path,
    Map<String, String> fields, {
    String? referer,
  }) async {
    await session.ensureLoaded();
    if (!session.isConnected) throw const MalWebNoSession();
    var token = await csrfToken();
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _serial(() async {
        final request = http.Request('POST', _uri(path))
          ..followRedirects = false
          ..headers.addAll(_headers(withSession: true, referer: referer ?? '$base/', ajax: true))
          ..headers['Content-Type'] = 'application/x-www-form-urlencoded; charset=UTF-8'
          ..bodyFields = {...fields, 'csrf_token': token};
        return _send(request);
      });
      if (response.isRedirect || (response.statusCode >= 300 && response.statusCode < 400)) {
        if (isLoginRedirect(response.headers['location'])) {
          await _expire();
          throw const MalWebSessionExpired();
        }
        return response;
      }
      final refused = response.statusCode == 400 || response.statusCode == 403;
      if (refused && attempt == 0) {
        token = await csrfToken(refresh: true);
        continue;
      }
      return response;
    }
    throw const MalWebActionFailed();
  }

  /// Forgets the cached token and check (after a sign out or a reconnect).
  void reset() {
    _csrf = null;
    _checkedAt = null;
  }
}
