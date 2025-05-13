// import 'package:flutter/material.dart';

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/auth/anilist_auth.dart';
import 'package:mywatchlist/services/auth/kitsu_auth.dart';
import 'package:mywatchlist/services/auth/mal_auth.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_login_dialog.dart';
import 'package:mywatchlist/widgets/common/logout_dialog.dart';

// final List<Tracker> trackers = [
//   Tracker(name: 'MyAnimeList', imageUrl: 'assets/images/mal-icon.png'),
//   Tracker(name: 'Anilist', imageUrl: 'assets/images/anilist-icon.png'),
//   Tracker(name: 'Kitsu', imageUrl: 'assets/images/kitsu-icon.png'),
//   Tracker(name: 'Simkl', imageUrl: 'assets/images/simkl-icon.png'),
// ];

// final MalAuth _malAuth = MalAuth();
// final SimklAuth _simklAuth = SimklAuth();
// final AnilistAuth _anilistAuth = AnilistAuth();
// final KitsuAuth _kitsuAuth = KitsuAuth();

// Future<void> handleMalAuth(
//     BuildContext context, int index, VoidCallback updateUI) async {
//   if (trackers[index].isActive ||
//       UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//     // Déconnecter l'utilisateur
//     awesomeLogoutDialog(context, trackers[index].name, () async {
//       await _malAuth.signOut();
//       trackers[index].isActive = false;

//       context
//           .read<AccountBloc>()
//           .add(RemoveAccountEvent(AccountType.myanimelist));
//       updateUI();
//     });
//     // showDialog(
//     //   context: context,
//     //   builder: (BuildContext context) {
//     //     return LogoutDialog(
//     //       trackerName: trackers[index].name,
//     //       onConfirm: () async {
//     //         await _malAuth.signOut();
//     //         trackers[index].isActive = false;

//     //         context
//     //             .read<AccountBloc>()
//     //             .add(RemoveAccountEvent(AccountType.myanimelist));
//     //         updateUI();
//     //       },
//     //     );
//     //   },
//     // );
//   } else {
//     // Authentifier l'utilisateur
//     await _malAuth.signInWithMAL(context, onComplete: () {
//       if (UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//         trackers[index].isActive = true;

//         // Force la mise à jour des comptes disponibles dans le bloc
//         updateUI();
//         // context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
//       }
//     });
//   }
// }

// Future<void> handleSimklAuth(
//     BuildContext context, int index, VoidCallback updateUI) async {
//   if (trackers[index].isActive ||
//       UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//     // Déconnecter l'utilisateur
//     awesomeLogoutDialog(context, trackers[index].name, () async {
//       await _simklAuth.signOut();
//       trackers[index].isActive = false;

//       context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.simkl));
//       updateUI();
//     });
//     // showDialog(
//     //     context: context,
//     //     builder: (BuildContext context) {
//     //       return LogoutDialog(
//     //         trackerName: trackers[index].name,
//     //         onConfirm: () async {
//     //           await _simklAuth.signOut();
//     //           trackers[index].isActive = false;
//     //           context
//     //               .read<AccountBloc>()
//     //               .add(RemoveAccountEvent(AccountType.simkl));
//     //           updateUI();
//     //         },
//     //       );
//     //     });
//   } else {
//     // Authentifier l'utilisateur
//     // Code d'authentification pour Simkl
//     await _simklAuth.signInWithSimkl(context, onComplete: () {
//       if (UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//         trackers[index].isActive = true;

//         // Force la mise à jour des comptes disponibles dans le bloc
//         updateUI();
//         // context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
//       }
//     });
//   }
// }

// Future<void> handleAnilistAuth(
//     BuildContext context, int index, VoidCallback updateUI) async {
//   if (trackers[index].isActive ||
//       UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//     // Déconnecter l'utilisateur
//     awesomeLogoutDialog(context, trackers[index].name, () async {
//       await _anilistAuth.signOut();
//       trackers[index].isActive = false;

//       context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.anilist));
//       updateUI();
//     });
//     // showDialog(
//     //     context: context,
//     //     builder: (BuildContext context) {
//     //       return LogoutDialog(
//     //         trackerName: trackers[index].name,
//     //         onConfirm: () async {
//     //           await _anilistAuth.signOut();
//     //           trackers[index].isActive = false;
//     //           context
//     //               .read<AccountBloc>()
//     //               .add(RemoveAccountEvent(AccountType.anilist));
//     //           updateUI();
//     //         },
//     //       );
//     //     });
//   } else {
//     // Authentifier l'utilisateur
//     await _anilistAuth.signInWithAnilist(context, onComplete: () {
//       if (UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//         trackers[index].isActive = true;

//         // Force la mise à jour des comptes disponibles dans le bloc
//         updateUI();
//         // context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
//       }
//     });
//   }
// }

// Future<void> handleKitsuAuth(
//     BuildContext context, int index, VoidCallback updateUI) async {
//   if (trackers[index].isActive ||
//       UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//     // Déconnecter l'utilisateur
//     awesomeLogoutDialog(context, trackers[index].name, () async {
//       await _kitsuAuth.signout();
//       trackers[index].isActive = false;

//       context.read<AccountBloc>().add(RemoveAccountEvent(AccountType.kitsu));
//       updateUI();
//     });
//     // showDialog(
//     //     context: context,
//     //     builder: (BuildContext context) {
//     //       return LogoutDialog(
//     //         trackerName: trackers[index].name,
//     //         onConfirm: () async {
//     //           await _kitsuAuth.signout();
//     //           trackers[index].isActive = false;
//     //           context
//     //               .read<AccountBloc>()
//     //               .add(RemoveAccountEvent(AccountType.kitsu));
//     //           updateUI();
//     //         },
//     //       );
//     //     });
//   } else {
//     // Authentifier l'utilisateur
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return KitsuLoginDialog(
//           onLogin: (username, password) async {
//             await _kitsuAuth.signInWithKitsu(context, username, password,
//                 onComplete: () {
//               if (UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
//                 trackers[index].isActive = true;

//                 // Force la mise à jour des comptes disponibles dans le bloc
//                 updateUI();
//                 // context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
//               }
//             });
//           },
//         );
//       },
//     );
//   }
// }

// final Map<String, Future<void> Function(BuildContext, int, VoidCallback)>
//     trackerFunctions = {
//   'MyAnimeList': handleMalAuth,
//   'Anilist': handleAnilistAuth,
//   'Kitsu': handleKitsuAuth,
//   'Simkl': handleSimklAuth,
// };

// import 'package:flutter/material.dart';
// import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/services/auth/anilist_auth.dart';
// import 'package:mywatchlist/services/auth/kitsu_auth.dart';
// import 'package:mywatchlist/services/auth/mal_auth.dart';
// import 'package:mywatchlist/services/auth/simkl_auth.dart';
// import 'package:mywatchlist/user/accounts/account_bloc.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
// import 'package:mywatchlist/user/user.dart';
// import 'package:mywatchlist/widgets/kitsu_login_dialog.dart';
// import 'package:mywatchlist/widgets/logout_dialog.dart';

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

final MalAuth _malAuth = MalAuth();
final SimklAuth _simklAuth = SimklAuth();
final AnilistAuth _anilistAuth = AnilistAuth();
final KitsuAuth _kitsuAuth = KitsuAuth();

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
      UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
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
              if (UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
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

/// Map of tracker names to their authentication functions
final Map<String, Future<void> Function(BuildContext, int, VoidCallback)>
    trackerFunctions = {
  'MyAnimeList': handleMalAuth,
  'Anilist': handleAnilistAuth,
  'Kitsu': handleKitsuAuth,
  'Simkl': handleSimklAuth,
};
