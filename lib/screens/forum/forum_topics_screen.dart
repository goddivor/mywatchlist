import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/forum/forum_topic_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ForumTopicsScreen extends StatefulWidget {
  final int? boardId;
  final int? subBoardId;
  final int? animeId;
  final int? mangaId;
  final String? title;
  final String? query;
  final int offset;

  const ForumTopicsScreen({
    super.key,
    this.boardId,
    this.subBoardId,
    this.animeId,
    this.mangaId,
    this.title,
    this.query,
    this.offset = 0,
  });

  @override
  State<ForumTopicsScreen> createState() => _ForumTopicsScreenState();
}

class _ForumTopicsScreenState extends State<ForumTopicsScreen> {
  final _forumApi = MalForumApi();
  final _scrollController = ScrollController();
  final List<ForumTopicsData> _topics = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  String? _searchQuery;
  static const _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.offset;
    _loadTopics();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadTopics();
    }
  }

  Future<void> _loadTopics() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final result = await _forumApi.getForumTopics(
        boardId: widget.boardId,
        subboardId: widget.subBoardId,
        animeId: widget.animeId,
        mangaId: widget.mangaId,
        q: _searchQuery ?? widget.query,
        offset: _currentOffset,
        limit: _pageSize,
        fromHtml: true,
      );

      if (mounted) {
        final newTopics = result?.data ?? [];
        setState(() {
          _topics.addAll(newTopics);
          _currentOffset += newTopics.length;
          _hasMore = newTopics.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load topics')),
        );
      }
    }
  }

  Future<void> _refresh() async {
    _topics.clear();
    _currentOffset = widget.offset;
    _hasMore = true;
    await _loadTopics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_searchQuery != null ? 'Search: $_searchQuery' : (widget.title ?? 'Forum')),
        actions: [
          if (_searchQuery != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchQuery = null;
                  _topics.clear();
                  _currentOffset = widget.offset;
                  _hasMore = true;
                });
                _loadTopics();
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final query = await showSearch<String?>(
                context: context,
                delegate: _ForumSearchDelegate(),
              );
              if (query != null && query.isNotEmpty) {
                setState(() {
                  _searchQuery = query;
                  _topics.clear();
                  _currentOffset = 0;
                  _hasMore = true;
                });
                _loadTopics();
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _topics.isEmpty && _isLoading
            ? _buildInitialLoading()
            : ListView.builder(
                controller: _scrollController,
                itemCount: _topics.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _topics.length) {
                    return _buildLoadingIndicator();
                  }
                  return ForumTopicWidget(topic: _topics[index]);
                },
              ),
      ),
    );
  }

  Widget _buildInitialLoading() {
    return ShimmerColor(
      ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ForumSearchDelegate extends SearchDelegate<String?> {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    close(context, query);
    return const SizedBox();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('Search forum topics...'),
      );
    }
    return ListTile(
      leading: const Icon(Icons.search),
      title: Text('Search for "$query"'),
      onTap: () => close(context, query),
    );
  }
}
