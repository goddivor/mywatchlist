import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

/// The pages of reviews of one title, for the detail section and the "view
/// all" screen.
///
/// Every page comes from MyAnimeList's own review pages, read through the
/// mwl-api `reviews` route ([JikanFallbacks.reviews]; the backend runs inside
/// the app when no remote server is set). Neither Jikan nor Tenrai is asked
/// (owner, 2026-11-20): Tenrai has no reviews, Jikan is often unreachable. A
/// failed next page keeps what is loaded and stops asking.
class ReviewsFeed extends ChangeNotifier {
  final int id;
  final String category;

  ReviewsFeed({required this.id, this.category = 'anime'});

  final List<AnimeReview> _reviews = [];
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
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

  Future<(List<AnimeReview>, bool)> _fetchPage() => _mwlPage();

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
