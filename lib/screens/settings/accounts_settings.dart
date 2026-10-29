import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/mal_session_settings.dart';
import 'package:mywatchlist/services/auth/simkl_auth_v2.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';

/// Settings > Accounts: every tracker in one list. Tap a connected account to make it the
/// active one (the home, your list and your profile follow it), connect or sign in again
/// with one button, sign out from the row menu.
class AccountsSettingsPage extends StatelessWidget {
  const AccountsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Settings_Accounts)),
      body: SafeArea(
        child: AccountsPanel(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Text(
                  S.current.Acc_Intro,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(S.current.Ms_Settings_Title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => AppRoutes.push<void>(context, const MalSessionSettingsPage()),
              ),
              // A V1 Simkl session can be replaced by a V2 one in a single tap.
              ListenableBuilder(
                listenable: UserSimklV2.instance,
                builder: (context, _) => UserSimklV2.instance.canUpgradeToV2
                    ? ListTile(
                        leading: const Icon(Icons.sync),
                        title: Text(S.current.Sf_Reconnect_Simkl),
                        onTap: () => SimklAuthV2().handleSignIn(context: context),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
