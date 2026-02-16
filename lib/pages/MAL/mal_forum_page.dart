import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/settings/settings_page.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_html.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/forum/board_widget.dart';
import 'package:mywatchlist/widgets/forum/club_list_widget.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/MAL/search/headerwidget.dart';

class MalForumPage extends StatefulWidget {
  const MalForumPage({super.key});

  @override
  State<MalForumPage> createState() => _MalForumPageState();
}

class _MalForumPageState extends State<MalForumPage>
    with SingleTickerProviderStateMixin {
  bool _hasOpened = false;
  late TabController _tabController;
  final _forumApi = MalForumApi();
  final _clubsApi = MalClubsApi();

  int _discussionIndex = 0;
  Categories? _categories;
  ForumTopics? _animeDisc;
  ForumTopics? _mangaDisc;
  ForumTopics? _newsDisc;
  ForumTopics? _seriesDisc;
  ForumTopics? _dbModsDisc;
  ClubListHtml? _clubListHtml;

  final _discussionLabels = [
    'Anime Discussions',
    'Manga Discussions',
    'Series Discussion',
    'News & Discussion',
    'DB Modifications',
  ];
  final _discussionBoardIds = [1, 2, 15, 5, 6];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _startOpeningAnimation();
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startOpeningAnimation() {
    Future.delayed(const Duration(milliseconds: 10)).then((_) {
      if (mounted) setState(() => _hasOpened = true);
    });
  }

  void _loadAll() {
    _categories = null;
    _animeDisc = null;
    _mangaDisc = null;
    _newsDisc = null;
    _seriesDisc = null;
    _dbModsDisc = null;
    _clubListHtml = null;
    if (mounted) setState(() {});
    _loadCategories();
    _loadDiscussions(1);
    _loadDiscussions(2);
    _loadDiscussions(15);
    _loadDiscussions(5);
    _loadDiscussions(6);
    _loadClubs();
  }

  Future<void> _loadCategories() async {
    _categories = await _forumApi.getForumBoards();
    if (mounted) setState(() {});
  }

  Future<void> _loadDiscussions(int boardId) async {
    final result = await _forumApi.getForumTopics(
      boardId: boardId,
      fromHtml: true,
    );
    if (mounted) {
      switch (boardId) {
        case 1:
          _animeDisc = result;
        case 2:
          _mangaDisc = result;
        case 15:
          _seriesDisc = result;
        case 5:
          _newsDisc = result;
        case 6:
          _dbModsDisc = result;
      }
      setState(() {});
    }
  }

  Future<void> _loadClubs() async {
    _clubListHtml = await _clubsApi.getClubs();
    if (mounted) setState(() {});
  }

  ForumTopics? _getDiscussionForIndex(int index) {
    switch (index) {
      case 0:
        return _animeDisc;
      case 1:
        return _mangaDisc;
      case 2:
        return _seriesDisc;
      case 3:
        return _newsDisc;
      case 4:
        return _dbModsDisc;
      default:
        return null;
    }
  }

  void _gotoForumTopicsPage() {
    gotoPage(
      context: context,
      newPage: ForumTopicsScreen(
        boardId: _discussionBoardIds[_discussionIndex],
        offset: 50,
        title: _discussionLabels[_discussionIndex],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _hasOpened ? 1 : 0,
      duration: const Duration(milliseconds: 300),
      child: _buildForumPage(),
    );
  }

  Widget _buildForumPage() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton(
              onPressed: () {
                launchUrl(
                  Uri.parse(
                      'https://myanimelist.net/clubs.php?action=create'),
                  mode: LaunchMode.externalApplication,
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              floating: true,
              expandedHeight: 120,
              title: Padding(
                padding: const EdgeInsets.only(bottom: 5.0),
                child: AppBarHome(
                  transparent: constraints.scrollOffset < 50,
                  backgroundColor: constraints.scrollOffset >= 50
                      ? theme.appBarTheme.backgroundColor
                      : Colors.transparent,
                  showAvatar: true,
                  showSettings: true,
                  onSearchTap: () {
                    gotoPage(
                      context: context,
                      newPage: const GeneralSearchScreen(
                        showBackButton: true,
                      ),
                    );
                  },
                  onSettingsTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsPage(),
                      ),
                    );
                  },
                  onUiChange: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
              titleSpacing: 0.0,
              backgroundColor: constraints.scrollOffset > 20
                  ? theme.appBarTheme.backgroundColor
                  : Colors.transparent,
              toolbarHeight: kToolbarHeight,
              actions: const [SizedBox.shrink()],
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Forums'),
                  Tab(text: 'Clubs'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Forums tab
            _KeepAliveWrapper(
              child: RefreshIndicator(
                onRefresh: () async => _loadAll(),
                child: _buildForumContent(),
              ),
            ),
            // Clubs tab
            _KeepAliveWrapper(
              child: RefreshIndicator(
                onRefresh: () async => _loadClubs(),
                child: _buildClubsContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForumContent() {
    return CustomScrollView(
      slivers: [
        // Boards carousel
        SliverToBoxAdapter(child: _buildBoards()),
        SB.lh20,
        // Discussion toggle (Anime / Manga)
        SliverToBoxAdapter(
          child: HeaderWidget(
            header: _discussionLabels,
            selectedIndex: _discussionIndex,
            onPressed: (value) {
              if (mounted) setState(() => _discussionIndex = value);
            },
          ),
        ),
        // Discussion topics
        SliverToBoxAdapter(
          child: ForumTopicsList(
            topics: _getDiscussionForIndex(_discussionIndex)?.data,
            onPressed: _gotoForumTopicsPage,
            showViewAllButton: true,
          ),
        ),
        SB.lh80,
      ],
    );
  }

  Widget _buildBoards() {
    const boardHeight = 188.0;

    return Container(
      height: boardHeight,
      padding: const EdgeInsets.only(top: 10.0),
      child: _categories?.forums == null
          ? _buildBoardsShimmer()
          : PageView.builder(
              controller: PageController(
                initialPage: 0,
                viewportFraction: 0.89,
              ),
              allowImplicitScrolling: true,
              itemCount: (_categories!.forums!.length / 2).ceil(),
              itemBuilder: (context, index) {
                final firstIndex = 2 * index;
                final secondIndex = 2 * index + 1;
                return Column(
                  children: [
                    BoardWidget(
                      forum: _categories!.forums![firstIndex],
                      forumIndex: firstIndex,
                    ),
                    if (secondIndex < _categories!.forums!.length)
                      BoardWidget(
                        forum: _categories!.forums![secondIndex],
                        forumIndex: secondIndex,
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildBoardsShimmer() {
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClubsContent() {
    if (_clubListHtml?.clubs == null) {
      return const SingleChildScrollView(
        child: ClubsShimmer(),
      );
    }

    if (_clubListHtml!.clubs!.isEmpty) {
      return const SingleChildScrollView(
        child: SizedBox(
          height: 200,
          child: Center(child: Text('No clubs found')),
        ),
      );
    }

    return SingleChildScrollView(
      child: ClubListWidget(clubListHtml: _clubListHtml!),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
