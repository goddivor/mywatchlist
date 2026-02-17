import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/user/tracker_search_sheet.dart';

class CrossTrackerWidget extends StatefulWidget {
  final int malId;
  final String title;
  final String category;
  final String? malStatus;
  final int? malScore;
  final int? malProgress;

  const CrossTrackerWidget({
    super.key,
    required this.malId,
    required this.title,
    required this.category,
    this.malStatus,
    this.malScore,
    this.malProgress,
  });

  @override
  State<CrossTrackerWidget> createState() => _CrossTrackerWidgetState();
}

class _CrossTrackerWidgetState extends State<CrossTrackerWidget> {
  final _service = TrackerSyncService.instance;

  // Per-tracker state
  final Map<AccountType, String?> _linkIds = {};
  final Map<AccountType, TrackerEntryStatus?> _statuses = {};
  final Map<AccountType, bool> _loading = {};
  final Map<AccountType, bool> _syncing = {};

  List<AccountType> get _otherTrackers => UserManager.instance
      .authenticatedTrackers
      .where((t) => t != AccountType.myanimelist)
      .toList();

  @override
  void initState() {
    super.initState();
    _loadAllLinks();
  }

  @override
  void didUpdateWidget(CrossTrackerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId) {
      _loadAllLinks();
    }
  }

  Future<void> _loadAllLinks() async {
    for (final tracker in _otherTrackers) {
      _loading[tracker] = true;
      final linkId =
          await _service.getLinkId(widget.malId, widget.category, tracker);
      _linkIds[tracker] = linkId;
      if (linkId != null) {
        final status =
            await _service.getEntryStatus(tracker, linkId, widget.category);
        _statuses[tracker] = status;
      }
      _loading[tracker] = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _linkTracker(AccountType tracker) async {
    final result = await TrackerSearchSheet.show(
      context,
      tracker: tracker,
      initialQuery: widget.title,
      category: widget.category,
    );
    if (result == null || !mounted) return;

    setState(() => _loading[tracker] = true);
    await _service.saveLinkId(
        widget.malId, widget.category, tracker, result.id);
    _linkIds[tracker] = result.id;

    // Fetch current status
    final status =
        await _service.getEntryStatus(tracker, result.id, widget.category);
    _statuses[tracker] = status;
    if (mounted) setState(() => _loading[tracker] = false);
  }

  Future<void> _unlinkTracker(AccountType tracker) async {
    await _service.removeLinkId(widget.malId, widget.category, tracker);
    _linkIds[tracker] = null;
    _statuses[tracker] = null;
    if (mounted) setState(() {});
  }

  Future<void> _removeFromList(AccountType tracker) async {
    final linkId = _linkIds[tracker];
    if (linkId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from list'),
        content: Text(
            'Remove this entry from ${TrackerSyncService.trackerName(tracker)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _syncing[tracker] = true);
    final success = await _service.deleteEntry(
        tracker, linkId, widget.category,
        malId: widget.malId);

    if (mounted) {
      setState(() => _syncing[tracker] = false);
      if (success) {
        _statuses[tracker] = null;
        setState(() {});
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Removed from ${TrackerSyncService.trackerName(tracker)}'
              : 'Remove failed'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _syncFromMal(AccountType tracker) async {
    final linkId = _linkIds[tracker];
    if (linkId == null) return;

    setState(() => _syncing[tracker] = true);
    final success = await _service.updateStatus(
      tracker,
      linkId,
      widget.category,
      malStatus: widget.malStatus,
      malScore: widget.malScore,
      progress: widget.malProgress,
      malId: widget.malId,
    );

    if (success) {
      // Refresh status
      final status =
          await _service.getEntryStatus(tracker, linkId, widget.category);
      _statuses[tracker] = status;
    }

    if (mounted) {
      setState(() => _syncing[tracker] = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Synced to ${TrackerSyncService.trackerName(tracker)}'
              : 'Sync failed'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackers = _otherTrackers;
    if (trackers.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 4,
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(
                children: [
                  Icon(Icons.sync,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Other Trackers',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tracker cards
              ...trackers.map((tracker) => _buildTrackerCard(theme, tracker)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackerCard(ThemeData theme, AccountType tracker) {
    final isLoading = _loading[tracker] ?? false;
    final isSyncing = _syncing[tracker] ?? false;
    final linkId = _linkIds[tracker];
    final isLinked = linkId != null;
    final status = _statuses[tracker];
    final trackerName = TrackerSyncService.trackerName(tracker);
    final trackerLogo = TrackerSyncService.trackerLogo(tracker);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: isLoading
            ? Row(
                children: [
                  _trackerLogo(trackerLogo),
                  const SizedBox(width: 10),
                  Text(trackerName, style: theme.textTheme.bodyMedium),
                  const Spacer(),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              )
            : isLinked
                ? _linkedCard(theme, tracker, trackerName, trackerLogo, status,
                    isSyncing)
                : _unlinkedCard(theme, tracker, trackerName, trackerLogo),
      ),
    );
  }

  Widget _unlinkedCard(ThemeData theme, AccountType tracker, String name,
      String logoPath) {
    return Row(
      children: [
        _trackerLogo(logoPath),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: theme.textTheme.bodyMedium),
        ),
        TextButton.icon(
          onPressed: () => _linkTracker(tracker),
          icon: Icon(Icons.add_link, size: 18, color: theme.colorScheme.primary),
          label: Text('Link',
              style: TextStyle(color: theme.colorScheme.primary)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _linkedCard(ThemeData theme, AccountType tracker, String name,
      String logoPath, TrackerEntryStatus? status, bool syncing) {
    final malStatusLabel = status?.status != null
        ? _service.mapStatusFromTracker(
            status!.status!, tracker, widget.category)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Logo + name + status chip + unlink
        Row(
          children: [
            _trackerLogo(logoPath),
            const SizedBox(width: 10),
            Expanded(
              child: Text(name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (malStatusLabel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: getAnimeStatusColor(malStatusLabel)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _displayStatus(status!.status!, tracker),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: getAnimeStatusColor(malStatusLabel),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _unlinkTracker(tracker),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.link_off,
                    size: 18,
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Row 2: Progress + Score + Sync button
        Row(
          children: [
            const SizedBox(width: 38), // align with text above logo
            if (status?.progress != null) ...[
              Icon(Icons.play_circle_outline,
                  size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 3),
              Text(
                'Ep. ${status!.progress}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (status?.score != null && status!.score! > 0) ...[
              Icon(Icons.star,
                  size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 3),
              Text(
                '${status.score}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            const Spacer(),
            if (syncing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              SizedBox(
                height: 30,
                child: TextButton.icon(
                  onPressed: () => _removeFromList(tracker),
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: theme.colorScheme.error),
                  label: Text('Remove',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      )),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                child: TextButton.icon(
                  onPressed: () => _syncFromMal(tracker),
                  icon: Icon(Icons.sync,
                      size: 16, color: theme.colorScheme.primary),
                  label: Text('Sync',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _trackerLogo(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        path,
        width: 28,
        height: 28,
        errorBuilder: (_, __, ___) => const Icon(Icons.link, size: 28),
      ),
    );
  }

  String _displayStatus(String trackerStatus, AccountType tracker) {
    // Show human-readable status from tracker's own naming
    switch (tracker) {
      case AccountType.anilist:
        return trackerStatus.replaceAll('_', ' ');
      case AccountType.kitsu:
        return trackerStatus.replaceAll('_', ' ');
      case AccountType.simkl:
        return trackerStatus.replaceAll('plantowatch', 'Plan to Watch');
      default:
        return trackerStatus;
    }
  }
}
