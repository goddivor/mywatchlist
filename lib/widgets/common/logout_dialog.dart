import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Asks before signing out of [trackerName]. Resolves to true only on the "Sign out" button
/// (back, a tap outside and "Cancel" all resolve to false).
Future<bool> confirmLogout(BuildContext context,
    {required String trackerName}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => LogoutDialog(trackerName: trackerName),
  );
  return confirmed ?? false;
}

/// The sign-out confirmation: what happens, then Cancel / Sign out (the destructive action
/// is the filled, error-colored button).
class LogoutDialog extends StatelessWidget {
  final String trackerName;

  const LogoutDialog({super.key, required this.trackerName});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: Text(S.current.Acc_Sign_Out_Title(trackerName)),
      content: Text(S.current.Acc_Sign_Out_Body(trackerName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(S.current.Cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(S.current.Acc_Sign_Out),
        ),
      ],
    );
  }
}
