import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_connect.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/private_notes/private_notes_store.dart';
import 'package:mywatchlist/widgets/user/edit/edit_fields.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/edit_sections.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/edit/number_bar.dart';
import 'package:mywatchlist/widgets/user/edit/private_note_field.dart';

/// The field a list write is about; it shows its own spinner meanwhile.
enum EditField {
  add,
  status,
  score,
  progress,
  volumes,
  repeating,
  timesRepeated,
  repeatValue,
  startDate,
  finishDate,
  priority,
  comments,
  tags,
  delete,
}

enum _Phase { loading, ready, failed, sessionExpired, notEditable }

/// Edit sheet of the user's list entry (status, progress, score, rewatch,
/// dates, priority, comments, tags, private note) for one anime or manga.
///
/// The entry is loaded with every list field when the sheet opens, so each
/// field is pre-filled exactly as on the tracker; [contentDetailed] is not
/// needed for that and may be null.
class ContentEditWidget extends StatefulWidget {
  final int id;
  final MalAnime? contentDetailed;
  final String category;
  final ValueChanged<bool>? onUpdate;

  /// Called after each successful write with the tracker's answer
  /// (`MyAnimeListStatus` or `MyMangaListStatus` for MAL).
  final ValueChanged<dynamic>? onListStatusChange;
  final VoidCallback? onDelete;

  /// Defaults to MyAnimeList; tests inject a fake.
  final ListEntryService? service;
  final PrivateNotesStore? notesStore;
  final DateTime Function()? clock;

  const ContentEditWidget({
    super.key,
    required this.id,
    this.contentDetailed,
    required this.category,
    this.onUpdate,
    this.onListStatusChange,
    this.onDelete,
    this.service,
    this.notesStore,
    this.clock,
  });

  @override
  State<ContentEditWidget> createState() => _ContentEditWidgetState();
}

class _ContentEditWidgetState extends State<ContentEditWidget> {
  /// Episode picker mode, kept for the session (bar = DAL's default).
  static bool _episodeBar = true;

  _Phase _phase = _Phase.loading;
  EditableContent? _content;
  ListEntry? _entry;
  final Set<EditField> _busy = {};

  final TextEditingController _progressController = TextEditingController();
  final TextEditingController _volumesController = TextEditingController();

  bool _advanced = false;
  bool _repeatOpen = false;
  bool _datesOpen = true;
  bool _othersOpen = false;
  bool _noteOpen = true;

  bool get _isAnime => widget.category.toLowerCase() == 'anime';
  ListEntryService get _service =>
      widget.service ?? const MalListEntryService();
  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ContentEditWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The detail page refreshes [contentDetailed] after each write; the sheet
    // already holds the tracker's answer, so only another entry reloads.
    if (oldWidget.id != widget.id || oldWidget.category != widget.category) {
      _load();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _volumesController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    if (!_service.canEdit) {
      setState(() => _phase = _Phase.notEditable);
      return;
    }
    setState(() => _phase = _Phase.loading);
    try {
      final content = await _service.load(widget.id, isAnime: _isAnime);
      if (!mounted) return;
      setState(() {
        _content = content;
        _entry = content.entry;
        _phase = _Phase.ready;
        _syncControllers();
      });
    } on MalSessionExpired {
      if (mounted) setState(() => _phase = _Phase.sessionExpired);
    } catch (e) {
      debugPrint('ContentEditWidget: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  void _syncControllers() {
    _progressController.text = '${_entry?.progress ?? 0}';
    _volumesController.text = '${_entry?.volumes ?? 0}';
  }

  AppPreferences get _prefs =>
      context.read<PreferencesBloc?>()?.state ?? Preferences.current;

  void _notify(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } else {
      showToast(message);
    }
  }

  /// Sends [patch]; the sheet then shows the tracker's answer.
  Future<bool> _send(EditField field, EntryPatch patch) async {
    final content = _content;
    if (content == null || _busy.contains(field)) return false;
    FocusScope.of(context).unfocus();
    setState(() => _busy.add(field));
    var ok = false;
    try {
      final result = await _service.update(widget.id,
          isAnime: _isAnime, patch: patch, previous: _entry);
      ok = true;
      if (mounted) {
        setState(() {
          _entry = result.entry;
          _syncControllers();
        });
      }
      widget.onListStatusChange?.call(result.status);
    } on MalSessionExpired {
      if (mounted) {
        _notify(S.current.Edit_Session_Expired);
        setState(() => _phase = _Phase.sessionExpired);
      }
    } catch (e) {
      debugPrint('ContentEditWidget update: $e');
      if (mounted) {
        _notify(S.current.Couldnt_Update);
        setState(_syncControllers);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(field));
    }
    widget.onUpdate?.call(ok);
    return ok;
  }

  void _addToList() {
    final content = _content;
    if (content == null) return;
    final prefs = _prefs;
    _send(
      EditField.add,
      planAdd(
        content: content,
        preferredStatus: _isAnime
            ? prefs.content.defaultAnimeAddStatus
            : prefs.content.defaultMangaAddStatus,
        autoDates: prefs.general.autoAddStartEndDate,
        now: _now,
      ),
    );
  }

  void _changeStatus(String status) {
    final content = _content;
    if (content == null || status == _entry?.status) return;
    _send(
      EditField.status,
      planStatusChange(
        content: content,
        entry: _entry,
        status: status,
        autoDates: _prefs.general.autoAddStartEndDate,
        now: _now,
      ),
    );
  }

  void _changeProgress(int value) {
    final content = _content;
    final entry = _entry;
    if (content == null || entry == null) return;
    final plan = planProgressChange(
      content: content,
      entry: entry,
      progress: value,
      autoDates: _prefs.general.autoAddStartEndDate,
      now: _now,
    );
    final patch = plan.patch;
    if (patch == null) {
      _notify(_progressError(plan.error!, volumes: false));
      setState(_syncControllers);
      return;
    }
    if (value == entry.progress && patch.status == null) return;
    _send(EditField.progress, patch);
  }

  void _changeVolumes(int value) {
    final content = _content;
    final entry = _entry;
    if (content == null || entry == null) return;
    final plan = planVolumesChange(content: content, volumes: value);
    final patch = plan.patch;
    if (patch == null) {
      _notify(_progressError(plan.error!, volumes: true));
      setState(_syncControllers);
      return;
    }
    if (value == entry.volumes) return;
    _send(EditField.volumes, patch);
  }

  String _progressError(ProgressError error, {required bool volumes}) {
    if (error == ProgressError.overMaximum) return S.current.Maximum_reached;
    if (volumes) return S.current.Negative_volumes_not_allowed;
    return _isAnime
        ? S.current.Negative_episode_not_allowed
        : S.current.Negative_chapters_not_allowed;
  }

  Future<void> _editComments() async {
    final initial = decodeMalText(_entry?.comments ?? '');
    final text = await showTextEditor(context,
        title: S.current.Edit_Comments, initial: initial);
    if (text == null || text == initial) return;
    _send(EditField.comments, EntryPatch(comments: text));
  }

  Future<void> _editTags() async {
    final initial = tagsToText(_entry?.tags ?? const []);
    final text = await showTextEditor(context,
        title: S.current.Edit_Tags,
        initial: initial,
        multiline: false,
        hint: S.current.Edit_Tags_Hint);
    if (text == null || textToTags(text) == textToTags(initial)) return;
    _send(EditField.tags, EntryPatch(tags: textToTags(text)));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.current.Item_delete_confi),
        content: Text(S.current.Item_delete_desc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.current.Delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(EditField.delete));
    var ok = false;
    try {
      await _service.delete(widget.id, isAnime: _isAnime);
      ok = true;
      if (mounted) {
        setState(() {
          _entry = null;
          _advanced = false;
          _syncControllers();
        });
      }
      widget.onDelete?.call();
    } on MalSessionExpired {
      if (mounted) {
        _notify(S.current.Edit_Session_Expired);
        setState(() => _phase = _Phase.sessionExpired);
      }
    } catch (e) {
      debugPrint('ContentEditWidget delete: $e');
      if (mounted) _notify(S.current.Couldnt_Delete);
    } finally {
      if (mounted) setState(() => _busy.remove(EditField.delete));
    }
    widget.onUpdate?.call(ok);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 6,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: editEaseOut,
          alignment: Alignment.bottomCenter,
          child: _body(),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.loading:
        return const SizedBox(
          key: ValueKey('edit-loading'),
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        );
      case _Phase.notEditable:
        return EditMessageView(
          key: const ValueKey('edit-not-editable'),
          icon: Icons.switch_account_outlined,
          message: S.current.Edit_Mal_Only,
        );
      case _Phase.sessionExpired:
        return EditMessageView(
          key: const ValueKey('edit-session-expired'),
          icon: Icons.lock_clock_outlined,
          message: S.current.Edit_Session_Expired,
          onRetry: _load,
        );
      case _Phase.failed:
        return EditMessageView(
          key: const ValueKey('edit-failed'),
          icon: Icons.cloud_off_outlined,
          message: S.current.Edit_Load_Failed,
          onRetry: _load,
        );
      case _Phase.ready:
        final entry = _entry;
        if (entry == null) return _addButton();
        return _editor(_content!, entry);
    }
  }

  Widget _addButton() {
    final busy = _busy.contains(EditField.add);
    return Padding(
      key: const ValueKey('edit-add'),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: busy ? null : _addToList,
          icon: busy
              ? SmallSpinner(color: Theme.of(context).colorScheme.primary)
              : const Icon(Icons.playlist_add),
          label: Text(S.current.Add_to_List,
              style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }

  Widget _editor(EditableContent content, ListEntry entry) {
    return Column(
      key: const ValueKey('edit-form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _isAnime
              ? _animeProgress(content, entry)
              : _mangaProgress(content, entry),
        ),
        const SizedBox(height: 8),
        _scoreBar(entry),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: editEaseOut,
          alignment: Alignment.topCenter,
          child: _advanced
              ? _advancedEditor(entry)
              : const SizedBox(width: double.infinity),
        ),
        _bottomBar(),
      ],
    );
  }

  void _toggleAdvanced([bool? open]) =>
      setState(() => _advanced = open ?? !_advanced);

  Widget _handle() {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: _advanced ? S.current.Edit_Fewer_Options : S.current.Edit_More_Options,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleAdvanced,
        onVerticalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -100) _toggleAdvanced(true);
          if (v > 100) _toggleAdvanced(false);
        },
        child: SizedBox(
          height: 24,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _progressHint(EditableContent content) {
    final total = content.progressTotal;
    if (total > 0) return S.current.Edit_Of_Total(total);
    final aired = estimateAiredEpisodes(content, _now);
    if (aired != null) return S.current.Edit_Aired_Estimate(aired);
    return null;
  }

  Widget _statusButton(ListEntry entry) => StatusButton(
        status: entry.status,
        isAnime: _isAnime,
        busy: _busy.contains(EditField.status),
        onChanged: _changeStatus,
      );

  Widget _animeProgress(EditableContent content, ListEntry entry) {
    final pickerCount = episodePickerCount(content, entry.progress, _now);
    final canUseBar = pickerCount != null;
    final useBar = canUseBar && _episodeBar;
    final toggle = canUseBar
        ? IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: useBar
                ? S.current.Edit_Type_Number
                : S.current.Edit_Pick_From_List,
            onPressed: () => setState(() => _episodeBar = !_episodeBar),
            icon: Icon(useBar ? Icons.dialpad : Icons.view_week_outlined,
                size: 20),
          )
        : null;
    final caption = FieldCaption(S.current.Edit_Episodes_Seen,
        hint: _progressHint(content), action: toggle);
    if (useBar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldCaption(S.current.Status),
          _statusButton(entry),
          const SizedBox(height: 8),
          caption,
          NumberBar(
            key: const ValueKey('edit-episode-bar'),
            first: 1,
            count: pickerCount,
            selected: entry.progress == 0 ? null : entry.progress,
            busy: _busy.contains(EditField.progress),
            onSelected: _changeProgress,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [FieldCaption(S.current.Status), _statusButton(entry)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              caption,
              ProgressStepper(
                key: const ValueKey('edit-progress'),
                controller: _progressController,
                semanticLabel: S.current.Edit_Episodes_Seen,
                busy: _busy.contains(EditField.progress),
                onSubmitted: _changeProgress,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mangaProgress(EditableContent content, ListEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldCaption(S.current.Status),
        _statusButton(entry),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldCaption(S.current.Edit_Chapters_Read,
                      hint: _progressHint(content)),
                  ProgressStepper(
                    key: const ValueKey('edit-progress'),
                    controller: _progressController,
                    semanticLabel: S.current.Edit_Chapters_Read,
                    busy: _busy.contains(EditField.progress),
                    onSubmitted: _changeProgress,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FieldCaption(S.current.Edit_Volumes_Read,
                      hint: content.numVolumes > 0
                          ? S.current.Edit_Of_Total(content.numVolumes)
                          : null),
                  ProgressStepper(
                    key: const ValueKey('edit-volumes'),
                    controller: _volumesController,
                    semanticLabel: S.current.Edit_Volumes_Read,
                    busy: _busy.contains(EditField.volumes),
                    onSubmitted: _changeVolumes,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreBar(ListEntry entry) {
    final score = entry.score;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FieldCaption(
            S.current.Score,
            hint: score > 0 ? '$score · ${scoreLabel(score)}' : scoreLabel(0),
          ),
        ),
        NumberBar(
          key: const ValueKey('edit-score-bar'),
          first: 0,
          count: 11,
          selected: score,
          busy: _busy.contains(EditField.score),
          semanticLabel: (v) => v == 0 ? scoreLabel(0) : '$v, ${scoreLabel(v)}',
          labelBuilder: (context, v) =>
              v == 0 ? const Icon(Icons.block) : Text('$v'),
          onSelected: (v) {
            if (v != entry.score) _send(EditField.score, EntryPatch(score: v));
          },
        ),
      ],
    );
  }

  Widget _advancedEditor(ListEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          EditSection(
            title: _isAnime
                ? S.current.Edit_Rewatch_Section
                : S.current.Edit_Reread_Section,
            icon: Icons.replay,
            open: _repeatOpen,
            onToggle: () => setState(() => _repeatOpen = !_repeatOpen),
            child: _repeatEditor(entry),
          ),
          EditSection(
            title: S.current.Dates_Priority,
            icon: Icons.event_note_outlined,
            open: _datesOpen,
            onToggle: () => setState(() => _datesOpen = !_datesOpen),
            child: _datesEditor(entry),
          ),
          EditSection(
            title: S.current.Others,
            icon: Icons.notes,
            open: _othersOpen,
            onToggle: () => setState(() => _othersOpen = !_othersOpen),
            child: _othersEditor(entry),
          ),
          _PrivateNoteSection(
            id: widget.id,
            category: _isAnime ? 'anime' : 'manga',
            store: widget.notesStore,
            open: _noteOpen,
            onToggle: () => setState(() => _noteOpen = !_noteOpen),
          ),
        ],
      ),
    );
  }

  Widget _repeatEditor(ListEntry entry) {
    final busyFlag = _busy.contains(EditField.repeating);
    final busyTimes = _busy.contains(EditField.timesRepeated);
    final busyValue = _busy.contains(EditField.repeatValue);
    return Column(
      children: [
        EditRow(
          label: _isAnime ? S.current.Edit_Rewatching : S.current.Edit_Rereading,
          control: busyFlag
              ? const Padding(
                  padding: EdgeInsets.all(12), child: SmallSpinner())
              : Switch(
                  value: entry.isRepeating,
                  onChanged: (v) => _send(
                      EditField.repeating, EntryPatch(isRepeating: v)),
                ),
        ),
        EditRow(
          label: _isAnime
              ? S.current.Edit_Times_Rewatched
              : S.current.Edit_Times_Reread,
          control: CountStepper(
            value: entry.timesRepeated,
            busy: busyTimes,
            onChanged: (v) =>
                _send(EditField.timesRepeated, EntryPatch(timesRepeated: v)),
          ),
        ),
        EditRow(
          label: _isAnime
              ? S.current.Edit_Rewatch_Value
              : S.current.Edit_Reread_Value,
          control: busyValue
              ? const Padding(
                  padding: EdgeInsets.all(12), child: SmallSpinner())
              : DropdownButton<int>(
                  value: entry.repeatValue.clamp(0, 5),
                  underline: const SizedBox.shrink(),
                  borderRadius: BorderRadius.circular(14),
                  items: [
                    for (var i = 0; i <= 5; i++)
                      DropdownMenuItem(
                          value: i, child: Text(repeatValueLabel(i))),
                  ],
                  onChanged: (v) {
                    if (v != null && v != entry.repeatValue) {
                      _send(EditField.repeatValue, EntryPatch(repeatValue: v));
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _datesEditor(ListEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DateField(
                key: const ValueKey('edit-start-date'),
                label: S.current.Start_Date,
                date: entry.startDate,
                busy: _busy.contains(EditField.startDate),
                onPicked: (d) => _send(EditField.startDate,
                    EntryPatch(startDate: formatApiDate(d))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DateField(
                key: const ValueKey('edit-finish-date'),
                label: S.current.Finish_Date,
                date: entry.finishDate,
                busy: _busy.contains(EditField.finishDate),
                onPicked: (d) => _send(EditField.finishDate,
                    EntryPatch(finishDate: formatApiDate(d))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FieldCaption(S.current.Edit_Priority),
        _busy.contains(EditField.priority)
            ? const SizedBox(height: 40, child: Center(child: SmallSpinner()))
            : SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (var i = 0; i <= 2; i++)
                    ButtonSegment(value: i, label: Text(priorityLabel(i))),
                ],
                selected: {entry.priority.clamp(0, 2)},
                onSelectionChanged: (s) {
                  final v = s.first;
                  if (v != entry.priority) {
                    _send(EditField.priority, EntryPatch(priority: v));
                  }
                },
              ),
      ],
    );
  }

  Widget _othersEditor(ListEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextPreviewTile(
          key: const ValueKey('edit-comments'),
          label: S.current.Edit_Comments,
          text: decodeMalText(entry.comments),
          emptyText: S.current.Edit_Comments_Empty,
          icon: Icons.chat_bubble_outline,
          busy: _busy.contains(EditField.comments),
          onTap: _editComments,
        ),
        const SizedBox(height: 8),
        TextPreviewTile(
          key: const ValueKey('edit-tags'),
          label: S.current.Edit_Tags,
          text: tagsToText(entry.tags),
          emptyText: S.current.Edit_Tags_Empty,
          icon: Icons.sell_outlined,
          busy: _busy.contains(EditField.tags),
          onTap: _editTags,
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final scheme = Theme.of(context).colorScheme;
    final deleting = _busy.contains(EditField.delete);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: deleting ? null : _delete,
            icon: deleting
                ? SmallSpinner(color: scheme.error)
                : const Icon(Icons.delete_outline),
            label: Text(S.current.Delete_from_List),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _toggleAdvanced,
            icon: AnimatedRotation(
              turns: _advanced ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              curve: editEaseOut,
              child: const Icon(Icons.expand_less),
            ),
            label: Text(_advanced
                ? S.current.Edit_Fewer_Options
                : S.current.Edit_More_Options),
          ),
        ],
      ),
    );
  }
}

/// The private note section, built only when `showPrivateNotes` is on; it
/// watches that one preference so nothing else rebuilds when it changes.
class _PrivateNoteSection extends StatelessWidget {
  final int id;
  final String category;
  final PrivateNotesStore? store;
  final bool open;
  final VoidCallback onToggle;

  const _PrivateNoteSection({
    required this.id,
    required this.category,
    required this.store,
    required this.open,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (!watchShowPrivateNotes(context)) return const SizedBox.shrink();
    return EditSection(
      title: S.current.Private_Note,
      icon: Icons.lock_outline,
      open: open,
      onToggle: onToggle,
      child: PrivateNoteField(id: id, category: category, store: store),
    );
  }
}
