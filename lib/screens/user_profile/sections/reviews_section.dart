import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/interest_stack_detail_screen.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tab.dart';
import 'package:mywatchlist/screens/user_profile/sections/profile_tabs_source.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart' show InterestStack;
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart' show InterestStackPictures;
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart' show showReviewPager;
import 'package:mywatchlist/widgets/MAL/review/review_item.dart' show ReviewScoreBadge;
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/user/profile/profile_states.dart';

/// A tab that lists what one MyAnimeList page gives a page at a time, with a "load more"
/// button under the last page. Tabs are built lazily and keep their state while the user
/// swipes around.
class _PagedProfileTab<T> extends StatefulWidget {
  final String storageKey;
  final Future<ProfilePage<T>> Function(int page) loader;
  final IconData emptyIcon;
  final String Function(S s) emptyTitle;
  final Widget Function(BuildContext context, List<T> items, int index) itemBuilder;

  const _PagedProfileTab({
    required this.storageKey,
    required this.loader,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.itemBuilder,
  });

  @override
  State<_PagedProfileTab<T>> createState() => _PagedProfileTabState<T>();
}

class _PagedProfileTabState<T> extends State<_PagedProfileTab<T>>
    with AutomaticKeepAliveClientMixin {
  final List<T> _items = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = true;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.loader(_page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _items.addAll(page.items);
        _hasNext = page.hasNext && page.items.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);

    if (_items.isEmpty) {
      final Widget child;
      if (_loading) {
        child = ProfileLoading(label: s.Prof_Loading);
      } else if (_error != null) {
        child = ProfileErrorView(error: _error!, onRetry: _loadNext);
      } else {
        child = ProfileMessage(icon: widget.emptyIcon, title: widget.emptyTitle(s));
      }
      return ProfileTabScroll(
        storageKey: widget.storageKey,
        slivers: [SliverFillRemaining(hasScrollBody: false, child: child)],
      );
    }

    return ProfileTabScroll(
      storageKey: widget.storageKey,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverList.builder(
          itemCount: _items.length,
          itemBuilder: (context, i) => widget.itemBuilder(context, _items, i),
        ),
        if (_hasNext || _error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : OutlinedButton(
                        onPressed: _loadNext,
                        child: Text(_error != null ? s.Prof_Retry : s.Prof_Load_More),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Reviews
// -----------------------------------------------------------------------------

/// The reviews a MyAnimeList user wrote: the title, the score, the start of the text. A tap
/// opens the review in the same pager the title pages use.
class ReviewsSection extends StatelessWidget {
  final String username;

  const ReviewsSection({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return _PagedProfileTab<ProfileReview>(
      storageKey: 'reviews_$username',
      loader: (page) => ProfileTabsSource.reviews(username, page: page),
      emptyIcon: Icons.rate_review_outlined,
      emptyTitle: (s) => s.Mpe_Reviews_Empty,
      itemBuilder: (context, items, i) => _ReviewTile(
        review: items[i],
        onTap: () => showReviewPager(
          context,
          reviews: [for (final r in items) r.toAnimeReview(username)],
          initialIndex: i,
          category: items[i].media.category,
        ),
      ),
    );
  }
}

extension ProfileReviewToJikan on ProfileReview {
  /// The review in the shape the review pager reads, with the profile's owner as reviewer.
  AnimeReview toAnimeReview(String username) => AnimeReview(
        user: User(username: username),
        malId: id,
        url: url,
        type: media.category,
        reactions: Reactions(overall: reactions),
        date: date?.toIso8601String(),
        review: text,
        score: score,
        tags: tags,
      );
}

/// A cover that opens its anime or manga page.
class _MediaCover extends StatelessWidget {
  final ProfileMediaRef media;
  final double width;
  final double height;

  const _MediaCover({required this.media, this.width = 56, this.height = 80});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: media.title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => AppRoutes.openContent(context, id: media.id, category: media.category),
        child: AppImage(
          url: media.imageUrl,
          width: width,
          height: height,
          borderRadius: BorderRadius.circular(8),
          placeholderColor: cs.surfaceContainerHighest,
        ),
      ),
    );
  }
}

/// "Sep 9, 2007" in the app's language, or MAL's own wording when it is not a plain day.
String? _dateLabel(BuildContext context, DateTime? date, String? text) {
  if (date == null) return text;
  return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(date);
}

class _ReviewTile extends StatelessWidget {
  final ProfileReview review;
  final VoidCallback onTap;

  const _ReviewTile({required this.review, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final faded = theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final date = _dateLabel(context, review.date, review.dateText);
    final meta = [
      if (date != null) date,
      ...review.tags,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MediaCover(media: review.media),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            review.media.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if ((review.score ?? 0) > 0) ...[
                          const SizedBox(width: 8),
                          ReviewScoreBadge(score: review.score, size: 16),
                        ],
                      ],
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: faded),
                    ],
                    if (review.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        review.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ],
                    if (review.reactions > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.thumb_up_alt_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${review.reactions}', style: faded),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Recommendations
// -----------------------------------------------------------------------------

/// The recommendations a MyAnimeList user made: "if you liked A, you might like B", with the
/// reason they gave.
class RecommendationsSection extends StatelessWidget {
  final String username;

  const RecommendationsSection({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return _PagedProfileTab<ProfileRecommendation>(
      storageKey: 'recommendations_$username',
      loader: (page) => ProfileTabsSource.recommendations(username, page: page),
      emptyIcon: Icons.thumbs_up_down_outlined,
      emptyTitle: (s) => s.Mpe_Recs_Empty,
      itemBuilder: (context, items, i) => _RecommendationTile(recommendation: items[i]),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final ProfileRecommendation recommendation;

  const _RecommendationTile({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final date = _dateLabel(context, recommendation.date, recommendation.dateText);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _RecommendedTitle(media: recommendation.from)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 28),
                    child: Icon(Icons.arrow_forward_rounded, color: cs.onSurfaceVariant),
                  ),
                  Expanded(child: _RecommendedTitle(media: recommendation.to)),
                ],
              ),
            ),
            if (recommendation.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                recommendation.text,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
            ],
            if (date != null) ...[
              const SizedBox(height: 8),
              Text(
                date,
                style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecommendedTitle extends StatelessWidget {
  final ProfileMediaRef media;

  const _RecommendedTitle({required this.media});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaCover(media: media, width: 48, height: 68),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            media.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Interest stacks
// -----------------------------------------------------------------------------

/// The interest stacks a MyAnimeList user made or restacked.
class StacksSection extends StatelessWidget {
  final String username;

  const StacksSection({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return _PagedProfileTab<InterestStack>(
      storageKey: 'stacks_$username',
      loader: (page) => ProfileTabsSource.stacks(username, page: page),
      emptyIcon: Icons.collections_bookmark_outlined,
      emptyTitle: (s) => s.Mpe_Stacks_Empty,
      itemBuilder: (context, items, i) => _StackTile(stack: items[i]),
    );
  }
}

class _StackTile extends StatelessWidget {
  final InterestStack stack;

  const _StackTile({required this.stack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final faded = theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final images = List<String>.from((stack.imageUrls ?? const <String>[]).reversed);
    final updated = stack.updatedAt;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => gotoPage(context: context, newPage: InterestStackDetailScreen(stack: stack)),
        child: SizedBox(
          height: 110,
          child: Row(
            children: [
              SizedBox(width: 110, child: InterestStackPictures(images: images)),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stack.title?.trim() ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          S.of(context).Social_Stack_Entries(stack.entries ?? 0),
                          S.of(context).Social_Stack_Restacks(stack.reStacks ?? 0),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: faded,
                      ),
                      if (updated != null && updated.isNotEmpty)
                        Text(updated, maxLines: 1, overflow: TextOverflow.ellipsis, style: faded),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Blog
// -----------------------------------------------------------------------------

/// The blog entries of a MyAnimeList user; a tap opens the entry (with its comments) on
/// MyAnimeList.
class BlogSection extends StatelessWidget {
  final String username;

  const BlogSection({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncProfileTab<List<ProfileBlogPost>>(
      storageKey: 'blog_$username',
      loader: () => ProfileTabsSource.blog(username),
      isEmpty: (posts) => posts.isEmpty,
      emptyBuilder: (context) =>
          ProfileMessage(icon: Icons.article_outlined, title: s.Mpe_Blog_Empty),
      slivers: (context, posts) => [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverList.builder(
          itemCount: posts.length,
          itemBuilder: (context, i) => _BlogTile(post: posts[i]),
        ),
      ],
    );
  }
}

class _BlogTile extends StatelessWidget {
  final ProfileBlogPost post;

  const _BlogTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final faded = theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => openLink(context, post.url),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.title, style: theme.textTheme.titleSmall),
              if (post.dateText != null) ...[
                const SizedBox(height: 2),
                Text(post.dateText!, style: faded),
              ],
              if (post.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.text,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
              const SizedBox(height: 8),
              Text(S.of(context).Mpe_Comments_Count(post.comments), style: faded),
            ],
          ),
        ),
      ),
    );
  }
}
