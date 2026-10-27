import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/settings/coming_soon_page.dart';
import 'package:mywatchlist/pages/settings/settings_section.dart';
import 'package:mywatchlist/screens/manage_accounts_page.dart';

/// Settings page for the connected trackers (connect, switch, sign out, sign in again).
///
/// Stub created by the app shell: until the accounts unit fills it, it links to the
/// existing tracker manager so the hub never loses access to account management.
class AccountsSettingsPage extends StatelessWidget {
  const AccountsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const section = SettingsSection.accounts;
    return ComingSoonPage(
      title: section.title,
      icon: section.icon,
      subtitle: section.description,
      action: FilledButton.tonalIcon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ManageAccountsPage()),
        ),
        icon: const Icon(Icons.link),
        label: Text(S.current.Settings_Accounts_Manage),
      ),
    );
  }
}
