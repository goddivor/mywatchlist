import 'package:flutter/material.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_card.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_kind_info.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_opener.dart';

enum _Sort { recent, title }

/// Saved anime, manga, characters, people, forum topics, users, clubs, news, featured
/// articles and interest stacks.
///
/// Filters: one chip per kind that has items (with its count), one per tracker when several
/// trackers have items, text search, sort. A list of forum topics only shows as rows (they
/// have no picture), anything else as a grid of covers. Removing shows an Undo. Open it with
/// `AppRoutes.openBookmarks`; other units save items through [Bookmarks].
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  BookmarkKind? _kind;
  String? _tracker;
  _Sort _sort = _Sort.recent;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
    if (_searching) _searchFocus.requestFocus();
  }

  Future<void> _remove(Bookmark b) async {
    final messenger = ScaffoldMessenger.of(context);
    await Bookmarks.remove(tracker: b.tracker, kind: b.kind, id: b.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(S.current.Bm_Removed),
        action: SnackBarAction(
          label: S.current.Bm_Undo,
          onPressed: () => Bookmarks.add(b),
        ),
      ));
  }

  Future<void> _confirmClear(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.Bm_Clear_Title),
        content: Text(S.current.Bm_Clear_Body(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.current.Cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.current.Bm_Remove),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Bookmarks.listenable.clear();
      if (mounted) {
        setState(() {
          _kind = null;
          _tracker = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Bookmarks.listenable;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final all = store.all;
        final kinds = BookmarkKind.values
            .where((k) => all.any((b) => b.kind == k))
            .toList();
        final trackers = all.map((b) => b.tracker).toSet().toList()..sort();
        // A filter whose items are all gone stops applying instead of showing nothing.
        final kind = kinds.contains(_kind) ? _kind : null;
        final tracker = trackers.contains(_tracker) ? _tracker : null;
        final query = _search.text.trim().toLowerCase();
        final shown = all.where((b) {
          if (kind != null && b.kind != kind) return false;
          if (tracker != null && b.tracker != tracker) return false;
          if (query.isNotEmpty && !b.title.toLowerCase().contains(query)) {
            return false;
          }
          return true;
        }).toList();
        if (_sort == _Sort.title) {
          shown.sort(
              (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        }
        return Scaffold(
          appBar: _buildAppBar(all.length),
          body: !store.loaded
              ? const Center(child: CircularProgressIndicator())
              : all.isEmpty
                  ? _Empty(
                      icon: Icons.bookmark_outline,
                      title: S.current.Bm_Empty_Title,
                    )
                  : Column(
                      children: [
                        _Filters(
                          all: all,
                          kinds: kinds,
                          trackers: trackers,
                          kind: kind,
                          tracker: tracker,
                          onKind: (k) => setState(() => _kind = k),
                          onTracker: (t) => setState(() => _tracker = t),
                        ),
                        Expanded(
                          child: shown.isEmpty
                              ? _Empty(
                                  icon: Icons.search_off,
                                  title: query.isNotEmpty
                                      ? S.current.Bm_No_Match
                                      : S.current.Bm_Empty_Kind(
                                          kind?.label ?? ''),
                                )
                              : shown.every((b) => b.kind.listsAsRows)
                                  ? _Rows(
                                      items: shown,
                                      onOpen: (b) => openBookmark(context, b),
                                      onRemove: _remove,
                                    )
                                  : _Grid(
                                      items: shown,
                                      onOpen: (b) => openBookmark(context, b),
                                      onRemove: _remove,
                                    ),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(int total) {
    final theme = Theme.of(context);
    return AppBar(
      title: _searching
          ? TextField(
              controller: _search,
              focusNode: _searchFocus,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: S.current.Bm_Search_Hint,
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.current.Bookmarks),
                if (total > 0)
                  Text(
                    S.current.Bm_Count(total),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
      actions: [
        if (total > 0)
          IconButton(
            tooltip: _searching ? S.current.Bm_Clear_Search : S.current.Search,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        if (total > 0)
          PopupMenuButton<Object>(
            tooltip: S.current.Show_Menu,
            onSelected: (v) {
              if (v is _Sort) {
                setState(() => _sort = v);
              } else {
                _confirmClear(total);
              }
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<Object>(
                value: _Sort.recent,
                checked: _sort == _Sort.recent,
                child: Text(S.current.Bm_Sort_Recent),
              ),
              CheckedPopupMenuItem<Object>(
                value: _Sort.title,
                checked: _sort == _Sort.title,
                child: Text(S.current.Bm_Sort_Title),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                value: 'clear',
                child: Text(S.current.Bm_Clear_All),
              ),
            ],
          ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  final List<Bookmark> all;
  final List<BookmarkKind> kinds;
  final List<String> trackers;
  final BookmarkKind? kind;
  final String? tracker;
  final ValueChanged<BookmarkKind?> onKind;
  final ValueChanged<String?> onTracker;

  const _Filters({
    required this.all,
    required this.kinds,
    required this.trackers,
    required this.kind,
    required this.tracker,
    required this.onKind,
    required this.onTracker,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (kinds.length > 1)
        ChoiceChip(
          label: Text(S.current.Bm_All),
          selected: kind == null,
          onSelected: (_) => onKind(null),
        ),
      for (final k in kinds)
        if (kinds.length > 1)
          ChoiceChip(
            avatar: Icon(k.icon, size: 18),
            label: Text('${k.label} · ${all.where((b) => b.kind == k).length}'),
            selected: kind == k,
            onSelected: (_) => onKind(kind == k ? null : k),
          ),
    ];
    final trackerChips = <Widget>[
      if (trackers.length > 1)
        for (final t in trackers)
          FilterChip(
            label: Text(AppRoutes.trackerLabel(
                AccountType.values.asNameMap()[t] ?? AccountType.none)),
            selected: tracker == t,
            onSelected: (_) => onTracker(tracker == t ? null : t),
          ),
    ];
    Widget row(List<Widget> children) => SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            scrollDirection: Axis.horizontal,
            itemCount: children.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => children[i],
          ),
        );
    return Column(
      children: [
        if (chips.isNotEmpty) row(chips),
        if (trackerChips.isNotEmpty) row(trackerChips),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  final List<Bookmark> items;
  final ValueChanged<Bookmark> onOpen;
  final ValueChanged<Bookmark> onRemove;

  const _Grid({
    required this.items,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final b = items[i];
        return BookmarkCard(
          key: ValueKey(b.key),
          bookmark: b,
          onTap: () => onOpen(b),
          onRemove: () => onRemove(b),
        );
      },
    );
  }
}

/// Picture-less bookmarks (forum topics) as rows, like DailyAL's forum topic list.
class _Rows extends StatelessWidget {
  final List<Bookmark> items;
  final ValueChanged<Bookmark> onOpen;
  final ValueChanged<Bookmark> onRemove;

  const _Rows({
    required this.items,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final b = items[i];
        return BookmarkRow(
          key: ValueKey(b.key),
          bookmark: b,
          onTap: () => onOpen(b),
          onRemove: () => onRemove(b),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;

  const _Empty({required this.icon, required this.title, this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.onPrimaryContainer),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
