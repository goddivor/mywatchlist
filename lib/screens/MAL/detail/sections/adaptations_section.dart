import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/adaptation_widget.dart';

/// Adaptations scraped from the MAL page.
DetailSection? adaptationsSection(DetailData data) {
  if (data.adaptations.isEmpty) return null;
  return DetailSection(
    TabType.Adaptations,
    AdaptationsWidget(nodes: data.adaptations),
  );
}
