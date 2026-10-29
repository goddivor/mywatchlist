import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';
import 'package:mywatchlist/widgets/Anilist/settings/settings_labels.dart';

/// One switch per AniList notification type. [onChanged] saves a type; the sheet keeps its
/// own copy so the switches answer at once.
Future<void> showNotificationTypesSheet(
  BuildContext context, {
  required Map<String, bool> enabled,
  required void Function(String type, bool value) onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final local = Map<String, bool>.of(enabled);
      return StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    S.current.Als_Notif_Types,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    itemCount: anilistNotificationTypes.length,
                    itemBuilder: (_, i) {
                      final type = anilistNotificationTypes[i];
                      return SwitchListTile(
                        title: Text(AnilistSettingsLabels.notification(type)),
                        value: local[type] ?? true,
                        onChanged: (v) {
                          setState(() => local[type] = v);
                          onChanged(type, v);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
