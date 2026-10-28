import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simkl sign in: Custom Tabs on Android (Simkl asks for the platform's secure browser, never an
/// embedded WebView), flutter_web_auth_2 elsewhere; the redirect comes back through app_links
/// (`main.dart` calls [checkIfSignIn]).
///
/// With a V2 client id (`SIMKL_V2_CLIENT_ID`) every new sign in, and every "sign in again" of a
/// V1 session, goes through AUTH V2: `/oauth2/authorize` with PKCE S256 and the
/// `media:read media:write` scopes, then `/oauth2/token`. Without one it stays on AUTH V1.
class SimklAuthV2 {
  SimklAuthV2({
    http.Client Function()? httpClient,
    Future<({String name, String avatar})?> Function()? fetchProfile,
  })  : _httpClient = httpClient ?? http.Client.new,
        _fetchProfile = fetchProfile ?? _defaultProfile;

  final http.Client Function() _httpClient;
  final Future<({String name, String avatar})?> Function() _fetchProfile;

  // Pending flow (SharedPreferences): survives the app being killed while the browser is open.
  static const String _stateKey = 'simkl_oauth_state';
  static const String _verifierKey = 'simkl_oauth_verifier';
  static const String _versionKey = 'simkl_oauth_version';

  String get _redirectUri => Constants.simklRedirectUri;

  static Future<({String name, String avatar})?> _defaultProfile() async {
    final profile = await SimklUser(client: SimklApi.sessionClient).getUserInfo();
    return (name: profile.name, avatar: profile.avatar);
  }

  /// Whether tokens existed when this sign in started (a reconnect of a signed-in account).
  bool _hadTokens = false;

  /// A sign in that did not finish leaves a still-working session signed in.
  void _endWithoutSignIn() {
    final user = UserSimklV2.instance;
    user.setStatus(_hadTokens && user.accessToken != null
        ? AuthStatus.AUTHENTICATED
        : AuthStatus.UNAUTHENTICATED);
    user.notifyAccountChange();
  }

  /// Starts the sign in. Returns false when it could not start or failed at once; on Android it
  /// returns true once the browser is open and the redirect finishes the job.
  Future<bool> handleSignIn({BuildContext? context}) async {
    final user = UserSimklV2.instance;
    if (user.getStatus() == AuthStatus.INPROGRESS) return false; // double tap

    _hadTokens = user.accessToken != null;
    user.setStatus(AuthStatus.INPROGRESS);
    user.notifyAccountChange();

    try {
      return await _oAuthSignIn(context: context);
    } catch (e) {
      debugPrint('Simkl sign in failed (${e.runtimeType})');
      _endWithoutSignIn();
      return false;
    }
  }

  /// The consent URL of a new flow, its state and verifier saved for the redirect.
  @visibleForTesting
  Future<Uri> startFlow() async {
    final state = SimklOAuth2.randomToken(48);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey, state);
    if (SimklOAuth2.isConfigured) {
      final verifier = SimklOAuth2.randomToken(64);
      await prefs.setString(_verifierKey, verifier);
      await prefs.setString(_versionKey, 'v2');
      return SimklOAuth2.authorizeUri(
        clientId: SimklOAuth2.clientId,
        redirectUri: _redirectUri,
        state: state,
        codeChallenge: SimklOAuth2.challengeOf(verifier),
      );
    }
    await prefs.remove(_verifierKey);
    await prefs.setString(_versionKey, 'v1');
    return Uri.parse(Constants.simklOAuthEndPoint).replace(queryParameters: {
      'response_type': 'code',
      'client_id': Constants.simklClientId,
      'redirect_uri': _redirectUri,
      'state': state,
    });
  }

  Future<bool> _oAuthSignIn({BuildContext? context}) async {
    final url = await startFlow();
    if (!kIsWeb && Platform.isAndroid) return _androidAuth(url, context);
    // Desktop: system browser; iOS and the rest: the platform's web auth session.
    final result = await FlutterWebAuth2.authenticate(
      url: url.toString(),
      callbackUrlScheme: Constants.simklCallbackScheme,
      options: FlutterWebAuth2Options(
        useWebview: !(!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)),
      ),
    );
    return checkIfSignIn(Uri.parse(result));
  }

  Future<bool> _androidAuth(Uri url, BuildContext? context) async {
    final colors = context != null && context.mounted ? Theme.of(context).colorScheme : null;
    await custom_tabs.launchUrl(
      url,
      customTabsOptions: custom_tabs.CustomTabsOptions(
        colorSchemes: colors != null
            ? custom_tabs.CustomTabsColorSchemes.defaults(toolbarColor: colors.surface)
            : null,
        shareState: custom_tabs.CustomTabsShareState.off,
        urlBarHidingEnabled: true,
        showTitle: true,
      ),
      safariVCOptions: custom_tabs.SafariViewControllerOptions(
        preferredBarTintColor: colors?.surface,
        preferredControlTintColor: colors?.primary,
        barCollapsingEnabled: true,
      ),
    );
    return true; // the redirect is handled by app_links
  }

  /// Handles the redirect `com.teen.mywatchlist://simkl-callback?code=…&state=…`.
  ///
  /// The state must match the saved one (CSRF), a V2 redirect must come from Simkl's issuer when
  /// it names one, and an `error` (refusal) ends the flow. The code is exchanged once: Simkl
  /// consumes it even when the exchange fails.
  Future<bool> checkIfSignIn(Uri? uri) async {
    if (uri == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final expected = prefs.getString(_stateKey);
    final verifier = prefs.getString(_verifierKey);
    final version = prefs.getString(_versionKey);
    final params = uri.queryParameters;
    final code = params['code'];
    final state = params['state'];
    final iss = params['iss'];

    final valid = expected != null &&
        state == expected &&
        params['error'] == null &&
        code != null &&
        code.isNotEmpty &&
        (version != 'v2' || ((iss == null || iss == SimklOAuth2.issuer) && verifier != null));
    // A redirect is answered once; the saved flow is dropped whatever happens next.
    if (expected != null) await _clearFlow(prefs);
    if (!valid) {
      _endWithoutSignIn();
      return false;
    }

    try {
      final auth = version == 'v2'
          ? await _exchangeV2(code, verifier!)
          : await _exchangeV1(code);
      if (auth == null) {
        _endWithoutSignIn();
        return false;
      }
      await _finishSignIn(auth);
      return true;
    } catch (e) {
      debugPrint('Simkl token exchange failed (${e.runtimeType})');
      _endWithoutSignIn();
      return false;
    }
  }

  Future<SimklAuthResponse?> _exchangeV2(String code, String verifier) async {
    final client = _httpClient();
    try {
      final response = await SimklOAuth2.postForm(
        client,
        SimklOAuth2.tokenUri,
        SimklOAuth2.codeGrant(
          code: code,
          codeVerifier: verifier,
          clientId: SimklOAuth2.clientId,
          redirectUri: _redirectUri,
        ),
      ).timeout(const Duration(seconds: 30));
      final auth = SimklOAuth2.parseToken(response);
      if (auth == null) {
        debugPrint('Simkl V2 token exchange refused: ${response.statusCode} '
            '${SimklOAuth2.errorOf(response) ?? ''}');
      } else if (!auth.canWrite) {
        debugPrint('Simkl granted read-only access (${auth.scope})');
      }
      return auth;
    } finally {
      client.close();
    }
  }

  Future<SimklAuthResponse?> _exchangeV1(String code) async {
    final client = _httpClient();
    try {
      final response = await client
          .post(
            Uri.parse(Constants.simklTokenEndPoint),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'code': code,
              'client_id': Constants.simklClientId,
              'client_secret': Constants.simklClientSecret,
              'redirect_uri': _redirectUri,
              'grant_type': 'authorization_code',
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint('Simkl V1 token exchange refused: ${response.statusCode}');
        return null;
      }
      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['access_token'] is! String) return null;
      return SimklAuthResponse.fromJson(data);
    } finally {
      client.close();
    }
  }

  Future<void> _finishSignIn(SimklAuthResponse auth) async {
    final user = UserSimklV2.instance;
    user.setAuthResponse(auth);
    user.setStatus(AuthStatus.AUTHENTICATED);
    user.notifyAccountChange();
    try {
      final profile = await _fetchProfile();
      if (profile != null) user.setUserInfo(profile.name, profile.avatar);
    } catch (e) {
      debugPrint('Simkl profile fetch failed (${e.runtimeType})');
    }
  }

  Future<void> _clearFlow(SharedPreferences prefs) async {
    await prefs.remove(_stateKey);
    await prefs.remove(_verifierKey);
    await prefs.remove(_versionKey);
  }

  /// Ends the V2 grant on Simkl (`/oauth2/revoke`, best effort: always 200, never blocks the
  /// sign out), then clears the local session. V1 has no revocation endpoint.
  Future<void> signOut() async {
    final user = UserSimklV2.instance;
    final auth = user.authResponse;
    final token = auth?.refreshToken ?? auth?.accessToken;
    if (auth != null && auth.isV2 && token != null && SimklOAuth2.isConfigured) {
      final client = _httpClient();
      try {
        await SimklOAuth2.postForm(client, SimklOAuth2.revokeUri, {
          'token': token,
          'client_id': SimklOAuth2.clientId,
        }).timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('Simkl revoke failed (${e.runtimeType})');
      } finally {
        client.close();
      }
    }
    user.clear();
    await _clearFlow(await SharedPreferences.getInstance());
  }
}
