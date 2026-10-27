import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/auth/anilist_auth_v2.dart';
import 'package:mywatchlist/services/auth/kitsu_auth.dart';
import 'package:mywatchlist/services/auth/mal_auth_v2.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_login_dialog.dart';
import 'package:mywatchlist/widgets/common/logout_dialog.dart';

/// The things a user can do to a tracker account: connect it, sign in again, give up a
/// sign in that never finished, sign out, make it the active account. Screens call these
/// and never touch the auth classes; the result reaches the UI through the user
/// singletons and `AccountBloc`.
abstract final class TrackerActions {
  /// Starts the sign in of [tracker] (also used to sign in again after a dead session).
  /// OAuth trackers open their web sign in and finish through the deep link; Kitsu opens
  /// its credentials dialog. A sign in that cannot even start shows a message.
  static Future<void> connect(BuildContext context, AccountType tracker) async {
    final user = UserManager.instance.getUserByTracker(tracker);
    final info = TrackerInfo.of(tracker);
    if (user == null || info == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);

    // A previous attempt that never came back (browser closed) must not block a new one.
    if (user.status == AuthStatus.INPROGRESS) cancelConnecting(tracker);

    if (info.usesPassword) {
      await KitsuLoginDialog.show(context, initialUsername: user.username);
      return;
    }

    final started = await _oauthSignIn(context, tracker);
    if (!started) {
      if (user.status == AuthStatus.INPROGRESS) cancelConnecting(tracker);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(S.current.Acc_Connect_Failed(info.name)),
        ));
    }
  }

  static Future<bool> _oauthSignIn(BuildContext context, AccountType tracker) {
    switch (tracker) {
      case AccountType.myanimelist:
        return MalAuthV2().handleSignIn(context: context);
      case AccountType.anilist:
        return AnilistAuthV2().handleSignIn(context: context);
      case AccountType.simkl:
        return SimklAuthV2().handleSignIn(context: context);
      case AccountType.kitsu:
      case AccountType.none:
        return Future.value(false);
    }
  }

  /// Gives up a sign in that is still waiting (the user closed the browser).
  static void cancelConnecting(AccountType tracker) {
    final user = UserManager.instance.getUserByTracker(tracker);
    if (user == null || user.status != AuthStatus.INPROGRESS) return;
    user.setStatus(AuthStatus.UNAUTHENTICATED);
    user.notifyAccountChange();
  }

  /// Confirms, then signs out of [tracker]. The next connected account becomes active (or
  /// the sign-in screen opens when none is left). True when the user signed out.
  static Future<bool> signOut(BuildContext context, AccountType tracker) async {
    final info = TrackerInfo.of(tracker);
    if (info == null) return false;
    final bloc = context.read<AccountBloc>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    if (!await confirmLogout(context, trackerName: info.name)) return false;

    switch (tracker) {
      case AccountType.myanimelist:
        await MalAuthV2().signOut();
      case AccountType.anilist:
        await AnilistAuthV2().signOut();
      case AccountType.simkl:
        await SimklAuthV2().signOut();
      case AccountType.kitsu:
        await KitsuAuth().signout();
      case AccountType.none:
        return false;
    }
    bloc.add(RemoveAccountEvent(tracker));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(S.current.Acc_Signed_Out(info.name)),
      ));
    return true;
  }

  /// Makes [tracker] the active account (one tap, no confirmation step).
  static void switchTo(BuildContext context, AccountType tracker) {
    context.read<AccountBloc>().add(ChangeAccountEvent(tracker));
  }
}
