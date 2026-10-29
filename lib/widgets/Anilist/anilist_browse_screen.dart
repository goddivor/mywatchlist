import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_filter_sheet.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_labels.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_result_tiles.dart';
import 'package:mywatchlist/widgets/Anilist/search/anilist_tag_explorer.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;
import 'package:shared_preferences/shared_preferences.dart';

/// AniList's search and browse screen.
///
/// - A "view all" page of a home or explore row ([searchable] false): the titles of [query],
///   with its filter and sort bar.
/// - AniList's own search ([searchable]): a text field, the kinds Anime · Manga · Characters ·
///   Staff · Studios · Users, and for titles the filter sheet (every `Page.media` filter),
///   the 36 sorts and removable chips of the active filters. With no text, titles come by
///   popularity and people by favourites.
///
/// Results are DailyAL-style rows (`#rank`, score and members, title, type line, own status,
/// edit pencil while signed in) or a grid; the choice is kept on the device.
class AnilistBrowseScreen extends StatefulWidget {
  final String title;
  final AnilistMediaQuery query;
  final bool searchable;
  final AnilistDiscoverService? service;
  final AnilistCatalog? catalog;

  /// The kind the search opens on; titles of [query]'s category by default.
  final AnilistSearchKind? kind;

  const AnilistBrowseScreen({
    super.key,
    required this.title,
    required this.query,
    this.searchable = false,
    this.service,
    this.catalog,
    this.kind,
  });

  @override
  State<AnilistBrowseScreen> createState() => _AnilistBrowseScreenState();
}

class _AnilistBrowseScreenState extends State<AnilistBrowseScreen> {
  static const int _perPage = 30;
  static const String _layoutKey = 'anilist_search_layout_v1';

  final TextEditingController _text = TextEditingController();
  Timer? _debounce;
  late AnilistMediaQuery _query = widget.query;
  late AnilistSearchKind _kind =
      widget.kind ?? (widget.query.category == 'manga' ? AnilistSearchKind.manga : AnilistSearchKind.anime);
  final List<AnilistSearchMedia> _items = [];
  final List<AnilistSearchHit> _hits = [];
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;
  bool _grid = false;
  AnilistCatalogData? _catalog;

  AnilistDiscoverService get _service => widget.service ?? AnilistDiscoverService.instance;
  AnilistCatalog get _catalogSource => widget.catalog ?? AnilistCatalog.instance;

  int get _count => _kind.isMedia ? _items.length : _hits.length;

  @override
  void initState() {
    super.initState();
    _text.text = widget.query.search ?? '';
    _catalog = _catalogSource.cached;
    _catalogSource.load().then((c) {
      if (mounted) setState(() => _catalog = c);
    });
    SharedPreferences.getInstance().then((p) {
      final grid = p.getString(_layoutKey) == 'grid';
      if (mounted && grid != _grid) setState(() => _grid = grid);
    }).catchError((_) {});
    // No setState yet: the first build already shows the loading state.
    _loadMore(initial: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _restart() {
    _generation++;
    _items.clear();
    _hits.clear();
    _page = 0;
    _hasNext = true;
    _error = null;
    _loading = false;
    _loadMore();
  }

  Future<void> _loadMore({bool initial = false}) async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    if (initial) {
      _loading = true;
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final next = _page + 1;
      final (int added, bool hasNext) result;
      if (_kind.isMedia) {
        final page = await _service.search(_query, page: next, perPage: _perPage);
        if (!mounted || generation != _generation) return;
        final known = {for (final m in _items) m.id};
        final fresh = page.items.where((m) => known.add(m.id)).toList();
        _items.addAll(fresh);
        result = (page.items.length, page.hasNext);
      } else {
        final page = await _service.people(_kind, _query.search ?? '', page: next, perPage: _perPage);
        if (!mounted || generation != _generation) return;
        final known = {for (final h in _hits) h.id};
        _hits.addAll(page.items.where((h) => known.add(h.id)));
        result = (page.items.length, page.hasNext);
      }
      setState(() {
        _page = next;
        _hasNext = result.$2 && result.$1 > 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _setQuery(AnilistMediaQuery q) {
    if (q == _query) return;
    setState(() => _query = q);
    _restart();
  }

  void _onText(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _setQuery(_query.copyWith(search: value));
    });
  }

  void _setKind(AnilistSearchKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      if (kind.isMedia) _query = _query.forCategory(kind == AnilistSearchKind.manga ? 'manga' : 'anime');
    });
    _restart();
  }

  Future<void> _toggleLayout() async {
    setState(() => _grid = !_grid);
    try {
      await (await SharedPreferences.getInstance()).setString(_layoutKey, _grid ? 'grid' : 'list');
    } catch (_) {}
  }

  Future<void> _openFilters() async {
    final catalog = _catalog ?? await _catalogSource.load();
    final adult = await _service.adultAllowed();
    if (!mounted) return;
    final picked = await showAnilistFilterSheet(
      context,
      query: _query,
      catalog: catalog,
      signedIn: _service.signedIn,
      adultAllowed: adult,
    );
    if (picked != null) _setQuery(picked);
  }

  Future<void> _openSort() async {
    final sort = await showAnilistSortSheet(context, query: _query);
    if (sort != null) _setQuery(_query.copyWith(sort: sort));
  }

  void _onEdited(AnilistSearchMedia edited) {
    final i = _items.indexWhere((m) => m.id == edited.id);
    if (i >= 0) setState(() => _items[i] = edited);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 600 && !_loading && _hasNext && _error == null) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = Theme.of(context).colorScheme;
    final tag = _query.tag != null ? _catalog?.tagNamed(_query.tag!) : null;
    final bars = <Widget>[
      if (widget.searchable) _KindBar(kind: _kind, onChanged: _setKind),
      if (_kind.isMedia)
        _FilterBar(
          query: _query,
          catalog: _catalog,
          onFilters: _openFilters,
          onSort: _openSort,
          onChanged: _setQuery,
        ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: widget.searchable
            ? TextField(
                controller: _text,
                autofocus: (widget.query.search ?? '').isEmpty,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: s.Als_Search_Hint, border: InputBorder.none),
                onChanged: _onText,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  _setQuery(_query.copyWith(search: v));
                },
              )
            : Text(widget.title),
        actions: [
          if (tag != null)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: tag.name,
              onPressed: () => showAnilistTagInfo(context, tag),
            ),
          if (_kind.isMedia)
            IconButton(
              icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
              tooltip: _grid ? s.Als_Layout_List : s.Als_Layout_Grid,
              onPressed: _toggleLayout,
            ),
        ],
        bottom: bars.isEmpty
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(bars.length * _barHeight),
                child: Column(children: bars),
              ),
      ),
      backgroundColor: cs.surface,
      body: _body(s),
    );
  }

  Widget _body(S s) {
    if (_count == 0) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return Center(
          child: HomeMessage(
            icon: Icons.cloud_off_outlined,
            text: s.Al_Load_Failed,
            actionLabel: s.Al_Retry,
            onAction: _loadMore,
          ),
        );
      }
      return HomeMessage(icon: Icons.inbox_outlined, text: s.Al_No_Results);
    }
    final signedIn = _service.signedIn;
    final Widget list;
    if (!_kind.isMedia) {
      list = SliverFixedExtentList(
        itemExtent: AnilistHitRow.height,
        delegate: SliverChildBuilderDelegate(
          (context, i) => AnilistHitRow(hit: _hits[i]),
          childCount: _hits.length,
        ),
      );
    } else if (_grid) {
      list = SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.52,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) => RepaintBoundary(child: AnilistResultCard(item: _items[i])),
        ),
      );
    } else {
      list = SliverFixedExtentList(
        itemExtent: AnilistResultRow.height,
        delegate: SliverChildBuilderDelegate(
          (context, i) => RepaintBoundary(
            child: AnilistResultRow(
              item: _items[i],
              index: i,
              editable: signedIn,
              onEdited: _onEdited,
            ),
          ),
          childCount: _items.length,
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        slivers: [
          list,
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                    : _error != null
                        ? TextButton(onPressed: _loadMore, child: Text(s.Al_Retry))
                        : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _barHeight = 48;

class _KindBar extends StatelessWidget {
  final AnilistSearchKind kind;
  final ValueChanged<AnilistSearchKind> onChanged;
  const _KindBar({required this.kind, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _barHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final k in AnilistSearchKind.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(AnilistLabels.kind(k)),
                selected: k == kind,
                showCheckmark: false,
                onSelected: (_) => onChanged(k),
              ),
            ),
        ],
      ),
    );
  }
}

/// Filters button (with the count), sort button, then one removable chip per active filter.
class _FilterBar extends StatelessWidget {
  final AnilistMediaQuery query;
  final AnilistCatalogData? catalog;
  final VoidCallback onFilters;
  final VoidCallback onSort;
  final ValueChanged<AnilistMediaQuery> onChanged;

  const _FilterBar({
    required this.query,
    required this.catalog,
    required this.onFilters,
    required this.onSort,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final count = query.filterCount;
    final active = activeAnilistFilters(query, catalog: catalog);
    final sortKey = AnilistSorts.keyOf(query.effectiveSort);
    final descending = query.effectiveSort == AnilistSorts.searchMatch || AnilistSorts.isDescending(query.effectiveSort);
    return SizedBox(
      height: _barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: 2 + active.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          if (i == 0) {
            return ActionChip(
              avatar: Badge(
                isLabelVisible: count > 0,
                label: Text('$count'),
                child: const Icon(Icons.tune_rounded, size: 18),
              ),
              label: Text(s.Als_Filters),
              onPressed: onFilters,
            );
          }
          if (i == 1) {
            return ActionChip(
              avatar: Icon(
                descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 18,
              ),
              label: Text(AnilistLabels.sortKey(sortKey)),
              onPressed: onSort,
            );
          }
          final f = active[i - 2];
          return InputChip(
            label: Text(f.label),
            onDeleted: () => onChanged(f.remove()),
          );
        },
      ),
    );
  }
}
