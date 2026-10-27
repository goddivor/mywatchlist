import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/show_featured.dart';

/// MAL featured articles about this title.
DetailSection? featuredSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.Featured_Articles,
    ShowAnimeFeatured(
      animeId: data.id,
      animeName: data.title,
      category: data.category,
    ),
  );
}
