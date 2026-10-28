import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';
import 'package:mywatchlist/widgets/MAL/review/review_filter_bar.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/reviews_feed.dart';

/// Every review of a title in one vertical list (DailyAL's "view all"
/// reviews page): pinned app bar with the filter row under the title, the
/// number of reviews shown, then 400 dp cards; the next page loads near the
/// end of the list.
class ReviewsListScreen extends StatefulWidget {
  final int id;
  final String category;

  const ReviewsListScreen({super.key, required this.id, this.category = 'anime'});

  @override
  State<ReviewsListScreen> createState() => _ReviewsListScreenState();
}

class _ReviewsListScreenState extends State<ReviewsListScreen> {
  static const double _cardHeight = 400;
  static const double _loadMoreDistance = 800;

  late final ReviewsFeed _feed = ReviewsFeed(id: widget.id, category: widget.category);
  final ScrollController _scroll = ScrollController();
  ReviewFilters _filters = const ReviewFilters();
  List<AnimeReview> _visible = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
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

  String get _webUrl => 'https://myanimelist.net/${widget.category}/${widget.id}/x/reviews';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = !_feed.isEmpty;
    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            title: Text(S.current.Dh_Tab_Reviews),
            actions: [
              IconButton(
                tooltip: S.current.Social_Review_Open_Web,
                icon: const Icon(Icons.open_in_browser),
                onPressed: () => openLink(context, _webUrl),
              ),
            ],
            bottom: hasContent
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(46),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ReviewFilterBar(
                        filters: _filters,
                        distribution: _feed.distribution,
                        tags: _feed.tags,
                        onChanged: _setFilters,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      ),
                    ),
                  )
                : null,
          ),
          ..._content(theme, hasContent),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  List<Widget> _content(ThemeData theme, bool hasContent) {
    if (_feed.loading && !hasContent) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(10, 20, 0, 0),
          sliver: SliverFixedExtentList(
            itemExtent: _cardHeight,
            delegate: SliverChildBuilderDelegate((_, __) => const ReviewLoadingCard(), childCount: 2),
          ),
        ),
      ];
    }
    if (_feed.failed) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: SectionMessage.error(
            height: 300,
            message: S.current.Social_Reviews_Failed,
            onRetry: () => _feed.start(reset: true),
          ),
        ),
      ];
    }
    if (_visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ReviewsEmptyState(filtered: hasContent, onClear: () => _setFilters(_filters.cleared())),
        ),
      ];
    }
    final showLoader = _feed.hasMore && _feed.loading;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            S.current.Social_Reviews_Count(_visible.length),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsetsDirectional.only(start: 10),
        sliver: SliverFixedExtentList(
          itemExtent: _cardHeight,
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == _visible.length) return const ReviewLoadingCard();
              return ReviewItem(
                review: _visible[index],
                onTap: () => showReviewPager(
                  context,
                  reviews: _visible,
                  initialIndex: index,
                  category: widget.category,
                ),
              );
            },
            childCount: _visible.length + (showLoader ? 1 : 0),
          ),
        ),
      ),
    ];
  }
}
