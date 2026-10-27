import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/common/select/select_date.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_labels.dart';

/// Step of the score slider on each tracker: AniList takes tenths
/// (POINT_10_DECIMAL), Kitsu half points, Simkl whole points.
double scoreStepOf(AccountType tracker) => switch (tracker) {
      AccountType.anilist => 0.1,
      AccountType.kitsu => 0.5,
      _ => 1,
    };

/// Edits the user's entry on [tracker] itself (status, score, progress and
/// dates), and creates it when the media is not on the list yet. Pops the
/// entry the tracker answered with, or null when nothing was saved.
Future<SyncEntry?> showTrackerEntryEditor(
  BuildContext context, {
  required TrackerSyncService service,
  required AccountType tracker,
  required String trackerId,
  required int malId,
  required String category,
  SyncEntry? initial,
}) {
  return showModalBottomSheet<SyncEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => TrackerEntryEditor(
      service: service,
      tracker: tracker,
      trackerId: trackerId,
      malId: malId,
      category: category,
      initial: initial,
    ),
  );
}

class TrackerEntryEditor extends StatefulWidget {
  const TrackerEntryEditor({
    super.key,
    required this.service,
    required this.tracker,
    required this.trackerId,
    required this.malId,
    required this.category,
    this.initial,
  });

  final TrackerSyncService service;
  final AccountType tracker;
  final String trackerId;
  final int malId;
  final String category;
  final SyncEntry? initial;

  @override
  State<TrackerEntryEditor> createState() => _TrackerEntryEditorState();
}

class _TrackerEntryEditorState extends State<TrackerEntryEditor> {
  late String _status;
  late double _score;
  late final TextEditingController _progress;
  late final TextEditingController _volumes;
  String? _start;
  String? _finish;
  bool _saving = false;
  Object? _error;

  bool get _isAnime => widget.category == 'anime';
  bool get _simkl => widget.tracker == AccountType.simkl;
  double get _step => scoreStepOf(widget.tracker);

  List<String> get _statuses => _isAnime
      ? const [
          'watching',
          'completed',
          'on_hold',
          'dropped',
          'plan_to_watch'
        ]
      : const ['reading', 'completed', 'on_hold', 'dropped', 'plan_to_read'];

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _status = e?.status ?? (_isAnime ? 'plan_to_watch' : 'plan_to_read');
    _score = _snap(e?.score ?? 0);
    _progress = TextEditingController(text: '${e?.progress ?? 0}');
    _volumes = TextEditingController(text: '${e?.volumes ?? 0}');
    _start = e?.startDate;
    _finish = e?.finishDate;
  }

  @override
  void dispose() {
    _progress.dispose();
    _volumes.dispose();
    super.dispose();
  }

  double _snap(double v) {
    final snapped = (v / _step).round() * _step;
    return double.parse(snapped.clamp(0, 10).toStringAsFixed(1));
  }

  int _int(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  void _bump(TextEditingController c, int by) {
    final next = (_int(c) + by).clamp(0, 99999);
    setState(() => c.text = '$next');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = SyncEntry(
        status: _status,
        score: _score,
        progress: _int(_progress),
        volumes: _isAnime || _simkl ? null : _int(_volumes),
        startDate: _start,
        finishDate: _finish,
      );
      final saved = await widget.service.saveTracker(
          widget.tracker, widget.trackerId, widget.category, entry,
          malId: widget.malId);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = TrackerSyncService.trackerName(widget.tracker);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              TrackerLogo(widget.tracker),
              const SizedBox(width: 12),
              Expanded(
                child: Text(S.current.Sync_Edit_Title(name),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(theme, S.current.Sync_Field_Status),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in _statuses)
                ChoiceChip(
                  label: Text(statusLabel(s)),
                  selected: _status == s,
                  onSelected:
                      _saving ? null : (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _scoreRow(theme),
          if (!_simkl) ...[
            const SizedBox(height: 8),
            _counter(
              theme,
              _isAnime
                  ? S.current.Sync_Field_Episodes
                  : S.current.Sync_Field_Chapters,
              _progress,
            ),
            if (!_isAnime)
              _counter(theme, S.current.Sync_Field_Volumes, _volumes),
            const SizedBox(height: 8),
            _dateRow(S.current.Sync_Field_Start, _start,
                (d) => setState(() => _start = d)),
            const SizedBox(height: 8),
            _dateRow(S.current.Sync_Field_Finish, _finish,
                (d) => setState(() => _finish = d)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error is Exception
                  ? syncErrorMessage(_error!, widget.tracker)
                  : S.current.Sync_Save_Failed,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(S.current.Sync_Save),
          ),
        ],
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );

  Widget _scoreRow(ThemeData theme) {
    final divisions = (10 / _step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _label(theme, S.current.Sync_Field_Score)),
            Text(
              _score > 0 ? SyncScores.format(_score) : S.current.Sync_No_Score,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
        Slider(
          value: _score,
          max: 10,
          divisions: divisions,
          label: _score > 0 ? SyncScores.format(_score) : null,
          onChanged: _saving ? null : (v) => setState(() => _score = _snap(v)),
        ),
      ],
    );
  }

  Widget _counter(
      ThemeData theme, String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          IconButton(
            tooltip: S.current.Sync_Decrease,
            onPressed: _saving ? null : () => _bump(controller, -1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: controller,
              enabled: !_saving,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            tooltip: S.current.Sync_Increase,
            onPressed: _saving ? null : () => _bump(controller, 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  Widget _dateRow(String label, String? value, ValueChanged<String> onPicked) {
    return SelectDate(
      label: label,
      hint: S.current.Sync_Pick_Date,
      date: value == null ? null : DateTime.tryParse(value),
      onChanged: (d) => onPicked(formatApiDate(d)),
    );
  }
}
