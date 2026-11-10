import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_authresp.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enhanced AniList authentication with Custom Tabs (mobile) and flutter_web_auth_2 (desktop)
/// Based on MalAuthV2 implementation
class AnilistAuthV2 {
  final String clientId = Constants.anilistClientId;
  final String clientSecret = Constants.anilistClientSecret;
  final String redirectUri = Constants.anilistRedirectUri;
  final String oauthEndPoint = Constants.anilistOAuthEndPoint;
  final String tokenEndPoint = Constants.anilistTokenEndPoint;

  final String _chars = Constants.chars;
  final Random _rnd = Random.secure();

  /// Generate a random string of specified length for PKCE code challenge
  String _getRandomString(int length) => String.fromCharCodes(
      Iterable.generate(length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

  /// Handle sign-in process
  /// Returns true if sign-in is successful, false otherwise
  Future<bool> handleSignIn({BuildContext? context}) async {
    final currentStatus = UserAnilistV2.instance.getStatus();

    // Prevent double-click
    if (currentStatus == AuthStatus.INPROGRESS) {
      return false;
    }

    UserAnilistV2.instance.setStatus(AuthStatus.INPROGRESS);
    UserAnilistV2.instance.notifyAccountChange();

    try {
      final success = await _oAuthSignIn(context: context);
      return success;
    } catch (e) {
      print('AniList sign-in error: $e');
      UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserAnilistV2.instance.notifyAccountChange();
      return false;
    }
  }

  /// Main OAuth sign-in flow
  Future<bool> _oAuthSignIn({BuildContext? context}) async {
    // Generate and cache code challenge (AniList uses state parameter, not code_challenge)
    final state = _getRandomString(127);
    await _saveState(state);

    // Build OAuth URL (AniList doesn't use PKCE, just state)
    final url = '$oauthEndPoint'
        '?client_id=$clientId'
        '&redirect_uri=$redirectUri'
        '&response_type=code'
        '&state=$state';

    // Use flutter_web_auth_2 for desktop platforms
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return await _desktopAuth(url, state);
    }
    // Use Custom Tabs for Android
    else if (!kIsWeb && Platform.isAndroid) {
      return await _mobileAuthAndroid(url, state, context);
    }
    // Use WebView for iOS or fallback
    else {
      return await _mobileAuthFallback(url, state);
    }
  }

  /// Desktop authentication using flutter_web_auth_2
  Future<bool> _desktopAuth(String url, String state) async {
    try {
      print('Starting AniList OAuth with flutter_web_auth_2 for desktop');

      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: Constants.anilistCallbackScheme,
        options: const FlutterWebAuth2Options(
          useWebview: false, // Use system browser
        ),
      );

      print('AniList OAuth callback received: $result');
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null) {
        return await _exchangeCodeForToken(code, state);
      } else {
        print('No code received from AniList OAuth callback');
        UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
        UserAnilistV2.instance.notifyAccountChange();
        return false;
      }
    } catch (e) {
      print('AniList OAuth error on desktop: $e');
      UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserAnilistV2.instance.notifyAccountChange();
      return false;
    }
  }

  /// Android authentication using Custom Tabs
  Future<bool> _mobileAuthAndroid(
    String url,
    String state,
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
      return true;
    } catch (e) {
      print('AniList Custom Tabs error: $e');
      UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserAnilistV2.instance.notifyAccountChange();
      return false;
    }
  }

  /// Fallback mobile authentication (iOS or other platforms)
  Future<bool> _mobileAuthFallback(String url, String state) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url,
        callbackUrlScheme: Constants.anilistCallbackScheme,
      );

      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];

      if (code != null) {
        return await _exchangeCodeForToken(code, state);
      }
      return false;
    } catch (e) {
      print('AniList fallback auth error: $e');
      UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserAnilistV2.instance.notifyAccountChange();
      return false;
    }
  }

  /// Exchange authorization code for access token
  Future<bool> _exchangeCodeForToken(String code, String state) async {
    try {
      final response = await http.post(
        Uri.parse(tokenEndPoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'code': code,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final authResponse = AnilistAuthResponse.fromJson(responseData);

        UserAnilistV2.instance.setAuthResponse(authResponse);
        UserAnilistV2.instance.setStatus(AuthStatus.AUTHENTICATED);
        UserAnilistV2.instance.notifyAccountChange();

        // Fetch user profile data
        try {
          final userProfile = await AnilistUser().getUserInfo();
          UserAnilistV2.instance.setUserInfo(userProfile.name, userProfile.avatarUrl);
        } catch (e) {
          print('Failed to fetch AniList user profile: $e');
        }

        // Clear cached state
        await _clearState();

        return true;
      } else {
        print('AniList token exchange failed: ${response.statusCode} - ${response.body}');
        UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
        UserAnilistV2.instance.notifyAccountChange();
        return false;
      }
    } catch (e) {
      print('Error exchanging AniList code for token: $e');
      UserAnilistV2.instance.setStatus(AuthStatus.UNAUTHENTICATED);
      UserAnilistV2.instance.notifyAccountChange();
      return false;
    }
  }

  /// Check if sign-in callback is valid and process it
  /// Used by app_links to handle deep link callbacks
  Future<bool> checkIfSignIn(Uri? uri) async {
    final code = uri?.queryParameters['code'];
    if (code != null) {
      final state = await _getState();
      if (state != null) {
        return await _exchangeCodeForToken(code, state);
      }
    }
    return false;
  }

  /// Save state to SharedPreferences
  Future<void> _saveState(String state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('anilist_oauth_state', state);
  }

  /// Get state from SharedPreferences
  Future<String?> _getState() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('anilist_oauth_state');
  }

  /// Clear state from SharedPreferences
  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('anilist_oauth_state');
  }

  /// Sign out
  Future<void> signOut() async {
    UserAnilistV2.instance.clear();
    await _clearState();
  }
}
