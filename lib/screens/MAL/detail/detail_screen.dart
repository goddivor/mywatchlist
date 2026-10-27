import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/MAL/detail/actions/detail_actions.dart';
import 'package:mywatchlist/screens/MAL/detail/actions/more_info_modal.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_edit_panel.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_error.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_fab.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/MAL/detail/header/detail_header.dart';
import 'package:mywatchlist/screens/MAL/detail/header/detail_title.dart';
import 'package:mywatchlist/screens/MAL/detail/header/header_background.dart' show contentPref;
import 'package:mywatchlist/screens/MAL/detail/header/next_episode.dart';
import 'package:mywatchlist/screens/MAL/detail/section_frame.dart';
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart' show ScheduleLinks;
import 'package:mywatchlist/widgets/MAL/content/synopsis_widget.dart';
import 'package:mywatchlist/widgets/common/slivers.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// Anime / manga detail page (MyAnimeList data): collapsing header, tab bar
/// synced with the scroll position, the ordered sections of
/// [DetailSections] and the floating list editor.
class ContentDetailedScreen extends StatefulWidget {
  final Anime? node;
  final int? id;
  final String? heroTag;

  /// `anime` or `manga`.
  final String category;

  const ContentDetailedScreen({
    super.key,
    required this.node,
    this.id,
    this.category = "anime",
    this.heroTag,
  });

  @override
  State<ContentDetailedScreen> createState() => _ContentDetailedScreenState();
}

class _ContentDetailedScreenState extends State<ContentDetailedScreen>
    with TickerProviderStateMixin {
  final GlobalKey _listKey = GlobalKey();
  final AutoScrollController _scroll = AutoScrollController();

  /// True while the user scrolls up (the collapsed app bar hides its title).
  final ValueNotifier<bool> _scrollingUp = ValueNotifier(true);

  late DetailData _data;
  List<DetailSection> _sections = const [];
  List<TabType> _tabTypes = const [];
  late TabController _tabController;
  final Map<TabType, GlobalKey> _sectionKeys = {};

  StreamSubscription<List<TabType>>? _tabPrefSub;
  StreamSubscription<TitleLang>? _titlePrefSub;
  bool _tabSyncScheduled = false;
  double _lastSyncOffset = double.negativeInfinity;

  late TitleLang _titleLang;
  bool _showContentEdit = false;
  bool _crossTrackerEnabled = true;
  LiveListStatus? _liveStatus;

  int get _id => (widget.node?.id ?? widget.id)!;

  @override
  void initState() {
    super.initState();
    _data = DetailData(
      id: _id,
      category: widget.category,
      node: widget.node,
      heroTag: widget.heroTag,
    );
    _titleLang = Preferences.general.preferredTitle;
    _tabController = TabController(length: 0, vsync: this);
    // The only scroll listener of the page, registered once.
    _scroll.addListener(_onScroll);
    _tabPrefSub = Preferences.bloc?.stream
        .map((s) => s.content.visibleTabs(manga: _data.isManga))
        .distinct(listEquals)
        .listen((_) => _refreshSections());
    // The page follows the preferred title language when it changes.
    _titlePrefSub = Preferences.bloc?.stream
        .map((s) => s.general.preferredTitle)
        .distinct()
        .listen((lang) {
      if (mounted) setState(() => _titleLang = lang);
    });
    _recordVisit(widget.node);
    _loadCrossTrackerPref();
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _tabPrefSub?.cancel();
    _titlePrefSub?.cancel();
    _scroll.dispose();
    _tabController.dispose();
    _scrollingUp.dispose();
    super.dispose();
  }

  // ---- Loading -----------------------------------------------------------

  void _load() {
    _loadMal();
    _loadHtml();
    if (_data.isAnime) {
      _loadVideos();
      _loadScheduleLinks();
    }
  }

  void _retry() {
    setState(() => _data = _data.copyWith(state: DetailLoadState.loading));
    _load();
  }

  Future<void> _loadMal() async {
    try {
      final content = _data.isManga
          ? await MalApi().getMangaDetails(_id)
          : await MalApi().getAnimeDetails(_id);
      if (!mounted) return;
      _data = _data.copyWith(content: content, state: DetailLoadState.loaded);
      _recordVisit(Anime(
        id: _id,
        title: content.title,
        imageUrl: content.mainPicture?.large ?? content.mainPicture?.medium ?? '',
        score: content.mean ?? 0.0,
        members: content.numListUsers ?? 0,
      ));
      _loadNextEpisode(content.status);
    } catch (e) {
      debugPrint('Error loading MAL details for $_id: $e');
      if (!mounted) return;
      // A failed refresh after an edit keeps the details already shown.
      if (!_data.hasContent) {
        _data = _data.copyWith(state: DetailLoadState.failed, error: e);
      }
    }
    _refreshSections();
  }

  Future<void> _loadHtml() async {
    try {
      final html = await MwlApi.i.getAnimeDetailedHtml(widget.category, _id);
      if (!mounted || html == null) return;
      _data = _data.copyWith(html: html);
      _refreshSections();
    } catch (e) {
      debugPrint('Error loading HTML details for $_id: $e');
    }
  }

  Future<void> _loadScheduleLinks() async {
    final links = await ScheduleLinks.forMalId(_id);
    if (!mounted || links == null) return;
    _data = _data.copyWith(scheduleLinks: links);
    _refreshSections();
  }

  Future<void> _loadVideos() async {
    try {
      final videos = await JikanApi().getAnimeVideos(_id);
      if (!mounted) return;
      _data = _data.copyWith(videos: videos);
      _refreshSections();
    } catch (e) {
      debugPrint('Error loading Jikan videos for $_id: $e');
    }
  }

  /// Countdown of an airing anime (LiveChart schedule); once per page.
  Future<void> _loadNextEpisode(String? status) async {
    if (!_data.isAnime || status != 'currently_airing' || _data.nextEpisode != null) {
      return;
    }
    final next = await NextEpisodes.forMalId(_id);
    if (!mounted || next == null) return;
    setState(() => _data = _data.copyWith(nextEpisode: next));
  }

  void _recordVisit(Anime? anime) {
    if (anime == null) return;
    if (_data.isManga) {
      SearchHistory.instance.addRecentManga(anime);
    } else {
      SearchHistory.instance.addRecentAnime(anime);
    }
  }

  Future<void> _loadCrossTrackerPref() async {
    final enabled = await UserPreference().getCrossTrackerEnabled();
    if (mounted) setState(() => _crossTrackerEnabled = enabled);
  }

  bool get _hasOtherTrackers => UserManager.instance.authenticatedTrackers
      .any((t) => t != AccountType.myanimelist);

  // ---- Sections and tab sync ---------------------------------------------

  /// Rebuilds the section list from the current data and the saved order.
  /// The tab controller is replaced only when the tab list changes, keeping
  /// the selected section; the old one is disposed after the frame that
  /// stops using it.
  void _refreshSections() {
    if (!mounted) return;
    final sections = DetailSections.build(_data);
    final tabs = [for (final s in sections) if (s.isTab) s.type];
    if (!listEquals(tabs, _tabTypes)) {
      final old = _tabController;
      final selected = _tabTypes.isEmpty ? null : _tabTypes[old.index];
      _tabController = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: selected == null ? 0 : math.max(0, tabs.indexOf(selected)),
      );
      _tabTypes = tabs;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    for (final type in tabs) {
      _sectionKeys.putIfAbsent(type, () => GlobalKey(debugLabel: type.name));
    }
    setState(() => _sections = sections);
  }

  void _onScroll() {
    final position = _scroll.position;
    final up = position.userScrollDirection == ScrollDirection.forward;
    if (_scrollingUp.value != up) _scrollingUp.value = up;

    // Tab sync: at most once per frame, after a real move, never while a tab
    // tap is scrolling to its section.
    if (_tabSyncScheduled || _scroll.isAutoScrolling) return;
    if ((position.pixels - _lastSyncOffset).abs() < 24) return;
    _tabSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabSyncScheduled = false;
      if (!mounted) return;
      _lastSyncOffset = _scroll.hasClients ? _scroll.offset : 0;
      final index = _centerTabIndex();
      if (index != null && index != _tabController.index) {
        _tabController.index = index;
      }
    });
  }

  /// Tab whose section crosses the vertical middle of the list, or null.
  /// Only built (on-screen or cached) sections have a render box.
  int? _centerTabIndex() {
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.hasSize) return null;
    final top = listBox.localToGlobal(Offset.zero).dy;
    final bottom = top + listBox.size.height;
    final center = top + listBox.size.height / 2;
    for (var i = 0; i < _tabTypes.length; i++) {
      final box = _sectionKeys[_tabTypes[i]]?.currentContext?.findRenderObject()
          as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final itemTop = box.localToGlobal(Offset.zero).dy;
      if (itemTop > bottom) break;
      if (itemTop <= center && itemTop + box.size.height >= center) return i;
    }
    return null;
  }

  // ---- Build -------------------------------------------------------------

  String get _title => resolveDetailTitle(_data, _titleLang);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showContentEdit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _showContentEdit) _toggleEdit();
      },
      child: Scaffold(
        floatingActionButtonLocation:
            _showContentEdit ? FloatingActionButtonLocation.endFloat : null,
        floatingActionButton: buildDetailFab(
          data: _data,
          editOpen: _showContentEdit,
          onPressed: _toggleEdit,
        ),
        floatingActionButtonAnimator: NoScalingAnimation(),
        body: Stack(
          children: [
            CustomScrollView(
              key: _listKey,
              controller: _scroll,
              slivers: [
                _appBar(context),
                _body(),
                const SliverWrapper(SizedBox(height: 80)),
              ],
            ),
            if (_showContentEdit && _data.hasContent)
              Positioned(
                left: 0,
                right: 0,
                bottom: 70,
                child: DetailEditPanel(
                  data: _data,
                  showCrossTracker: _crossTrackerEnabled && _hasOtherTrackers,
                  live: _liveStatus,
                  onUpdate: (success) {
                    if (success) _loadMal();
                  },
                  onLiveStatus: (live) => setState(() => _liveStatus = live),
                  onDelete: () {
                    setState(() => _showContentEdit = false);
                    _loadMal();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _toggleEdit() {
    if (mounted) setState(() => _showContentEdit = !_showContentEdit);
  }

  SliverAppBar _appBar(BuildContext context) {
    final theme = Theme.of(context);
    final countdown = contentPref(context, (c) => c.showCountdownOnDetail);
    return SliverAppBar(
      pinned: true,
      expandedHeight: DetailHeader.extentFor(
        _data,
        topInset: MediaQuery.paddingOf(context).top,
        countdown: countdown,
      ),
      toolbarHeight: DetailHeader.toolbarHeight,
      title: ValueListenableBuilder<bool>(
        valueListenable: _scrollingUp,
        builder: (context, up, _) =>
            up ? const SizedBox.shrink() : Text(_title),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: ShimmerConditionally(
          showShimmer: _data.state == DetailLoadState.loading,
          baseColor: theme.scaffoldBackgroundColor,
          highlightColor: theme.scaffoldBackgroundColor.withValues(alpha: .3),
          child: DetailHeader(
            data: _data,
            title: _title,
            titleLang: _titleLang,
            onTitleLangChanged: (lang) => setState(() => _titleLang = lang),
            onMoreInfo: _data.hasContent
                ? () => showMoreInfoModal(context, _data)
                : null,
          ),
        ),
      ),
      bottom: _tabBar(),
      actions: buildDetailActions(context, _data),
    );
  }

  PreferredSizeWidget _tabBar() {
    if (!_data.hasContent) {
      return PreferredSize(
        preferredSize: const Size(double.infinity, DetailHeader.tabBarHeight),
        child: _data.state == DetailLoadState.failed
            ? const SizedBox.shrink()
            : const ShimmerColor(SizedBox.shrink()),
      );
    }
    return TabBar(
      isScrollable: true,
      controller: _tabController,
      tabAlignment: TabAlignment.start,
      onTap: (index) => _scroll.scrollToIndex(
        index,
        preferPosition: AutoScrollPosition.middle,
      ),
      tabs: [for (final type in _tabTypes) Tab(text: detailTabLabel(type))],
    );
  }

  Widget _body() {
    if (!_data.hasContent) {
      if (_data.state == DetailLoadState.failed) {
        return SliverToBoxAdapter(
          child: DetailErrorView(error: _data.error, onRetry: _retry),
        );
      }
      return const SliverWrapper(SysonpsisWidget());
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _buildSection(index),
        childCount: _sections.length,
      ),
    );
  }

  Widget _buildSection(int index) {
    final section = _sections[index];
    final frame = DetailSectionFrame(section: section, isFirst: index == 0);
    if (!section.isTab) return frame;
    return wrapScrollTag(
      controller: _scroll,
      index: _tabTypes.indexOf(section.type),
      child: KeyedSubtree(key: _sectionKeys[section.type], child: frame),
    );
  }
}
