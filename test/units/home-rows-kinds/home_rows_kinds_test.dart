import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_home_sections.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_rows.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_home_plan.dart';

const _newKinds = [
  SectionType.topAnimeOva,
  SectionType.topAnimeOna,
  SectionType.topMangaOnly,
  SectionType.topOneshots,
  SectionType.topDoujin,
  SectionType.topLightNovels,
  SectionType.topNovels,
  SectionType.topManhwa,
  SectionType.topManhua,
  SectionType.topMangaFavorites,
];

HomeSectionPreference _pref(SectionType t) => HomeSectionPreference(type: t);

void main() {
  test('each new kind is a MAL content row', () {
    for (final t in _newKinds) {
      expect(t.isContentRow, isTrue, reason: t.name);
    }
  });

  group('AniList', () {
    test('OVA, ONA, one-shot and novel rows filter by format', () {
      expect(anilistQueryFor(_pref(SectionType.topAnimeOva))!.formats, ['OVA']);
      expect(anilistQueryFor(_pref(SectionType.topAnimeOna))!.formats, ['ONA']);
      expect(anilistQueryFor(_pref(SectionType.topOneshots))!.formats,
          ['ONE_SHOT']);
      expect(anilistQueryFor(_pref(SectionType.topNovels))!.formats, ['NOVEL']);
      expect(anilistQueryFor(_pref(SectionType.topLightNovels))!.formats,
          ['NOVEL']);
    });

    test('manhwa and manhua filter by country of origin', () {
      expect(anilistQueryFor(_pref(SectionType.topManhwa))!.country, 'KR');
      expect(anilistQueryFor(_pref(SectionType.topManhua))!.country, 'CN');
      expect(anilistQueryFor(_pref(SectionType.topManhwa))!.category, 'manga');
    });

    test('doujin has no AniList row and is hidden', () {
      expect(anilistQueryFor(_pref(SectionType.topDoujin)), isNull);
      expect(anilistShowsSection(_pref(SectionType.topDoujin)), isFalse);
      expect(anilistShowsSection(_pref(SectionType.topManhwa)), isTrue);
    });

    test('the country is part of the query identity', () {
      expect(anilistQueryFor(_pref(SectionType.topManhwa)),
          isNot(anilistQueryFor(_pref(SectionType.topManhua))));
    });
  });

  group('Kitsu', () {
    test('every new kind maps to a search of the right media', () {
      for (final t in _newKinds) {
        final q = kitsuQueryForSection(_pref(t));
        expect(q, isNotNull, reason: t.name);
        expect(q!.isAnime,
            t == SectionType.topAnimeOva || t == SectionType.topAnimeOna,
            reason: t.name);
      }
    });

    test('subtypes match', () {
      String? sub(SectionType t) =>
          kitsuQueryForSection(_pref(t))!.filters['subtype'];
      expect(sub(SectionType.topAnimeOva), 'OVA');
      expect(sub(SectionType.topAnimeOna), 'ONA');
      expect(sub(SectionType.topManhwa), 'manhwa');
      expect(sub(SectionType.topManhua), 'manhua');
      expect(sub(SectionType.topNovels), 'novel');
      expect(sub(SectionType.topOneshots), 'oneshot');
      expect(sub(SectionType.topDoujin), 'doujin');
    });
  });

  test('Simkl hides every new kind', () {
    final plan = simklHomePlan([for (final t in _newKinds) _pref(t)]);
    expect(plan.where((b) => b.feed != null), isEmpty);
  });
}
