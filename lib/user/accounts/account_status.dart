import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_manager.dart';

/// Where a tracker stands for the user.
enum TrackerStatus {
  /// No account.
  disconnected,

  /// A sign in is running (the browser is open, or Kitsu is checking the password).
  connecting,

  /// Signed in.
  connected,

  /// An account that was signed in but whose session died: it must sign in again.
  needsSignIn,
}

/// The four trackers, in display order.
const List<AccountType> kTrackers = [
  AccountType.myanimelist,
  AccountType.anilist,
  AccountType.kitsu,
  AccountType.simkl,
];

/// Status of [tracker] right now (reads the user singletons, no state kept here).
TrackerStatus trackerStatus(AccountType tracker, [UserManager? users]) {
  final user = (users ?? UserManager.instance).getUserByTracker(tracker);
  if (user == null) return TrackerStatus.disconnected;
  if (user.status == AuthStatus.AUTHENTICATED) return TrackerStatus.connected;
  if (user.status == AuthStatus.INPROGRESS) return TrackerStatus.connecting;
  if (user.needsReLogin) return TrackerStatus.needsSignIn;
  // MAL also reports a dead session from its API layer; only an account that had an
  // identity counts (a MAL-less user must not be told to sign in again).
  if (tracker == AccountType.myanimelist &&
      MalApi.sessionExpired.value &&
      (user.username?.isNotEmpty ?? false)) {
    return TrackerStatus.needsSignIn;
  }
  return TrackerStatus.disconnected;
}

/// Trackers with a live session, in display order.
List<AccountType> connectedTrackers([UserManager? users]) => [
      for (final t in kTrackers)
        if (trackerStatus(t, users) == TrackerStatus.connected) t,
    ];

/// Trackers whose session died, in display order.
List<AccountType> expiredTrackers([UserManager? users]) => [
      for (final t in kTrackers)
        if (trackerStatus(t, users) == TrackerStatus.needsSignIn) t,
    ];
