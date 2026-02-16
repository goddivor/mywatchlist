import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';
import 'package:mywatchlist/widgets/forum/next_previous_row.dart';
import 'package:mywatchlist/widgets/forum/post_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:share_plus/share_plus.dart';

class ForumPostsScreen extends StatefulWidget {
  final ForumTopicsData? topic;
  final bool showAppbar;
  final VoidCallback? onUiChange;

  const ForumPostsScreen({
    super.key,
    this.topic,
    this.showAppbar = true,
    this.onUiChange,
  });

  @override
  State<ForumPostsScreen> createState() => _ForumPostsScreenState();
}

class _ForumPostsScreenState extends State<ForumPostsScreen> {
  final _forumApi = MalForumApi();
  final _postLimit = 14;
  final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');

  int _pageIndex = 0;
  String _sortType = 'Oldest';
  bool _enableShare = false;
  Set<ForumTopicPost> _selectedPosts = {};
  Future<ForumTopicData?>? _topicFuture;
  late AutoScrollController _scrollController;

  ForumTopicsData? get topic => widget.topic;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 100, 0, MediaQuery.of(context).padding.bottom),
    );
    _fetchTopicData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchTopicData() {
    final totalPosts = topic?.numberOfPosts ?? 0;
    int offset;
    if (_sortType == 'Newest') {
      final lastPageIndex =
          ((totalPosts - _postLimit) / _postLimit).ceil().clamp(0, 999);
      offset = (_pageIndex - lastPageIndex).abs() * _postLimit;
    } else {
      offset = _pageIndex * _postLimit;
    }

    _topicFuture = _forumApi.getForumTopicDetail(
      topic!.id!,
      limit: _postLimit,
      offset: offset,
    );
    if (mounted) setState(() {});
  }

  void _changePage(int index) {
    if (_enableShare) return;
    _scrollController
        .animateTo(0,
            curve: Curves.ease, duration: const Duration(milliseconds: 400))
        .then((_) {
      setState(() {
        _pageIndex = index;
        _fetchTopicData();
      });
    });
  }

  void _changeSortType(String value) {
    if (_enableShare) return;
    setState(() {
      _sortType = value;
      _pageIndex = 0;
      _fetchTopicData();
    });
  }

  int get _totalPages =>
      ((topic?.numberOfPosts ?? 0) / _postLimit).ceil();

  bool get _showPages =>
      topic?.numberOfPosts != null && topic!.numberOfPosts! > _postLimit;

  @override
  Widget build(BuildContext context) {
    if (topic == null) {
      return Scaffold(
        appBar: widget.showAppbar ? AppBar() : null,
        body: const Center(child: Text('No topic selected')),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open MAL forum in browser to post a reply
          final url =
              'https://myanimelist.net/forum/?action=message&topic_id=${topic!.id}';
          // For now just copy the URL
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forum URL copied')),
          );
        },
        child: const Icon(Icons.post_add),
      ),
      body: PopScope(
        canPop: !_enableShare,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _enableShare) {
            setState(() {
              _selectedPosts = {};
              _enableShare = false;
            });
          }
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<ForumTopicData?>(
      future: _topicFuture,
      builder: (context, snapshot) {
        final isLoaded = snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done;

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header
            _buildSliverHeader(),
            // Content
            if (isLoaded && snapshot.data?.posts != null) ...[
              // Poll
              if (snapshot.data?.poll != null)
                SliverToBoxAdapter(
                  child: _buildPollWidget(snapshot.data!.poll!),
                ),
              SB.lh10,
              // Posts
              PostWidgetBuilder(
                postList: snapshot.data!.posts,
                controller: _scrollController,
                reverse: _sortType == 'Newest',
                offset: _pageIndex * _postLimit,
                postLimit: _postLimit,
                clearSelection: !_enableShare,
                onPostsSelected: (posts) {
                  _selectedPosts = posts;
                  setState(() {
                    _enableShare = posts.isNotEmpty;
                  });
                },
              ),
              // Pagination
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: NextPreviousRow(
                    onPrevious: _pageIndex > 0
                        ? () => _changePage(_pageIndex - 1)
                        : null,
                    onNext: _pageIndex < _totalPages - 1
                        ? () => _changePage(_pageIndex + 1)
                        : null,
                  ),
                ),
              ),
              SB.lh80,
            ] else if (!isLoaded) ...[
              SliverToBoxAdapter(child: _buildLoadingState()),
            ] else ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'No posts found',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSliverHeader() {
    if (!widget.showAppbar) {
      return SliverToBoxAdapter(child: _buildInlineHeader());
    }

    return SliverAppBar(
      pinned: true,
      floating: false,
      automaticallyImplyLeading: _selectedPosts.isEmpty,
      title: _selectedPosts.isNotEmpty
          ? _buildSharePrefix()
          : null,
      actions: _selectedPosts.isNotEmpty
          ? _buildShareActions()
          : [
              if (topic?.numberOfPosts != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: _changeSortType,
                  itemBuilder: (_) => ['Oldest', 'Newest']
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                ),
              SB.w10,
            ],
      expandedHeight: _showPages ? 270 : 230,
      bottom: _showPages ? _buildPageSelector() : null,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.only(
              top: 100, left: 15, right: 15, bottom: 20),
          child: ForumPostHeader(
            dateFormat: _dateFormat,
            forumTopic: topic,
            sizedbox: const SizedBox(height: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ForumPostHeader(
                  forumTopic: topic,
                  dateFormat: _dateFormat,
                  sizedbox: const SizedBox(height: 20),
                ),
              ),
              if (topic?.numberOfPosts != null)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  onSelected: _changeSortType,
                  itemBuilder: (_) => ['Oldest', 'Newest']
                      .map((s) => PopupMenuItem(
                            value: s,
                            child: Text(s),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
        if (_showPages) _buildPageSelector(),
        const Divider(thickness: 1),
      ],
    );
  }

  PreferredSize _buildPageSelector() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(50),
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _totalPages,
          itemBuilder: (context, index) {
            final isSelected = index == _pageIndex;
            final theme = Theme.of(context);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text('${index + 1}'),
                selected: isSelected,
                onSelected: (_) => _changePage(index),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                selectedColor: theme.colorScheme.primary,
                visualDensity: VisualDensity.compact,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSharePrefix() {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              _selectedPosts = {};
              _enableShare = false;
            });
          },
          icon: const Icon(Icons.cancel_rounded),
        ),
        SB.w10,
        Text('${_selectedPosts.length} selected'),
      ],
    );
  }

  List<Widget> _buildShareActions() {
    return [
      IconButton(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _getShareableContent()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Copied to clipboard')),
          );
          setState(() {
            _selectedPosts = {};
            _enableShare = false;
          });
        },
        icon: Icon(
            _selectedPosts.length > 1 ? Icons.copy_all : Icons.copy),
      ),
      IconButton(
        onPressed: () async {
          await Share.share(_getShareableContent());
          setState(() {
            _selectedPosts = {};
            _enableShare = false;
          });
        },
        icon: const Icon(Icons.share),
      ),
      SB.w10,
    ];
  }

  String _getShareableContent() {
    if (_selectedPosts.length == 1) {
      return _selectedPosts.first.toString();
    }
    return 'Posts: ${_selectedPosts.length}\n' +
        _selectedPosts.map((e) => e.toString()).join('\n---\n');
  }

  Widget _buildPollWidget(ForumTopicPoll poll) {
    if (poll.question == null) return const SizedBox();

    final totalVotes = poll.options
            ?.fold<int>(0, (sum, opt) => sum + (opt.votes ?? 0)) ??
        1;
    final total = totalVotes == 0 ? 1 : totalVotes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: ExpansionTile(
          title: Text(
            'Poll: ${poll.question}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            if (poll.options != null)
              ...poll.options!.map((opt) => ListTile(
                    title: Text(
                      '${opt.text} (${((opt.votes ?? 0) / total * 100).toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: SizedBox(
                      width: 35,
                      height: 35,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            value: (opt.votes ?? 0) / total,
                          ),
                          Text(
                            '${opt.votes ?? 0}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ShimmerColor(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: List.generate(
            5,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
