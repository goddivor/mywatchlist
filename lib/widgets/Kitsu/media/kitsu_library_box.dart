import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart' show KitsuMediaKind;
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_entry_sheet.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_parts.dart' show kitsuPagePadding;
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/Kitsu/profile/kitsu_profile_rows.dart' show kitsuStatusLabel;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// The signed-in user's side of one title: their library entry and their favourite. The title
/// page creates one, the library box and the app bar heart listen to it. Every write starts from
/// a tap and updates the state with what Kitsu answered.
class KitsuMyTitle extends ChangeNotifier {
  KitsuMyTitle({
    required this.kind,
    required this.mediaId,
    required this.total,
    KitsuMyLibrary? service,
  }) : service = service ?? KitsuMyLibrary.instance;

  final KitsuMediaKind kind;
  final String mediaId;

  /// Episodes or chapters, 0 when unknown.
  final int total;
  final KitsuMyLibrary service;

  bool loading = true;

  /// The entry could not be read: the box stays hidden (no error card for trackers).
  bool failed = false;
  bool busy = false;
  KitsuMyEntry? entry;
  String? favouriteId;
  bool _disposed = false;

  bool get isFavourite => favouriteId != null;
  int get progress => entry?.progress ?? 0;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    loading = true;
    failed = false;
    _notify();
    try {
      final results = await Future.wait<Object?>([
        service.entryOf(kind, mediaId),
        service.favouriteOf(kind, mediaId).catchError((Object _) => null),
      ]);
      entry = results[0] as KitsuMyEntry?;
      favouriteId = results[1] as String?;
    } catch (_) {
      failed = true;
    }
    loading = false;
    _notify();
  }

  Future<bool> _write(Future<void> Function() run) async {
    if (busy) return false;
    busy = true;
    _notify();
    try {
      await run();
      return true;
    } catch (_) {
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  /// Adds the title with [status], or moves the entry to it.
  Future<bool> setStatus(ListEntryStatus status) => _write(() async {
        final e = entry;
        final completing = status == ListEntryStatus.completed && total > 0;
        entry = e == null
            ? await service.add(kind, mediaId, status, progress: completing ? total : null)
            : await service.update(e.id, status: status, progress: completing ? total : null);
      });

  /// Sets the progress to [value]; reaching the total completes the entry. Returns false when
  /// the write failed.
  Future<bool> setProgress(int value) => _write(() async {
        final e = entry;
        if (e == null) return;
        final done = total > 0 && value >= total;
        entry = await service.update(
          e.id,
          progress: total > 0 ? value.clamp(0, total) : value,
          status: done
              ? ListEntryStatus.completed
              : (e.status == ListEntryStatus.planned && value > 0 ? ListEntryStatus.current : null),
        );
      });

  /// Rates the entry (`ratingTwenty`, 0 removes the rating).
  Future<bool> setRating(int twenty) => _write(() async {
        final e = entry;
        if (e == null) return;
        entry = await service.update(e.id, rating: twenty);
      });

  Future<bool> toggleFavourite() => _write(() async {
        final id = favouriteId;
        if (id == null) {
          favouriteId = await service.addFavourite(kind, mediaId);
        } else {
          await service.removeFavourite(id);
          favouriteId = null;
        }
      });

  /// The answer of the edit sheet.
  void apply(KitsuEntryResult result) {
    switch (result) {
      case KitsuEntrySaved(:final entry):
        this.entry = entry;
      case KitsuEntryRemoved():
        entry = null;
    }
    _notify();
  }
}

/// Shows a short "couldn't save" message.
void kitsuWriteFailed(BuildContext context) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(S.current.Kr_Save_Failed)));
}

/// After the last episode: asks for the rating, as Kitsu does when a title is completed.
Future<void> kitsuAskRatingOnComplete(BuildContext context, KitsuMyTitle my) async {
  final e = my.entry;
  if (e == null || e.status != ListEntryStatus.completed || e.isRated) return;
  final picked = await showKitsuRatingSheet(context, title: S.current.Kr_Completed_Rate);
  if (picked == null || picked == 0 || !context.mounted) return;
  if (!await my.setRating(picked) && context.mounted) kitsuWriteFailed(context);
}

/// The title page's library box (Kitsu's sidebar box): not in the library = "Add to library"
/// with the five statuses; in it = the status, the rating in the account's system, the progress
/// with +1, the user's reaction and Edit.
class KitsuLibraryBox extends StatelessWidget {
  final KitsuMyTitle my;
  final String title;

  const KitsuLibraryBox({super.key, required this.my, required this.title});

  bool get _anime => my.kind == KitsuMediaKind.anime;

  static const List<ListEntryStatus> statuses = [
    ListEntryStatus.current,
    ListEntryStatus.planned,
    ListEntryStatus.completed,
    ListEntryStatus.onHold,
    ListEntryStatus.dropped,
  ];

  Future<void> _status(BuildContext context, ListEntryStatus status) async {
    if (!await my.setStatus(status)) {
      if (context.mounted) kitsuWriteFailed(context);
      return;
    }
    if (context.mounted) await kitsuAskRatingOnComplete(context, my);
  }

  Future<void> _plusOne(BuildContext context) async {
    if (!await my.setProgress(my.progress + 1)) {
      if (context.mounted) kitsuWriteFailed(context);
      return;
    }
    if (context.mounted) await kitsuAskRatingOnComplete(context, my);
  }

  Future<void> _rate(BuildContext context) async {
    final picked = await showKitsuRatingSheet(context, current: my.entry?.rating);
    if (picked == null || !context.mounted) return;
    if (!await my.setRating(picked) && context.mounted) kitsuWriteFailed(context);
  }

  Future<void> _edit(BuildContext context) async {
    final result = await showKitsuEntrySheet(
      context,
      kind: my.kind,
      mediaId: my.mediaId,
      title: title,
      total: my.total,
      initial: my.entry,
      service: my.service,
    );
    if (result != null) my.apply(result);
  }

  Widget _statusMenu(BuildContext context, {required Widget Function(VoidCallback? open) button}) {
    return MenuAnchor(
      menuChildren: [
        for (final st in statuses)
          MenuItemButton(
            onPressed: () => _status(context, st),
            child: Text(kitsuStatusLabel(st, isAnime: _anime)),
          ),
      ],
      builder: (context, controller, _) => button(my.busy ? null : () => controller.isOpen ? controller.close() : controller.open()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: my,
      builder: (context, _) {
        if (my.loading) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(kitsuPagePadding, 16, kitsuPagePadding, 0),
            child: SizedBox(height: 48),
          );
        }
        if (my.failed) return const SizedBox.shrink();
        final s = S.current;
        final e = my.entry;
        if (e == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(kitsuPagePadding, 16, kitsuPagePadding, 0),
            child: _statusMenu(
              context,
              button: (open) => FilledButton.icon(
                onPressed: open,
                icon: const Icon(Icons.add_rounded),
                label: Text(s.Kr_Add_To_Library),
              ),
            ),
          );
        }
        return _Box(box: this, entry: e);
      },
    );
  }
}

class _Box extends StatelessWidget {
  final KitsuLibraryBox box;
  final KitsuMyEntry entry;

  const _Box({required this.box, required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.current;
    final my = box.my;
    final anime = box._anime;
    final role = entry.status.colors(context);
    final total = my.total;
    final canStep = entry.status != ListEntryStatus.completed && (total == 0 || entry.progress < total);
    final progressText = total > 0
        ? (anime ? s.Kr_Ep_Of(entry.progress, total) : s.Kr_Ch_Of(entry.progress, total))
        : (anime ? s.Kr_Ep_N(entry.progress) : s.Kr_Ch_N(entry.progress));
    return Padding(
      padding: const EdgeInsets.fromLTRB(kitsuPagePadding, 16, kitsuPagePadding, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  box._statusMenu(
                    context,
                    button: (open) => FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: role.container,
                        foregroundColor: role.onContainer,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: open,
                      icon: Icon(entry.status.icon, size: 18),
                      label: Text(kitsuStatusLabel(entry.status, isAnime: anime)),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: my.busy ? null : () => box._rate(context),
                    child: KitsuRatingBadge(
                      twenty: entry.rating,
                      size: 18,
                      empty: Text(s.Kr_Rate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(progressText, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: total > 0 ? (entry.progress / total).clamp(0.0, 1.0) : (entry.progress > 0 ? 1 : 0),
                            minHeight: 6,
                            color: role.color,
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canStep) ...[
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: my.busy ? null : () => box._plusOne(context),
                      child: Text(s.Kr_Plus_One),
                    ),
                  ],
                ],
              ),
              if (entry.reaction != null) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.reaction!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: my.busy ? null : () => box._edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(s.Kr_Edit_Entry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Next episode: Ep 6 · Fri, Nov 1, 3:00 PM" while a title is airing (Kitsu's `nextRelease`).
class KitsuNextEpisodeLine extends StatelessWidget {
  final DateTime release;

  /// The episode number, when known (the user's progress + 1).
  final int? number;
  final bool isAnime;

  const KitsuNextEpisodeLine({super.key, required this.release, this.number, this.isAnime = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = release.toLocal();
    final when = '${DateFormat.MMMEd().format(local)}, ${DateFormat.jm().format(local)}';
    final s = S.current;
    final text = number == null
        ? s.Kr_Next_Release(when)
        : (isAnime ? s.Kr_Next_Episode(number!, when) : s.Kr_Next_Chapter(number!, when));
    return Padding(
      padding: const EdgeInsets.fromLTRB(kitsuPagePadding + 4, 12, kitsuPagePadding, 0),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The app bar heart: the title is one of the user's favourites or not.
class KitsuFavouriteButton extends StatelessWidget {
  final KitsuMyTitle my;

  const KitsuFavouriteButton({super.key, required this.my});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: my,
      builder: (context, _) {
        if (my.loading || my.failed) return const SizedBox.shrink();
        final fav = my.isFavourite;
        return IconButton(
          tooltip: fav ? S.current.Kr_Unfavourite : S.current.Kr_Favourite,
          isSelected: fav,
          onPressed: my.busy
              ? null
              : () async {
                  if (!await my.toggleFavourite() && context.mounted) kitsuWriteFailed(context);
                },
          icon: const Icon(Icons.favorite_border_rounded),
          selectedIcon: Icon(Icons.favorite_rounded, color: Theme.of(context).colorScheme.error),
        );
      },
    );
  }
}
