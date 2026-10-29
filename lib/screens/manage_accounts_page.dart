import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';

/// Settings > Accounts, opened by `AppRoutes.openManageAccounts`: every tracker in one list,
/// like DailyAL's account screen (no explanatory text above it). Tap a connected account to
/// make it active; the row menu signs out, and the MyAnimeList row also opens the website
/// session page.
class ManageAccountsPage extends StatelessWidget {
  const ManageAccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Settings_Accounts)),
      body: SafeArea(
        child: AccountsPanel(
          malSessionEntry: true,
          // A V1 Simkl session can be replaced by a V2 one in a single tap.
          header: ListenableBuilder(
            listenable: UserSimklV2.instance,
            builder: (context, _) => UserSimklV2.instance.canUpgradeToV2
                ? ListTile(
                    leading: const Icon(Icons.sync),
                    title: Text(S.current.Sf_Reconnect_Simkl),
                    onTap: () => SimklAuthV2().handleSignIn(context: context),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
