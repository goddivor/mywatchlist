import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/featured_section.dart' show FeaturedArticles;
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/enums.dart' show ForumConstants;
import 'package:mywatchlist/screens/MAL/featured_screen.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_featured.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';

/// MAL featured articles about a title ([FeaturedArticles]: mwl-api
/// `content/featured`, a MAL page parsed by the backend). Ends in articles,
/// nothing at all when the title has none (the detail screen then drops the
/// section, title row and tab included), or an error with Retry.
class ShowAnimeFeatured extends StatefulWidget {
  final int animeId;
  final String animeName;
  final String category;

  const ShowAnimeFeatured({
    super.key,
    required this.animeId,
    required this.animeName,
    this.category = "anime",
  });

  @override
  State<ShowAnimeFeatured> createState() => _ShowAnimeFeaturedState();
}

class _ShowAnimeFeaturedState extends State<ShowAnimeFeatured>
    with AutomaticKeepAliveClientMixin {
  AnimeFeaturedResult? featuredArticles;
  bool isLoading = true;
  bool hasError = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchFeaturedArticles();
  }

  Future<void> _fetchFeaturedArticles({bool refresh = false}) async {
    try {
      // Shared with the detail screen, which drops the whole section (title
      // row and tab) once the answer is empty.
      final result = await FeaturedArticles.load(
        widget.animeId,
        widget.category,
        widget.animeName,
        refresh: refresh,
      );
      if (!mounted) return;
      setState(() {
        featuredArticles = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint('Error fetching featured articles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return _buildLoadingState();
    }

    if (hasError) {
      return SectionMessage.error(
        message: S.current.Res_Featured_Failed,
        onRetry: () {
          setState(() {
            isLoading = true;
            hasError = false;
          });
          _fetchFeaturedArticles(refresh: true);
        },
      );
    }

    // Nothing to show: no block at all, as in DailyAL (no "no articles" message).
    if (featuredArticles == null ||
        featuredArticles!.featuredArticles.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: featuredArticles!.featuredArticles.length,
        itemBuilder: (context, index) {
          final article = featuredArticles!.featuredArticles[index];
          final theme = Theme.of(context);
          return SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  final match = RegExp(r'/featured/(\d+)').firstMatch(article.url);
                  final id = match != null ? int.tryParse(match.group(1)!) : null;
                  if (id != null) {
                    gotoPage(
                      context: context,
                      newPage: FeaturedScreen(
                        id: id,
                        featureTitle: article.title,
                        imgUrl: article.imageUrl,
                        category: 'featured',
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _imageWidget(article),
                    _titleWidget(article, theme),
                    _summaryWidget(article, theme),
                    _authorAndTagsWidget(article, theme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _imageWidget(AnimeFeatured article) {
    if (article.imageUrl.isNotEmpty) {
      return AvatarWidget(
        height: 110,
        width: double.infinity,
        url: article.imageUrl,
        radius: BorderRadius.zero,
        userRoundBorderforLoading: false,
      );
    }
    return Container(
      height: 110,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Icon(
          Icons.article_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _titleWidget(AnimeFeatured article, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Text(
        article.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _summaryWidget(AnimeFeatured article, ThemeData theme) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Text(
          article.text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
          overflow: TextOverflow.fade,
        ),
      ),
    );
  }

  Widget _authorAndTagsWidget(AnimeFeatured article, ThemeData theme) {
    final viewsFormatted = NumberFormat.compact().format(article.views);
    final mutedColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  article.author,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.visibility_outlined, size: 13, color: mutedColor),
              const SizedBox(width: 4),
              Text(
                viewsFormatted,
                style: theme.textTheme.labelSmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
          if (article.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: article.tags.take(3).map((tag) {
                final bool isSpoiler = tag.toLowerCase() == 'spoiler';
                final searchKey = _tagKey(tag);
                return Material(
                  color: isSpoiler
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    // Opens the featured search on this tag; a spoiler marker is a label.
                    onTap: searchKey == null
                        ? null
                        : () => gotoPage(
                              context: context,
                              newPage: GeneralSearchScreen.byTag(searchKey),
                            ),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isSpoiler
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
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
        itemBuilder: (context, index) {
          return SizedBox(
            width: 300,
            child: Card(
              margin: const EdgeInsets.only(right: 10, bottom: 4, top: 4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: ShimmerColor(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 110, color: Theme.of(context).colorScheme.onSurface),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Container(
                        height: 16,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Container(
                        height: 16,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 12, width: 70,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: 12, width: 40,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface,
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
          );
        },
      ),
    );
  }

  /// The featured-search key of a tag (matched ignoring case), null when the
  /// search does not know it (spoiler markers included).
  String? _tagKey(String tag) {
    final lower = tag.trim().toLowerCase();
    for (final key in ForumConstants.tags.keys) {
      if (key != 'All' && key.toLowerCase() == lower) return key;
    }
    return null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
