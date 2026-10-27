import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/screens/forum/forum_topics_screen.dart';
import 'package:mywatchlist/widgets/MAL/content/show_forum.dart';

/// Latest forum topics, arrow opens the full topic list.
DetailSection? forumsSection(DetailData data) {
  if (!data.hasContent) return null;
  return DetailSection(
    TabType.Forums,
    ShowAnimeForum(animeId: data.id, category: data.category),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: ForumTopicsScreen(
        animeId: data.isAnime ? data.id : null,
        mangaId: data.isManga ? data.id : null,
        title: S.current.Forums,
      ),
    ),
  );
}
