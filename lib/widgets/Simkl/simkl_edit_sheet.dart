import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_list_service.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';

/// Opens the Simkl edit sheet of [entry] (status, episodes watched, score, remove) and reports
/// what was saved. An entry without a status is created on Save.
Future<ListEditResult> showSimklEditSheet(
  BuildContext context,
  ListEntryView entry, {
  SimklListService? service,
}) async {
  final result = await showModalBottomSheet<ListEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SimklEditSheet(entry: entry, service: service ?? SimklListService.instance),
  );
  return result ?? const ListEditUnchanged();
}

class SimklEditSheet extends StatefulWidget {
  final ListEntryView entry;
  final SimklListService service;

  const SimklEditSheet({super.key, required this.entry, required this.service});

  @override
  State<SimklEditSheet> createState() => _SimklEditSheetState();
}

class _SimklEditSheetState extends State<SimklEditSheet> {
  late ListEntryStatus _status = widget.entry.status ?? ListEntryStatus.planned;
  late int _progress = widget.entry.progress;
  late double _score = widget.entry.score.toDouble();
  bool _busy = false;
  String? _error;

  ListEntryView get _entry => widget.entry;
  bool get _isNew => _entry.status == null;

  bool get _changed =>
      _isNew ||
      _status != _entry.status ||
      _progress != _entry.progress ||
      _score.round() != _entry.score;

  void _bump(int by) {
    final max = _entry.total > 0 ? _entry.total : 100000;
    setState(() => _progress = (_progress + by).clamp(0, max));
  }

  Future<void> _run(Future<ListEditResult> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await action();
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is SimklSessionExpired
            ? S.current.Sk_Session_Expired
            : S.current.Sk_Edit_Failed;
      });
    }
  }

  Future<void> _save() => _run(() async {
        var updated = _entry;
        final scoreChanged = _score.round() != _entry.score;
        if (_isNew || _status != _entry.status || scoreChanged) {
          updated = await widget.service.save(
            updated,
            status: _status,
            score: scoreChanged || _isNew ? _score.round() : null,
          );
        }
        if (_progress != _entry.progress) {
          updated = await widget.service.setProgress(updated, _progress);
        }
        return ListEditUpdated(updated);
      });

  Future<void> _remove() => _run(() async {
        await widget.service.remove(_entry);
        return const ListEditRemoved();
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final total = _entry.total;
    final score = _score.round();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_entry.title, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Text(s.Sk_Edit_Status, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final status in ListEntryStatus.values)
                ChoiceChip(
                  avatar: Icon(status.icon, size: 18),
                  label: Text(status.label(isAnime: true)),
                  selected: _status == status,
                  onSelected: _busy ? null : (_) => setState(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(s.Sk_Edit_Progress, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: s.UserList_Minus_One,
                onPressed: _busy || _progress <= 0 ? null : () => _bump(-1),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  total > 0 ? '$_progress / $total' : '$_progress',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton.filledTonal(
                tooltip: s.UserList_Plus_One,
                onPressed: _busy || (total > 0 && _progress >= total) ? null : () => _bump(1),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(s.Sk_Edit_Score, style: theme.textTheme.labelLarge),
              const Spacer(),
              Text(
                score == 0 ? s.UserList_Not_Scored : '$score / 10',
                style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          Slider(
            value: _score,
            max: 10,
            divisions: 10,
            label: score == 0 ? s.UserList_Not_Scored : '$score',
            onChanged: _busy ? null : (v) => setState(() => _score = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error)),
            ),
          Row(
            children: [
              if (!_isNew)
                TextButton.icon(
                  onPressed: _busy ? null : _remove,
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(s.Sk_Edit_Remove),
                ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(const ListEditUnchanged()),
                child: Text(s.Cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy || !_changed ? null : _save,
                child: _busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(s.UserList_Save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
