import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved indices of the existing kinds are unchanged (kinds are only appended)', () {
    expect(SectionType.news.index, 0);
    expect(SectionType.topMangaPopular.index, 12);
    expect(SectionType.forum.index, 15);
    expect(SectionType.topAnimeOva.index, 16);
  });

  test('the section picker lists every kind exactly once', () {
    expect(kSectionPickerOrder.toSet(), SectionType.values.toSet());
    expect(kSectionPickerOrder.length, SectionType.values.length);
  });

  test('every MAL anime and manga ranking has a home row', () {
    final anime = {
      for (final t in SectionType.values)
        if (t.animeRanking case final r?) r,
    };
    final manga = {
      for (final t in SectionType.values)
        if (t.mangaRanking case final r?) r,
    };
    expect(anime, RankingType.values.toSet());
    expect(manga, MangaRanking.values.toSet());
  });

  test('content rows are the season, the suggestions and the rankings', () {
    expect(SectionType.seasonNow.isContentRow, isTrue);
    expect(SectionType.suggested.isContentRow, isTrue);
    expect(SectionType.topManhwa.isContentRow, isTrue);
    expect(SectionType.topAnimeOna.isContentRow, isTrue);
    for (final t in [SectionType.news, SectionType.features, SectionType.userList, SectionType.forum]) {
      expect(t.isContentRow, isFalse, reason: t.name);
    }
  });

  test('the item count is read back within the slider bounds', () {
    final high = HomeSectionPreference.tryFromJson({'type': SectionType.topScore.index, 'itemCount': 99});
    final low = HomeSectionPreference.tryFromJson({'type': SectionType.topScore.index, 'itemCount': 1});
    final kept = HomeSectionPreference.tryFromJson({'type': SectionType.topScore.index, 'itemCount': 30});
    expect(high!.itemCount, kHomeRowMaxItems);
    expect(low!.itemCount, kHomeRowMinItems);
    expect(kept!.itemCount, 30);
  });

  test('row cache keys are distinct per kind and carry the item count', () {
    final keys = {
      for (final t in SectionType.values)
        if (t.isContentRow) RequestsBloc.rowCacheKey(t, 30),
    };
    expect(keys.length, SectionType.values.where((t) => t.isContentRow).length);
    expect(RequestsBloc.rowCacheKey(SectionType.topScore, 15),
        isNot(RequestsBloc.rowCacheKey(SectionType.topScore, 30)));
  });

  test('new rows have their own title in English and French', () async {
    const added = [
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
    await LanguageBloc.apply('en');
    final en = [for (final t in added) HomeSectionPreference(type: t).getDefaultTitle()];
    expect(en.toSet().length, added.length);
    expect(en, contains('Top Manhwa'));
    await LanguageBloc.apply('fr_FR');
    final fr = [for (final t in added) HomeSectionPreference(type: t).getDefaultTitle()];
    expect(fr, contains('Meilleurs manhwas'));
    for (var i = 0; i < added.length; i++) {
      expect(fr[i], isNot(en[i]), reason: added[i].name);
    }
    await LanguageBloc.apply('en');
  });
}
