import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/auth/retry_policy.dart';

enum AuthStatus { UNAUTHENTICATED, AUTHENTICATED, INPROGRESS }

/// Abstract base class for all user types (MAL, AniList, Kitsu, Simkl)
/// Uses generics to support different AuthResponse types
abstract class BaseUser<T> with ChangeNotifier {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  T? authResponse;
  String? username;
  String? profileImage;
  AuthStatus status = AuthStatus.UNAUTHENTICATED;

  /// Storage keys for secure storage
  String get authResponseKey;
  String get usernameKey;
  String get profileImageKey;

  /// OAuth configuration
  String get clientId;
  String get clientSecret;
  String get redirectUri;
  String get tokenEndPoint;

  /// Convert auth response to/from JSON
  T? authResponseFromJson(Map<String, dynamic> json);
  Map<String, dynamic>? authResponseToJson(T? response);

  /// Set authentication response and save to secure storage
  void setAuthResponse(T response) {
    authResponse = response;
    status = AuthStatus.AUTHENTICATED;
    needsReLogin = false;
    _saveAuthResponse();
    notifyListeners();
  }

  /// Set user info (username and profile image)
  void setUserInfo(String name, String image) {
    print('📝 setUserInfo called - name: $name, image: $image');
    username = name;
    profileImage = image;
    print('✅ setUserInfo assigned - username: $username, profileImage: $profileImage');
    _saveUserInfo();
    notifyListeners();
    print('🔔 setUserInfo notified listeners');
  }

  /// Set authentication status
  void setStatus(AuthStatus authStatus) {
    status = authStatus;
  }

  /// Get authentication status
  AuthStatus getStatus() {
    return status;
  }

  /// Get access token from auth response
  String? get accessToken;

  /// Get refresh token from auth response
  String? get refreshToken;

  /// Get token expiration time
  DateTime? get tokenExpiryTime;

  // ---------------------------------------------------------------------
  // Token lifecycle: refresh before expiry, refresh on 401, retry transient
  // network errors, drop to a re-login state when the session is dead.
  // ---------------------------------------------------------------------

  /// Margin before the real expiry at which a token already counts as stale.
  static const Duration refreshSkew = Duration(seconds: 60);

  /// True once the session can no longer be recovered silently (refresh token
  /// rejected, or a tracker without refresh token answered 401). The UI shows
  /// a "sign in again" prompt from this flag. Reset by [setAuthResponse].
  bool needsReLogin = false;

  /// Retry policy for transient network errors (DAL: 8 attempts).
  RetryPolicy retryPolicy = const RetryPolicy();

  /// Builds the HTTP client used for token and API calls. Tests replace it.
  http.Client Function() clientFactory = http.Client.new;

  Future<bool>? _refreshInFlight;

  /// Whether this tracker can renew its token silently. Trackers without a
  /// refresh token (Simkl) override this to false.
  bool get supportsRefresh {
    final rt = refreshToken;
    return rt != null && rt.isNotEmpty;
  }

  /// Token is missing or past its expiry. A token without expiry information
  /// is considered valid: the 401 path handles it.
  bool get isTokenExpired {
    final token = accessToken;
    if (token == null || token.isEmpty) return true;
    final expiryTime = tokenExpiryTime;
    if (expiryTime == null) return false;
    return expiryTime.isBefore(DateTime.now());
  }

  /// Token expires within [refreshSkew]: refresh before using it.
  bool get needsRefresh {
    final expiryTime = tokenExpiryTime;
    if (expiryTime == null) return false;
    return expiryTime.isBefore(DateTime.now().add(refreshSkew));
  }

  /// Drop the dead credentials but keep the identity (username, avatar) so
  /// the UI can ask the user to sign in again with the same account.
  void markNeedsReLogin() {
    authResponse = null;
    status = AuthStatus.UNAUTHENTICATED;
    needsReLogin = true;
    secureStorage.delete(key: authResponseKey).catchError((_) {});
    notifyListeners();
  }

  /// Sends the refresh request. Form encoded by default (MAL, AniList);
  /// Kitsu overrides it with a JSON body.
  @protected
  Future<http.Response> sendRefreshRequest(
      http.Client client, String refreshTok) {
    return client.post(
      Uri.parse(tokenEndPoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshTok,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      },
    );
  }

  /// Refresh the access token using the refresh token.
  ///
  /// Concurrent callers share one request. Returns true when a new token is in
  /// place. When the server rejects the refresh token the account moves to the
  /// re-login state; a network failure keeps the session untouched.
  Future<bool> refreshAccessToken() {
    if (!supportsRefresh) return Future.value(false);
    return _refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _refresh() async {
    final refreshTok = refreshToken!;
    final client = clientFactory();
    try {
      final response = await retryPolicy
          .run(() => sendRefreshRequest(client, refreshTok));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) return false;
        final newToken = data['access_token'];
        if (newToken is! String || newToken.isEmpty) return false;
        // Some servers do not rotate the refresh token: keep the old one.
        final rt = data['refresh_token'];
        if (rt is! String || rt.isEmpty) data['refresh_token'] = refreshTok;
        final newAuth = authResponseFromJson(data);
        if (newAuth == null) return false;
        setAuthResponse(newAuth);
        return true;
      }
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        markNeedsReLogin();
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh failed (${e.runtimeType})');
      return false;
    } finally {
      client.close();
    }
  }

  /// Refresh now if the token is about to expire. Returns true when a usable
  /// token is available afterwards.
  Future<bool> ensureFreshToken() async {
    if (accessToken == null || accessToken!.isEmpty) return false;
    if (needsRefresh) {
      if (supportsRefresh) {
        await refreshAccessToken();
      } else if (isTokenExpired) {
        markNeedsReLogin();
      }
    }
    return authResponse != null && accessToken != null;
  }

  /// Runs [send] with a valid bearer token and handles the whole lifecycle:
  /// refresh before expiry, transient errors retried with backoff, one
  /// refresh + replay on 401, never another retry on a 4xx.
  ///
  /// Returns null when the account has no usable credentials (signed out or
  /// session dead). Throws the last transient error after the final attempt.
  Future<http.Response?> sendAuthenticated(
    Future<http.Response> Function(http.Client client, String token) send,
  ) async {
    if (!await ensureFreshToken()) return null;
    final client = clientFactory();
    try {
      final token = accessToken!;
      var response = await retryPolicy.run(() => send(client, token));
      if (response.statusCode != 401) return response;

      if (!supportsRefresh) {
        markNeedsReLogin();
        return response;
      }
      // Another request may already have renewed the token meanwhile.
      if (accessToken == token && !await refreshAccessToken()) return response;
      final fresh = accessToken;
      if (fresh == null) return response;
      response = await retryPolicy.run(() => send(client, fresh));
      if (response.statusCode == 401) markNeedsReLogin();
      return response;
    } finally {
      client.close();
    }
  }

  /// Make authenticated API request with automatic token refresh.
  /// [body] is sent JSON encoded. Returns null when it cannot be completed.
  Future<http.Response?> makeAuthenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    final verb = method.toUpperCase();
    if (!const {'GET', 'POST', 'PUT', 'DELETE'}.contains(verb)) {
      throw Exception('Unsupported HTTP method: $method');
    }
    try {
      return await sendAuthenticated((client, token) {
        final request = http.Request(verb, Uri.parse(url))
          ..headers.addAll({
            if (body != null) 'Content-Type': 'application/json',
            ...?headers,
            'Authorization': 'Bearer $token',
          });
        if (body != null && verb != 'GET' && verb != 'DELETE') {
          request.body = json.encode(body);
        }
        return client.send(request).then(http.Response.fromStream);
      });
    } catch (e) {
      debugPrint('Authenticated request failed (${e.runtimeType})');
      return null;
    }
  }

  /// Save authentication response to secure storage
  Future<void> _saveAuthResponse() async {
    final json = authResponseToJson(authResponse);
    if (json != null) {
      await secureStorage.write(
        key: authResponseKey,
        value: jsonEncode(json),
      );
    }
  }

  /// Save user info to secure storage
  Future<void> _saveUserInfo() async {
    await secureStorage.write(key: usernameKey, value: username ?? '');
    await secureStorage.write(key: profileImageKey, value: profileImage ?? '');
  }

  /// Load user info from secure storage
  Future<void> loadUserInfo() async {
    username = await secureStorage.read(key: usernameKey);
    profileImage = await secureStorage.read(key: profileImageKey);
    notifyListeners();
  }

  /// Load authentication data from secure storage
  Future<void> loadFromPreferences() async {
    final authResponseString = await secureStorage.read(key: authResponseKey);
    if (authResponseString != null) {
      final jsonData = json.decode(authResponseString);
      authResponse = authResponseFromJson(jsonData);
      username = await secureStorage.read(key: usernameKey);
      profileImage = await secureStorage.read(key: profileImageKey);
      status = AuthStatus.AUTHENTICATED;
      notifyListeners();
    }
  }

  /// Clear all user data
  void clear() {
    authResponse = null;
    username = null;
    profileImage = null;
    status = AuthStatus.UNAUTHENTICATED;
    _clearPreferences();
    notifyListeners();
  }

  /// Clear data from secure storage
  Future<void> _clearPreferences() async {
    await secureStorage.delete(key: authResponseKey);
    await secureStorage.delete(key: usernameKey);
    await secureStorage.delete(key: profileImageKey);
  }

  /// Notify listeners of account change
  void notifyAccountChange() {
    notifyListeners();
  }
}
