import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/screens/MAL/detail/sections/section_states.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/MAL/review/review_detail_page.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_summary.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

/// Reviews section of a detail page: the AI summary row, a filter bar (score distribution,
/// sort, score, tags) and a horizontal list of reviews that loads the next Jikan page near
/// its end. A tap on a review opens a swipeable sheet with the full text.
///
/// Source: Jikan `reviews`; when Jikan fails on the first page, the mwl-api
/// `reviews` route (MAL review pages parsed by the backend) serves this and
/// the next pages.
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
  static const _cardWidth = 300.0;
  static const _loadMoreDistance = 240.0;

  @override
  bool get wantKeepAlive => true;

  final List<AnimeReview> _reviews = [];
  List<AnimeReview> _visible = const [];
  bool _loading = true;
  bool _failed = false;
  bool _hasMore = true;
  int _page = 1;

  /// True once Jikan failed and the pages come from the mwl-api.
  bool _fromMwl = false;

  // One controller drives the list, the "near the end" listener and the jump made when the
  // user swipes between full reviews.
  final AutoScrollController _scroll = AutoScrollController();

  ReviewSort _sort = ReviewSort.newest;
  int? _score;
  final Set<String> _tags = {};
  Map<int, int> _distribution = const {};
  List<String> _availableTags = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore || _failed) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreDistance) _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _reviews.clear();
      _visible = const [];
      _page = 1;
      _hasMore = true;
      _fromMwl = false;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final (page, hasMore) = await _fetchPage();
      if (!mounted) return;
      _reviews.addAll(page);
      _hasMore = hasMore;
      _page++;
      _distribution = reviewScoreDistribution(_reviews);
      _availableTags = reviewTags(_reviews);
      setState(() {
        _loading = false;
        _visible = _filtered();
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error fetching reviews: $e');
      setState(() {
        _loading = false;
        // A failed next page keeps what is already shown and stops asking.
        if (_reviews.isEmpty) {
          _failed = true;
        } else {
          _hasMore = false;
        }
      });
    }
  }

  /// One page of reviews and whether another one exists.
  Future<(List<AnimeReview>, bool)> _fetchPage() async {
    if (!_fromMwl) {
      try {
        final response = await JikanApi().getAnimeReviews(widget.animeId, page: _page, category: widget.category);
        return (response.data, response.pagination.hasNextPage ?? false);
      } catch (e) {
        // A later page keeps Jikan's numbering: give up instead of mixing sources.
        if (_page > 1) rethrow;
        debugPrint('Jikan reviews failed, trying the mwl-api: $e');
        _fromMwl = true;
      }
    }
    final list = await JikanFallbacks.reviews(widget.animeId, widget.category, _page);
    return (list, list.isNotEmpty);
  }

  List<AnimeReview> _filtered() => filterReviews(_reviews, sort: _sort, score: _score, tags: _tags);

  void _refilter(VoidCallback change) {
    setState(() {
      change();
      _visible = _filtered();
    });
  }

  void _showReview(int index) {
    final controller = PageController(initialPage: index);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      enableDrag: false,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.9,
        child: PageView.builder(
          itemCount: _visible.length,
          controller: controller,
          onPageChanged: (page) {
            if (_scroll.hasClients) {
              _scroll.scrollToIndex(page, duration: const Duration(milliseconds: 200));
            }
          },
          itemBuilder: (_, i) => ReviewDetailPage(review: _visible[i], category: widget.category),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDistribution() {
    if (_distribution.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => _DistributionDialog(distribution: _distribution),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final hasContent = _reviews.isNotEmpty;
    return Column(
      children: [
        if (hasContent)
          ReviewSummaryEntry(
            id: widget.animeId,
            category: widget.category,
            texts: reviewTextsForSummary(_reviews),
          ),
        if (hasContent) _buildFilterBar(),
        SizedBox(
          height: hasContent ? 340 : 200,
          child: _loading && _reviews.isEmpty
              ? _buildLoadingState()
              : _failed
                  ? _buildErrorState()
                  : _visible.isEmpty
                      ? _buildEmptyState()
                      : _buildReviewList(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);
    final scores = _distribution.keys.toList()..sort();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            if (_distribution.isNotEmpty)
              IconButton(
                tooltip: S.current.Social_Reviews_Score_Distribution,
                onPressed: _showDistribution,
                icon: Icon(Icons.bar_chart, size: 20, color: theme.colorScheme.primary),
                visualDensity: VisualDensity.compact,
              ),
            _buildSortSelect(theme),
            if (scores.isNotEmpty) ...[
              const SizedBox(width: 8),
              _buildScoreSelect(theme, scores),
            ],
            for (final tag in _availableTags) _buildTagButton(theme, tag),
          ],
        ),
      ),
    );
  }

  Widget _buildSortSelect(ThemeData theme) {
    return PopupMenuButton<ReviewSort>(
      tooltip: S.current.Social_Reviews_Sort,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _refilter(() => _sort = value),
      itemBuilder: (_) => [
        for (final option in ReviewSort.values)
          PopupMenuItem<ReviewSort>(
            value: option,
            height: 40,
            child: Row(
              children: [
                Icon(
                  option.icon,
                  size: 16,
                  color: option == _sort ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  option.label,
                  style: TextStyle(
                    fontWeight: option == _sort ? FontWeight.w600 : FontWeight.normal,
                    color: option == _sort ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: _Pill(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(_sort.label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 2),
            Icon(_sort.icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSelect(ThemeData theme, List<int> scores) {
    final selected = _score;
    final foreground = selected != null ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;
    return PopupMenuButton<int>(
      tooltip: S.current.Social_Reviews_Filter_Score,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) => _refilter(() => _score = value),
      itemBuilder: (_) => [
        for (final score in scores.reversed)
          PopupMenuItem<int>(
            value: score,
            height: 40,
            child: Row(
              children: [
                Image.asset('assets/images/star.png', height: 16),
                const SizedBox(width: 8),
                Text(
                  '$score',
                  style: TextStyle(
                    fontWeight: score == selected ? FontWeight.w600 : FontWeight.normal,
                    color: score == selected ? theme.colorScheme.primary : null,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 16),
                Text(
                  '${_distribution[score] ?? 0}',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
      child: _Pill(
        color: selected != null ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/star.png', height: 14),
            const SizedBox(width: 6),
            if (selected != null) ...[
              Text('$selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: foreground)),
              const SizedBox(width: 6),
              // Clearing sits on its own tap target so it never opens the menu.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _refilter(() => _score = null),
                child: Tooltip(
                  message: S.current.Social_Reviews_Clear_Filter,
                  child: Icon(Icons.close, size: 16, color: foreground),
                ),
              ),
            ] else
              Icon(Icons.arrow_drop_down, size: 20, color: foreground),
          ],
        ),
      ),
    );
  }

  Widget _buildTagButton(ThemeData theme, String tag) {
    final selected = _tags.contains(tag);
    final foreground = selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: _Pill(
        color: selected ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
        onTap: () => _refilter(() => selected ? _tags.remove(tag) : _tags.add(tag)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.close, size: 14, color: foreground),
              const SizedBox(width: 4),
            ],
            Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList() {
    final showLoader = _hasMore && _loading;
    return ListView.builder(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _visible.length + (showLoader ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _visible.length) return const _LoadingCard();
        return AutoScrollTag(
          key: ValueKey(index),
          controller: _scroll,
          index: index,
          child: SizedBox(
            width: _cardWidth,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (_, __) => const _LoadingCard(detailed: true),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final filtered = _reviews.isNotEmpty;
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            TextButton(
              onPressed: () => _refilter(() {
                _score = null;
                _tags.clear();
              }),
              child: Text(S.current.Social_Reviews_Clear_Filter),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() => SectionMessage.error(
        height: 200,
        message: S.current.Social_Reviews_Failed,
        onRetry: () => _load(reset: true),
      );

}

/// Rounded filter button; wraps [child] with the tap area of a Material pill.
class _Pill extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  const _Pill({required this.color, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Placeholder card shown while reviews load ([detailed] = skeleton of a review).
class _LoadingCard extends StatelessWidget {
  final bool detailed;

  const _LoadingCard({this.detailed = false});

  @override
  Widget build(BuildContext context) {
    // The shimmer paints over the shape; any opaque theme colour works.
    final fill = Theme.of(context).colorScheme.onSurface;
    Widget bar(double height, double? width, [double radius = 4]) => Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius)),
        );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 12),
      child: ShimmerColor(
        SizedBox(
          width: 300,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: detailed
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [bar(28, 60), const SizedBox(height: 8), bar(12, 100)],
                            ),
                            bar(42, 42, 21),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(child: bar(double.infinity, double.infinity)),
                        const SizedBox(height: 10),
                        bar(14, 150),
                      ],
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(16)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Bars of the number of reviews per score (1 to 10).
class _DistributionDialog extends StatelessWidget {
  final Map<int, int> distribution;

  const _DistributionDialog({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = NumberFormat.compact(locale: Localizations.localeOf(context).toString());
    final maxCount = distribution.values.reduce((a, b) => a > b ? a : b);
    final total = distribution.values.fold(0, (a, b) => a + b);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.bar_chart, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(S.current.Social_Reviews_Score_Distribution, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 260,
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var score = 1; score <= 10; score++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if ((distribution[score] ?? 0) > 0)
                              Text(format.format(distribution[score]), style: const TextStyle(fontSize: 9)),
                            const SizedBox(height: 4),
                            Container(
                              height: maxCount > 0 ? (distribution[score] ?? 0) / maxCount * 180 : 0,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$score',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.current.Social_Reviews_Count(total),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.current.Social_Close)),
      ],
    );
  }
}
