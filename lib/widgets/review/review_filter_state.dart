// lib/widgets/review/review_filter_state.dart (mise à jour)

import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/review/review_filters.dart';

enum FilterState {
  inactive,
  include,
  exclude
}

class ReviewFilterState extends ChangeNotifier {
  final Map<ReviewFilterType, FilterState> _filterStates = {
    for (var filter in ReviewFilterType.values) filter: FilterState.inactive
  };
  
  ReviewSortType _sortType = ReviewSortType.dateDesc;
  Map<int, int>? _scoreDistribution;
  int? _selectedScore;
  
  ReviewSortType get sortType => _sortType;
  Map<ReviewFilterType, FilterState> get filterStates => _filterStates;
  Map<int, int>? get scoreDistribution => _scoreDistribution;
  int? get selectedScore => _selectedScore;
  
  void setSortType(ReviewSortType sortType) {
    _sortType = sortType;
    notifyListeners();
  }
  
  void setScoreDistribution(Map<int, int> distribution) {
    _scoreDistribution = distribution;
    notifyListeners();
  }
  
  void setSelectedScore(int? score) {
    _selectedScore = score;
    notifyListeners();
  }
  
  void toggleFilter(ReviewFilterType filter) {
    switch (_filterStates[filter]) {
      case FilterState.inactive:
        _filterStates[filter] = FilterState.include;
        break;
      case FilterState.include:
        _filterStates[filter] = FilterState.exclude;
        break;
      case FilterState.exclude:
      default:
        _filterStates[filter] = FilterState.inactive;
        break;
    }
    notifyListeners();
  }
  
  void resetFilters() {
    for (var filter in ReviewFilterType.values) {
      _filterStates[filter] = FilterState.inactive;
    }
    notifyListeners();
  }
}