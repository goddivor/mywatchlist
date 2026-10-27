import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/tracker_actions.dart';
import 'package:mywatchlist/user/trackers/widgets/tracker_tile.dart';
import 'package:mywatchlist/user/user_manager.dart';

/// The account list every account screen shares: the signed-in accounts (tap one to make
/// it active, menu to sign out, "Sign in again" when its session died), then the trackers
/// that can still be connected.
///
/// It listens to [UserManager] (sign in / out / dead session) and rebuilds only itself.
class AccountsPanel extends StatelessWidget {
  /// Shown above the list (title, intro text…).
  final Widget? header;

  /// Called right after a connected account was made active (the switcher closes itself).
  final ValueChanged<AccountType>? onSwitched;

  /// Padding of the list (a screen with its own bottom controls enlarges the bottom).
  final EdgeInsetsGeometry padding;

  /// Show a snackbar naming the account that became active.
  final bool confirmSwitch;

  const AccountsPanel({
    super.key,
    this.header,
    this.onSwitched,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.confirmSwitch = true,
  });

  void _switch(BuildContext context, AccountType tracker) {
    TrackerActions.switchTo(context, tracker);
    if (confirmSwitch) {
      final name = TrackerInfo.of(tracker)?.name ?? '';
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: Text(S.current.Acc_Switched_To(name)),
        ));
    }
    onSwitched?.call(tracker);
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select<AccountBloc, AccountType>((bloc) {
      final state = bloc.state;
      return state is AccountLoaded ? state.selectedAccountType : AccountType.none;
    });
    return ListenableBuilder(
      listenable: UserManager.instance,
      builder: (context, _) {
        final users = UserManager.instance;
        final statuses = {for (final t in kTrackers) t: trackerStatus(t, users)};
        final withAccount = [
          for (final t in kTrackers)
            if (statuses[t] == TrackerStatus.connected ||
                statuses[t] == TrackerStatus.needsSignIn)
              t,
        ];
        final others = [
          for (final t in kTrackers)
            if (!withAccount.contains(t)) t,
        ];

        Widget tile(AccountType tracker) {
          final info = TrackerInfo.of(tracker)!;
          final status = statuses[tracker]!;
          final user = users.getUserByTracker(tracker);
          final hasAccount = status == TrackerStatus.connected ||
              status == TrackerStatus.needsSignIn;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TrackerTile(
              key: ValueKey(tracker),
              info: info,
              status: status,
              username: user?.username,
              imageUrl: user?.profileImage,
              isActive: tracker == selected,
              onSelect: () => _switch(context, tracker),
              onConnect: () => TrackerActions.connect(context, tracker),
              onCancel: () => TrackerActions.cancelConnecting(tracker),
              onSignOut: hasAccount
                  ? () => TrackerActions.signOut(context, tracker)
                  : null,
            ),
          );
        }

        final theme = Theme.of(context);
        Widget label(String text) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Semantics(
                header: true,
                child: Text(
                  text,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );

        return ListView(
          padding: padding,
          children: [
            if (header != null) header!,
            if (withAccount.isNotEmpty) ...[
              label(S.current.Acc_Your_Accounts),
              for (final t in withAccount) tile(t),
            ],
            if (others.isNotEmpty) ...[
              label(withAccount.isEmpty
                  ? S.current.Acc_Connect_Tracker
                  : S.current.Acc_Add_Account),
              for (final t in others) tile(t),
            ],
          ],
        );
      },
    );
  }
}
