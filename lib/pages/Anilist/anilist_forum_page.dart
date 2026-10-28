import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_thread_tile.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumSkeleton;
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeMessage;

/// The AniList forum tab: the threads, sorted by recent activity, newest, most viewed or most
/// replied, loaded page by page. A thread opens on anilist.co.
class AnilistForumPage extends StatefulWidget {
  final AnilistDiscoverService? service;

  const AnilistForumPage({super.key, this.service});

  @override
  State<AnilistForumPage> createState() => _AnilistForumPageState();
}

class _AnilistForumPageState extends State<AnilistForumPage> {
  /// AniList `ThreadSort` values, in chip order.
  static const _sorts = ['REPLIED_AT_DESC', 'ID_DESC', 'VIEW_COUNT_DESC', 'REPLY_COUNT_DESC'];

  final List<AnilistThread> _threads = [];
  String _sort = _sorts.first;
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;

  AnilistDiscoverService get _service => widget.service ?? AnilistDiscoverService.instance;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  String _label(String sort, S s) => switch (sort) {
        'ID_DESC' => s.Al_Forum_Newest,
        'VIEW_COUNT_DESC' => s.Al_Forum_Most_Viewed,
        'REPLY_COUNT_DESC' => s.Al_Forum_Most_Replied,
        _ => s.Al_Forum_Recent,
      };

  void _setSort(String sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _generation++;
      _threads.clear();
      _page = 0;
      _hasNext = true;
      _loading = false;
      _error = null;
    });
    _load();
  }

  Future<void> _refresh() async {
    _generation++;
    _threads.clear();
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
    await _load();
  }

  Future<void> _load({bool initial = false}) async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    if (initial) {
      _loading = true;
    } else if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await _service.threads(sort: _sort, page: _page + 1);
      if (!mounted || generation != _generation) return;
      final known = {for (final t in _threads) t.id};
      setState(() {
        _page++;
        _threads.addAll(page.items.where((t) => !known.contains(t.id)));
        _hasNext = page.hasNext && page.items.isNotEmpty;
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

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.extentAfter < 500) _load();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          AppBarHome(
            title: s.Al_Forum_Title,
            showSearch: false,
            showBookmarks: false,
            showCalendar: false,
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _sorts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ChoiceChip(
                label: Text(_label(_sorts[i], s)),
                selected: _sort == _sorts[i],
                onSelected: (_) => _setSort(_sorts[i]),
              ),
            ),
          ),
          Expanded(child: _body(s)),
        ],
      ),
    );
  }

  Widget _body(S s) {
    if (_threads.isEmpty) {
      if (_loading) return const ForumSkeleton(count: 8);
      if (_error != null) {
        return Center(
          child: HomeMessage(
            icon: Icons.cloud_off_outlined,
            text: s.Al_Load_Failed,
            actionLabel: s.Al_Retry,
            onAction: _load,
          ),
        );
      }
      return Center(child: HomeMessage(icon: Icons.forum_outlined, text: s.Fc_Topics_Empty_Title));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          itemCount: _threads.length + 1,
          itemBuilder: (context, i) {
            if (i < _threads.length) return AnilistThreadTile(thread: _threads[i]);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : _error != null
                        ? TextButton(onPressed: _load, child: Text(s.Al_Retry))
                        : const SizedBox.shrink(),
              ),
            );
          },
        ),
      ),
    );
  }
}
