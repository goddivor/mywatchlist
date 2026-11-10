import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart';
import 'package:shared_preferences/shared_preferences.dart';

Anime _anime(int id, String title, int members) =>
    Anime(id: id, title: title, imageUrl: '', score: 8, members: members);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CacheManager cache;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CacheManager.pref = null;
    cache = CacheManager();
  });

  Future<List<Anime>> load({
    required Future<List<Anime>> Function() fetch,
    bool preferCache = true,
  }) =>
      loadHomeSeasonRow(
        season: SeasonType.FALL,
        year: 2026,
        limit: 10,
        maxAge: const Duration(hours: 2),
        preferCache: preferCache,
        fetch: fetch,
        cache: cache,
      );

  test('the disk key names the members sort, so old score-sorted rows are never read', () {
    expect(homeSeasonCacheKey(SeasonType.FALL, 2026, 10), contains('members'));
    expect(homeSeasonCacheKey(SeasonType.FALL, 2026, 10),
        isNot(homeSeasonCacheKey(SeasonType.FALL, 2026, 20)));
  });

  test('a fresh disk copy is served without a request', () async {
    final first = await load(fetch: () async => [_anime(21, 'One Piece', 2740899)]);
    expect(first.single.title, 'One Piece');
    var asked = false;
    final second = await load(fetch: () async {
      asked = true;
      return [];
    });
    expect(asked, isFalse);
    expect(second.single.id, 21);
  });

  test('a refresh asks MAL again and keeps its order', () async {
    await load(fetch: () async => [_anime(1, 'Old', 1)]);
    final rows = await load(
      preferCache: false,
      fetch: () async => [_anime(21, 'One Piece', 2740899), _anime(235, 'Meitantei Conan', 383082)],
    );
    expect(rows.map((a) => a.id), [21, 235]);
  });

  test('a failed request falls back to the last copy, else fails', () async {
    await expectLater(load(fetch: () async => throw Exception('offline')), throwsException);
    await load(fetch: () async => [_anime(21, 'One Piece', 2740899)]);
    final rows = await load(preferCache: false, fetch: () async => throw Exception('offline'));
    expect(rows.single.id, 21);
  });
}
