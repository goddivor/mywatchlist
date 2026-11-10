import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_entry_editor.dart' show anilistWriteError;
import 'package:mywatchlist/widgets/Anilist/list/anilist_score_input.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_status.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/edit/edit_fields.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Opens the selection page over [entries] (the rows of the current tab, as shown) and edits
/// the selected ones at once (`UpdateMediaListEntries`: status, score, priority, private,
/// hidden). Answers the rows AniList saved, null when nothing was saved.
Future<List<ListEntryView>?> openAnilistBulkEdit(
  BuildContext context, {
  required AnilistUserListAdapter adapter,
  required String category,
  required List<ListEntryView> entries,
  required String title,
}) {
  return Navigator.of(context).push<List<ListEntryView>>(MaterialPageRoute(
    builder: (_) => AnilistBulkEditPage(
      adapter: adapter,
      category: category,
      entries: entries,
      title: title,
    ),
  ));
}

class AnilistBulkEditPage extends StatefulWidget {
  final AnilistUserListAdapter adapter;
  final String category;
  final List<ListEntryView> entries;
  final String title;

  const AnilistBulkEditPage({
    super.key,
    required this.adapter,
    required this.category,
    required this.entries,
    required this.title,
  });

  @override
  State<AnilistBulkEditPage> createState() => _AnilistBulkEditPageState();
}

class _AnilistBulkEditPageState extends State<AnilistBulkEditPage> {
  final Set<int> _selected = {};
  bool _saving = false;

  bool get _isAnime => widget.category == 'anime';
  bool get _allSelected => _selected.length == widget.entries.length;

  void _toggleAll() => setState(() {
        if (_allSelected) {
          _selected.clear();
        } else {
          _selected
            ..clear()
            ..addAll(widget.entries.map((e) => e.id));
        }
      });

  Future<void> _edit() async {
    final options =
        widget.adapter.lists.optionsOf(widget.category) ?? const AnilistListOptions();
    final input = await showModalBottomSheet<AnilistBulkInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _BulkSheet(
        count: _selected.length,
        isAnime: _isAnime,
        options: options,
      ),
    );
    if (input == null || input.isEmpty || !mounted) return;
    setState(() => _saving = true);
    try {
      final saved = await applyAnilistBulkEdit(
        widget.adapter,
        category: widget.category,
        entries: [for (final e in widget.entries) if (_selected.contains(e.id)) e],
        input: input,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(anilistWriteError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.entries;
    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty
            ? widget.title
            : S.current.Fc_Selected_Count(_selected.length)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _toggleAll,
            child: Text(_allSelected ? S.current.Alf_Select_None : S.current.Select_All),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: entries.length,
        itemExtent: 72,
        itemBuilder: (context, i) {
          final e = entries[i];
          final detail = widget.adapter.lists.detailOf(widget.category, e.id);
          final on = _selected.contains(e.id);
          return CheckboxListTile(
            value: on,
            onChanged: _saving
                ? null
                : (v) => setState(() => v == true ? _selected.add(e.id) : _selected.remove(e.id)),
            secondary: SizedBox(
              width: 40,
              height: 56,
              child: AppImage(
                url: e.imageUrl,
                width: 40,
                height: 56,
                borderRadius: BorderRadius.circular(6),
                placeholderColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                anilistStatusLabel(detail?.status, isAnime: _isAnime),
                if (detail != null && detail.scoreRaw > 0)
                  (widget.adapter.lists.optionsOf(widget.category)?.scoreFormat ??
                          AnilistScoreFormat.point10)
                      .format(detail.scoreRaw),
                if (detail?.private ?? false) S.current.Alf_Private,
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _saving ? null : _edit,
            icon: _saving ? const SmallSpinner() : const Icon(Icons.edit_rounded),
            label: Text(S.current.Alf_Edit_Selected(_selected.length)),
          ),
        ),
      ),
    );
  }
}

/// Sends [input] for every entry of [entries] in one request and applies the answer to the
/// rows and the kept list; answers the saved rows.
Future<List<ListEntryView>> applyAnilistBulkEdit(
  AnilistUserListAdapter adapter, {
  required String category,
  required List<ListEntryView> entries,
  required AnilistBulkInput input,
}) async {
  final byEntryId = <int, ListEntryView>{};
  for (final e in entries) {
    final d = adapter.lists.detailOf(category, e.id);
    if (d != null && d.entryId > 0) byEntryId[d.entryId] = e;
  }
  final saved = await adapter.writer.updateMany(byEntryId.keys.toList(), input);
  final out = <ListEntryView>[];
  for (final json in saved) {
    final entryId = (json['id'] as num?)?.toInt();
    final view = byEntryId[entryId];
    if (view == null) continue;
    final detail = adapter.lists.detailOf(category, view.id);
    if (detail == null) continue;
    out.add(adapter.applyDetail(view, detail.merge(json)));
  }
  return out;
}

/// The fields of a bulk edit; each starts unchanged.
class _BulkSheet extends StatefulWidget {
  final int count;
  final bool isAnime;
  final AnilistListOptions options;

  const _BulkSheet({required this.count, required this.isAnime, required this.options});

  @override
  State<_BulkSheet> createState() => _BulkSheetState();
}

class _BulkSheetState extends State<_BulkSheet> {
  String? _status;
  int? _scoreRaw;
  int? _priority;
  bool? _private;
  bool? _hidden;

  AnilistBulkInput get _input => AnilistBulkInput(
        status: _status,
        scoreRaw: _scoreRaw,
        priority: _priority,
        private: _private,
        hiddenFromStatusLists: _hidden,
      );

  Widget _tri(String label, bool? value, ValueChanged<bool?> onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldCaption(label),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(S.current.Alf_Unchanged)),
              ButtonSegment(value: 1, label: Text(S.current.Alf_Yes)),
              ButtonSegment(value: 2, label: Text(S.current.Alf_No)),
            ],
            selected: {value == null ? 0 : (value ? 1 : 2)},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onChanged(switch (s.first) {
              1 => true,
              2 => false,
              _ => null,
            }),
          ),
          const SizedBox(height: 8),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = widget.options.scoreFormat;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(S.current.Alf_Edit_Selected(widget.count),
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          FieldCaption(
            S.current.Sync_Field_Status,
            action: _status == null
                ? null
                : TextButton(
                    onPressed: () => setState(() => _status = null),
                    child: Text(S.current.Alf_Unchanged)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in anilistStatuses)
                ChoiceChip(
                  label: Text(anilistStatusLabel(s, isAnime: widget.isAnime)),
                  selected: _status == s,
                  onSelected: (on) => setState(() => _status = on ? s : null),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.current.Alf_Change_Score),
            value: _scoreRaw != null,
            onChanged: (on) => setState(() => _scoreRaw = on ? 0 : null),
          ),
          if (_scoreRaw != null)
            AnilistScoreInput(
              format: format,
              raw: _scoreRaw!,
              onChanged: (v) => setState(() => _scoreRaw = v),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(S.current.Alf_Change_Priority),
            value: _priority != null,
            onChanged: (on) => setState(() => _priority = on ? 0 : null),
          ),
          if (_priority != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CountStepper(
                value: _priority!,
                onChanged: (v) => setState(() => _priority = v.clamp(0, 5)),
              ),
            ),
          _tri(S.current.Alf_Private, _private, (v) => setState(() => _private = v)),
          if (widget.options.customLists.isNotEmpty)
            _tri(S.current.Alf_Hidden, _hidden, (v) => setState(() => _hidden = v)),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _input.isEmpty ? null : () => Navigator.of(context).pop(_input),
            child: Text(S.current.Edit_Save),
          ),
        ],
      ),
    );
  }
}
