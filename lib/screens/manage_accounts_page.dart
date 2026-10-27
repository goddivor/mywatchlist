import 'package:flutter/material.dart';
import 'package:mywatchlist/screens/settings/accounts_settings.dart';

/// Tracker manager opened by `AppRoutes.openManageAccounts` (connect, switch, sign out).
/// It is the Accounts settings page: one screen manages accounts, wherever it is opened from.
class ManageAccountsPage extends StatelessWidget {
  const ManageAccountsPage({super.key});

  @override
  Widget build(BuildContext context) => const AccountsSettingsPage();
}
