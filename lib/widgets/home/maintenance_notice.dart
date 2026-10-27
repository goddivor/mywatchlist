import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';

bool _shownThisSession = false;

/// Tells the user, once per app session, that MyAnimeList is under maintenance (its API answers
/// 503). The probe is bounded and cached by [MalApi.isUnderMaintenance]; offline or any other
/// failure is not a maintenance, so nothing is shown.
Future<void> checkMalMaintenance(BuildContext context) async {
  if (_shownThisSession) return;
  final underMaintenance = await MalApi.isUnderMaintenance();
  if (!underMaintenance || !context.mounted) return;
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
