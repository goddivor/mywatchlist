import 'package:flutter/material.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ShowAnimeNews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeNews(
      {super.key, required this.animeId, this.category = "anime"});

  @override
  _ShowAnimeNewsState createState() => _ShowAnimeNewsState();
}

class _ShowAnimeNewsState extends State<ShowAnimeNews>
    with AutomaticKeepAliveClientMixin {
  List<AnimeNews>? newsList;
  List<AnimeNews> newsFullList = [];
  int _currentPage = 1;
  bool _hasNextPage = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchNews();
  }

  Future<void> _onScroll() async {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore) {
      _isLoadingMore = true;
      await _fetchNews();
      _isLoadingMore = false;
    }
  }

  Future<void> _fetchNews() async {
    if (_hasNextPage) {
      final response = await JikanApi().getAnimeNews(widget.animeId,
          page: _currentPage, category: widget.category);
      if (!mounted) return;
      setState(() {
        newsList = response.data;
        newsFullList.addAll(newsList!);
        _currentPage++;
        _hasNextPage = response.pagination.hasNextPage ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (newsFullList.isEmpty && newsList == null) {
      return _buildLoadingState();
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: newsFullList.length + (_hasNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < newsFullList.length) {
            return _buildNewsCard(newsFullList[index]);
          }
          return _buildLoadingCard();
        },
      ),
    );
  }

  Widget _buildNewsCard(AnimeNews news) {
    final theme = Theme.of(context);
    final dateStr = news.date != null
        ? DateFormat('MMM d, yyyy')
            .format(DateTime.parse(news.date!))
        : '';

    return SizedBox(
      width: 320,
      child: Card(
        margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Image thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AvatarWidget(
                    height: 240,
                    width: 90,
                    url: news.images?.jpg?.imageUrl,
                    userRoundBorderforLoading: false,
                    radius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                // Right: Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        news.title ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Excerpt
                      Expanded(
                        child: Text(
                          news.excerpt ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          overflow: TextOverflow.fade,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Bottom: Author + Date + Comments
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              news.authorUsername ?? '',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Comments count
                      if (news.comments != null && news.comments! > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 13,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${news.comments}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (context, index) => _buildLoadingCard(),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return SizedBox(
      width: 320,
      child: Card(
        margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ShimmerColor(
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 240,
                  width: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 16,
                        width: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 12,
                            width: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
