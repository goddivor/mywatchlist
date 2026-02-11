// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_auth.dart';
import 'package:mywatchlist/services/auth/kitsu_auth.dart';
import 'package:mywatchlist/services/auth/mal_auth.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
// V2 Auth classes with Custom Tabs + Desktop support
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
// V2 User classes with BaseUser inheritance
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_login_dialog.dart';
import 'package:mywatchlist/widgets/common/logout_dialog.dart';

/// List of available trackers with enhanced styling
final List<Tracker> trackers = [
  Tracker(
    name: 'MyAnimeList',
    imageUrl: 'assets/images/mal-icon.png',
    primaryColor: const Color(0xFF2E51A2), // MyAnimeList blue
    description:
        'The world\'s most active online anime and manga community and database',
  ),
  Tracker(
    name: 'Anilist',
    imageUrl: 'assets/images/anilist-icon.png',
    primaryColor: const Color(0xFF02A9FF), // Anilist blue
    description:
        'Track, discover, share anime and manga with a modern and customizable experience',
  ),
  Tracker(
    name: 'Kitsu',
    imageUrl: 'assets/images/kitsu-icon.png',
    primaryColor: const Color(0xFFEF5D5D), // Kitsu red
    description:
        'A modern anime discovery platform that helps you track and share your anime journey',
  ),
  Tracker(
    name: 'Simkl',
    imageUrl: 'assets/images/simkl-icon.png',
    primaryColor: const Color.fromARGB(255, 202, 25, 96), // Simkl dark gray
    description:
        'TV, Anime and Movie tracking service with apps for mobile and TV',
  ),
];

// Old auth instances (deprecated, will be removed)
final MalAuth _malAuth = MalAuth();
final SimklAuth _simklAuth = SimklAuth();
final AnilistAuth _anilistAuth = AnilistAuth();
final KitsuAuth _kitsuAuth = KitsuAuth();

// New V2 auth instances with Custom Tabs + Desktop support
final MalAuthV2 _malAuthV2 = MalAuthV2();
final AnilistAuthV2 _anilistAuthV2 = AnilistAuthV2();
final SimklAuthV2 _simklAuthV2 = SimklAuthV2();

/// Handle MyAnimeList authentication
Future<void> handleMalAuth(
    BuildContext context, int index, VoidCallback updateUI) async {
  if (trackers[index].isActive ||
      UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _malAuth.signOut();
      trackers[index].isActive = false;

      context
          .read<AccountBloc>()
          .add(RemoveAccountEvent(AccountType.myanimelist));
      updateUI();
    });
  } else {
    // Authenticate the user
    await _malAuth.signInWithMAL(context, onComplete: () {
      if (UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
        trackers[index].isActive = true;
        updateUI();
      }
    });
  }
}

/// Handle Simkl authentication
Future<void> handleSimklAuth(
    BuildContext context, int index, VoidCallback updateUI) async {
  if (trackers[index].isActive ||
      UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _simklAuth.signOut();
      trackers[index].isActive = false;

      context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.simkl));
      updateUI();
    });
  } else {
    // Authenticate the user
    await _simklAuth.signInWithSimkl(context, onComplete: () {
      if (UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
        trackers[index].isActive = true;
        updateUI();
      }
    });
  }
}

/// Handle Anilist authentication
Future<void> handleAnilistAuth(
    BuildContext context, int index, VoidCallback updateUI) async {
  if (trackers[index].isActive ||
      UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _anilistAuth.signOut();
      trackers[index].isActive = false;

      context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.anilist));
      updateUI();
    });
  } else {
    // Authenticate the user
    await _anilistAuth.signInWithAnilist(context, onComplete: () {
      if (UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
        trackers[index].isActive = true;
        updateUI();
      }
    });
  }
}

/// Handle Kitsu authentication
Future<void> handleKitsuAuth(
    BuildContext context, int index, VoidCallback updateUI) async {
  if (trackers[index].isActive ||
      UserKitsuV2.instance.getStatus() == AuthStatus.AUTHENTICATED) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _kitsuAuth.signout();
      trackers[index].isActive = false;

      context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.kitsu));
      updateUI();
    });
  } else {
    // Authenticate the user with Kitsu login dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return KitsuLoginDialog(
          onLogin: (username, password) async {
            await _kitsuAuth.signInWithKitsu(context, username, password,
                onComplete: () {
              if (UserKitsuV2.instance.getStatus() == AuthStatus.AUTHENTICATED) {
                trackers[index].isActive = true;
                updateUI();
              }
            });
          },
        );
      },
    );
  }
}

/// Handle MyAnimeList authentication (V2 with UserManager)
Future<void> handleMalAuthV2(
    BuildContext context, int index, VoidCallback updateUI) async {
  final userManager = UserManager.instance;

  if (trackers[index].isActive ||
      userManager.isAuthenticated(AccountType.myanimelist)) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _malAuthV2.signOut();
      trackers[index].isActive = false;

      context
          .read<AccountBloc>()
          .add(RemoveAccountEvent(AccountType.myanimelist));
      updateUI();
    });
  } else {
    // Authenticate the user
    final success = await _malAuthV2.handleSignIn(context: context);
    if (success || userManager.mal.status == AuthStatus.INPROGRESS) {
      // Wait for callback to complete (handled by main.dart)
      // Listen for status change
      Future.delayed(Duration(seconds: 1), () {
        if (userManager.isAuthenticated(AccountType.myanimelist)) {
          trackers[index].isActive = true;
          updateUI();
        }
      });
    }
  }
}

/// Handle Anilist authentication (V2 with UserManager)
Future<void> handleAnilistAuthV2(
    BuildContext context, int index, VoidCallback updateUI) async {
  final userManager = UserManager.instance;

  if (trackers[index].isActive ||
      userManager.isAuthenticated(AccountType.anilist)) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _anilistAuthV2.signOut();
      trackers[index].isActive = false;

      context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.anilist));
      updateUI();
    });
  } else {
    // Authenticate the user
    final success = await _anilistAuthV2.handleSignIn(context: context);
    if (success || userManager.anilist.status == AuthStatus.INPROGRESS) {
      // Wait for callback to complete (handled by main.dart)
      Future.delayed(Duration(seconds: 1), () {
        if (userManager.isAuthenticated(AccountType.anilist)) {
          trackers[index].isActive = true;
          updateUI();
        }
      });
    }
  }
}

/// Handle Simkl authentication (V2 with UserManager)
Future<void> handleSimklAuthV2(
    BuildContext context, int index, VoidCallback updateUI) async {
  final userManager = UserManager.instance;

  if (trackers[index].isActive ||
      userManager.isAuthenticated(AccountType.simkl)) {
    // Log out the user
    awesomeLogoutDialog(context, trackers[index].name, () async {
      await _simklAuthV2.signOut();
      trackers[index].isActive = false;

      context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.simkl));
      updateUI();
    });
  } else {
    // Authenticate the user
    final success = await _simklAuthV2.handleSignIn(context: context);
    if (success || userManager.simkl.status == AuthStatus.INPROGRESS) {
      // Wait for callback to complete (handled by main.dart)
      Future.delayed(Duration(seconds: 1), () {
        if (userManager.isAuthenticated(AccountType.simkl)) {
          trackers[index].isActive = true;
          updateUI();
        }
      });
    }
  }
}

/// Map of tracker names to their authentication functions
/// Using V2 handlers with UserManager architecture
final Map<String, Future<void> Function(BuildContext, int, VoidCallback)>
    trackerFunctions = {
  'MyAnimeList': handleMalAuthV2, // Using V2
  'Anilist': handleAnilistAuthV2, // Using V2
  'Kitsu': handleKitsuAuth, // Still using old (Kitsu uses password auth)
  'Simkl': handleSimklAuthV2, // Using V2
};

/// Legacy map (old handlers, kept for reference)
final Map<String, Future<void> Function(BuildContext, int, VoidCallback)>
    trackerFunctionsLegacy = {
  'MyAnimeList': handleMalAuth,
  'Anilist': handleAnilistAuth,
  'Kitsu': handleKitsuAuth,
  'Simkl': handleSimklAuth,
};
