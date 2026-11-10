import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/review/review_detail_page.dart';
import 'package:mywatchlist/widgets/MAL/review/review_filter_bar.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_summary.dart';
import 'package:mywatchlist/widgets/MAL/review/reviews_feed.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// Reviews section of a detail page, laid out like DailyAL's: the AI summary
/// row, the filter row (score distribution, score, sort, tags) and a
/// horizontal list of 320 dp review cards that loads the next page near its
/// end. A tap on a review opens a swipeable sheet with the full text; the
/// section's arrow opens [ReviewsListScreen].
///
/// Source: [ReviewsFeed] (Jikan raced against the mwl-api `reviews` route).
class ShowAnimeReviews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeReviews({
    super.key,
    required this.animeId,
    this.category = 'anime',
  });

  @override
  State<ShowAnimeReviews> createState() => _ShowAnimeReviewsState();
}

class _ShowAnimeReviewsState extends State<ShowAnimeReviews> with AutomaticKeepAliveClientMixin {
  static const _cardWidth = 320.0;
  static const _listHeight = 385.0;
  static const _loadMoreDistance = 240.0;

  @override
  bool get wantKeepAlive => true;

  late final ReviewsFeed _feed = ReviewsFeed(id: widget.animeId, category: widget.category);
  ReviewFilters _filters = const ReviewFilters();
  List<AnimeReview> _visible = const [];

  // One controller drives the list, the "near the end" listener and the jump made when the
  // user swipes between full reviews.
  final AutoScrollController _scroll = AutoScrollController(axis: Axis.horizontal);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Started before listening: the feed's synchronous "loading" notice must not call
    // setState inside initState.
    _feed.start();
    _feed.addListener(_onFeed);
  }

  @override
  void dispose() {
    _feed.removeListener(_onFeed);
    _feed.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onFeed() => setState(() => _visible = _filtered());

  void _onScroll() {
    if (!_scroll.hasClients || _feed.loading || !_feed.hasMore) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) _feed.loadMore();
  }

  List<AnimeReview> _filtered() =>
      filterReviews(_feed.reviews, sort: _filters.sort, score: _filters.score, tags: _filters.tags);

  void _setFilters(ReviewFilters filters) => setState(() {
        _filters = filters;
        _visible = _filtered();
      });

  void _showReview(int index) {
    showReviewPager(
      context,
      reviews: _visible,
      initialIndex: index,
      category: widget.category,
      onPageChanged: (page) {
        if (_scroll.hasClients) {
          _scroll.scrollToIndex(page, duration: const Duration(milliseconds: 200));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final reviews = _feed.reviews;
    final hasContent = reviews.isNotEmpty;
    final Widget body;
    if (_feed.loading && !hasContent) {
      body = SizedBox(height: _listHeight, child: _buildLoadingState());
    } else if (_feed.failed) {
      body = SectionMessage.error(
        height: 200,
        message: S.current.Social_Reviews_Failed,
        onRetry: () => _feed.start(reset: true),
      );
    } else if (_visible.isEmpty) {
      body = SizedBox(height: 200, child: _buildEmptyState(filtered: hasContent));
    } else {
      body = SizedBox(height: _listHeight, child: _buildReviewList());
    }
    return Column(
      children: [
        if (hasContent)
          ReviewSummaryEntry(
            id: widget.animeId,
            category: widget.category,
            texts: reviewTextsForSummary(reviews),
          ),
        if (hasContent)
          ReviewFilterBar(
            filters: _filters,
            distribution: _feed.distribution,
            tags: _feed.tags,
            onChanged: _setFilters,
          ),
        if (hasContent) const SizedBox(height: 12),
        body,
      ],
    );
  }

  Widget _buildReviewList() {
    final showLoader = _feed.hasMore && _feed.loading;
    return ListView.builder(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      itemExtent: _cardWidth,
      itemCount: _visible.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _visible.length) return const ReviewLoadingCard();
        return AutoScrollTag(
          key: ValueKey(index),
          controller: _scroll,
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 17),
            child: ReviewItem(review: _visible[index], onTap: () => _showReview(index)),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      itemExtent: _cardWidth,
      itemCount: 3,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 17),
        child: ReviewLoadingCard(),
      ),
    );
  }

  Widget _buildEmptyState({required bool filtered}) {
    return ReviewsEmptyState(
      filtered: filtered,
      onClear: () => _setFilters(_filters.cleared()),
    );
  }
}

/// Opens the full reviews in a sheet the user swipes through (DailyAL's
/// "show more" pager), starting at [initialIndex].
void showReviewPager(
  BuildContext context, {
  required List<AnimeReview> reviews,
  required int initialIndex,
  required String category,
  ValueChanged<int>? onPageChanged,
}) {
  final controller = PageController(initialPage: initialIndex);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    enableDrag: false,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.9,
      child: PageView.builder(
        itemCount: reviews.length,
        controller: controller,
        onPageChanged: onPageChanged,
        itemBuilder: (_, i) => ReviewDetailPage(review: reviews[i], category: category),
      ),
    ),
  ).whenComplete(controller.dispose);
}

/// No review at all, or none left by the filters (with a button clearing them).
class ReviewsEmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClear;

  const ReviewsEmptyState({super.key, required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rate_review_outlined, size: 40, color: color),
          const SizedBox(height: 12),
          Text(
            filtered ? S.current.Social_Reviews_Empty_Filtered : S.current.Social_Reviews_Empty,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
          if (filtered) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onClear, child: Text(S.current.Social_Reviews_Clear_Filter)),
          ],
        ],
      ),
    );
  }
}

/// Skeleton of a review card while reviews load.
class ReviewLoadingCard extends StatelessWidget {
  const ReviewLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The shimmer paints over the shapes; any opaque theme colour works.
    final fill = scheme.onSurface;
    Widget bar(double height, double? width, [double radius = 4]) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius)),
        );
    return Card(
      margin: const EdgeInsetsDirectional.only(end: 10, bottom: 4, top: 4),
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ShimmerColor(
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(24, 60), const SizedBox(height: 10), bar(10, 90), const SizedBox(height: 4), bar(10, 70)],
                  ),
                  bar(40, 40, 20),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(child: bar(double.infinity, double.infinity)),
              const SizedBox(height: 10),
              bar(12, 150),
            ],
          ),
        ),
      ),
    );
  }
}
