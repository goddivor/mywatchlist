import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/widgets/user/edit/edit_rules.dart';
import 'package:mywatchlist/widgets/user/edit/list_entry_service.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// The titles picked on a list in selection mode. The list shows a check on each card while
/// [active]; a tap on a card toggles it instead of opening it.
class ListSelection extends ChangeNotifier {
  bool _active = false;
  final Set<int> _ids = {};

  bool get active => _active;
  Set<int> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(int id) => _ids.contains(id);

  /// Enters selection mode, with [first] already picked (a long press on a card).
  void start([int? first]) {
    _active = true;
    if (first != null) _ids.add(first);
    notifyListeners();
  }

  /// Leaves selection mode and forgets the picks.
  void stop() {
    if (!_active && _ids.isEmpty) return;
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  void toggle(int id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// Picks every id of [shown], or none when they are all picked already.
  void toggleAll(Iterable<int> shown) {
    final all = shown.toSet();
    if (all.isNotEmpty && _ids.containsAll(all)) {
      _ids.removeAll(all);
    } else {
      _ids.addAll(all);
    }
    notifyListeners();
  }

  /// Keeps only the picks still listed (after a refresh or a filter).
  void retain(Iterable<int> listed) {
    final before = _ids.length;
    _ids.retainAll(listed.toSet());
    if (_ids.length != before) notifyListeners();
  }
}

/// A list card in selection mode: a round check near the top start (under the airing band), an outline in the accent
/// colour when picked, and taps that toggle the pick instead of opening the title. Outside
/// selection mode it is the card itself.
class SelectableEntry extends StatelessWidget {
  const SelectableEntry({super.key, required this.selection, required this.id, required this.child});

  final ListSelection selection;
  final int id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: selection,
      child: child,
      builder: (context, card) {
        if (!selection.active) return card!;
        final picked = selection.contains(id);
        final scheme = Theme.of(context).colorScheme;
        return Semantics(
          checked: picked,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => selection.toggle(id),
            child: Stack(
              children: [
                IgnorePointer(child: card!),
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: picked ? scheme.primary : Colors.transparent, width: 2.5),
                      color: picked ? scheme.primary.withValues(alpha: 0.12) : Colors.transparent,
                    ),
                  ),
                ),
                // Under the airing band a grid cover draws across its top.
                PositionedDirectional(
                  top: 28,
                  start: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: picked ? scheme.primary : scheme.surface.withValues(alpha: 0.85),
                      border: Border.all(color: picked ? scheme.primary : scheme.outline, width: 2),
                    ),
                    child: picked ? Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary) : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One action of the selection bar.
class BulkAction {
  const BulkAction({required this.icon, required this.label, required this.onPressed, this.destructive = false});

  final IconData icon;
  final String label;

  /// Null greys the action out (nothing picked it applies to).
  final VoidCallback? onPressed;
  final bool destructive;
}

/// The bar of selection mode, at the bottom of the list: close, how many are picked, pick all
/// the titles shown, then the actions.
class BulkActionBar extends StatelessWidget {
  const BulkActionBar({super.key, required this.selection, required this.shown, required this.actions});

  final ListSelection selection;

  /// The ids the list shows (for "select all").
  final List<int> shown;
  final List<BulkAction> actions;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final all = shown.isNotEmpty && selection.ids.containsAll(shown);
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: s.Bulk_Close,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: selection.stop,
                  ),
                  Expanded(
                    child: Text(
                      s.Bulk_Count(selection.count),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: shown.isEmpty ? null : () => selection.toggleAll(shown),
                    icon: Icon(all ? Icons.deselect_rounded : Icons.select_all_rounded, size: 20),
                    label: Text(all ? s.Bulk_None : s.Bulk_All),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 8),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _ActionButton(action: actions[i])),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final BulkAction action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = action.destructive
        ? FilledButton.styleFrom(backgroundColor: scheme.errorContainer, foregroundColor: scheme.onErrorContainer)
        : null;
    return FilledButton.tonalIcon(
      style: style?.copyWith(padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10))) ??
          const ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10))),
      onPressed: action.onPressed,
      icon: Icon(action.icon, size: 18),
      label: Text(action.label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Asks the status to give the [count] picked titles: the five list statuses in their
/// colours. Null when dismissed.
Future<ListEntryStatus?> pickBulkStatus(BuildContext context, {required bool isAnime, required int count, String? title}) {
  return showModalBottomSheet<ListEntryStatus>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final s = S.of(context);
      final theme = Theme.of(context);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title ?? s.Bulk_Status_Title(count), style: theme.textTheme.titleMedium),
            ),
            for (final status in ListEntryStatus.values)
              ListTile(
                leading: CircleAvatar(radius: 8, backgroundColor: status.colors(context).color),
                title: Text(status.label(isAnime: isAnime)),
                onTap: () => Navigator.pop(context, status),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// Asks before removing [count] titles from the user's list.
Future<bool> confirmBulkRemove(BuildContext context, int count) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.Bulk_Remove_Confirm(count)),
      content: Text(s.Bulk_Remove_Desc),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.Cancel)),
        FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: Text(s.Bulk_Remove)),
      ],
    ),
  );
  return ok ?? false;
}

/// What a batch of list writes did.
class BulkResult {
  const BulkResult(this.done, this.failed);
  final int done;
  final int failed;
}

/// Writes to the user's MAL list for many titles, one after the other (MAL's own pace), and
/// keeps [ListStatusCache] in step so every card shows the new status at once.
class MalBulkWriter {
  MalBulkWriter({ListEntryService? service, ListStatusCache? cache})
      : _service = service ?? const MalListEntryService(),
        _cache = cache;

  final ListEntryService _service;
  final ListStatusCache? _cache;

  ListStatusCache get cache => _cache ?? ListStatusCache.instance;

  /// Gives [status] to every entry of [entries]; a completed title also gets all its
  /// episodes (chapters) when their number is known. [onProgress] follows each write.
  ///
  /// [onSaved] gets each entry as MAL saved it (the list moves it to its new tab).
  Future<BulkResult> setStatus(
    List<ListEntryView> entries,
    ListEntryStatus status, {
    void Function(int done)? onProgress,
    void Function(ListEntryView old, ListEntryView saved)? onSaved,
  }) async {
    var done = 0;
    var failed = 0;
    for (final e in entries) {
      final isAnime = e.isAnime;
      final value = status.malValue(isAnime: isAnime);
      try {
        final update = await _service.update(
          e.id,
          isAnime: isAnime,
          patch: EntryPatch(
            status: value,
            progress: status == ListEntryStatus.completed && e.total > 0 ? e.total : null,
          ),
        );
        cache.put(
          e.id,
          CachedListStatus(status: value, score: update.entry.score, progress: update.entry.progress),
          category: e.category,
        );
        onSaved?.call(e, e.copyWith(status: status, score: update.entry.score, progress: update.entry.progress));
        done++;
      } catch (err) {
        debugPrint('Bulk status ${e.id}: $err');
        failed++;
      }
      onProgress?.call(done + failed);
    }
    return BulkResult(done, failed);
  }

  /// Removes every entry of [entries] from the user's list.
  Future<BulkResult> remove(
    List<ListEntryView> entries, {
    void Function(int done)? onProgress,
    void Function(ListEntryView removed)? onRemoved,
  }) async {
    var done = 0;
    var failed = 0;
    for (final e in entries) {
      try {
        await _service.delete(e.id, isAnime: e.isAnime);
        cache.remove(e.id, category: e.category);
        onRemoved?.call(e);
        done++;
      } catch (err) {
        debugPrint('Bulk remove ${e.id}: $err');
        failed++;
      }
      onProgress?.call(done + failed);
    }
    return BulkResult(done, failed);
  }
}

/// Runs [work] behind a dialog that shows how many of [total] titles are done, then a
/// message with the result. Answers the result.
Future<BulkResult> runBulkWithProgress(
  BuildContext context, {
  required int total,
  required Future<BulkResult> Function(void Function(int done) onProgress) work,
}) async {
  final progress = ValueNotifier<int>(0);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.maybeOf(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, done, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context).Bulk_Progress(done, total)),
              const SizedBox(height: 16),
              LinearProgressIndicator(value: total == 0 ? null : done / total),
            ],
          ),
        ),
      ),
    ),
  );
  final result = await work((done) => progress.value = done);
  navigator.pop();
  progress.dispose();
  final s = S.current;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(result.failed == 0 ? s.Bulk_Done(result.done) : s.Bulk_Partial(result.done, result.failed)),
    ));
  return result;
}
