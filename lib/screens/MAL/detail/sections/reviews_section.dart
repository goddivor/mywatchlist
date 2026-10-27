import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';

/// User reviews (loaded by the widget itself).
DetailSection? reviewsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.Reviews,
    ShowAnimeReviews(animeId: data.id, category: data.category),
  );
}
