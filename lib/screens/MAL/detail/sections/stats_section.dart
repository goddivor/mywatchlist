import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/animestatisticswidget.dart';

/// List status statistics (MAL API).
DetailSection? statsSection(DetailData data) {
  final stats = data.content?.statistics;
  if (stats == null) return null;
  return DetailSection(TabType.Stats, AnimeStatisticsWidget(stats: stats));
}
