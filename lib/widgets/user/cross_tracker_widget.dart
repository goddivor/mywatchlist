import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/user/edit/edit_extras.dart';
import 'package:mywatchlist/widgets/user/edit/edit_labels.dart';
import 'package:mywatchlist/widgets/user/edit/edit_sections.dart';
import 'package:mywatchlist/widgets/user/sync/cross_tracker_controller.dart';
import 'package:mywatchlist/widgets/user/sync/sync_dialog.dart';
import 'package:mywatchlist/widgets/user/sync/sync_labels.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_entry_editor.dart';
import 'package:mywatchlist/widgets/user/tracker_search_sheet.dart';

/// The user's twin entries on the other signed-in trackers, with a two-way
/// sync against MyAnimeList, an editor for each tracker's own entry and
/// linking by hand when the automatic link finds nothing.
///
/// Nothing loads until the user opens the section: when an edit sheet of the
/// same entry is mounted next to it, the section lives inside that sheet's
/// "More options" (see [EditExtras]); otherwise it draws itself as a
/// collapsed card.
///
/// [malStatus], [malScore] and [malProgress] are no longer shown (the sheet
/// already shows them); a sync reads the MAL entry itself.
class CrossTrackerWidget extends StatefulWidget {
  final int malId;
  final String title;
  final String category;
  final String? malStatus;
  final int? malScore;
  final int? malProgress;

  /// Default: the shared service and the signed-in trackers; tests inject
  /// fakes.
  final TrackerSyncService? service;
  final List<AccountType>? trackers;

  const CrossTrackerWidget({
    super.key,
    required this.malId,
    required this.title,
    required this.category,
    this.malStatus,
    this.malScore,
    this.malProgress,
    this.service,
    this.trackers,
  });

  @override
  State<CrossTrackerWidget> createState() => _CrossTrackerWidgetState();
}

class _CrossTrackerWidgetState extends State<CrossTrackerWidget> {
  late TrackerSyncService _service;
  late List<AccountType> _trackers;
  late String _key;
  CrossTrackerController? _controller;

  /// Open state of the standalone card.
  bool _open = false;

  late final WidgetBuilder _section = (_) => _TrackerRows(owner: this);

  bool get _isAnime => widget.category == 'anime';
  EditExtras get _extras => EditExtras.instance;

  void _setUp() {
    _service = widget.service ?? TrackerSyncService.instance;
    _trackers = (widget.trackers ?? UserManager.instance.authenticatedTrackers)
        .where((t) => t != AccountType.myanimelist && t != AccountType.none)
        .toList();
    _key = EditExtras.keyOf(widget.malId, widget.category);
    if (_trackers.isNotEmpty) _extras.attach(_key, _section);
  }

  /// Created, and loading, the first time the rows are shown.
  CrossTrackerController _ensureController() =>
      _controller ??= CrossTrackerController(
        service: _service,
        trackers: _trackers,
        malId: widget.malId,
        category: widget.category,
      )..loadAll();

  @override
  void initState() {
    super.initState();
    _setUp();
    _extras.addListener(_onExtras);
  }

  void _onExtras() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(CrossTrackerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.malId != widget.malId ||
        oldWidget.category != widget.category ||
        oldWidget.service != widget.service) {
      _extras.detach(_key, _section);
      _controller?.dispose();
      _controller = null;
      _open = false;
      _setUp();
    }
  }

  @override
  void dispose() {
    _extras.removeListener(_onExtras);
    _extras.detach(_key, _section);
    _controller?.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ));
  }

  Future<void> _link(AccountType tracker) async {
    final result = await TrackerSearchSheet.show(
      context,
      tracker: tracker,
      initialQuery: widget.title,
      category: widget.category,
    );
    if (result == null || !mounted) return;
    await _controller?.link(tracker, result.id);
  }

  Future<void> _edit(AccountType tracker, TrackerSlot slot) async {
    final saved = await showTrackerEntryEditor(
      context,
      service: _service,
      tracker: tracker,
      trackerId: slot.linkId!,
      malId: widget.malId,
      category: widget.category,
      initial: slot.entry,
    );
    if (saved == null || !mounted) return;
    if (saved.isRemoved) {
      // Deleted from the tracker: the card goes back to "not on this list".
      _controller?.clearEntry(tracker);
      _toast(S.current.Sync_Removed(TrackerSyncService.trackerName(tracker)));
      return;
    }
    _controller?.applyEntry(tracker, saved);
    _toast(S.current.Sync_Saved(TrackerSyncService.trackerName(tracker)));
  }

  Future<void> _sync(AccountType tracker, TrackerSlot slot) async {
    final result = await showSyncDialog(
      context,
      service: _service,
      tracker: tracker,
      trackerId: slot.linkId!,
      malId: widget.malId,
      category: widget.category,
    );
    if (result == null || !mounted) return;
    if (result.cancelled) {
      _toast(S.current.Sync_Cancelled);
      return;
    }
    final outcome = result.outcome!;
    _controller?.applyEntry(tracker, outcome.tracker);
    _toast(S.current.Sync_Done_To(result.direction == SyncDirection.malToTracker
        ? TrackerSyncService.trackerName(tracker)
        : TrackerSyncService.trackerName(AccountType.myanimelist)));
  }

  Future<void> _remove(AccountType tracker, TrackerSlot slot) async {
    final name = TrackerSyncService.trackerName(tracker);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.current.Sync_Remove_Title),
        content: Text(S.current.Sync_Remove_Message(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.current.Sync_Cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(S.current.Sync_Remove),
          ),
        ],
      ),
    );
    final controller = _controller;
    if (confirmed != true || !mounted || controller == null) return;
    controller.setBusy(tracker, true);
    try {
      await _service.deleteTracker(tracker, slot.linkId!, widget.category,
          malId: widget.malId);
      controller.clearEntry(tracker);
      _toast(S.current.Sync_Removed(name));
    } catch (_) {
      controller.setBusy(tracker, false);
      _toast(S.current.Sync_Remove_Failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Shown inside the edit sheet's "More options" while a sheet hosts it.
    if (_trackers.isEmpty || _extras.isHosted(_key)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, fabClearance(context)),
      child: Card(
        key: const ValueKey('cross-tracker-card'),
        elevation: 4,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: EditSection(
          title: S.current.Sync_Section_Title,
          icon: Icons.sync,
          open: _open,
          onToggle: () => setState(() => _open = !_open),
          child: _section(context),
        ),
      ),
    );
  }
}

/// One row per tracker; mounting it is what starts the loading.
class _TrackerRows extends StatelessWidget {
  const _TrackerRows({required this.owner});

  final _CrossTrackerWidgetState owner;

  @override
  Widget build(BuildContext context) {
    final controller = owner._ensureController();
    return Column(
      key: const ValueKey('cross-tracker-rows'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tracker in controller.trackers)
          ValueListenableBuilder<TrackerSlot>(
            valueListenable: controller.slots[tracker]!,
            builder: (context, slot, _) => _TrackerCard(
              slot: slot,
              isAnime: owner._isAnime,
              onLink: () => owner._link(tracker),
              onUnlink: () => owner._controller?.unlink(tracker),
              onRetry: () => owner._controller?.load(tracker),
              onEdit: () => owner._edit(tracker, slot),
              onSync: () => owner._sync(tracker, slot),
              onRemove: () => owner._remove(tracker, slot),
            ),
          ),
      ],
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.slot,
    required this.isAnime,
    required this.onLink,
    required this.onUnlink,
    required this.onRetry,
    required this.onEdit,
    required this.onSync,
    required this.onRemove,
  });

  final TrackerSlot slot;
  final bool isAnime;
  final VoidCallback onLink;
  final VoidCallback onUnlink;
  final VoidCallback onRetry;
  final VoidCallback onEdit;
  final VoidCallback onSync;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = TrackerSyncService.trackerName(slot.tracker);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(10),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: const Cubic(0.23, 1, 0.32, 1),
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, name),
              ..._body(context, name),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String name) {
    final theme = Theme.of(context);
    final entry = slot.entry;
    return Row(
      children: [
        TrackerLogo(slot.tracker),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name, style: theme.textTheme.bodyMedium),
        ),
        if (slot.phase == SlotPhase.loading ||
            (slot.phase == SlotPhase.linked && !slot.entryLoaded) ||
            slot.busy)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (entry?.status != null)
          _StatusChip(entry!.status!),
        if (slot.isLinked && slot.phase == SlotPhase.linked && !slot.busy)
          PopupMenuButton<_Menu>(
            tooltip: S.current.Sync_Unlink,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (m) => switch (m) {
              _Menu.unlink => onUnlink(),
              _Menu.remove => onRemove(),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _Menu.unlink,
                child: Text(S.current.Sync_Unlink),
              ),
              if (entry != null)
                PopupMenuItem(
                  value: _Menu.remove,
                  child: Text(S.current.Sync_Remove_Title),
                ),
            ],
          ),
      ],
    );
  }

  List<Widget> _body(BuildContext context, String name) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget message(String text, {Widget? action, bool error = false}) =>
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(text,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: error ? theme.colorScheme.error : muted)),
              ),
              if (action != null) action,
            ],
          ),
        );

    switch (slot.phase) {
      case SlotPhase.loading:
        return const [];
      case SlotPhase.unlinked:
        return [
          message(
            S.current.Sync_Not_Linked,
            action: TextButton.icon(
              onPressed: onLink,
              icon: const Icon(Icons.add_link, size: 18),
              label: Text(S.current.Sync_Link),
              style: _compact,
            ),
          ),
        ];
      case SlotPhase.authRequired:
        return [message(S.current.Sync_Sign_In_Again(name), error: true)];
      case SlotPhase.unsupported:
        return [message(S.current.Sync_Manga_Unsupported(name))];
      case SlotPhase.failed:
        return [
          message(
            S.current.Sync_Load_Failed(name),
            error: true,
            action: TextButton(
              onPressed: onRetry,
              style: _compact,
              child: Text(S.current.Sync_Retry),
            ),
          ),
        ];
      case SlotPhase.linked:
        final entry = slot.entry;
        final summary = entry == null
            ? ''
            // The chip already shows the status.
            : entrySummary(entry, isAnime: isAnime, withStatus: false);
        return [
          if (slot.entryLoaded)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              // Wraps the buttons under the summary when a language's
              // labels do not fit on one line (French).
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (entry != null && entry.hasScore) ...[
                        Icon(Icons.star,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          entry == null ? S.current.Sync_Not_On_List : summary,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: muted),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: slot.busy ? null : onEdit,
                        style: _compact,
                        child: Text(S.current.Sync_Edit),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: slot.busy ? null : onSync,
                        icon: const Icon(Icons.sync, size: 16),
                        label: Text(S.current.Sync_Sync),
                        style: _compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ];
    }
  }

  static final ButtonStyle _compact = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    visualDensity: VisualDensity.compact,
    minimumSize: const Size(0, 32),
  );
}

enum _Menu { unlink, remove }

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = AppColors.of(context).statusOf(status);
    // Theme status chip: solid status colour, semi-bold `onContainer` text (≥ 3:1
    // in light, dark and black); unknown status = neutral tonal chip.
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: role?.container ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: role?.onContainer ?? scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
