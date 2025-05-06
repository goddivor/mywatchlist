// lib/widgets/show_reviews.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/review/review_detail_page.dart';
import 'package:mywatchlist/widgets/review/review_filter_state.dart';
import 'package:mywatchlist/widgets/review/review_filters.dart';
import 'package:mywatchlist/widgets/review/review_item.dart';
import 'package:mywatchlist/widgets/review/filter_chip_widget.dart';
import 'package:mywatchlist/widgets/review/sort_dropdown.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class ShowAnimeReviews extends StatefulWidget {
  final int animeId;
  final String category;

  const ShowAnimeReviews(
      {super.key, required this.animeId, this.category = "anime"});

  @override
  State<ShowAnimeReviews> createState() => _ShowAnimeReviewsState();
}

class _ShowAnimeReviewsState extends State<ShowAnimeReviews> {
  List<AnimeReview> reviews = [];
  List<AnimeReview> filteredReviews = [];
  bool isLoading = true;
  bool hasError = false;
  bool hasMoreReviews = true;
  int currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  late AutoScrollController _autoScrollController;
  PageController? _modalController;
  final ReviewFilterState _filterState = ReviewFilterState();

  @override
  void initState() {
    super.initState();
    _autoScrollController = AutoScrollController();
    _scrollController.addListener(_scrollListener);
    _filterState.addListener(_applyFilters);
    _fetchReviews();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (hasMoreReviews) {
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
      );

      setState(() {
        reviews.addAll(response.data);
        isLoading = false;
        hasMoreReviews = response.pagination.hasNextPage ?? false;

        // Calculate score distribution
        final scoreDistribution = <int, int>{};
        for (var review in reviews) {
          final score = review.score ?? 0;
          scoreDistribution[score] = (scoreDistribution[score] ?? 0) + 1;
        }
        _filterState.setScoreDistribution(scoreDistribution);
      });

      _applyFilters();
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      debugPrint('Error fetching reviews: $e');
    }
  }

  Future<void> _fetchMoreReviews() async {
    if (!hasMoreReviews || isLoading) return;

    setState(() {
      isLoading = true;
    });

    currentPage++;
    await _fetchReviews();
  }

  void _applyFilters() {
    final sortType = _filterState.sortType;
    final filterStates = _filterState.filterStates;

    // Start with all reviews
    List<AnimeReview> result = List.from(reviews);

    // Apply filters
    final hasActiveFilters =
        filterStates.values.any((state) => state != FilterState.inactive);

    if (hasActiveFilters) {
      // Category filters (recommended, mixed, not recommended)
      final includeRecommended =
          filterStates[ReviewFilterType.recommended] == FilterState.include;
      final excludeRecommended =
          filterStates[ReviewFilterType.recommended] == FilterState.exclude;

      final includeMixed =
          filterStates[ReviewFilterType.mixedFeelings] == FilterState.include;
      final excludeMixed =
          filterStates[ReviewFilterType.mixedFeelings] == FilterState.exclude;

      final includeNotRecommended =
          filterStates[ReviewFilterType.notRecommended] == FilterState.include;
      final excludeNotRecommended =
          filterStates[ReviewFilterType.notRecommended] == FilterState.exclude;

      // Reaction filters
      final includeFunny =
          filterStates[ReviewFilterType.funny] == FilterState.include;
      final excludeFunny =
          filterStates[ReviewFilterType.funny] == FilterState.exclude;

      final includeInformative =
          filterStates[ReviewFilterType.informative] == FilterState.include;
      final excludeInformative =
          filterStates[ReviewFilterType.informative] == FilterState.exclude;

      final includeWellWritten =
          filterStates[ReviewFilterType.wellWritten] == FilterState.include;
      final excludeWellWritten =
          filterStates[ReviewFilterType.wellWritten] == FilterState.exclude;

      final includeCreative =
          filterStates[ReviewFilterType.creative] == FilterState.include;
      final excludeCreative =
          filterStates[ReviewFilterType.creative] == FilterState.exclude;

      // Special case filters
      final includePreliminary =
          filterStates[ReviewFilterType.preliminary] == FilterState.include;
      final excludePreliminary =
          filterStates[ReviewFilterType.preliminary] == FilterState.exclude;

      final includeSpoiler =
          filterStates[ReviewFilterType.spoiler] == FilterState.include;
      final excludeSpoiler =
          filterStates[ReviewFilterType.spoiler] == FilterState.exclude;

      result = result.where((review) {
        // Recommendation category filtering
        final score = review.score ?? 0;
        final isRecommended = score >= 8;
        final isMixed = score >= 5 && score < 8;
        final isNotRecommended = score < 5;

        bool passesRecommendationFilter = true;

        if (includeRecommended) {
          passesRecommendationFilter = isRecommended;
        } else if (excludeRecommended) {
          passesRecommendationFilter = !isRecommended;
        }

        if (includeMixed) {
          passesRecommendationFilter = isMixed;
        } else if (excludeMixed) {
          passesRecommendationFilter = !isMixed;
        }

        if (includeNotRecommended) {
          passesRecommendationFilter = isNotRecommended;
        } else if (excludeNotRecommended) {
          passesRecommendationFilter = !isNotRecommended;
        }

        // Reaction filtering
        final reactions = review.reactions;
        bool passesReactionFilter = true;

        if (includeFunny) {
          passesReactionFilter = (reactions?.funny ?? 0) > 0;
        } else if (excludeFunny) {
          passesReactionFilter = (reactions?.funny ?? 0) == 0;
        }

        if (includeInformative) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.informative ?? 0) > 0;
        } else if (excludeInformative) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.informative ?? 0) == 0;
        }

        if (includeWellWritten) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.wellWritten ?? 0) > 0;
        } else if (excludeWellWritten) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.wellWritten ?? 0) == 0;
        }

        if (includeCreative) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.creative ?? 0) > 0;
        } else if (excludeCreative) {
          passesReactionFilter =
              passesReactionFilter && (reactions?.creative ?? 0) == 0;
        }

        // Special case filtering
        bool passesSpecialCaseFilter = true;

        if (includePreliminary) {
          passesSpecialCaseFilter = review.isPreliminary == true;
        } else if (excludePreliminary) {
          passesSpecialCaseFilter = review.isPreliminary != true;
        }

        if (includeSpoiler) {
          passesSpecialCaseFilter =
              passesSpecialCaseFilter && review.isSpoiler == true;
        } else if (excludeSpoiler) {
          passesSpecialCaseFilter =
              passesSpecialCaseFilter && review.isSpoiler != true;
        }

        return passesRecommendationFilter &&
            passesReactionFilter &&
            passesSpecialCaseFilter;
      }).toList();
    }

    // Apply sorting
    switch (sortType) {
      case ReviewSortType.dateDesc:
        result.sort((a, b) => _compareDate(b.date, a.date));
        break;
      case ReviewSortType.dateAsc:
        result.sort((a, b) => _compareDate(a.date, b.date));
        break;
      case ReviewSortType.scoreDesc:
        result.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
        break;
      case ReviewSortType.scoreAsc:
        result.sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));
        break;
    }

    setState(() {
      filteredReviews = result;
    });
  }

  int _compareDate(String? a, String? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    try {
      final dateA = DateTime.parse(a);
      final dateB = DateTime.parse(b);
      return dateA.compareTo(dateB);
    } catch (_) {
      return a.compareTo(b);
    }
  }

  void _showReviewDetails(int index) {
    _modalController = PageController(initialPage: index);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => Material(
        color: Colors.transparent,
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
              child: ReviewDetailPage(
                review: filteredReviews[i],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _filterState,
      child: Column(
        children: [
          _buildFilterSection(),
          if (filteredReviews.isEmpty && !isLoading)
            _buildEmptyState()
          else
            SizedBox(
              height: 450,
              child: _buildReviewList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort controls
          Row(
            children: [
              const Text('Sort by:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Consumer<ReviewFilterState>(
                builder: (context, filterState, _) {
                  return SortDropdown(
                    sortType: filterState.sortType,
                    onChanged: (sortType) {
                      if (sortType != null) {
                        filterState.setSortType(sortType);
                      }
                    },
                    scoreDistribution: filterState.scoreDistribution,
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Consumer<ReviewFilterState>(
              builder: (context, filterState, _) {
                return Row(
                  children: [
                    const Text('Filter:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ...ReviewFilterType.values.map((filter) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChipWidget(
                            filter: filter,
                            state: filterState.filterStates[filter] ??
                                FilterState.inactive,
                            onTap: () => filterState.toggleFilter(filter),
                          ),
                        )),
                    if (filterState.filterStates.values
                        .any((state) => state != FilterState.inactive))
                      TextButton.icon(
                        onPressed: filterState.resetFilters,
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewList() {
    if (isLoading && reviews.isEmpty) {
      return _buildLoadingState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredReviews.length + (hasMoreReviews && isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredReviews.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return AutoScrollTag(
          key: ValueKey(index),
          controller: _autoScrollController,
          index: index,
          child: ReviewItem(
            review: filteredReviews[index],
            onTap: () => _showReviewDetails(index),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ShimmerColor(
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune critique disponible',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
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
    _filterState.removeListener(_applyFilters);
    super.dispose();
  }
}
