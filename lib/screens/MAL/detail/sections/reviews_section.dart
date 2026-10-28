import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';
import 'package:mywatchlist/widgets/MAL/review/reviews_list_screen.dart';

/// User reviews (loaded by the widget itself); the arrow opens every review
/// in one vertical list, as DailyAL.
DetailSection? reviewsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.Reviews,
    ShowAnimeReviews(animeId: data.id, category: data.category),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: ReviewsListScreen(id: data.id, category: data.category),
    ),
  );
}
