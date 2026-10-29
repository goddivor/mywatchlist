import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_thread_tile.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_feed.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_reviews_feed.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_social_ui.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_thread_composer.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart' show ForumMessage, ForumSkeleton;

/// The AniList "Forum" tab: Forum (threads by sort, category, subscribed, search; a thread
/// opens in the app) and Activity (the Following / Global feed, post a status). The app bar
/// menu also opens the latest reviews and the new thread editor.
///
/// With [mediaId] it is the forum of one title (no Activity tab).
///
/// With [standalone] it is a page of its own: a real app bar with a back button instead of
/// the home bar (which, pushed over a page, would cover it). Use it for a pushed page, such as
/// a title's forum or the home "view all".
class AnilistForumPage extends StatefulWidget {
  const AnilistForumPage({
    super.key,
    this.service,
    this.initialTab = 0,
    this.mediaId,
    this.standalone = false,
  });

  final bool standalone;

  final AnilistSocialService? service;

  /// 0 = Forum, 1 = Activity.
  final int initialTab;
  final int? mediaId;

  @override
  State<AnilistForumPage> createState() => _AnilistForumPageState();
}

class _AnilistForumPageState extends State<AnilistForumPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.mediaId == null ? 2 : 1,
    vsync: this,
    initialIndex: widget.mediaId == null ? widget.initialTab.clamp(0, 1) : 0,
  );

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _menu(_ForumAction action) {
    switch (action) {
      case _ForumAction.reviews:
        openAnilistReviews(context);
      case _ForumAction.newThread:
        openAnilistThreadComposer(
          context,
          mediaIds: [if (widget.mediaId != null) widget.mediaId!],
          service: _service,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final single = widget.mediaId != null;
    final standalone = widget.standalone;
    final menu = PopupMenuButton<_ForumAction>(
      icon: Icon(Icons.more_vert, color: scheme.onSurfaceVariant),
      onSelected: _menu,
      itemBuilder: (_) => [
        if (!single)
          PopupMenuItem(value: _ForumAction.reviews, child: Text(s.Als_Latest_Reviews)),
        if (_service.signedIn)
          PopupMenuItem(value: _ForumAction.newThread, child: Text(s.Als_New_Thread)),
      ],
    );
    return Scaffold(
      backgroundColor: standalone ? null : Colors.transparent,
      appBar: standalone
          ? AppBar(
              title: Text(s.Al_Forum_Title),
              actions: [menu],
              bottom: single
                  ? null
                  : TabBar(
                      controller: _tabs,
                      tabs: [Tab(text: s.Als_Tab_Forum), Tab(text: s.Als_Activity)],
                    ),
            )
          : null,
      body: Column(
        children: [
          if (!standalone) ...[
            AppBarHome(
              title: s.Al_Forum_Title,
              showSearch: false,
              showBookmarks: false,
              showCalendar: false,
            ),
            Row(
              children: [
                Expanded(
                  child: single
                      ? const SizedBox(height: 8)
                      : TabBar(
                          controller: _tabs,
                          tabs: [Tab(text: s.Als_Tab_Forum), Tab(text: s.Als_Activity)],
                        ),
                ),
                menu,
              ],
            ),
          ],
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                AnilistThreadList(service: widget.service, mediaId: widget.mediaId),
                if (!single) _KeepAlive(child: AnilistActivityFeed(service: widget.service)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ForumAction { reviews, newThread }

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Forum threads with their filters: sort chips, category, "Subscribed" (signed in) and a
/// search field; page by page with pull to refresh.
class AnilistThreadList extends StatefulWidget {
  const AnilistThreadList({super.key, this.service, this.mediaId});

  final AnilistSocialService? service;
  final int? mediaId;

  @override
  State<AnilistThreadList> createState() => _AnilistThreadListState();
}

class _AnilistThreadListState extends State<AnilistThreadList>
    with AutomaticKeepAliveClientMixin {
  /// AniList `ThreadSort` values, in chip order.
  static const _sorts = ['REPLIED_AT_DESC', 'ID_DESC', 'VIEW_COUNT_DESC', 'REPLY_COUNT_DESC'];

  final List<AnilistThread> _threads = [];
  final _search = TextEditingController();
  Timer? _debounce;
  late AnilistThreadFilter _filter = AnilistThreadFilter(mediaId: widget.mediaId);
  bool _searching = false;
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasNext = true;
  Object? _error;

  AnilistSocialService get _service => widget.service ?? AnilistSocialService.instance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  String _label(String sort, S s) => switch (sort) {
        'ID_DESC' => s.Al_Forum_Newest,
        'VIEW_COUNT_DESC' => s.Al_Forum_Most_Viewed,
        'REPLY_COUNT_DESC' => s.Al_Forum_Most_Replied,
        _ => s.Al_Forum_Recent,
      };

  void _reset() {
    _generation++;
    _threads.clear();
    _page = 0;
    _hasNext = true;
    _loading = false;
    _error = null;
  }

  void _setFilter(AnilistThreadFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _reset();
    });
    _load();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final query = text.trim();
      _setFilter(_filter.copyWith(search: () => query.isEmpty ? null : query));
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching && _search.text.isNotEmpty) {
      _search.clear();
      _setFilter(_filter.copyWith(search: () => null));
    }
  }

  Future<void> _refresh() async {
    setState(_reset);
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasNext) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.threads(_filter, page: _page + 1);
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

  Future<void> _pickCategory() async {
    final s = S.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            ListTile(
              title: Text(s.Als_All_Categories),
              selected: _filter.categoryId == null,
              onTap: () => Navigator.of(context).pop(0),
            ),
            for (final c in AnilistForumCategory.all)
              ListTile(
                title: Text(anilistCategoryName(c)),
                selected: _filter.categoryId == c.id,
                onTap: () => Navigator.of(context).pop(c.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _setFilter(_filter.copyWith(categoryId: () => picked == 0 ? null : picked));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final category = _filter.categoryId == null
        ? null
        : AnilistForumCategory.all.where((c) => c.id == _filter.categoryId).firstOrNull;
    final filters = SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: s.Search,
            isSelected: _searching,
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search, size: 20),
            selectedIcon: const Icon(Icons.close, size: 20),
          ),
          const SizedBox(width: 8),
          if (widget.mediaId == null) ...[
            FilterChip(
              label: Text(category == null ? s.Als_Categories : anilistCategoryName(category)),
              selected: category != null,
              avatar: const Icon(Icons.category_outlined, size: 18),
              onSelected: (_) => _pickCategory(),
            ),
            const SizedBox(width: 8),
          ],
          if (_service.signedIn) ...[
            FilterChip(
              label: Text(s.Als_Subscribed),
              selected: _filter.subscribed,
              onSelected: (on) => _setFilter(_filter.copyWith(subscribed: on)),
            ),
            const SizedBox(width: 8),
          ],
          for (final sort in _sorts)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(_label(sort, s)),
                selected: _filter.sort == sort,
                onSelected: (_) => _setFilter(_filter.copyWith(sort: sort)),
              ),
            ),
        ],
      ),
    );

    return Column(
      children: [
        filters,
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onSearch,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: s.Als_Search_Threads,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        Expanded(child: _body(s)),
      ],
    );
  }

  Widget _body(S s) {
    if (_threads.isEmpty) {
      if (_loading) return const ForumSkeleton(count: 8, round: true);
      if (_error != null) {
        return ForumMessage(
          icon: Icons.cloud_off_outlined,
          title: anilistErrorText(_error!),
          onRetry: _load,
        );
      }
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ForumMessage(icon: Icons.forum_outlined, title: s.Fc_Topics_Empty_Title),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 500) _load();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          itemCount: _threads.length + 1,
          itemBuilder: (context, i) {
            if (i < _threads.length) {
              return AnilistThreadTile(key: ValueKey(_threads[i].id), thread: _threads[i]);
            }
            return AnilistPageFooter(loading: _loading, failed: _error != null, onRetry: _load);
          },
        ),
      ),
    );
  }
}
