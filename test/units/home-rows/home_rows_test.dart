import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/requests/requests_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved indices of the existing kinds are unchanged (kinds are only appended)', () {
    expect(SectionType.news.index, 0);
    expect(SectionType.topMangaPopular.index, 12);
    expect(SectionType.forum.index, 15);
  });

  test('the section picker lists every kind exactly once', () {
    expect(kSectionPickerOrder.toSet(), SectionType.values.toSet());
    expect(kSectionPickerOrder.length, SectionType.values.length);
  });

  test('ranking rows map to their MAL ranking', () {
    expect(SectionType.topScore.animeRanking, RankingType.ALL);
    expect(SectionType.upcoming.animeRanking, RankingType.UPCOMING);
    expect(SectionType.topMangaPopular.mangaRanking, MangaRanking.bypopularity);
    expect(SectionType.topManga.animeRanking, isNull);
    expect(SectionType.news.mangaRanking, isNull);
  });

  test('content rows are the season, the suggestions and the rankings', () {
    expect(SectionType.seasonNow.isContentRow, isTrue);
    expect(SectionType.suggested.isContentRow, isTrue);
    expect(SectionType.topAnimeSpecial.isContentRow, isTrue);
    expect(SectionType.topManga.isContentRow, isTrue);
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
}
