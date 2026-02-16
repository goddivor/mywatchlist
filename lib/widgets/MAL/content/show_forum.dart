import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

class ShowAnimeForum extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeForum(
      {super.key, required this.animeId, this.category = "anime"});

  @override
  State<ShowAnimeForum> createState() => _ShowAnimeForumState();
}

class _ShowAnimeForumState extends State<ShowAnimeForum>
    with AutomaticKeepAliveClientMixin {
  List<AnimeForum> forumTopicsList = [];
  bool isLoading = true;
  bool hasError = false;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchForumTopics();
  }

  Future<void> _fetchForumTopics() async {
    try {
      final response = await JikanApi().getAnimeForum(
        widget.animeId,
        AnimeForumFilter.all,
        category: widget.category,
      );

      if (!mounted) return;
      setState(() {
        forumTopicsList = response.data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint('Error fetching forum topics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return _buildLoadingState();
    }

    if (hasError) {
      return _buildErrorState();
    }

    if (forumTopicsList.isEmpty) {
      return _buildEmptyState();
    }

    // Show max 15 topics in a paginated vertical card layout
    final topics = forumTopicsList.take(15).toList();
    const int itemsPerPage = 3;
    final int pageCount = (topics.length / itemsPerPage).ceil();

    // Dynamic height based on item count per page
    final double containerHeight;
    if (topics.length == 1) {
      containerHeight = 110;
    } else if (topics.length == 2) {
      containerHeight = 210;
    } else {
      containerHeight = 310;
    }

    return SizedBox(
      height: containerHeight,
      child: PageView.builder(
        padEnds: false,
        controller: PageController(viewportFraction: 0.92),
        itemCount: pageCount,
        itemBuilder: (context, pageIndex) {
          final startIndex = pageIndex * itemsPerPage;
          final endIndex = (startIndex + itemsPerPage).clamp(0, topics.length);
          final pageTopics = topics.sublist(startIndex, endIndex);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              children: pageTopics.map((topic) {
                return _buildForumTopicCard(context, topic);
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForumTopicCard(BuildContext context, AnimeForum topic) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 96,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (topic.malId != null) {
                gotoPage(
                  context: context,
                  newPage: ForumPostsScreen(
                    topic: ForumTopicsData(
                      id: topic.malId,
                      title: topic.title,
                      createdBy: ForumUser(name: topic.authorUsername),
                      numberOfPosts: topic.comments,
                    ),
                  ),
                );
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title
                  Expanded(
                    child: Text(
                      topic.title ?? 'Untitled',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Bottom row: author + date | post count
                  Row(
                    children: [
                      // Author
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          topic.authorUsername ?? 'Unknown',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Date
                      if (topic.date != null) ...[
                        Text(
                          ' · ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _formatDate(topic.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const Spacer(),
                      // Post count
                      Icon(
                        Icons.forum_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${topic.comments ?? 0}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Last reply info
                  if (topic.lastComment != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.reply,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${topic.lastComment!.authorUsername ?? ''} · ${_formatDate(topic.lastComment!.date)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return _dateFormat.format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 310,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: ShimmerColor(
          Column(
            children: List.generate(
              3,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  height: 96,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            height: 14,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                height: 12,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                height: 12,
                                width: 40,
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No forum topics available',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load forum topics',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  hasError = false;
                });
                _fetchForumTopics();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
