import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';

/// Opened from the avatar of the home app bar. Switching is one tap: the tapped account
/// becomes active, the page closes, the home follows. Adding, signing in again and signing
/// out are in the same list, so nothing needs a second screen.
class AccountSwitcherPage extends StatelessWidget {
  /// Called after the active account changed (the caller refreshes its own UI).
  final VoidCallback? onUiChange;

  const AccountSwitcherPage({super.key, this.onUiChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.current.Acc_Switch_Title)),
      body: SafeArea(
        child: AccountsPanel(
          onSwitched: (_) {
            onUiChange?.call();
            Navigator.of(context).maybePop();
          },
        ),
      ),
    );
  }
}
