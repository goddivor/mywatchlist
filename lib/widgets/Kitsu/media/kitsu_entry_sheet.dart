import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuStatusLabel;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// What the Kitsu edit sheet saved.
sealed class KitsuEntryResult {
  const KitsuEntryResult();
}

class KitsuEntrySaved extends KitsuEntryResult {
  final KitsuMyEntry entry;
  const KitsuEntrySaved(this.entry);
}

class KitsuEntryRemoved extends KitsuEntryResult {
  const KitsuEntryRemoved();
}

/// Kitsu's own edit sheet (the site's library modal): status in Kitsu's words, progress, the
/// rating in the account's rating system, rewatches, dates, notes, private, remove. Writes only
/// when the user taps Save or Remove. With no [initial] entry it reads the user's entry first;
/// a title that is not in the library is added on Save.
Future<KitsuEntryResult?> showKitsuEntrySheet(
  BuildContext context, {
  required KitsuMediaKind kind,
  required String mediaId,
  required String title,
  int total = 0,
  KitsuMyEntry? initial,
  bool load = true,
  KitsuMyLibrary? service,
}) {
  return showModalBottomSheet<KitsuEntryResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => KitsuEntrySheet(
      kind: kind,
      mediaId: mediaId,
      title: title,
      total: total,
      initial: initial,
      load: load && initial == null,
      service: service ?? KitsuMyLibrary.instance,
    ),
  );
}

class KitsuEntrySheet extends StatefulWidget {
  final KitsuMediaKind kind;
  final String mediaId;
  final String title;
  final int total;
  final KitsuMyEntry? initial;
  final bool load;
  final KitsuMyLibrary service;

  const KitsuEntrySheet({
    super.key,
    required this.kind,
    required this.mediaId,
    required this.title,
    required this.total,
    required this.initial,
    required this.load,
    required this.service,
  });

  @override
  State<KitsuEntrySheet> createState() => _KitsuEntrySheetState();
}

class _KitsuEntrySheetState extends State<KitsuEntrySheet> {
  late final TextEditingController _notes = TextEditingController(text: widget.initial?.notes ?? '');
  KitsuMyEntry? _entry;
  bool _loading = false;
  bool _failed = false;
  bool _saving = false;
  String? _error;

  ListEntryStatus _status = ListEntryStatus.planned;
  int _progress = 0;
  int? _rating;
  int _rewatches = 0;
  bool _private = false;
  DateTime? _started;
  DateTime? _finished;

  bool get _anime => widget.kind == KitsuMediaKind.anime;

  @override
  void initState() {
    super.initState();
    _apply(widget.initial);
    if (widget.load) _read();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _apply(KitsuMyEntry? e) {
    _entry = e;
    if (e == null) return;
    _status = e.status;
    _progress = e.progress;
    _rating = e.rating;
    _rewatches = e.reconsumeCount;
    _private = e.private;
    _started = e.startedAt;
    _finished = e.finishedAt;
    _notes.text = e.notes ?? '';
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final e = await widget.service.entryOf(widget.kind, widget.mediaId);
      if (!mounted) return;
      setState(() {
        _apply(e);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  void _setProgress(int value) {
    final max = widget.total > 0 ? widget.total : 1 << 20;
    setState(() {
      _progress = value.clamp(0, max);
      if (widget.total > 0 && _progress == widget.total && _status == ListEntryStatus.current) {
        _status = ListEntryStatus.completed;
      }
    });
  }

  void _setStatus(ListEntryStatus status) {
    setState(() {
      _status = status;
      if (status == ListEntryStatus.completed && widget.total > 0) _progress = widget.total;
    });
  }

  Future<void> _pickRating() async {
    final picked = await showKitsuRatingSheet(context, current: _rating);
    if (picked == null || !mounted) return;
    setState(() => _rating = picked == 0 ? null : picked);
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _started : _finished) ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => start ? _started = picked : _finished = picked);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = widget.service;
      var entry = _entry;
      entry ??= await service.add(widget.kind, widget.mediaId, _status, progress: _progress);
      final saved = await service.update(
        entry.id,
        status: _status,
        progress: _progress,
        rating: _rating ?? (entry.isRated ? 0 : null),
        reconsumeCount: _rewatches,
        private: _private,
        notes: _notes.text.trim() == (entry.notes ?? '') ? null : _notes.text.trim(),
        startedAt: _started,
        finishedAt: _finished,
      );
      if (mounted) Navigator.of(context).pop(KitsuEntrySaved(saved));
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.current.Kr_Save_Failed;
        });
      }
    }
  }

  Future<void> _remove() async {
    final entry = _entry;
    if (entry == null) return;
    final s = S.current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.Kr_Remove_Title),
        content: Text(s.Kr_Remove_Body(widget.title)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.Kr_Remove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.remove(entry.id);
      if (mounted) Navigator.of(context).pop(const KitsuEntryRemoved());
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = S.current.Kr_Save_Failed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.current;
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
    }
    if (_failed) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(s.Kr_Load_Failed, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: _read, child: Text(s.Kr_Retry)),
          ]),
        ),
      );
    }
    final label = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    final dates = DateFormat.yMMMd();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final st in const [
                  ListEntryStatus.current,
                  ListEntryStatus.planned,
                  ListEntryStatus.completed,
                  ListEntryStatus.onHold,
                  ListEntryStatus.dropped,
                ])
                  ChoiceChip(
                    label: Text(kitsuStatusLabel(st, isAnime: _anime)),
                    selected: _status == st,
                    onSelected: (_) => _setStatus(st),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(_anime ? s.Kr_Episodes_Watched : s.Kr_Chapters_Read, style: label)),
                IconButton.filledTonal(
                  tooltip: s.Kr_Minus_One,
                  onPressed: _progress > 0 ? () => _setProgress(_progress - 1) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    widget.total > 0 ? '$_progress / ${widget.total}' : '$_progress',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: s.Kr_Plus_One,
                  onPressed: widget.total == 0 || _progress < widget.total ? () => _setProgress(_progress + 1) : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.Kr_My_Rating),
              trailing: KitsuRatingBadge(
                twenty: _rating,
                size: 18,
                empty: Text(s.Kr_Not_Rated, style: label),
              ),
              onTap: _pickRating,
            ),
            Row(
              children: [
                Expanded(child: Text(_anime ? s.Kr_Rewatches : s.Kr_Rereads, style: label)),
                IconButton(
                  tooltip: s.Kr_Minus_One,
                  onPressed: _rewatches > 0 ? () => setState(() => _rewatches--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text('$_rewatches', style: theme.textTheme.titleMedium),
                IconButton(
                  tooltip: s.Kr_Plus_One,
                  onPressed: () => setState(() => _rewatches++),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.Kr_Started),
                    subtitle: Text(_started == null ? '–' : dates.format(_started!.toLocal())),
                    onTap: () => _pickDate(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.Kr_Finished),
                    subtitle: Text(_finished == null ? '–' : dates.format(_finished!.toLocal())),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: s.Kr_Notes, border: const OutlineInputBorder()),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.Kr_Private),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: scheme.error)),
              ),
            Row(
              children: [
                if (_entry != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                    onPressed: _saving ? null : _remove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(s.Kr_Remove),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_entry == null ? s.Kr_Add : s.Kr_Save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
