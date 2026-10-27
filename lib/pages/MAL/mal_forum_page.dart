import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/forum/board_widget.dart';
import 'package:mywatchlist/widgets/forum/club_list_widget.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';

/// The discussion boards the Forums tab shows first: label, MAL board id.
class _Discussion {
  final String Function() label;
  final int boardId;

  const _Discussion(this.label, this.boardId);
}

/// What one board's topics are doing: loading, loaded or failed.
class _Slot {
  List<ForumTopicsData>? topics;
  bool failed = false;
}

/// The Forums page: forum categories and recent discussions, and MAL's club list.
class MalForumPage extends StatefulWidget {
  const MalForumPage({super.key});

  @override
  State<MalForumPage> createState() => _MalForumPageState();
}

class _MalForumPageState extends State<MalForumPage> with SingleTickerProviderStateMixin {
  static final _discussions = [
    _Discussion(() => S.current.Fc_Disc_Anime, 1),
    _Discussion(() => S.current.Fc_Disc_Manga, 2),
    _Discussion(() => S.current.Fc_Disc_Series, 15),
    _Discussion(() => S.current.Fc_Disc_News, 5),
    _Discussion(() => S.current.Fc_Disc_Db, 6),
  ];

  late final TabController _tabController;
  late final PageController _boardsController;
  final _forumApi = MalForumApi();

  int _discussionIndex = 0;
  Categories? _categories;
  bool _categoriesFailed = false;
  late final List<_Slot> _slots;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _boardsController = PageController(viewportFraction: 0.89);
    _slots = List.generate(_discussions.length, (_) => _Slot());
    _loadCategories();
    _loadDiscussion(_discussionIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _boardsController.dispose();
    super.dispose();
  }

  /// Reloads the categories and the open discussion (the other ones load when picked).
  Future<void> _reload() async {
    _generation++;
    setState(() {
      _categories = null;
      _categoriesFailed = false;
      for (final slot in _slots) {
        slot
          ..topics = null
          ..failed = false;
      }
    });
    await Future.wait([_loadCategories(), _loadDiscussion(_discussionIndex)]);
  }

  Future<void> _loadCategories() async {
    final generation = _generation;
    Categories? result;
    try {
      result = await _forumApi.getForumBoards();
    } catch (_) {}
    if (!mounted || generation != _generation) return;
    setState(() {
      _categories = result;
      _categoriesFailed = result?.forums == null;
    });
  }

  Future<void> _loadDiscussion(int index) async {
    final generation = _generation;
    final slot = _slots[index];
    setState(() {
      slot
        ..topics = null
        ..failed = false;
    });
    ForumTopics? result;
    try {
      result = await _forumApi.getForumTopics(
        boardId: _discussions[index].boardId,
        fromHtml: true,
      );
    } catch (_) {}
    if (!mounted || generation != _generation) return;
    setState(() {
      slot
        ..topics = result?.data
        ..failed = result == null;
    });
  }

  void _pickDiscussion(int index) {
    if (index == _discussionIndex) return;
    setState(() => _discussionIndex = index);
    final slot = _slots[index];
    if (slot.topics == null && !slot.failed) _loadDiscussion(index);
  }

  void _openAllTopics() {
    final discussion = _discussions[_discussionIndex];
    gotoPage(
      context: context,
      newPage: ForumTopicsScreen(
        boardId: discussion.boardId,
        offset: 50,
        title: discussion.label(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) => _tabController.index == 1
            ? FloatingActionButton.extended(
                onPressed: () => launchWebView(ForumUrls.createClub(), context: context),
                icon: const Icon(Icons.add),
                label: Text(S.current.Fc_Create_Club),
              )
            : const SizedBox.shrink(),
      ),
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
                  onSearchTap: () => gotoPage(
                    context: context,
                    newPage: const GeneralSearchScreen(showBackButton: true),
                  ),
                  onSettingsTap: () => AppRoutes.openSettings(context),
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
                tabs: [
                  Tab(text: S.current.Fc_Tab_Forums),
                  Tab(text: S.current.Fc_Tab_Clubs),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _KeepAliveWrapper(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: _buildForumContent(),
              ),
            ),
            const _KeepAliveWrapper(child: ClubsTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildForumContent() {
    final slot = _slots[_discussionIndex];
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildBoards()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: _DiscussionPicker(
            labels: [for (final d in _discussions) d.label()],
            selected: _discussionIndex,
            onSelected: _pickDiscussion,
          ),
        ),
        ForumTopicsSliver(
          topics: slot.topics,
          failed: slot.failed,
          onRetry: () => _loadDiscussion(_discussionIndex),
          onViewAll: _openAllTopics,
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildBoards() {
    const boardHeight = 188.0;
    final forums = _categories?.forums;

    if (_categoriesFailed) {
      return SizedBox(
        height: boardHeight,
        child: ForumMessage.error(onRetry: _loadCategories, scrollable: false),
      );
    }
    if (forums == null) {
      return const SizedBox(
        height: boardHeight,
        child: ForumSkeleton(count: 2, rowHeight: 74, padding: EdgeInsets.fromLTRB(12, 16, 12, 0)),
      );
    }
    return SizedBox(
      height: boardHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: PageView.builder(
          controller: _boardsController,
          allowImplicitScrolling: true,
          itemCount: (forums.length / 2).ceil(),
          itemBuilder: (context, index) {
            final first = 2 * index;
            final second = first + 1;
            return Column(
              children: [
                BoardWidget(forum: forums[first], forumIndex: first),
                if (second < forums.length) BoardWidget(forum: forums[second], forumIndex: second),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A row of chips to pick which discussion board the list shows.
class _DiscussionPicker extends StatelessWidget {
  const _DiscussionPicker({
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: labels.length,
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(labels[index]),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (_) => onSelected(index),
              selectedColor: scheme.primary,
              labelStyle: TextStyle(color: isSelected ? scheme.onPrimary : scheme.onSurface),
            ),
          );
        },
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
