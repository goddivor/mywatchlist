import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/scorestatisticswidget.dart';

/// Score distribution (loaded by the widget itself).
DetailSection? scoreStatsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.ScoreStats,
    ScoreStatisticsWidget(
      horizPadding: detailHorizPadding,
      category: data.category,
      id: data.id,
    ),
  );
}
