import 'package:mywatchlist/constants/constants.dart' show TabType;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/content/synopsis_widget.dart';

/// Synopsis, genres and background.
DetailSection? synopsisSection(DetailData data) {
  final content = data.content;
  if (content == null) return null;
  return DetailSection(
    TabType.Synopsis,
    SysonpsisWidget(
      synopsis: content.synopsis,
      genres: content.genres,
      background: content.background,
      category: data.category,
      horizPadding: detailHorizPadding,
    ),
  );
}
