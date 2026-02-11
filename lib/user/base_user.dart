import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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
    _saveAuthResponse();
    notifyListeners();
  }

  /// Set user info (username and profile image)
  void setUserInfo(String name, String image) {
    username = name;
    profileImage = image;
    _saveUserInfo();
    notifyListeners();
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

  /// Check if token is expired
  bool get isTokenExpired {
    final expiryTime = tokenExpiryTime;
    if (expiryTime == null) return true;
    return expiryTime.isBefore(DateTime.now());
  }

  /// Refresh the access token using refresh token
  Future<bool> refreshAccessToken() async {
    final refreshTok = refreshToken;
    if (refreshTok == null || refreshTok.isEmpty) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(tokenEndPoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshTok,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final newAuthResponse = authResponseFromJson(responseData);
        if (newAuthResponse != null) {
          setAuthResponse(newAuthResponse);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  /// Make authenticated API request with automatic token refresh
  Future<http.Response?> makeAuthenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    int retryCount = 0,
    int maxRetries = 3,
  }) async {
    // Check if token is expired and refresh if needed
    if (isTokenExpired) {
      final refreshed = await refreshAccessToken();
      if (!refreshed) {
        status = AuthStatus.UNAUTHENTICATED;
        notifyListeners();
        return null;
      }
    }

    final token = accessToken;
    if (token == null) {
      return null;
    }

    try {
      final requestHeaders = {
        'Authorization': 'Bearer $token',
        ...?headers,
      };

      http.Response response;
      if (method == 'GET') {
        response = await http.get(Uri.parse(url), headers: requestHeaders);
      } else if (method == 'POST') {
        response = await http.post(
          Uri.parse(url),
          headers: {...requestHeaders, 'Content-Type': 'application/json'},
          body: body != null ? json.encode(body) : null,
        );
      } else if (method == 'PUT') {
        response = await http.put(
          Uri.parse(url),
          headers: {...requestHeaders, 'Content-Type': 'application/json'},
          body: body != null ? json.encode(body) : null,
        );
      } else if (method == 'DELETE') {
        response = await http.delete(Uri.parse(url), headers: requestHeaders);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }

      // If token expired (401), try to refresh and retry
      if (response.statusCode == 401 && retryCount < maxRetries) {
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          return makeAuthenticatedRequest(
            url,
            method: method,
            headers: headers,
            body: body,
            retryCount: retryCount + 1,
            maxRetries: maxRetries,
          );
        }
      }

      return response;
    } catch (e) {
      print('Error making authenticated request: $e');
      // Retry on network error
      if (retryCount < maxRetries) {
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        return makeAuthenticatedRequest(
          url,
          method: method,
          headers: headers,
          body: body,
          retryCount: retryCount + 1,
          maxRetries: maxRetries,
        );
      }
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
