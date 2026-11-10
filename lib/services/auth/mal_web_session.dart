import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';

/// The in-app WebView's cookie jar, read natively: `document.cookie` cannot see the HttpOnly
/// `MALSESSIONID`, Android's `CookieManager` can (MainActivity answers the channel).
abstract class WebViewCookies {
  /// Every cookie the jar sends to [url], as one `a=b; c=d` header, or null.
  Future<String?> read(String url);

  /// Expires every cookie of [url]'s host.
  Future<void> clear(String url);
}

class NativeWebViewCookies implements WebViewCookies {
  const NativeWebViewCookies();

  static const MethodChannel _channel = MethodChannel('com.teen.mywatchlist/webview_cookies');

  static bool get supported => !kIsWeb && Platform.isAndroid;

  @override
  Future<String?> read(String url) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<String>('getCookies', {'url': url});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<void> clear(String url) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>('clearCookies', {'url': url});
    } on PlatformException {
      // Nothing to clear.
    } on MissingPluginException {
      // Not on Android.
    }
  }
}

enum MalWebSessionState {
  /// Not read from storage yet.
  loading,

  /// No website session: never captured, or the user signed out.
  none,

  /// Cookies stored for the signed-in MAL account.
  connected,

  /// MAL refused the stored cookies (logged out on the website, or they expired).
  expired,

  /// This platform cannot read the WebView's cookies (only Android can).
  unsupported,
}

/// Parses a `Cookie` header (`a=b; c=d`) into ordered name/value pairs; malformed parts are
/// dropped.
Map<String, String> parseCookieHeader(String? header) {
  final jar = <String, String>{};
  if (header == null) return jar;
  for (final part in header.split(';')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq).trim();
    if (name.isEmpty) continue;
    jar[name] = part.substring(eq + 1).trim();
  }
  return jar;
}

/// The `name=value` pairs of a `Set-Cookie` response header. `package:http` joins several
/// headers with a comma, and `Expires` dates hold commas too, so only a comma followed by a
/// `name=` starts a new cookie. An expired or emptied cookie maps to null (delete it).
Map<String, String?> parseSetCookie(String? header) {
  final out = <String, String?>{};
  if (header == null || header.isEmpty) return out;
  for (final cookie in header.split(RegExp(r',(?=\s*[A-Za-z0-9_.\-]+=)'))) {
    final parts = cookie.split(';');
    final first = parts.first;
    final eq = first.indexOf('=');
    if (eq <= 0) continue;
    final name = first.substring(0, eq).trim();
    var value = first.substring(eq + 1).trim();
    final attrs = parts.skip(1).map((a) => a.trim().toLowerCase());
    final gone = value.isEmpty ||
        value == 'deleted' ||
        attrs.any((a) => a == 'max-age=0' || a.startsWith('max-age=-')) ||
        attrs.any((a) => a.startsWith('expires=') && a.contains('1970'));
    out[name] = gone ? null : value;
  }
  return out;
}

/// The MAL website session (cookies) captured from the login WebView, kept next to the MAL
/// tokens in secure storage. The official API has no endpoint for comments, forum posts,
/// messages, friends, clubs or favourites: those go through the website with these cookies.
///
/// The cookies are never logged and never leave the device except to myanimelist.net.
class MalWebSession extends ChangeNotifier {
  MalWebSession({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    WebViewCookies cookies = const NativeWebViewCookies(),
    bool? platformSupported,
    UserMalV2? malUser,
  })  : _storage = storage,
        _webView = cookies,
        _supported = platformSupported ?? NativeWebViewCookies.supported,
        _malUser = malUser;

  static MalWebSession instance = MalWebSession();

  static const String storageKey = 'mal_web_session_v1';
  static const String siteUrl = 'https://myanimelist.net';

  final FlutterSecureStorage _storage;
  final WebViewCookies _webView;
  final bool _supported;
  final UserMalV2? _malUser;

  MalWebSessionState _state = MalWebSessionState.loading;
  Map<String, String> _jar = {};
  String? _username;
  DateTime? _savedAt;
  Future<void>? _loading;
  bool _following = false;
  bool _capturing = false;

  MalWebSessionState get state => _state;
  bool get isConnected => _state == MalWebSessionState.connected;
  bool get isSupported => _supported;

  /// The MAL user name the cookies belong to (may be null until the profile is known).
  String? get username => _username;
  DateTime? get savedAt => _savedAt;

  /// The `Cookie` header for myanimelist.net, or null without a session.
  String? get cookieHeader {
    if (!isConnected || _jar.isEmpty) return null;
    return _jar.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  UserMalV2 get _mal => _malUser ?? UserMalV2.instance;

  /// Reads the stored session once (later calls wait for the same read).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    _followAccount();
    if (!_supported) {
      _set(MalWebSessionState.unsupported);
      return;
    }
    Map<String, dynamic>? stored;
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw != null) stored = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      stored = null;
    }
    if (stored == null) {
      _set(MalWebSessionState.none);
      return;
    }
    _jar = parseCookieHeader(stored['cookies'] as String?);
    _username = stored['username'] as String?;
    _savedAt = DateTime.tryParse(stored['savedAt'] as String? ?? '');
    final expired = stored['expired'] == true;
    if (!_accountStillMatches()) {
      await clear(webView: false);
      return;
    }
    _set(expired
        ? MalWebSessionState.expired
        : (_jar.isEmpty ? MalWebSessionState.none : MalWebSessionState.connected));
  }

  /// True when a jar holds a logged-in MAL session (MALClient checks `is_logged_in=1`).
  static bool looksLoggedIn(Map<String, String> jar) =>
      jar['is_logged_in'] == '1' || (jar['MALSESSIONID']?.isNotEmpty ?? false);

  /// Called by the MAL sign in as soon as the OAuth redirect arrives, before the token
  /// exchange: the WebView the user signed in with holds MAL's cookies now. Account changes
  /// are not followed until [finishCapture] or [cancelCapture].
  Future<Map<String, String>> beginCapture() async {
    await ensureLoaded();
    _capturing = true;
    if (!_supported) return const {};
    return parseCookieHeader(await _webView.read(siteUrl));
  }

  /// Stores [jar] for [username] once the tokens are saved. Returns true when a logged-in
  /// session was stored; otherwise a session of another account is dropped.
  Future<bool> finishCapture(Map<String, String> jar, {String? username}) async {
    _capturing = false;
    if (_supported && looksLoggedIn(jar)) {
      _jar = Map.of(jar);
      _username = username;
      _savedAt = DateTime.now();
      await _persist();
      _set(MalWebSessionState.connected);
      return true;
    }
    if (!_accountStillMatches()) await clear(webView: false);
    return false;
  }

  /// The sign in did not finish: nothing changes.
  void cancelCapture() => _capturing = false;

  /// [beginCapture] then [finishCapture] in one go (tests, or a WebView already closed).
  Future<bool> captureFromWebView({String? username}) async =>
      finishCapture(await beginCapture(), username: username);

  /// Records which MAL account the cookies belong to, once the sign in knows the name.
  Future<void> setUsername(String? name) async {
    if (name == null || name.isEmpty || name == _username) return;
    _username = name;
    if (_state == MalWebSessionState.connected || _state == MalWebSessionState.expired) {
      await _persist();
    }
  }

  /// Applies a `Set-Cookie` answer of MAL (it renews or drops cookies) to the stored jar.
  Future<void> applySetCookie(String? header) async {
    if (!isConnected) return;
    final changes = parseSetCookie(header);
    if (changes.isEmpty) return;
    var changed = false;
    changes.forEach((name, value) {
      if (value == null) {
        changed |= _jar.remove(name) != null;
      } else if (_jar[name] != value) {
        _jar[name] = value;
        changed = true;
      }
    });
    if (changed) await _persist();
  }

  /// MAL no longer accepts the cookies: keep the state so screens offer to reconnect.
  Future<void> markExpired() async {
    if (_state != MalWebSessionState.connected) return;
    _jar = {};
    await _persist(expired: true);
    _set(MalWebSessionState.expired);
  }

  /// Forgets the session: stored cookies and, with [webView], the WebView's MAL cookies (so
  /// the next sign in asks for the credentials again).
  Future<void> clear({bool webView = true}) async {
    _jar = {};
    _username = null;
    _savedAt = null;
    try {
      await _storage.delete(key: storageKey);
    } catch (_) {
      // Already gone.
    }
    if (webView) await _webView.clear(siteUrl);
    _set(_supported ? MalWebSessionState.none : MalWebSessionState.unsupported);
  }

  Future<void> _persist({bool expired = false}) async {
    try {
      await _storage.write(
        key: storageKey,
        value: jsonEncode({
          'cookies': _jar.entries.map((e) => '${e.key}=${e.value}').join('; '),
          'username': _username,
          'savedAt': _savedAt?.toIso8601String(),
          'expired': expired,
        }),
      );
    } catch (_) {
      // Secure storage unavailable: the session lives for this run only.
    }
  }

  /// The cookies belong to the MAL account of the tokens: no MAL account (signed out from
  /// any path) or another account means they must go.
  bool _accountStillMatches() {
    final mal = _mal;
    final signedOut = mal.accessToken == null && !mal.needsReLogin;
    if (signedOut) return false;
    final current = mal.username;
    if (_username != null && current != null && current.isNotEmpty) {
      return current.toLowerCase() == _username!.toLowerCase();
    }
    return true;
  }

  void _followAccount() {
    if (_following) return;
    _following = true;
    _mal.addListener(_onAccountChanged);
  }

  void _onAccountChanged() {
    if (_capturing) return;
    if (_state == MalWebSessionState.loading || _state == MalWebSessionState.unsupported) return;
    // A sign in in progress keeps the old tokens until it ends.
    if (_mal.status == AuthStatus.INPROGRESS) return;
    if (_jar.isEmpty && _state != MalWebSessionState.expired) return;
    // Signed out (any path): the WebView's cookies go too; another account: only ours.
    if (!_accountStillMatches()) clear(webView: _mal.accessToken == null && !_mal.needsReLogin);
  }

  void _set(MalWebSessionState state) {
    _state = state;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTest() {
    _loading = null;
    _state = MalWebSessionState.loading;
    _jar = {};
    _username = null;
  }

  @override
  String toString() => 'MalWebSession(${_state.name}, user: $_username, cookies: <redacted>)';
}
