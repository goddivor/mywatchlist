import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/auth_webview.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MAL sign in. On Android it runs in the in-app [AuthWebView] on myanimelist.net: when the
/// OAuth redirect arrives, the WebView the user signed in with holds MAL's website cookies,
/// which [MalWebSession] stores next to the tokens (comments and other website features).
/// "Open in browser" in that page, and a missing context, fall back to Custom Tabs (tokens
/// only). Desktop uses flutter_web_auth_2.
class MalAuthV2 {
  /// [httpClient] replaces the network for the token exchange (tests only).
  MalAuthV2({http.Client? httpClient}) : _http = httpClient;

  final http.Client? _http;

  final String clientId = Constants.malclientId;
  final String clientSecret = Constants.malClientSecret;
  final String redirectUri = Constants.malredirectUri;
  final String oauthEndPoint = Constants.maloauthEndPoint;
  final String tokenEndPoint = Constants.maltokenEndPoint;

  final String _chars = Constants.chars;
  final Random _rnd = Random.secure();

  /// Generate a random string of specified length for PKCE code challenge
  String _getRandomString(int length) => String.fromCharCodes(
      Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  /// Handle sign-in process
  /// Returns true if sign-in is successful, false otherwise
  Future<bool> handleSignIn({BuildContext? context}) async {
    final currentStatus = UserMalV2.instance.getStatus();

    // Prevent double-click
    if (currentStatus == AuthStatus.INPROGRESS) {
      return false;
    }

    UserMalV2.instance.setStatus(AuthStatus.INPROGRESS);
    UserMalV2.instance.notifyAccountChange();

    try {
      final success = await _oAuthSignIn(context: context);
      return success;
    } catch (e) {
      debugPrint('MAL sign-in error: ${e.runtimeType}');
      _endWithoutSignIn();
      return false;
    }
  }

  /// A sign in that was cancelled or failed leaves the account as it was. A dead session
  /// has no tokens ([BaseUser.markNeedsReLogin] drops them), so tokens mean the account is
  /// still signed in and must not look disconnected; without tokens it is signed out.
  /// Works for the deep link too, which can come back through another [MalAuthV2].
  void _endWithoutSignIn() {
    final user = UserMalV2.instance;
    user.setStatus(
      user.accessToken != null ? AuthStatus.AUTHENTICATED : AuthStatus.UNAUTHENTICATED,
    );
    user.notifyAccountChange();
  }

  /// Main OAuth sign-in flow
  Future<bool> _oAuthSignIn({BuildContext? context}) async {
    // Generate and cache code challenge
    final codeChallenge = _getRandomString(127);
    await _saveChallengeCode(codeChallenge);

    // Build OAuth URL
    final url = '$oauthEndPoint'
        '?response_type=code'
        '&client_id=$clientId'
        '&code_challenge=$codeChallenge'
        '&state=OAuthLogin'
        '&redirect_uri=$redirectUri';

    // Use flutter_web_auth_2 for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return await _desktopAuth(url, codeChallenge);
    }
    // Android: in-app WebView (captures the website session), Custom Tabs as fallback
    else if (!kIsWeb && Platform.isAndroid) {
      if (context != null && context.mounted) {
        return await _webViewAuthAndroid(url, codeChallenge, context);
      }
      return await _mobileAuthAndroid(url, codeChallenge, context);
    }
    // Use WebView for iOS or fallback
    else {
      return await _mobileAuthFallback(url, codeChallenge);
    }
  }

  /// Desktop authentication using flutter_web_auth_2
  Future<bool> _desktopAuth(String url, String codeChallenge) async {
    try {
      print('Starting OAuth with flutter_web_auth_2 for desktop');

      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: Constants.malCallbackScheme,
        options: const FlutterWebAuth2Options(
          useWebview: false, // Use system browser
        ),
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null) {
        return await _exchangeCodeForToken(code, codeChallenge);
      } else {
        print('No code received from OAuth callback');
        _endWithoutSignIn();
        return false;
      }
    } catch (e) {
      print('OAuth error on desktop: $e');
      _endWithoutSignIn();
      return false;
    }
  }

  /// Android sign in inside [AuthWebView]. Returns true once the page opened (the outcome
  /// reaches the UI through [UserMalV2]); a closed page restores the previous state.
  Future<bool> _webViewAuthAndroid(String url, String codeChallenge, BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await AuthWebView.open(
      context,
      url: url,
      redirectPrefix: redirectUri,
      title: 'MyAnimeList',
      allowBrowser: true,
    );
    if (result.useBrowser) {
      if (!context.mounted) {
        _endWithoutSignIn();
        return true;
      }
      return _mobileAuthAndroid(url, codeChallenge, context);
    }
    final code = result.callback?.queryParameters['code'];
    if (code == null) {
      _endWithoutSignIn();
      return true;
    }
    final jar = await MalWebSession.instance.beginCapture();
    final ok = await _exchangeCodeForToken(code, codeChallenge, webSessionJar: jar);
    if (!ok) {
      MalWebSession.instance.cancelCapture();
      _endWithoutSignIn();
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(S.current.Ms_Sign_In_Failed),
        ));
    }
    return true;
  }

  /// Android authentication using Custom Tabs
  Future<bool> _mobileAuthAndroid(
    String url,
    String codeChallenge,
    BuildContext? context,
  ) async {
    try {
      // Launch Custom Tabs with theme colors
      await custom_tabs.launchUrl(
        Uri.parse(url),
        customTabsOptions: custom_tabs.CustomTabsOptions(
          colorSchemes: context != null
              ? custom_tabs.CustomTabsColorSchemes.defaults(
                  toolbarColor: Theme.of(context).colorScheme.surface,
                )
              : null,
          shareState: custom_tabs.CustomTabsShareState.off,
          urlBarHidingEnabled: true,
          showTitle: true,
        ),
        safariVCOptions: custom_tabs.SafariViewControllerOptions(
          preferredBarTintColor: context != null
              ? Theme.of(context).colorScheme.surface
              : null,
          preferredControlTintColor: context != null
              ? Theme.of(context).colorScheme.primary
              : null,
          barCollapsingEnabled: true,
        ),
      );

      // The callback will be handled by app_links
      // We need to wait for the callback to be processed
      return true;
    } catch (e) {
      print('Custom Tabs error: $e');
      _endWithoutSignIn();
      return false;
    }
  }

  /// Fallback mobile authentication (iOS or other platforms)
  Future<bool> _mobileAuthFallback(String url, String codeChallenge) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: Constants.malCallbackScheme,
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null) {
        return await _exchangeCodeForToken(code, codeChallenge);
      }
      return false;
    } catch (e) {
      print('Fallback auth error: $e');
      _endWithoutSignIn();
      return false;
    }
  }

  /// Exchange authorization code for access token
  Future<bool> _exchangeCodeForToken(
    String code,
    String codeChallenge, {
    Map<String, String>? webSessionJar,
  }) async {
    try {
      final response = await (_http?.post ?? http.post)(
        Uri.parse(tokenEndPoint),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': codeChallenge,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'client_secret': clientSecret, // ✅ CLIENT SECRET INCLUDED!
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final authResponse = AuthResponse.fromJson(responseData);

        UserMalV2.instance.setAuthResponse(authResponse);
        UserMalV2.instance.setStatus(AuthStatus.AUTHENTICATED);
        UserMalV2.instance.notifyAccountChange();

        // Fetch user profile data
        String? name;
        try {
          final userProfile = await MalUser().getUserInfo();
          name = userProfile.name;
          UserMalV2.instance.setUserInfo(userProfile.name, userProfile.picture);
        } catch (e) {
          debugPrint('Failed to fetch MAL user profile: ${e.runtimeType}');
        }

        // The WebView the user signed in with holds MAL's website cookies.
        if (webSessionJar != null) {
          MalWebClient.instance.reset();
          await MalWebSession.instance.finishCapture(webSessionJar, username: name);
        }

        // Clear cached code challenge
        await _clearChallengeCode();

        return true;
      } else {
        debugPrint('MAL token exchange failed: ${response.statusCode}');
        _endWithoutSignIn();
        return false;
      }
    } catch (e) {
      debugPrint('MAL token exchange error: ${e.runtimeType}');
      _endWithoutSignIn();
      return false;
    }
  }

  /// Check if sign-in callback is valid and process it
  /// Used by app_links to handle deep link callbacks
  Future<bool> checkIfSignIn(Uri? uri) async {
    final code = uri?.queryParameters['code'];
    if (code != null) {
      final codeChallenge = await _getChallengeCode();
      if (codeChallenge != null) {
        return await _exchangeCodeForToken(code, codeChallenge);
      }
    }
    return false;
  }

  /// Save code challenge to SharedPreferences
  Future<void> _saveChallengeCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mal_code_challenge', code);
  }

  /// Get code challenge from SharedPreferences
  Future<String?> _getChallengeCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('mal_code_challenge');
  }

  /// Clear code challenge from SharedPreferences
  Future<void> _clearChallengeCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mal_code_challenge');
  }

  /// Sign out: tokens and the website session go together.
  Future<void> signOut() async {
    UserMalV2.instance.clear();
    MalWebClient.instance.reset();
    await MalWebSession.instance.clear();
    await _clearChallengeCode();
  }
}
