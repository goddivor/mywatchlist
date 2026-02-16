import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/MAL/mal_clubs_api.dart';
import 'package:mywatchlist/services/api/MAL/models/club/club_data.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ClubForumScreen extends StatefulWidget {
  final int clubId;
  final String? clubTitle;

  const ClubForumScreen({
    super.key,
    required this.clubId,
    this.clubTitle,
  });

  @override
  State<ClubForumScreen> createState() => _ClubForumScreenState();
}

class _ClubForumScreenState extends State<ClubForumScreen> {
  final _clubsApi = MalClubsApi();
  final _scrollController = ScrollController();
  final List<ClubForumTopic> _topics = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
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
      final result = await _clubsApi.getClubViewAll(
        widget.clubId,
        'forum',
        _currentOffset,
      );

      if (mounted) {
        final newTopics =
            (result ?? []).whereType<ClubForumTopic>().toList();
        setState(() {
          _topics.addAll(newTopics);
          _currentOffset += newTopics.length;
          _hasMore = newTopics.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _extractPostCount(String? replies) {
    if (replies == null) return 0;
    final match = RegExp(r'\d+').firstMatch(replies);
    if (match != null) {
      return (int.tryParse(match.group(0)!) ?? 0) + 1;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Forums${widget.clubTitle != null ? ' - ${widget.clubTitle}' : ''}',
        ),
      ),
      body: _topics.isEmpty && _isLoading
          ? _buildLoading()
          : RefreshIndicator(
              onRefresh: () async {
                _topics.clear();
                _currentOffset = 0;
                _hasMore = true;
                await _loadTopics();
              },
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _topics.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _topics.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _buildTopicTile(_topics[index]);
                },
              ),
            ),
    );
  }

  Widget _buildTopicTile(ClubForumTopic topic) {
    final postCount = _extractPostCount(topic.replies);
    return ListTile(
      title: Text(
        topic.title ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (topic.createdBy != null) topic.createdBy,
          if (postCount > 0) '$postCount posts',
        ].join(' · '),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: topic.lastPostTime != null
          ? Text(
              topic.lastPostTime!,
              style: Theme.of(context).textTheme.labelSmall,
            )
          : null,
      onTap: () {
        if (topic.id != null) {
          gotoPage(
            context: context,
            newPage: ForumPostsScreen(
              topic: ForumTopicsData(
                id: topic.id,
                title: topic.title,
                createdBy: ForumUser(name: topic.createdBy),
                numberOfPosts: postCount > 0 ? postCount : null,
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLoading() {
    return ShimmerColor(
      ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}
