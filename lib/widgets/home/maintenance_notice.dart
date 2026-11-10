import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

bool _shownThisSession = false;
bool _checking = false;

/// Forgets that the dialog was shown. Tests only.
void resetMalMaintenanceNoticeForTest() {
  _shownThisSession = false;
  _checking = false;
}

/// Tells the user, once per app session, that MyAnimeList is under maintenance (its API answers
/// 503). The probe is bounded and cached by [MalApi.isUnderMaintenance]; offline or any other
/// failure is not a maintenance, so nothing is shown.
///
/// [probe] defaults to [MalApi.isUnderMaintenance] (a parameter for tests). The check is claimed
/// before the first await, so two calls racing can never open two dialogs.
Future<void> checkMalMaintenance(
  BuildContext context, {
  Future<bool> Function()? probe,
}) async {
  if (_shownThisSession || _checking) return;
  _checking = true;
  final bool underMaintenance;
  try {
    underMaintenance = await (probe ?? MalApi.isUnderMaintenance)();
  } catch (_) {
    _checking = false;
    return;
  }
  _checking = false;
  if (!underMaintenance || !context.mounted || _shownThisSession) return;
  _shownThisSession = true;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.construction_rounded),
      title: Text(S.current.Hw_Maintenance_Title),
      content: Text(S.current.Hw_Maintenance_Body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(S.current.Hw_Ok),
        ),
      ],
    ),
  );
}
