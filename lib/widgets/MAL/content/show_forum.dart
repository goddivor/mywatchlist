import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/screens/forum/forum_posts_screen.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// Latest forum topics of a title: Jikan `forum`, else MyAnimeList's forum
/// page for that title (`JikanFallbacks.forum`); pages of three cards.
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
  final PageController _pages = PageController(viewportFraction: 0.92);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchForumTopics();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<List<AnimeForum>> _load() async {
    try {
      final response = await JikanApi().getAnimeForum(
        widget.animeId,
        AnimeForumFilter.all,
        category: widget.category,
      );
      return response.data;
    } catch (e) {
      debugPrint('Jikan forum failed, trying MyAnimeList: $e');
      return JikanFallbacks.forum(widget.animeId, widget.category);
    }
  }

  Future<void> _fetchForumTopics() async {
    try {
      final topics = await _load();
      if (!mounted) return;
      setState(() {
        forumTopicsList = topics;
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
        controller: _pages,
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
                      topic.title ?? S.current.Res_Forum_Untitled,
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
                          topic.authorUsername ?? S.current.Res_Unknown,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Date
                      if (topic.date != null) ...[
                        const SizedBox(width: 10),
                        Icon(
                          Icons.date_range,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
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
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date.toLocal());
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
                              color: Theme.of(context).colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 14,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface,
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
                                  color: Theme.of(context).colorScheme.onSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                height: 12,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildEmptyState() =>
      SectionMessage(icon: Icons.forum_outlined, message: S.current.Res_Forum_Empty);

  Widget _buildErrorState() => SectionMessage.error(
        message: S.current.Res_Forum_Failed,
        onRetry: () {
          setState(() {
            isLoading = true;
            hasError = false;
          });
          _fetchForumTopics();
        },
      );
}
