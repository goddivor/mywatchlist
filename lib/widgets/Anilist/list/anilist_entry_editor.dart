import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_list_write.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_score_input.dart';
import 'package:mywatchlist/widgets/Anilist/list/anilist_status.dart';
import 'package:mywatchlist/widgets/user/edit/edit_fields.dart';
import 'package:mywatchlist/widgets/user/edit/edit_sections.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/sync/sync_labels.dart' show TrackerLogo;

/// What the AniList editor did.
sealed class AnilistEditResult {
  const AnilistEditResult();
}

/// Saved: [detail] is the entry as AniList now holds it.
class AnilistEditSaved extends AnilistEditResult {
  final AnilistListEntry detail;
  const AnilistEditSaved(this.detail);
}

/// Deleted from the list.
class AnilistEditRemoved extends AnilistEditResult {
  const AnilistEditRemoved();
}

/// The message of a failed AniList write.
String anilistWriteError(Object error) => switch (error) {
      AnilistSessionExpired() => S.current.UserList_Session_Expired,
      AnilistRateLimited() => S.current.Alf_Rate_Limited,
      _ => S.current.Sync_Save_Failed,
    };

/// Edits the user's AniList entry of [entry] with every field AniList has: status (Rewatching
/// included), score in the account's format, progress, volumes, dates, repeat count,
/// priority, notes, private, hidden from status lists, custom lists and advanced scores.
/// [detail] null = the media is not on the list yet (the editor creates it). Pops what was
/// done, or null when nothing was saved.
Future<AnilistEditResult?> showAnilistEntryEditor(
  BuildContext context, {
  required ListEntryView entry,
  required AnilistListEntry? detail,
  required AnilistListOptions options,
  AnilistListWrite? write,
  DateTime Function()? clock,
}) {
  return showModalBottomSheet<AnilistEditResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AnilistEntryEditor(
      entry: entry,
      detail: detail,
      options: options,
      write: write ?? AnilistListWrite.instance,
      clock: clock ?? DateTime.now,
    ),
  );
}

class AnilistEntryEditor extends StatefulWidget {
  final ListEntryView entry;
  final AnilistListEntry? detail;
  final AnilistListOptions options;
  final AnilistListWrite write;
  final DateTime Function() clock;

  const AnilistEntryEditor({
    super.key,
    required this.entry,
    required this.detail,
    required this.options,
    required this.write,
    required this.clock,
  });

  @override
  State<AnilistEntryEditor> createState() => AnilistEntryEditorState();
}

@visibleForTesting
class AnilistEntryEditorState extends State<AnilistEntryEditor> {
  late String _status;
  late int _scoreRaw;
  late final TextEditingController _progress;
  late final TextEditingController _volumes;
  late int _repeat;
  late int _priority;
  late bool _private;
  late bool _hidden;
  late String _notes;
  late Set<String> _customLists;

  /// Advanced score per category, raw 0-100 like the main score.
  late Map<String, int> _advanced;
  String? _start;
  String? _finish;
  bool _more = false;
  bool _saving = false;
  String? _error;

  ListEntryView get _entry => widget.entry;
  bool get _isAnime => _entry.isAnime;
  AnilistScoreFormat get _format => widget.options.scoreFormat;
  bool get _exists => widget.detail != null && widget.detail!.entryId > 0;

  @override
  void initState() {
    super.initState();
    final d = widget.detail;
    _status = d?.status ?? 'PLANNING';
    _scoreRaw = d?.scoreRaw ?? 0;
    _progress = TextEditingController(text: '${d?.progress ?? _entry.progress}');
    _volumes = TextEditingController(text: '${d?.progressVolumes ?? _entry.progressVolumes}');
    _repeat = d?.repeat ?? 0;
    _priority = d?.priority ?? 0;
    _private = d?.private ?? false;
    _hidden = d?.hiddenFromStatusLists ?? false;
    _notes = d?.notes ?? '';
    _customLists = {...?d?.customLists};
    _advanced = {
      for (final name in widget.options.advancedScoring)
        name: _format.toRaw(d?.advancedScores[name] ?? 0),
    };
    _start = d?.startedAt ?? _entry.listStartDate;
    _finish = d?.completedAt ?? _entry.listFinishDate;
  }

  @override
  void dispose() {
    _progress.dispose();
    _volumes.dispose();
    super.dispose();
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  String _today() {
    final d = widget.clock();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  void _setStatus(String status) {
    setState(() {
      _status = status;
      // As AniList's own editor: completing fills the progress and the finish date,
      // starting fills the start date.
      if (status == 'COMPLETED') {
        if (_entry.total > 0) _progress.text = '${_entry.total}';
        if (!_isAnime && _entry.totalVolumes > 0) _volumes.text = '${_entry.totalVolumes}';
        if (_finish == null || _finish!.isEmpty) _finish = _today();
      } else if ((status == 'CURRENT' || status == 'REPEATING') &&
          (_start == null || _start!.isEmpty)) {
        _start = _today();
      }
    });
  }

  void _setProgress(TextEditingController c, int value, int total) {
    var v = value < 0 ? 0 : value;
    if (total > 0 && v > total) v = total;
    setState(() => c.text = '$v');
    if (!identical(c, _progress)) return;
    if (total > 0 && v == total && _status != 'COMPLETED') {
      _setStatus('COMPLETED');
    } else if (v > 0 && _status == 'PLANNING') {
      _setStatus('CURRENT');
    }
  }

  /// Every field of the editor as one `SaveMediaListEntry`.
  @visibleForTesting
  AnilistEntryInput input() => AnilistEntryInput(
        mediaId: _entry.id,
        status: _status,
        scoreRaw: _scoreRaw,
        progress: _int(_progress),
        progressVolumes: _isAnime ? null : _int(_volumes),
        repeat: _repeat,
        priority: _priority,
        private: _private,
        notes: _notes,
        hiddenFromStatusLists: _hidden,
        customLists: widget.options.customLists.isEmpty && _customLists.isEmpty
            ? null
            : [for (final n in widget.options.customLists) if (_customLists.contains(n)) n],
        advancedScores: widget.options.showsAdvanced
            ? [
                for (final n in widget.options.advancedScoring)
                  _format.fromRaw(_advanced[n] ?? 0),
              ]
            : null,
        startedAt: _start ?? '',
        completedAt: _finish ?? '',
      );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.write.save(input());
      final base = widget.detail ??
          AnilistListEntry(entryId: 0, mediaId: _entry.id, category: _entry.category);
      if (!mounted) return;
      Navigator.of(context).pop(AnilistEditSaved(base.merge(saved)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = anilistWriteError(e);
      });
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.current.Sync_Remove_Title),
        content: Text(S.current.Sync_Remove_Message('AniList')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.current.Sync_Cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(S.current.Sync_Remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.write.delete(widget.detail!.entryId);
      if (!mounted) return;
      Navigator.of(context).pop(const AnilistEditRemoved());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is AnilistSessionExpired || e is AnilistRateLimited
            ? anilistWriteError(e)
            : S.current.Sync_Remove_Failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final total = _entry.total;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const TrackerLogo(AccountType.anilist, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _card(theme, [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldCaption(S.current.Sync_Field_Status),
                        AnilistStatusButton(
                          status: _status,
                          isAnime: _isAnime,
                          busy: _saving,
                          onChanged: _setStatus,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FieldCaption(
                          _isAnime ? S.current.Edit_Episodes_Seen : S.current.Edit_Chapters_Read,
                          action: total > 0
                              ? Text(S.current.Edit_Of_Total(total),
                                  style: theme.textTheme.bodySmall)
                              : null,
                        ),
                        ProgressStepper(
                          controller: _progress,
                          busy: _saving,
                          semanticLabel: _isAnime
                              ? S.current.Edit_Episodes_Seen
                              : S.current.Edit_Chapters_Read,
                          onSubmitted: (v) => _setProgress(_progress, v, total),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_isAnime) ...[
                const SizedBox(height: 8),
                FieldCaption(
                  S.current.Edit_Volumes_Read,
                  action: _entry.totalVolumes > 0
                      ? Text(S.current.Edit_Of_Total(_entry.totalVolumes),
                          style: theme.textTheme.bodySmall)
                      : null,
                ),
                ProgressStepper(
                  controller: _volumes,
                  busy: _saving,
                  semanticLabel: S.current.Edit_Volumes_Read,
                  onSubmitted: (v) => _setProgress(_volumes, v, _entry.totalVolumes),
                ),
              ],
              const SizedBox(height: 8),
              FieldCaption(S.current.Sync_Field_Score),
              AnilistScoreInput(
                format: _format,
                raw: _scoreRaw,
                busy: _saving,
                onChanged: (v) => setState(() => _scoreRaw = v),
              ),
            ]),
            const SizedBox(height: 8),
            _card(theme, [
              EditSection(
                title: _more ? S.current.Edit_Fewer_Options : S.current.Edit_More_Options,
                icon: Icons.tune_rounded,
                open: _more,
                onToggle: () => setState(() => _more = !_more),
                child: _moreFields(theme),
              ),
            ], padding: EdgeInsets.zero),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (_exists)
                  FilledButton.tonalIcon(
                    onPressed: _saving ? null : _remove,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.errorContainer,
                      foregroundColor: theme.colorScheme.onErrorContainer,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(S.current.Delete),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SmallSpinner() : Text(S.current.Edit_Save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(ThemeData theme, List<Widget> children, {EdgeInsets? padding}) => Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: padding ?? const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      );

  Widget _dateField(String label, String? value, ValueChanged<String?> onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DateField(
            label: label,
            date: value == null || value.isEmpty ? null : value,
            busy: _saving,
            onPicked: (d) {
              String two(int n) => n.toString().padLeft(2, '0');
              onChanged('${d.year}-${two(d.month)}-${two(d.day)}');
            },
          ),
        ),
        if (value != null && value.isNotEmpty)
          IconButton(
            tooltip: S.current.Alf_Clear_Date,
            onPressed: _saving ? null : () => onChanged(null),
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }

  Widget _moreFields(ThemeData theme) {
    final options = widget.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _dateField(S.current.Sync_Field_Start, _start,
                  (v) => setState(() => _start = v)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dateField(S.current.Sync_Field_Finish, _finish,
                  (v) => setState(() => _finish = v)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        EditRow(
          label: _isAnime ? S.current.Edit_Times_Rewatched : S.current.Edit_Times_Reread,
          control: CountStepper(
            value: _repeat,
            busy: _saving,
            onChanged: (v) => setState(() => _repeat = v),
          ),
        ),
        EditRow(
          label: S.current.Edit_Priority,
          control: CountStepper(
            value: _priority,
            busy: _saving,
            onChanged: (v) => setState(() => _priority = v.clamp(0, 5)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.lock_outline_rounded),
          title: Text(S.current.Alf_Private),
          value: _private,
          onChanged: _saving ? null : (v) => setState(() => _private = v),
        ),
        if (options.customLists.isNotEmpty) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(S.current.Alf_Hidden),
            value: _hidden,
            onChanged: _saving ? null : (v) => setState(() => _hidden = v),
          ),
          FieldCaption(S.current.Alf_Custom_Lists),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final name in options.customLists)
                FilterChip(
                  label: Text(name),
                  selected: _customLists.contains(name),
                  onSelected: _saving
                      ? null
                      : (on) => setState(() =>
                          on ? _customLists.add(name) : _customLists.remove(name)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (options.showsAdvanced) ...[
          FieldCaption(S.current.Alf_Advanced_Scores),
          for (final name in options.advancedScoring)
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: AnilistScoreSlider(
                    format: _format,
                    raw: _advanced[name] ?? 0,
                    busy: _saving,
                    onChanged: (v) => setState(() => _advanced[name] = v),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
        ],
        TextPreviewTile(
          label: S.current.Alf_Notes,
          text: _notes,
          emptyText: S.current.Alf_Notes_Empty,
          icon: Icons.notes_rounded,
          busy: _saving,
          onTap: () async {
            final text = await showTextEditor(context, title: S.current.Alf_Notes, initial: _notes);
            if (text != null && mounted) setState(() => _notes = text);
          },
        ),
      ],
    );
  }
}
