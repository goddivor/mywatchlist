import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart' show SeasonType;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

void main() {
  test('every home section kind maps to a Kitsu search or to nothing', () {
    for (final type in SectionType.values) {
      final query = kitsuQueryForSection(HomeSectionPreference(type: type));
      switch (type) {
        case SectionType.news:
        case SectionType.suggested:
        case SectionType.features:
        case SectionType.userList:
        case SectionType.forum:
          expect(query, isNull, reason: type.name);
        default:
          expect(query, isNotNull, reason: type.name);
      }
    }
  });

  test('a fixed season filters by season and year', () {
    final query = kitsuQueryForSection(HomeSectionPreference(
        type: SectionType.seasonNow, season: SeasonType.FALL, year: 2024))!;
    expect(query.filters, {'season': 'fall', 'seasonYear': '2024'});
    expect(query.isAnime, isTrue);
  });

  test('manga sections search manga', () {
    expect(kitsuQueryForSection(HomeSectionPreference(type: SectionType.topManga))!.isAnime,
        isFalse);
  });

  test('an entry without a MyAnimeList id has no home card', () {
    const entry = ListEntryView(id: 1, category: 'anime', title: 'T');
    expect(kitsuEntryToAnime(entry), isNull);
    final card = kitsuEntryToAnime(const ListEntryView(id: 1, malId: 9, category: 'anime', title: 'T'));
    expect(card!.id, 9);
  });
}
