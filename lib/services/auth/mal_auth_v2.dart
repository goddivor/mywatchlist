import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced MAL authentication with Custom Tabs (mobile) and flutter_web_auth_2 (desktop)
/// Based on DailyAL implementation with improvements
class MalAuthV2 {
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
    final currentStatus = UserMal.instance.getStatus();

    // Prevent double-click
    if (currentStatus == AuthStatus.INPROGRESS) {
      return false;
    }

    UserMal.instance.setStatus(AuthStatus.INPROGRESS);
    UserMal.instance.notifyAccountChange();

    try {
      final success = await _oAuthSignIn(context: context);
      return success;
    } catch (e) {
      print('Sign-in error: $e');
      UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserMal.instance.notifyAccountChange();
      return false;
    }
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
    // Use Custom Tabs for Android
    else if (!kIsWeb && Platform.isAndroid) {
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

      print('OAuth callback received: $result');
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null) {
        return await _exchangeCodeForToken(code, codeChallenge);
      } else {
        print('No code received from OAuth callback');
        UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
        UserMal.instance.notifyAccountChange();
        return false;
      }
    } catch (e) {
      print('OAuth error on desktop: $e');
      UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserMal.instance.notifyAccountChange();
      return false;
    }
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
      UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserMal.instance.notifyAccountChange();
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
      UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserMal.instance.notifyAccountChange();
      return false;
    }
  }

  /// Exchange authorization code for access token
  Future<bool> _exchangeCodeForToken(String code, String codeChallenge) async {
    try {
      final response = await http.post(
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

        UserMal.instance.setAuthResponse(authResponse);
        UserMal.instance.setStatus(AuthStatus.AUTHENTICATED);
        UserMal.instance.notifyAccountChange();

        // Clear cached code challenge
        await _clearChallengeCode();

        return true;
      } else {
        print('Token exchange failed: ${response.statusCode} - ${response.body}');
        UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
        UserMal.instance.notifyAccountChange();
        return false;
      }
    } catch (e) {
      print('Error exchanging code for token: $e');
      UserMal.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserMal.instance.notifyAccountChange();
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

  /// Sign out
  Future<void> signOut() async {
    UserMal.instance.clear();
    await _clearChallengeCode();
  }
}
