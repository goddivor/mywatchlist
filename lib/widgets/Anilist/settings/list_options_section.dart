import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';
import 'package:mywatchlist/widgets/Anilist/settings/settings_tiles.dart';

/// Asks for one line of text; null when cancelled or empty.
Future<String?> askName(BuildContext context, String title, String label) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(dialog, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog), child: Text(S.current.Cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, controller.text.trim()),
          child: Text(S.current.Save),
        ),
      ],
    ),
  ).whenComplete(controller.dispose).then((v) => (v == null || v.isEmpty) ? null : v);
}

/// The settings of one list kind: advanced scoring with its categories, split of the
/// completed section, and the custom lists (add, delete).
class ListOptionsSection extends StatelessWidget {
  final String title;
  final AnilistListTypeOptions options;

  /// Sends a `MediaListOptionsInput` patch.
  final ValueChanged<Map<String, Object?>> onPatch;
  final ValueChanged<String> onAddList;
  final ValueChanged<String> onDeleteList;

  const ListOptionsSection({
    super.key,
    required this.title,
    required this.options,
    required this.onPatch,
    required this.onAddList,
    required this.onDeleteList,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SettingsGroup(
      title: title,
      children: [
        SwitchRow(
          title: S.current.Als_Advanced_Scoring,
          value: options.advancedScoringEnabled,
          onChanged: (v) => onPatch({'advancedScoringEnabled': v}),
        ),
        if (options.advancedScoringEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final c in options.advancedScoring)
                  InputChip(
                    label: Text(c),
                    onDeleted: () =>
                        onPatch({'advancedScoring': [...options.advancedScoring]..remove(c)}),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: Text(S.current.Als_Add_Category),
                  onPressed: () async {
                    final name =
                        await askName(context, S.current.Als_Add_Category, S.current.Als_Category_Name);
                    if (name != null && !options.advancedScoring.contains(name)) {
                      onPatch({'advancedScoring': [...options.advancedScoring, name]});
                    }
                  },
                ),
              ],
            ),
          ),
        SwitchRow(
          title: S.current.Als_Split_Completed,
          value: options.splitCompletedSectionByFormat,
          onChanged: (v) => onPatch({'splitCompletedSectionByFormat': v}),
        ),
        ListTile(
          title: Text(S.current.Als_Custom_Lists),
          trailing: IconButton(
            tooltip: S.current.Als_Add_List,
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final name = await askName(context, S.current.Als_Add_List, S.current.Als_List_Name);
              if (name != null) onAddList(name);
            },
          ),
        ),
        for (final name in options.customLists)
          ListTile(
            dense: true,
            leading: Icon(Icons.list_rounded, color: cs.onSurfaceVariant),
            title: Text(name),
            trailing: IconButton(
              tooltip: S.current.Delete,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: Text(S.current.Als_Delete_List_Title(name)),
                    content: Text(S.current.Als_Delete_List_Body),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: Text(S.current.Cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: Text(S.current.Delete),
                      ),
                    ],
                  ),
                );
                if (ok == true) onDeleteList(name);
              },
            ),
          ),
      ],
    );
  }
}
