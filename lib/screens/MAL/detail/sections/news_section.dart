import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/home/show_news.dart';

/// MAL news about this title.
DetailSection? newsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.News,
    ShowAnimeNews(animeId: data.id, category: data.category),
  );
}
