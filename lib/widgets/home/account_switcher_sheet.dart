import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';

/// Opens the account switcher as a bottom sheet (the avatar of the home app bar, long press).
/// Switching is one tap: the tapped account becomes active, the sheet closes and [onSwitched]
/// lets the caller refresh its own UI. Adding, signing in again and signing out are in the same
/// list.
Future<void> showAccountSwitcherSheet(BuildContext context, {VoidCallback? onSwitched}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final height = math.min(MediaQuery.sizeOf(sheetContext).height * 0.72, 620.0);
      return SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  header: true,
                  child: Text(S.current.Hw_Switch_Account,
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                ),
              ),
            ),
            Expanded(
              child: AccountsPanel(
                onSwitched: (_) {
                  onSwitched?.call();
                  Navigator.of(sheetContext).maybePop();
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
