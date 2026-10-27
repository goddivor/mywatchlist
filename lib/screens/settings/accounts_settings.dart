import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';

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
          header: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Text(
              S.current.Acc_Intro,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}
