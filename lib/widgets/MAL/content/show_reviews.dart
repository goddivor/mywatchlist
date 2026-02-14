import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/MAL/review/review_detail_page.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ShowAnimeReviews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeReviews({
    super.key,
    required this.animeId,
    this.category = "anime",
  });

  @override
  State<ShowAnimeReviews> createState() => _ShowAnimeReviewsState();
}

class _ShowAnimeReviewsState extends State<ShowAnimeReviews>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<AnimeReview> reviews = [];
  List<AnimeReview> filteredReviews = [];
  bool isLoading = true;
  bool hasError = false;
  bool hasMoreReviews = true;
  int currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  late AutoScrollController _autoScrollController;
  PageController? _modalController;

  // Filter state
  String _sortBy = 'date'; // 'date', 'score_desc', 'score_asc'
  int? _selectedScore;
  Map<int, int> _scoreDistribution = {};

  @override
  void initState() {
    super.initState();
    _autoScrollController = AutoScrollController();
    _scrollController.addListener(_scrollListener);
    _fetchReviews();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (hasMoreReviews && !isLoading) {
        _fetchMoreReviews();
      }
    }
  }

  Future<void> _fetchReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        currentPage = 1;
        reviews.clear();
        filteredReviews.clear();
        isLoading = true;
        hasError = false;
      });
    }

    try {
      final response = await JikanApi().getAnimeReviews(
        widget.animeId,
        page: currentPage,
        category: widget.category,
      );

      if (!mounted) return;
      setState(() {
        reviews.addAll(response.data);
        isLoading = false;
        hasMoreReviews = response.pagination.hasNextPage ?? false;
        // Recompute score distribution
        _scoreDistribution = {};
        for (var review in reviews) {
          final score = review.score ?? 0;
          _scoreDistribution[score] = (_scoreDistribution[score] ?? 0) + 1;
        }
      });

      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint('Error fetching reviews: $e');
    }
  }

  Future<void> _fetchMoreReviews() async {
    if (!hasMoreReviews || isLoading || !mounted) return;
    setState(() => isLoading = true);
    currentPage++;
    await _fetchReviews();
  }

  void _applyFilters() {
    List<AnimeReview> result = List.from(reviews);

    // Score filter
    if (_selectedScore != null) {
      result =
          result.where((review) => review.score == _selectedScore).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'score_desc':
        result.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
        break;
      case 'score_asc':
        result.sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));
        break;
      case 'date':
      default:
        // Keep API order (newest first)
        break;
    }

    if (!mounted) return;
    setState(() => filteredReviews = result);
  }

  void _showReviewDetails(int index) {
    _modalController = PageController(initialPage: index);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: PageView.builder(
            itemCount: filteredReviews.length,
            controller: _modalController,
            onPageChanged: (pageIndex) {
              _autoScrollController.scrollToIndex(
                pageIndex,
                duration: const Duration(milliseconds: 200),
              );
            },
            itemBuilder: (context, i) => SingleChildScrollView(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.9,
                child: ReviewDetailPage(review: filteredReviews[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        _buildFilterBar(),
        SizedBox(
          height: 340,
          child: isLoading && reviews.isEmpty
              ? _buildLoadingState()
              : hasError
                  ? _buildErrorState()
                  : filteredReviews.isEmpty
                      ? _buildEmptyState()
                      : _buildReviewList(),
        ),
      ],
    );
  }

  void _showScoreDistributionDialog() {
    if (_scoreDistribution.isEmpty) return;

    final maxCount = _scoreDistribution.values.reduce((a, b) => a > b ? a : b);
    final totalReviews = _scoreDistribution.values.fold(0, (a, b) => a + b);
    final theme = Theme.of(context);
    final format = NumberFormat.compact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.bar_chart, color: theme.colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Score Distribution', style: TextStyle(fontSize: 16)),
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
                  children: List.generate(10, (i) {
                    final score = i + 1;
                    final count = _scoreDistribution[score] ?? 0;
                    final barHeight =
                        maxCount > 0 ? (count / maxCount * 180) : 0.0;
                    final Color barColor = score >= 8
                        ? Colors.green
                        : (score >= 5 ? Colors.amber : Colors.red);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (count > 0)
                              Text(
                                format.format(count),
                                style: const TextStyle(fontSize: 9),
                              ),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: barColor,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
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
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$totalReviews reviews',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final theme = Theme.of(context);

    // Get unique scores for the score filter
    final scores = reviews.map((r) => r.score ?? 0).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Score distribution button
            if (_scoreDistribution.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  onPressed: _showScoreDistributionDialog,
                  icon: Icon(
                    Icons.bar_chart,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),

            // Sort chips
            _buildSortChip(theme, 'Recent', 'date'),
            const SizedBox(width: 6),
            _buildSortChip(theme, 'Best', 'score_desc'),
            const SizedBox(width: 6),
            _buildSortChip(theme, 'Worst', 'score_asc'),

            if (scores.isNotEmpty) ...[
              const SizedBox(width: 12),
              // Vertical divider
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: theme.colorScheme.outlineVariant,
              ),
              const SizedBox(width: 12),

              // Score filter chips
              if (_selectedScore != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/images/star.png', height: 14),
                        const SizedBox(width: 4),
                        Text('$_selectedScore'),
                        const SizedBox(width: 4),
                        const Icon(Icons.close, size: 14),
                      ],
                    ),
                    onPressed: () {
                      setState(() => _selectedScore = null);
                      _applyFilters();
                    },
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                )
              else
                ...scores.reversed.map((score) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        avatar:
                            Image.asset('assets/images/star.png', height: 14),
                        label: Text('$score'),
                        onPressed: () {
                          setState(() => _selectedScore = score);
                          _applyFilters();
                        },
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                      ),
                    )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSortChip(ThemeData theme, String label, String sortValue) {
    final isSelected = _sortBy == sortValue;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isSelected ? theme.colorScheme.onPrimary : null,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _sortBy = sortValue);
        _applyFilters();
      },
      selectedColor: theme.colorScheme.primary,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildReviewList() {
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredReviews.length + (hasMoreReviews && isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredReviews.length) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ShimmerColor(
              SizedBox(
                width: 300,
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return AutoScrollTag(
          key: ValueKey(index),
          controller: _autoScrollController,
          index: index,
          child: SizedBox(
            width: 300,
            child: ReviewItem(
              review: filteredReviews[index],
              onTap: () => _showReviewDetails(index),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: ShimmerColor(
            SizedBox(
              width: 300,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
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
                            children: [
                              Container(
                                height: 28,
                                width: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 42,
                            width: 42,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(21),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 14,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
              Icons.rate_review_outlined,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'No reviews available',
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
              'Failed to load reviews',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _fetchReviews(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _autoScrollController.dispose();
    _modalController?.dispose();
    super.dispose();
  }
}
