import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';
import 'package:mywatchlist/widgets/user/sync/sync_labels.dart';

/// How the sync dialog ended.
class SyncDialogResult {
  /// Null when the user cancelled.
  final SyncDirection? direction;
  final SyncOutcome? outcome;
  const SyncDialogResult.done(SyncDirection this.direction, SyncOutcome this.outcome);
  const SyncDialogResult.cancelled()
      : direction = null,
        outcome = null;
  bool get cancelled => outcome == null;
}

/// Opens the two-way sync dialog between MyAnimeList and [tracker].
Future<SyncDialogResult?> showSyncDialog(
  BuildContext context, {
  required TrackerSyncService service,
  required AccountType tracker,
  required String trackerId,
  required int malId,
  required String category,
}) {
  return showDialog<SyncDialogResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => SyncDialog(
      service: service,
      tracker: tracker,
      trackerId: trackerId,
      malId: malId,
      category: category,
    ),
  );
}

enum _Phase { loading, ready, running }

/// Both entries are read when the dialog opens (lazy: nothing is loaded
/// before the user asks for a sync), each side shows what it would copy, then
/// one tap runs the chosen direction. Cancel is always there, also while the
/// sync runs: the sync stops before its next step and no write is started.
class SyncDialog extends StatefulWidget {
  const SyncDialog({
    super.key,
    required this.service,
    required this.tracker,
    required this.trackerId,
    required this.malId,
    required this.category,
  });

  final TrackerSyncService service;
  final AccountType tracker;
  final String trackerId;
  final int malId;
  final String category;

  @override
  State<SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<SyncDialog> {
  final _cancel = SyncCancelToken();
  _Phase _phase = _Phase.loading;
  SyncEntry? _mal;
  SyncEntry? _other;
  Object? _malError;
  Object? _otherError;
  Object? _runError;
  SyncDirection? _running;

  bool get _isAnime => widget.category == 'anime';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _malError = _otherError = _runError = null;
    });
    final s = widget.service;
    await Future.wait([
      () async {
        try {
          if (!s.mal.connected) {
            throw const SyncAuthRequired(AccountType.myanimelist);
          }
          _mal = await s.mal.read(widget.malId, isAnime: _isAnime);
        } catch (e) {
          _malError = e;
        }
      }(),
      () async {
        try {
          _other = await s.readTracker(
              widget.tracker, widget.trackerId, widget.category,
              malId: widget.malId);
        } catch (e) {
          _otherError = e;
        }
      }(),
    ]);
    if (!mounted || _cancel.isCancelled) return;
    setState(() => _phase = _Phase.ready);
  }

  Future<void> _run(SyncDirection direction) async {
    setState(() {
      _phase = _Phase.running;
      _running = direction;
      _runError = null;
    });
    try {
      final outcome = await widget.service.sync(
        direction: direction,
        tracker: widget.tracker,
        trackerId: widget.trackerId,
        malId: widget.malId,
        category: widget.category,
        cancel: _cancel,
      );
      if (!mounted || _cancel.isCancelled) return;
      Navigator.of(context).pop(SyncDialogResult.done(direction, outcome));
    } on SyncCancelled {
      // Cancel already closed the dialog.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _runError = e;
      });
    }
  }

  void _onCancel() {
    _cancel.cancel();
    Navigator.of(context).pop(const SyncDialogResult.cancelled());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = TrackerSyncService.trackerName(widget.tracker);
    final mal = TrackerSyncService.trackerName(AccountType.myanimelist);
    final busy = _phase == _Phase.running;

    return AlertDialog(
      title: Text(S.current.Sync_Dialog_Title(name)),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.current.Sync_Dialog_Hint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              if (widget.tracker == AccountType.simkl) ...[
                const SizedBox(height: 4),
                Text(S.current.Sync_Simkl_Limited,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 16),
              _DirectionTile(
                from: AccountType.myanimelist,
                to: widget.tracker,
                title: S.current.Sync_Direction(mal, name),
                loading: _phase == _Phase.loading,
                running: busy && _running == SyncDirection.malToTracker,
                enabled: !busy &&
                    _phase == _Phase.ready &&
                    _mal != null &&
                    _otherError == null,
                subtitle: _subtitle(_mal, _malError, AccountType.myanimelist),
                onTap: () => _run(SyncDirection.malToTracker),
              ),
              const SizedBox(height: 10),
              _DirectionTile(
                from: widget.tracker,
                to: AccountType.myanimelist,
                title: S.current.Sync_Direction(name, mal),
                loading: _phase == _Phase.loading,
                running: busy && _running == SyncDirection.trackerToMal,
                enabled: !busy &&
                    _phase == _Phase.ready &&
                    _other != null &&
                    _malError == null,
                subtitle: _subtitle(_other, _otherError, widget.tracker),
                onTap: () => _run(SyncDirection.trackerToMal),
              ),
              if (_other != null &&
                  _other!.hasScore &&
                  _other!.score != _other!.score!.roundToDouble()) ...[
                const SizedBox(height: 10),
                Text(
                  S.current.Sync_Whole_Points(
                    SyncScores.format(_other!.score!),
                    SyncScores.toMal(_other!.score!).toString(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              if (_runError != null) ...[
                const SizedBox(height: 12),
                _ErrorLine(syncErrorMessage(_runError!, widget.tracker)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_phase == _Phase.ready && (_malError != null || _otherError != null))
          TextButton(onPressed: _load, child: Text(S.current.Sync_Retry)),
        TextButton(
          onPressed: _onCancel,
          child: Text(S.current.Sync_Cancel),
        ),
      ],
    );
  }

  /// The source line of a tile: its entry, why it can't be read, or empty.
  String? _subtitle(SyncEntry? entry, Object? error, AccountType side) {
    if (_phase == _Phase.loading) return null;
    if (error != null) return syncErrorMessage(error, side);
    if (entry == null) {
      return S.current.Sync_Source_Empty(TrackerSyncService.trackerName(side));
    }
    final line = entrySummary(entry, isAnime: _isAnime);
    return line.isEmpty ? S.current.Sync_Not_On_List : line;
  }
}

class _DirectionTile extends StatelessWidget {
  const _DirectionTile({
    required this.from,
    required this.to,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.running,
    required this.enabled,
    required this.onTap,
  });

  final AccountType from;
  final AccountType to;
  final String title;
  final String? subtitle;
  final bool loading;
  final bool running;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dim = !enabled && !running;
    return Semantics(
      button: true,
      enabled: enabled,
      label: title,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                TrackerLogo(from, size: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                TrackerLogo(to, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall?.copyWith(
                              color: dim
                                  ? scheme.onSurface.withValues(alpha: 0.5)
                                  : null)),
                      if (subtitle != null)
                        Text(subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: dim ? 0.7 : 1))),
                    ],
                  ),
                ),
                if (loading || running)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 18, color: scheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error)),
        ),
      ],
    );
  }
}
