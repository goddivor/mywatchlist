import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';

void main() {
  group('season maps', () {
    test('every season has a lowercase API value that maps back', () {
      for (final season in SeasonType.values) {
        final value = seasonMap[season];
        expect(value, isNotNull, reason: '$season has no API value');
        expect(value, value!.toLowerCase());
        expect(seasonMapInverse[value], season);
      }
    });

    test('capitalised labels match the API values', () {
      for (final season in SeasonType.values) {
        expect(seasonMapCaps[season]!.toLowerCase(), seasonMap[season]);
      }
    });
  });

  group('status maps', () {
    test('MyStatus constants are keys of the list status maps', () {
      for (final status in [
        MyStatus.watching,
        MyStatus.completed,
        MyStatus.onHold,
        MyStatus.dropped,
        MyStatus.planToWatch,
      ]) {
        expect(myAnimeStatusMap, contains(status));
      }
      for (final status in [
        MyStatus.reading,
        MyStatus.completed,
        MyStatus.onHold,
        MyStatus.dropped,
        MyStatus.planToRead,
      ]) {
        expect(myMangaStatusMap, contains(status));
      }
    });

    test('the "all" maps are the list maps plus an "all" entry', () {
      expect(allAnimeStatusMap.keys.first, 'all');
      expect(allAnimeStatusMap.keys.skip(1), myAnimeStatusMap.keys);
      expect(allMangaStatusMap.keys.first, 'all');
      expect(allMangaStatusMap.keys.skip(1), myMangaStatusMap.keys);
    });

    test('combined map covers anime and manga statuses', () {
      expect(
        combinedStatusMap.keys.toSet(),
        {...allAnimeStatusMap.keys, ...allMangaStatusMap.keys},
      );
    });

    test('Jikan anime statuses translate to MAL statuses', () {
      for (final value in jikanAnimeStatusMap.values) {
        expect(animeStatusInverseMap, contains(value));
      }
    });
  });

  group('ranking and type maps', () {
    test('every manga ranking has an API value', () {
      for (final ranking in MangaRanking.values) {
        expect(mangaRankingMap[ranking], isNotEmpty, reason: '$ranking');
      }
    });

    test('every manga type has an API value', () {
      for (final type in MangaType.values) {
        expect(mangaTypeMap[type], isNotEmpty, reason: '$type');
      }
    });

    test('the SFW rating map is a subset of the full rating map', () {
      for (final entry in ratedMapSFW.entries) {
        expect(ratedMap[entry.key], entry.value);
      }
      expect(ratedMapSFW, isNot(contains(RatedType.rx)));
    });
  });
}
