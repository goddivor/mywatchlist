import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

/// The pages of reviews of one title, for the detail section and the "view
/// all" screen.
///
/// The first page races Jikan `reviews` against the mwl-api `reviews` route
/// (MAL review pages parsed by the backend), see [JikanFallbacks.race], so it
/// ends within about 12 s; the next pages come from the source that answered
/// first (the two number their pages differently and are never mixed). A
/// failed next page keeps what is loaded and stops asking.
class ReviewsFeed extends ChangeNotifier {
  final int id;
  final String category;

  ReviewsFeed({required this.id, this.category = 'anime'});

  final List<AnimeReview> _reviews = [];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
  bool _fromMwl = false;
  int _page = 1;
  bool _disposed = false;
  Map<int, int> _distribution = const {};
  List<String> _tags = const [];

  /// Loaded reviews, in the order of the source.
  List<AnimeReview> get reviews => List.unmodifiable(_reviews);
  bool get loading => _loading;

  /// The first page failed on both sources.
  bool get failed => _failed;
  bool get hasMore => _hasMore;
  bool get isEmpty => _reviews.isEmpty;

  /// Number of loaded reviews per score.
  Map<int, int> get distribution => _distribution;

  /// Every tag of the loaded reviews.
  List<String> get tags => _tags;

  /// Loads the first page (or everything again with [reset]).
  Future<void> start({bool reset = false}) {
    if (reset) {
      _reviews.clear();
      _page = 1;
      _hasMore = true;
      _fromMwl = false;
      _distribution = const {};
      _tags = const [];
    }
    return loadMore();
  }

  /// Loads the next page unless one is loading or none is left.
  Future<void> loadMore() async {
    if (_loading || !_hasMore || (_failed && _reviews.isNotEmpty)) return;
    _loading = true;
    _failed = false;
    _notify();
    try {
      final (page, hasMore) = await _fetchPage();
      if (_disposed) return;
      _reviews.addAll(page);
      _hasMore = hasMore && page.isNotEmpty;
      _page++;
      _distribution = reviewScoreDistribution(_reviews);
      _tags = reviewTags(_reviews);
    } catch (e) {
      debugPrint('Reviews of $category $id, page $_page failed: $e');
      if (_disposed) return;
      if (_reviews.isEmpty) {
        _failed = true;
      } else {
        _hasMore = false;
      }
    }
    _loading = false;
    _notify();
  }

  Future<(List<AnimeReview>, bool)> _fetchPage() async {
    if (_page == 1) {
      final result = await JikanFallbacks.race<(List<AnimeReview>, bool)>(
        jikan: _jikanPage,
        fallback: _mwlPage,
      );
      _fromMwl = !result.fromJikan;
      return result.value;
    }
    return _fromMwl ? _mwlPage() : _jikanPage();
  }

  Future<(List<AnimeReview>, bool)> _jikanPage() async {
    final response = await JikanApi().getAnimeReviews(id, page: _page, category: category);
    return (response.data, response.pagination.hasNextPage ?? false);
  }

  Future<(List<AnimeReview>, bool)> _mwlPage() async {
    final list = await JikanFallbacks.reviews(id, category, _page);
    return (list, list.isNotEmpty);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
