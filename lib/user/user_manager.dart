import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized User Manager for all trackers
/// Manages authentication state for MAL, AniList, Kitsu, and Simkl
/// Uses singleton pattern with ChangeNotifier for reactive UI updates
class UserManager with ChangeNotifier {
  static final UserManager _instance = UserManager._internal();

  factory UserManager() {
    return _instance;
  }

  UserManager._internal();

  static UserManager get instance => _instance;

  // Tracker instances - All using V2 with BaseUser inheritance
  final UserMalV2 mal = UserMalV2.instance;
  final UserAnilistV2 anilist = UserAnilistV2.instance;
  final UserKitsuV2 kitsu = UserKitsuV2.instance;
  final UserSimklV2 simkl = UserSimklV2.instance;

  // Current active tracker
  AccountType _currentTracker = AccountType.none;

  AccountType get currentTracker => _currentTracker;

  /// Get the currently active user based on selected tracker
  BaseUser? get currentUser {
    switch (_currentTracker) {
      case AccountType.myanimelist:
        return mal;
      case AccountType.anilist:
        return anilist;
      case AccountType.kitsu:
        return kitsu;
      case AccountType.simkl:
        return simkl;
      case AccountType.none:
        return null;
    }
  }

  /// Get user by tracker type
  BaseUser? getUserByTracker(AccountType tracker) {
    switch (tracker) {
      case AccountType.myanimelist:
        return mal;
      case AccountType.anilist:
        return anilist;
      case AccountType.kitsu:
        return kitsu;
      case AccountType.simkl:
        return simkl;
      case AccountType.none:
        return null;
    }
  }

  /// Check if a tracker is authenticated
  bool isAuthenticated(AccountType tracker) {
    final user = getUserByTracker(tracker);
    return user?.status == AuthStatus.AUTHENTICATED;
  }

  /// Check if any tracker is authenticated
  bool get hasAnyAuthentication {
    return isAuthenticated(AccountType.myanimelist) ||
        isAuthenticated(AccountType.anilist) ||
        isAuthenticated(AccountType.kitsu) ||
        isAuthenticated(AccountType.simkl);
  }

  /// Get list of authenticated trackers
  List<AccountType> get authenticatedTrackers {
    final List<AccountType> authenticated = [];
    if (isAuthenticated(AccountType.myanimelist)) {
      authenticated.add(AccountType.myanimelist);
    }
    if (isAuthenticated(AccountType.anilist)) {
      authenticated.add(AccountType.anilist);
    }
    if (isAuthenticated(AccountType.kitsu)) {
      authenticated.add(AccountType.kitsu);
    }
    if (isAuthenticated(AccountType.simkl)) {
      authenticated.add(AccountType.simkl);
    }
    return authenticated;
  }

  /// Set the current active tracker
  Future<void> setCurrentTracker(AccountType tracker) async {
    if (_currentTracker == tracker) return;

    _currentTracker = tracker;
    await _saveCurrentTracker();
    notifyListeners();
  }

  /// Load current tracker from SharedPreferences
  Future<void> loadCurrentTracker() async {
    final prefs = await SharedPreferences.getInstance();
    final trackerString = prefs.getString('current_tracker');
    if (trackerString != null) {
      try {
        _currentTracker = AccountType.values.firstWhere(
          (e) => e.toString() == trackerString,
          orElse: () => AccountType.none,
        );
      } catch (e) {
        _currentTracker = AccountType.none;
      }
    }
    notifyListeners();
  }

  /// Save current tracker to SharedPreferences
  Future<void> _saveCurrentTracker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_tracker', _currentTracker.toString());
  }

  /// Refresh, before it is used, every token that is about to expire.
  /// Each tracker is handled on its own: one failure never blocks the others.
  Future<void> refreshExpiringTokens() async {
    await Future.wait(
      [mal, anilist, kitsu, simkl].map((BaseUser user) async {
        try {
          if (user.status == AuthStatus.AUTHENTICATED) {
            await user.ensureFreshToken();
          }
        } catch (_) {
          // Transient failure: the 401 path retries on the first request.
        }
      }),
    );
  }

  /// Users whose session died (refresh rejected, 401 without refresh token).
  List<AccountType> get trackersNeedingReLogin => [
        for (final t in const [
          AccountType.myanimelist,
          AccountType.anilist,
          AccountType.kitsu,
          AccountType.simkl,
        ])
          if (getUserByTracker(t)?.needsReLogin ?? false) t,
      ];

  /// Initialize all users from secure storage
  Future<void> initializeAllUsers() async {
    await mal.loadFromPreferences();
    await anilist.loadFromPreferences();
    await kitsu.loadFromPreferences();
    await simkl.loadFromPreferences();

    // Load current tracker
    await loadCurrentTracker();

    // Setup listeners for all users
    _setupUserListeners();

    // Renew stale tokens in the background so the first request is clean.
    unawaited(refreshExpiringTokens());
  }

  /// Setup listeners to propagate changes from individual users
  void _setupUserListeners() {
    mal.addListener(() {
      notifyListeners();
    });
    anilist.addListener(() {
      notifyListeners();
    });
    kitsu.addListener(() {
      notifyListeners();
    });
    simkl.addListener(() {
      notifyListeners();
    });
  }

  /// Sign out from a specific tracker
  Future<void> signOut(AccountType tracker) async {
    final user = getUserByTracker(tracker);
    if (user != null) {
      user.clear();

      // If signing out from current tracker, reset to none
      if (_currentTracker == tracker) {
        await setCurrentTracker(AccountType.none);
      }

      notifyListeners();
    }
  }

  /// Sign out from all trackers
  Future<void> signOutAll() async {
    mal.clear();
    anilist.clear();
    kitsu.clear();
    simkl.clear();

    await setCurrentTracker(AccountType.none);
    notifyListeners();
  }

  /// Get username for a tracker
  String? getUsername(AccountType tracker) {
    return getUserByTracker(tracker)?.username;
  }

  /// Get profile image for a tracker
  String? getProfileImage(AccountType tracker) {
    return getUserByTracker(tracker)?.profileImage;
  }

  /// Get access token for current user
  String? get currentAccessToken {
    return currentUser?.accessToken;
  }

  /// Check if current user's token is expired
  bool get isCurrentTokenExpired {
    return currentUser?.isTokenExpired ?? true;
  }

  /// Refresh current user's token
  Future<bool> refreshCurrentToken() async {
    final user = currentUser;
    if (user == null) return false;
    return await user.refreshAccessToken();
  }

  /// Refresh the token of a given tracker (not only the active one).
  Future<bool> refreshToken(AccountType tracker) async {
    final user = getUserByTracker(tracker);
    if (user == null) return false;
    return await user.refreshAccessToken();
  }

  /// Make authenticated request with current user
  Future<dynamic> makeAuthenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) async {
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }

    return await currentUser!.makeAuthenticatedRequest(
      url,
      method: method,
      headers: headers,
      body: body,
    );
  }

  /// Debug info
  void printDebugInfo() {
    print('=== UserManager Debug Info ===');
    print('Current Tracker: $_currentTracker');
    print('MAL Authenticated: ${isAuthenticated(AccountType.myanimelist)}');
    print('AniList Authenticated: ${isAuthenticated(AccountType.anilist)}');
    print('Kitsu Authenticated: ${isAuthenticated(AccountType.kitsu)}');
    print('Simkl Authenticated: ${isAuthenticated(AccountType.simkl)}');
    print('Authenticated Trackers: $authenticatedTrackers');
    print('Has Any Auth: $hasAnyAuthentication');
    print('==============================');
  }
}
