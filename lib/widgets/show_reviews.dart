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

  const ShowAnimeReviews({
    super.key, 
    required this.animeId,
    this.category = "anime"
  });

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
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
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
    final selectedScore = _filterState.selectedScore;
    
    // Start with all reviews
    List<AnimeReview> result = List.from(reviews);
    
    // Apply score filter if selected
    if (selectedScore != null) {
      result = result.where((review) => 
        review.score == selectedScore).toList();
    }
    
    // Apply other filters
    final hasActiveFilters = filterStates.values.any((state) => state != FilterState.inactive);
    
    if (hasActiveFilters) {
      // Category filters (recommended, mixed, not recommended)
      final includeRecommended = filterStates[ReviewFilterType.recommended] == FilterState.include;
      final excludeRecommended = filterStates[ReviewFilterType.recommended] == FilterState.exclude;
      
      final includeMixed = filterStates[ReviewFilterType.mixedFeelings] == FilterState.include;
      final excludeMixed = filterStates[ReviewFilterType.mixedFeelings] == FilterState.exclude;
      
      final includeNotRecommended = filterStates[ReviewFilterType.notRecommended] == FilterState.include;
      final excludeNotRecommended = filterStates[ReviewFilterType.notRecommended] == FilterState.exclude;
      
      // Reaction filters
      final includeFunny = filterStates[ReviewFilterType.funny] == FilterState.include;
      final excludeFunny = filterStates[ReviewFilterType.funny] == FilterState.exclude;
      
      final includeNice = filterStates[ReviewFilterType.nice] == FilterState.include;
      final excludeNice = filterStates[ReviewFilterType.nice] == FilterState.exclude;
      
      final includeLoveIt = filterStates[ReviewFilterType.loveIt] == FilterState.include;
      final excludeLoveIt = filterStates[ReviewFilterType.loveIt] == FilterState.exclude;
      
      final includeConfusing = filterStates[ReviewFilterType.confusing] == FilterState.include;
      final excludeConfusing = filterStates[ReviewFilterType.confusing] == FilterState.exclude;
      
      final includeInformative = filterStates[ReviewFilterType.informative] == FilterState.include;
      final excludeInformative = filterStates[ReviewFilterType.informative] == FilterState.exclude;
      
      final includeWellWritten = filterStates[ReviewFilterType.wellWritten] == FilterState.include;
      final excludeWellWritten = filterStates[ReviewFilterType.wellWritten] == FilterState.exclude;
      
      final includeCreative = filterStates[ReviewFilterType.creative] == FilterState.include;
      final excludeCreative = filterStates[ReviewFilterType.creative] == FilterState.exclude;
      
      // Special case filters
      final includePreliminary = filterStates[ReviewFilterType.preliminary] == FilterState.include;
      final excludePreliminary = filterStates[ReviewFilterType.preliminary] == FilterState.exclude;
      
      final includeSpoiler = filterStates[ReviewFilterType.spoiler] == FilterState.include;
      final excludeSpoiler = filterStates[ReviewFilterType.spoiler] == FilterState.exclude;
      
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
        
        if (includeNice) {
          passesReactionFilter = (reactions?.nice ?? 0) > 0;
        } else if (excludeNice) {
          passesReactionFilter = (reactions?.nice ?? 0) == 0;
        }
        
        if (includeLoveIt) {
          passesReactionFilter = passesReactionFilter && (reactions?.loveIt ?? 0) > 0;
        } else if (excludeLoveIt) {
          passesReactionFilter = passesReactionFilter && (reactions?.loveIt ?? 0) == 0;
        }
        
        if (includeFunny) {
          passesReactionFilter = passesReactionFilter && (reactions?.funny ?? 0) > 0;
        } else if (excludeFunny) {
          passesReactionFilter = passesReactionFilter && (reactions?.funny ?? 0) == 0;
        }
        
        if (includeConfusing) {
          passesReactionFilter = passesReactionFilter && (reactions?.confusing ?? 0) > 0;
        } else if (excludeConfusing) {
          passesReactionFilter = passesReactionFilter && (reactions?.confusing ?? 0) == 0;
        }
        
        if (includeInformative) {
          passesReactionFilter = passesReactionFilter && (reactions?.informative ?? 0) > 0;
        } else if (excludeInformative) {
          passesReactionFilter = passesReactionFilter && (reactions?.informative ?? 0) == 0;
        }
        
        if (includeWellWritten) {
          passesReactionFilter = passesReactionFilter && (reactions?.wellWritten ?? 0) > 0;
        } else if (excludeWellWritten) {
          passesReactionFilter = passesReactionFilter && (reactions?.wellWritten ?? 0) == 0;
        }
        
        if (includeCreative) {
          passesReactionFilter = passesReactionFilter && (reactions?.creative ?? 0) > 0;
        } else if (excludeCreative) {
          passesReactionFilter = passesReactionFilter && (reactions?.creative ?? 0) == 0;
        }
        
        // Special case filtering
        bool passesSpecialCaseFilter = true;
        
        if (includePreliminary) {
          passesSpecialCaseFilter = review.isPreliminary == true;
        } else if (excludePreliminary) {
          passesSpecialCaseFilter = review.isPreliminary != true;
        }
        
        if (includeSpoiler) {
          passesSpecialCaseFilter = passesSpecialCaseFilter && review.isSpoiler == true;
        } else if (excludeSpoiler) {
          passesSpecialCaseFilter = passesSpecialCaseFilter && review.isSpoiler != true;
        }
        
        return passesRecommendationFilter && passesReactionFilter && passesSpecialCaseFilter;
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
              child: ReviewDetailPage(
                review: filteredReviews[i],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  void _showScoreFilterBottomSheet() {
    final distribution = _filterState.scoreDistribution;
    if (distribution == null) return;
    
    final scores = distribution.keys.toList()..sort();
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Filtrer par score',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _filterState.selectedScore == null,
                  onSelected: (_) {
                    setState(() {
                      _filterState.setSelectedScore(null);
                      Navigator.pop(context);
                    });
                  },
                ),
                ...scores.map((score) => FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$score'),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/images/star.png',
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text('(${distribution[score]})')
                    ],
                  ),
                  selected: _filterState.selectedScore == score,
                  onSelected: (_) {
                    setState(() {
                      _filterState.setSelectedScore(score);
                      Navigator.pop(context);
                    });
                  },
                )),
              ],
            ),
          ],
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
          _buildFilterBar(),
          SizedBox(
            height: 270,
            child: filteredReviews.isEmpty && !isLoading
                ? _buildEmptyState()
                : _buildReviewList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Sort controls
            Consumer<ReviewFilterState>(
              builder: (context, filterState, _) {
                return Row(
                  children: [
                    const Text(
                      'Trier:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    
                    // Sort buttons instead of dropdown
                    Row(
                      children: [
                        // Date (newest first)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          tooltip: 'Date: Récent → Ancien',
                          color: filterState.sortType == ReviewSortType.dateDesc
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          onPressed: () {
                            filterState.setSortType(ReviewSortType.dateDesc);
                          },
                        ),
                        
                        // Date (oldest first)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: 'Date: Ancien → Récent',
                          color: filterState.sortType == ReviewSortType.dateAsc
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          onPressed: () {
                            filterState.setSortType(ReviewSortType.dateAsc);
                          },
                        ),
                        
                        // Score (high to low)
                        IconButton(
                          icon: Image.asset(
                            'assets/images/star.png',
                            height: 24,
                            color: filterState.sortType == ReviewSortType.scoreDesc
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          tooltip: 'Score: Haut → Bas',
                          onPressed: () {
                            filterState.setSortType(ReviewSortType.scoreDesc);
                          },
                        ),
                        
                        // Score (low to high)
                        Transform.rotate(
                          angle: 3.14159, // 180 degrees in radians
                          child: IconButton(
                            icon: Image.asset(
                              'assets/images/star.png',
                              height: 24,
                              color: filterState.sortType == ReviewSortType.scoreAsc
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            tooltip: 'Score: Bas → Haut',
                            onPressed: () {
                              filterState.setSortType(ReviewSortType.scoreAsc);
                            },
                          ),
                        ),
                        
                        // Score distribution button
                        if (filterState.scoreDistribution != null)
                          IconButton(
                            icon: const Icon(Icons.bar_chart),
                            tooltip: 'Distribution des scores',
                            onPressed: () => _showScoreDistributionDialog(context),
                          ),
                        
                        // Score filter button
                        IconButton(
                          icon: Stack(
                            alignment: Alignment.center,
                            children: [
                              Image.asset(
                                'assets/images/star.png',
                                height: 24,
                              ),
                              if (filterState.selectedScore != null)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${filterState.selectedScore}',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          tooltip: 'Filtrer par score',
                          onPressed: _showScoreFilterBottomSheet,
                        ),
                      ],
                    ),
                    
                    const SizedBox(width: 16),
                    
                    const Text(
                      'Filtrer:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    
                    // Filter icons
                    for (var filter in [
                      ReviewFilterType.nice,
                      ReviewFilterType.loveIt,
                      ReviewFilterType.funny,
                      ReviewFilterType.confusing,
                      ReviewFilterType.informative,
                      ReviewFilterType.wellWritten,
                      ReviewFilterType.creative,
                      ReviewFilterType.spoiler,
                      ReviewFilterType.preliminary,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: IconFilterChip(
                          filter: filter,
                          state: filterState.filterStates[filter] ?? FilterState.inactive,
                          onTap: () => filterState.toggleFilter(filter),
                        ),
                      ),
                    
                    if (filterState.filterStates.values.any((state) => state != FilterState.inactive) ||
                        filterState.selectedScore != null)
                      TextButton.icon(
                        onPressed: () {
                          filterState.resetFilters();
                          filterState.setSelectedScore(null);
                        },
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Effacer'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviewList() {
    if (isLoading && reviews.isEmpty) {
      return _buildLoadingState();
    }
    
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
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
  
  void _showScoreDistributionDialog(BuildContext context) {
    final scoreDistribution = _filterState.scoreDistribution;
    if (scoreDistribution == null || scoreDistribution.isEmpty) return;
    
    // Find max count for scaling
    final maxCount = scoreDistribution.values.reduce((a, b) => a > b ? a : b);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Distribution des scores'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(11, (index) {
                    // Score ranges from 0 to 10
                    final count = scoreDistribution[index] ?? 0;
                    final barHeight = count > 0 
                        ? (count / maxCount * 200) 
                        : 0.0;
                    
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              count.toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: _getScoreColor(index),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$index',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: ShimmerColor(
            SizedBox(
              width: 300,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
  
  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.amber;
    return Colors.red;
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