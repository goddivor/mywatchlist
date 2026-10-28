import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_feeds.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_media_widgets.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';

/// Explore tab for Simkl: a search bar over the Simkl anime catalogue and the three lists Simkl
/// publishes (airing today, trending, new premieres) as a poster grid. Simkl has no manga, so
/// there is no anime / manga switch.
class SimklExplorePage extends StatefulWidget {
  const SimklExplorePage({super.key, this.service});

  /// Test hook; defaults to the shared Simkl discover service.
  final SimklDiscoverService? service;

  @override
  State<SimklExplorePage> createState() => _SimklExplorePageState();
}

enum _Load { loading, ready, failed }

class _SimklExplorePageState extends State<SimklExplorePage> {
  final TextEditingController _controller = TextEditingController();
  final Map<SimklFeed, List<SimklMedia>> _feeds = {};
  Timer? _debounce;
  SimklFeed _feed = SimklFeed.trending;
  _Load _feedState = _Load.loading;
  String _query = '';
  List<SimklMedia> _results = const [];
  _Load _searchState = _Load.ready;
  int _token = 0;

  SimklDiscoverService get _service => widget.service ?? SimklDiscoverService.instance;
  bool get _searching => _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool force = false}) async {
    final feed = _feed;
    final kept = force ? null : _feeds[feed] ?? HomeSectionCache.fresh<List<SimklMedia>>(feed.cacheKey, const Duration(minutes: 30));
    if (kept != null) {
      _feeds[feed] = kept;
      setState(() => _feedState = _Load.ready);
      return;
    }
    final token = ++_token;
    setState(() => _feedState = _Load.loading);
    try {
      final items = await feed.load(_service);
      HomeSectionCache.put(feed.cacheKey, items);
      if (!mounted || token != _token) return;
      setState(() {
        _feeds[feed] = items;
        _feedState = _Load.ready;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _feedState = _Load.failed);
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.isEmpty) {
      _token++;
      setState(() {
        _query = '';
        _results = const [];
        _searchState = _Load.ready;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String text) async {
    final token = ++_token;
    setState(() {
      _query = text;
      _searchState = _Load.loading;
    });
    try {
      final items = await _service.search(text);
      if (!mounted || token != _token) return;
      setState(() {
        _results = items;
        _searchState = _Load.ready;
      });
    } catch (_) {
      if (!mounted || token != _token) return;
      setState(() => _searchState = _Load.failed);
    }
  }

  void _pickFeed(SimklFeed feed) {
    if (feed == _feed) return;
    _feed = feed;
    _loadFeed();
  }

  Future<void> _onRefresh() => _searching ? _search(_query) : _loadFeed(force: true);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = _searching ? _searchState : _feedState;
    final items = _searching ? _results : (_feeds[_feed] ?? const <SimklMedia>[]);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              floating: true,
              snap: true,
              titleSpacing: 0,
              toolbarHeight: kToolbarHeight,
              title: AppBarHome(title: s.Hw_Tab_Explore, transparent: true, showSettings: true),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
                child: SearchBar(
                  controller: _controller,
                  hintText: s.Sk_Search_Hint,
                  leading: const Icon(Icons.search_rounded),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
                  onChanged: _onQuery,
                  trailing: [
                    if (_searching || _controller.text.isNotEmpty)
                      IconButton(
                        tooltip: s.UserList_Clear,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _controller.clear();
                          _onQuery('');
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (!_searching)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    children: [
                      for (final feed in SimklFeed.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(feed.title),
                            selected: feed == _feed,
                            onSelected: (_) => _pickFeed(feed),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ..._content(context, state, items),
            SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, _Load state, List<SimklMedia> items) {
    final s = S.of(context);
    switch (state) {
      case _Load.loading:
        return const [
          SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 24), child: SimklRowSkeleton())),
        ];
      case _Load.failed:
        return [
          SliverToBoxAdapter(
            child: HomeMessage(
              icon: Icons.cloud_off_outlined,
              text: s.Sk_Load_Failed,
              actionLabel: s.Hw_Retry,
              onAction: () => _searching ? _search(_query) : _loadFeed(force: true),
            ),
          ),
        ];
      case _Load.ready:
        if (items.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: HomeMessage(
                icon: _searching ? Icons.search_off_rounded : Icons.movie_filter_outlined,
                text: _searching ? s.Sk_Search_Empty(_query) : s.Sk_Feed_Empty,
              ),
            ),
          ];
        }
        return [
          SimklMediaGrid(items: items, onTap: (media) => openSimklMedia(context, media, service: _service)),
        ];
    }
  }
}
