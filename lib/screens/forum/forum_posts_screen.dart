import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywatchlist/cache/bookmarks.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/bookmarks/bookmark_button.dart';
import 'package:mywatchlist/widgets/common/app_bar_menu.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';
import 'package:mywatchlist/widgets/forum/forum_common.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';
import 'package:mywatchlist/widgets/forum/next_previous_row.dart';
import 'package:mywatchlist/widgets/forum/post_widget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:share_plus/share_plus.dart';

/// The posts of a forum topic, fourteen per page. Long press a post to select it for copying or
/// sharing; the reply button opens MyAnimeList's reply form in the in-app browser.
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
  static const _postLimit = 14;

  final _forumApi = MalForumApi();

  int _pageIndex = 0;
  bool _newestFirst = false;
  bool _enableShare = false;
  Set<ForumTopicPost> _selectedPosts = {};
  ForumTopicData? _data;
  bool _loading = true;
  bool _failed = false;
  int _requestId = 0;
  late final AutoScrollController _scrollController;

  ForumTopicsData? get topic => widget.topic;

  @override
  void initState() {
    super.initState();
    _scrollController = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 100, 0, MediaQuery.paddingOf(context).bottom),
    );
    _fetchTopicData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchTopicData() async {
    final id = topic?.id;
    if (id == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    final totalPosts = topic?.numberOfPosts ?? 0;
    int offset;
    if (_newestFirst) {
      final lastPageIndex =
          ((totalPosts - _postLimit) / _postLimit).ceil().clamp(0, 999);
      offset = (_pageIndex - lastPageIndex).abs() * _postLimit;
    } else {
      offset = _pageIndex * _postLimit;
    }

    final request = ++_requestId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final result = await _forumApi.getForumTopicDetail(
      id,
      limit: _postLimit,
      offset: offset,
    );
    if (!mounted || request != _requestId) return;
    setState(() {
      _data = result;
      _loading = false;
      _failed = result == null;
    });
  }

  Future<void> _changePage(int index) async {
    if (_enableShare || index == _pageIndex) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        curve: Curves.ease,
        duration: const Duration(milliseconds: 250),
      );
    }
    if (!mounted) return;
    _pageIndex = index;
    _fetchTopicData();
  }

  void _changeSort(bool newestFirst) {
    if (_enableShare || newestFirst == _newestFirst) return;
    _newestFirst = newestFirst;
    _pageIndex = 0;
    _fetchTopicData();
  }

  void _clearSelection() {
    setState(() {
      _selectedPosts = {};
      _enableShare = false;
    });
  }

  int get _totalPages => ((topic?.numberOfPosts ?? 0) / _postLimit).ceil();

  /// False when the topic was opened without its post count (a bookmark, a link): the pages
  /// then follow MyAnimeList's `paging.next` instead of a known total.
  bool get _knownCount => topic?.numberOfPosts != null;

  bool get _hasNextPage => _knownCount
      ? _pageIndex < _totalPages - 1
      : _data?.paging?.next != null;

  String get _bookmarkTitle {
    final title = topic?.title;
    if (title != null && title.isNotEmpty) return title;
    return _data?.title ?? '';
  }

  /// The topic's bookmark (MyAnimeList forum topic), once it has an id and a title.
  Widget _bookmarkButton() {
    final id = topic?.id;
    final title = _bookmarkTitle;
    if (id == null || title.isEmpty) return const SizedBox.shrink();
    final author = topic?.createdBy?.name;
    return BookmarkButton(
      tracker: 'myanimelist',
      kind: BookmarkKind.forumTopic,
      id: id,
      title: title,
      subtitle: author == null || author.isEmpty ? null : author,
    );
  }

  bool get _showPages =>
      topic?.numberOfPosts != null && topic!.numberOfPosts! > _postLimit;

  bool get _canReply => topic?.id != null && topic?.isLocked != true;

  String? get _topicUrl => topic?.id == null ? null : ForumUrls.topic(topic!.id!);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canReply && !_enableShare
          ? FloatingActionButton.extended(
              onPressed: () => launchWebView(ForumUrls.reply(topic!.id!), context: context),
              icon: const Icon(Icons.reply),
              label: Text(S.current.Fc_Reply),
            )
          : null,
      body: PopScope(
        canPop: !_enableShare,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _enableShare) _clearSelection();
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final posts = _data?.posts;
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        _buildSliverHeader(),
        if (_loading && posts == null)
          const SliverToBoxAdapter(child: ForumSkeleton(count: 5, rowHeight: 96, round: true))
        else if (_failed && posts == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ForumMessage.error(onRetry: _fetchTopicData, scrollable: false),
          )
        else if (posts == null || posts.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ForumMessage(
              icon: Icons.forum_outlined,
              title: S.current.Fc_Posts_Empty,
              onRetry: _fetchTopicData,
              scrollable: false,
            ),
          )
        else ...[
          if (_data?.poll != null)
            SliverToBoxAdapter(child: _PollCard(poll: _data!.poll!)),
          PostWidgetBuilder(
            key: ValueKey('$_pageIndex-$_newestFirst-${_data.hashCode}'),
            postList: posts,
            controller: _scrollController,
            reverse: _newestFirst,
            offset: _pageIndex * _postLimit,
            postLimit: _postLimit,
            clearSelection: !_enableShare,
            onPostsSelected: (selected) {
              _selectedPosts = selected;
              setState(() => _enableShare = selected.isNotEmpty);
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
              child: NextPreviousRow(
                page: _knownCount ? _pageIndex + 1 : null,
                total: _knownCount ? _totalPages : null,
                onPrevious: _pageIndex > 0 ? () => _changePage(_pageIndex - 1) : null,
                onNext: _hasNextPage ? () => _changePage(_pageIndex + 1) : null,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sortMenu() {
    if (topic?.numberOfPosts == null) return const SizedBox.shrink();
    return PopupMenuButton<bool>(
      tooltip: S.current.Fc_Sort,
      icon: const Icon(Icons.sort),
      onSelected: _changeSort,
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: false,
          checked: !_newestFirst,
          child: Text(S.current.Fc_Sort_Oldest),
        ),
        CheckedPopupMenuItem(
          value: true,
          checked: _newestFirst,
          child: Text(S.current.Fc_Sort_Newest),
        ),
      ],
    );
  }

  Widget _buildSliverHeader() {
    if (!widget.showAppbar) {
      return SliverToBoxAdapter(child: _buildInlineHeader());
    }

    final selecting = _selectedPosts.isNotEmpty;
    final title = topic?.title ?? '';
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: !selecting,
      leading: selecting
          ? IconButton(
              tooltip: S.current.Fc_Cancel_Selection,
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
            )
          : null,
      title: selecting ? Text(S.current.Fc_Selected_Count(_selectedPosts.length)) : null,
      actions: selecting
          ? _buildShareActions()
          : [
              _bookmarkButton(),
              _sortMenu(),
              AppBarMenu(
                onShare: _topicUrl == null
                    ? null
                    : () => showShareBuilder(
                          context,
                          subject: title,
                          fields: [
                            if (title.isNotEmpty)
                              ShareField(label: S.current.Fc_Field_Title, value: title),
                            ShareField(label: S.current.Fc_Field_Link, value: _topicUrl!),
                          ],
                        ),
                onOpenInBrowser:
                    _topicUrl == null ? null : () => launchWebView(_topicUrl!, context: context),
              ),
            ],
      bottom: _showPages ? _PageSelector(current: _pageIndex, total: _totalPages, onSelected: _changePage) : null,
    );
  }

  Widget _buildInlineHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: (topic?.title ?? '').isEmpty
                    ? const SizedBox.shrink()
                    : ForumTopicHeader(topic: topic),
              ),
              _bookmarkButton(),
              _sortMenu(),
            ],
          ),
        ),
        if (_showPages)
          SizedBox(
            height: 48,
            child: _PageChips(current: _pageIndex, total: _totalPages, onSelected: _changePage),
          ),
        const Divider(height: 1),
      ],
    );
  }

  List<Widget> _buildShareActions() {
    return [
      IconButton(
        tooltip: S.current.Fc_Copy,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: _getShareableContent()));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(S.current.Fc_Copied)),
          );
          _clearSelection();
        },
        icon: Icon(_selectedPosts.length > 1 ? Icons.copy_all : Icons.copy),
      ),
      IconButton(
        tooltip: S.current.Share,
        onPressed: () async {
          final text = _getShareableContent();
          _clearSelection();
          await Share.share(text);
        },
        icon: const Icon(Icons.share),
      ),
    ];
  }

  String _getShareableContent() {
    if (_selectedPosts.length == 1) {
      return _selectedPosts.first.toString();
    }
    return '${S.current.Fc_Posts_Count(_selectedPosts.length)}\n'
        '${_selectedPosts.map((e) => e.toString()).join('\n---\n')}';
  }
}

/// The page numbers of a topic as chips, with the current one filled.
class _PageChips extends StatelessWidget {
  const _PageChips({required this.current, required this.total, required this.onSelected});

  final int current;
  final int total;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: total,
      itemBuilder: (context, index) {
        final selected = index == current;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Text('${index + 1}'),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(index),
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
            selectedColor: scheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        );
      },
    );
  }
}

class _PageSelector extends StatelessWidget implements PreferredSizeWidget {
  const _PageSelector({required this.current, required this.total, required this.onSelected});

  final int current;
  final int total;
  final ValueChanged<int> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 48, child: _PageChips(current: current, total: total, onSelected: onSelected));
}

/// The poll of a topic: each option with its share of the votes.
class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll});

  final ForumTopicPoll poll;

  @override
  Widget build(BuildContext context) {
    if (poll.question == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = poll.options ?? const <ForumTopicOptions>[];
    final totalVotes = options.fold<int>(0, (sum, opt) => sum + (opt.votes ?? 0));
    final total = totalVotes == 0 ? 1 : totalVotes;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(Icons.poll_outlined, color: scheme.primary),
          title: Text(
            poll.question!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            [
              S.current.Fc_Poll,
              S.current.Fc_Poll_Votes(totalVotes),
              if (poll.close == true) S.current.Fc_Poll_Closed,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            for (final option in options)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            option.text ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${((option.votes ?? 0) / total * 100).toStringAsFixed(1)}% · ${option.votes ?? 0}',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (option.votes ?? 0) / total,
                        minHeight: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
