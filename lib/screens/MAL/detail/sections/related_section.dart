import 'package:mywatchlist/constants/constants.dart' show TabType, nullOrEmpty;
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/MAL/content/relatedanimewidget.dart';

/// Related anime and manga in one row.
DetailSection? relatedSection(DetailData data) {
  final content = data.content;
  if (nullOrEmpty(content?.relatedAnime) && nullOrEmpty(content?.relatedManga)) {
    return null;
  }
  return DetailSection(
    TabType.Related,
    RelatedAnimeWidget(
      relatedAnimeList: [
        ...?content?.relatedAnime,
        ...?content?.relatedManga?.map((rm) => RelatedAnime(
              animenode: rm.manganode,
              relationType: rm.relationType,
              relationTypeFormatted: rm.relationTypeFormatted,
            )),
      ],
      horizPadding: detailHorizPadding,
      id: data.id,
      // A manga page has no relation graph: the widget hides that button.
      category: data.category,
      title: data.node?.title ?? content?.title,
    ),
  );
}
