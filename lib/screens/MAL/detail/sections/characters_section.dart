import 'package:mywatchlist/constants/constants.dart' show TabType, gotoPage;
import 'package:mywatchlist/screens/MAL/characters_staff_screen.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_sections.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';

/// Characters (with voice actors for an anime); arrow opens the full cast.
DetailSection? charactersSection(DetailData data) {
  if (data.html == null) return null;
  final empty = data.isManga
      ? data.mangaCharacters.isEmpty
      : data.charactersVoiceActors.isEmpty;
  if (empty) return null;
  return DetailSection(
    TabType.Characters,
    data.isManga
        ? AnimeCharacterWidget(
            mangaCharacterList: data.mangaCharacters,
            horizPadding: detailHorizPadding,
          )
        : AnimeCharacterWidget(
            animeCharacterList: data.charactersVoiceActors,
            horizPadding: detailHorizPadding,
          ),
    onViewAll: (context) => gotoPage(
      context: context,
      newPage: CharactersStaffScreen(id: data.id, category: data.category),
    ),
  );
}
