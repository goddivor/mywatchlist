import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/settings/prefs/pref_widgets.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:uuid/uuid.dart';

/// Saved card layouts of the user list (`ListPreferences.cardProfiles`): create from the
/// default layout, rename, duplicate and delete. Arranging the fields of a layout belongs to
/// the list screen's card editor.
class CardProfilesSection extends StatelessWidget {
  const CardProfilesSection({super.key});

  static const Uuid _uuid = Uuid();

  void _update(BuildContext context, List<ContentCardProps> Function(List<ContentCardProps>) edit) {
    context.read<PreferencesBloc>().add(ListPreferencesChanged(
        (p) => p.copyWith(cardProfiles: edit(List.of(p.cardProfiles)))));
  }

  Future<void> _add(BuildContext context, List<ContentCardProps> profiles) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: S.current.Prefs_Cards_Default_Name(profiles.length + 1)),
    );
    if (name == null || !context.mounted) return;
    final profile = ContentCardProps.defaultObject().copyWith(id: _uuid.v4(), profileName: name);
    _update(context, (list) => [...list, profile]);
  }

  Future<void> _rename(BuildContext context, ContentCardProps profile) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: profile.profileName),
    );
    if (name == null || !context.mounted) return;
    _update(context, (list) => [
          for (final item in list)
            if (item.id == profile.id) item.copyWith(profileName: name) else item,
        ]);
  }

  void _duplicate(BuildContext context, ContentCardProps profile) {
    final copy = profile.copyWith(
      id: _uuid.v4(),
      profileName: S.current.Prefs_Cards_Copy_Suffix(profile.profileName),
    );
    _update(context, (list) {
      final at = list.indexWhere((item) => item.id == profile.id);
      return list..insert(at == -1 ? list.length : at + 1, copy);
    });
  }

  Future<void> _delete(BuildContext context, ContentCardProps profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(S.current.Prefs_Cards_Delete_Title(profile.profileName)),
        content: Text(S.current.Prefs_Cards_Delete_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Prefs_Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Prefs_Cards_Delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    _update(context, (list) => list..removeWhere((item) => item.id == profile.id));
  }

  @override
  Widget build(BuildContext context) {
    final profiles = context.select((PreferencesBloc b) => b.state.list.cardProfiles);
    final theme = Theme.of(context);
    return PrefGroup(
      title: S.current.Prefs_Sec_Cards,
      description: S.current.Prefs_Cards_Desc,
      children: [
        if (profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Row(
              children: [
                Icon(Icons.view_agenda_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    S.current.Prefs_Cards_Empty,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        for (final profile in profiles)
          _ProfileTile(
            key: ValueKey(profile.id),
            profile: profile,
            onRename: () => _rename(context, profile),
            onDuplicate: () => _duplicate(context, profile),
            onDelete: () => _delete(context, profile),
          ),
        ListTile(
          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 2, 12, 2),
          leading: const PrefIcon(Icons.add),
          title: Text(S.current.Prefs_Cards_New),
          onTap: () => _add(context, profiles),
        ),
      ],
    );
  }
}

enum _ProfileAction { rename, duplicate, delete }

class _ProfileTile extends StatelessWidget {
  final ContentCardProps profile;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _ProfileTile({
    super.key,
    required this.profile,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final shown = profile.fields.where((f) => !f.hidden).length;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 2, 4, 2),
      leading: const PrefIcon(Icons.view_agenda_outlined),
      title: Text(profile.profileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(S.current.Prefs_Cards_Summary(shown, profile.height.round())),
      trailing: PopupMenuButton<_ProfileAction>(
        tooltip: S.current.Prefs_Cards_Actions,
        onSelected: (action) => switch (action) {
          _ProfileAction.rename => onRename(),
          _ProfileAction.duplicate => onDuplicate(),
          _ProfileAction.delete => onDelete(),
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: _ProfileAction.rename, child: Text(S.current.Prefs_Cards_Rename)),
          PopupMenuItem(
              value: _ProfileAction.duplicate, child: Text(S.current.Prefs_Cards_Duplicate)),
          PopupMenuItem(value: _ProfileAction.delete, child: Text(S.current.Prefs_Cards_Delete)),
        ],
      ),
    );
  }
}

/// Asks for a layout name; pops the trimmed text, or null on cancel.
class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(S.current.Prefs_Cards_Name),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.current.Prefs_Cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(S.current.Prefs_Cards_Save),
        ),
      ],
    );
  }
}
