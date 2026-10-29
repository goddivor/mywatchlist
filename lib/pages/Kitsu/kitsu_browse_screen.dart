import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show HomePageTileSize, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_row.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_media_tile.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// The titles of one Kitsu search as an endless grid (a home row's "View all", a category), or,
/// with [searchable], a search screen: a field at the top, anime and manga switch, results below.
class KitsuBrowseScreen extends StatefulWidget {
  final String title;
  final KitsuMediaQuery query;
  final bool searchable;

  /// Kitsu category id: a "Trending in <title>" row tops the grid.
  final String? trendingCategoryId;

  const KitsuBrowseScreen({
    super.key,
    required this.title,
    required this.query,
    this.searchable = false,
    this.trendingCategoryId,
  });

  /// The search screen of the Kitsu catalogue.
  factory KitsuBrowseScreen.search({Key? key, bool isAnime = true}) => KitsuBrowseScreen(
        key: key,
        title: S.current.Kitsu_Search_Title,
        query: KitsuMediaQuery(isAnime: isAnime, sort: 'popularityRank'),
        searchable: true,
      );

  @override
  State<KitsuBrowseScreen> createState() => _KitsuBrowseScreenState();
}

class _KitsuBrowseScreenState extends State<KitsuBrowseScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;

  late KitsuMediaQuery _query = widget.query;
  final List<KitsuMedia> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  int _generation = 0;

  bool get _waitingForText => widget.searchable && _query.text == null;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (!widget.searchable) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _field.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 600) _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore || _waitingForText) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await KitsuCatalog.instance.page(_query, offset: _items.length);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _restart(KitsuMediaQuery query) {
    _generation++;
    setState(() {
      _query = query;
      _items.clear();
      _hasMore = true;
      _loading = false;
      _failed = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _load();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _restart(_query.withText(value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: widget.searchable
            ? TextField(
                controller: _field,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: s.Kitsu_Search_Hint,
                  border: InputBorder.none,
                ),
                style: theme.textTheme.titleMedium,
                onChanged: _onTextChanged,
              )
            : Text(widget.title),
        actions: [
          if (widget.searchable && _field.text.isNotEmpty)
            IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _field.clear();
                _restart(_query.withText(null));
              },
            ),
        ],
        bottom: widget.searchable
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: true, label: Text(s.Explore_Anime)),
                      ButtonSegment(value: false, label: Text(s.Explore_Manga)),
                    ],
                    selected: {_query.isAnime},
                    onSelectionChanged: (v) => _restart(KitsuMediaQuery(
                      isAnime: v.first,
                      sort: _query.sort,
                      text: _query.text,
                    )),
                  ),
                ),
              )
            : null,
      ),
      body: _body(s),
    );
  }

  Widget _trendingRow() {
    final id = widget.trendingCategoryId!;
    final isAnime = widget.query.isAnime;
    final tile = getTileSizeValues(HomePageTileSize.m);
    return SliverToBoxAdapter(
      child: KitsuMediaRow(
        key: ValueKey('trending-category:$id:$isAnime'),
        cacheKey: 'kitsu:trending:category:$id:${isAnime ? 'anime' : 'manga'}',
        title: S.current.Kitsu_Trending_In(widget.title),
        isAnime: isAnime,
        load: () => KitsuCatalog.instance.trendingInCategory(id, isAnime: isAnime),
        cardWidth: tile.containerHeight * (2 / 3),
        cardHeight: tile.containerHeight,
        hideWhenEmpty: true,
      ),
    );
  }

  Widget _body(S s) {
    if (_waitingForText) {
      return HomeMessage(icon: Icons.search_rounded, text: s.Kitsu_Search_Prompt);
    }
    if (_items.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_failed) {
        return Center(
          child: HomeMessage(
            icon: Icons.cloud_off_outlined,
            text: s.Hw_Section_Failed,
            actionLabel: s.Hw_Retry,
            onAction: _load,
          ),
        );
      }
      return HomeMessage(
        icon: Icons.inbox_outlined,
        text: widget.searchable ? s.Kitsu_Search_Empty(_query.text ?? '') : s.Hw_Empty_Items,
      );
    }
    final width = MediaQuery.sizeOf(context).width;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        if (widget.trendingCategoryId != null && !widget.searchable) _trendingRow(),
        SliverPadding(
          padding: const EdgeInsets.all(12),
          sliver: SliverGrid.builder(
            gridDelegate: KitsuMediaTile.gridDelegate(width),
            itemCount: _items.length,
            itemBuilder: (context, i) => KitsuMediaRow.tile(_items[i]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : _failed
                      ? TextButton(onPressed: _load, child: Text(s.Hw_Retry))
                      : const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
