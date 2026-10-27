import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('statuses survive a restart (written once, read back)', () async {
    final cache = ListStatusCache(saveDelay: Duration.zero);
    await cache.ensureLoaded();
    cache.putAll({
      1: const CachedListStatus(status: 'watching', score: 8, progress: 3),
      2: const CachedListStatus(status: 'completed', score: 10, progress: 12),
    });
    cache.put(7, const CachedListStatus(status: 'reading'), category: 'manga');
    await cache.flush();

    final restarted = ListStatusCache();
    await restarted.ensureLoaded();
    expect(restarted.statusOf(1), 'watching');
    expect(restarted.entryOf(2), const CachedListStatus(status: 'completed', score: 10, progress: 12));
    expect(restarted.statusOf(7, category: 'manga'), 'reading');
    expect(restarted.statusOf(7), isNull, reason: 'anime and manga ids are separate');
    expect(restarted.statusOf(1, tracker: AccountType.anilist), isNull);
  });

  test('watch follows put, remove and the initial load', () async {
    SharedPreferences.setMockInitialValues({
      'list_status_cache_v1:myanimelist:anime': '{"owner":"me","items":{"5":["dropped",3,1]}}',
    });
    final cache = ListStatusCache(saveDelay: Duration.zero);
    final w = cache.watch(5);
    final seen = <String?>[];
    w.addListener(() => seen.add(w.value?.status));
    await cache.ensureLoaded();
    expect(w.value?.status, 'dropped');
    cache.put(5, const CachedListStatus(status: 'completed'));
    cache.remove(5);
    expect(seen, ['dropped', 'completed', null]);
  });

  test('a whole status tab replaces stale entries of that status only', () async {
    final cache = ListStatusCache(saveDelay: Duration.zero);
    await cache.ensureLoaded();
    cache.putAll({
      1: const CachedListStatus(status: 'watching'),
      2: const CachedListStatus(status: 'watching'),
      3: const CachedListStatus(status: 'completed'),
    });
    cache.replaceStatuses({1: const CachedListStatus(status: 'watching', progress: 4)},
        statuses: {'watching'});
    expect(cache.statusOf(1), 'watching');
    expect(cache.entryOf(1)?.progress, 4);
    expect(cache.statusOf(2), isNull, reason: 'left the watching list elsewhere');
    expect(cache.statusOf(3), 'completed');
  });

  test('another account drops the previous badges', () async {
    final cache = ListStatusCache(saveDelay: Duration.zero);
    await cache.ensureLoaded();
    cache.bindOwner(AccountType.myanimelist, 'alice');
    cache.put(1, const CachedListStatus(status: 'watching'));
    cache.bindOwner(AccountType.myanimelist, 'alice');
    expect(cache.statusOf(1), 'watching');
    cache.bindOwner(AccountType.myanimelist, 'bob');
    expect(cache.statusOf(1), isNull);
  });

  test('legacy single-string values and bad JSON are tolerated', () async {
    SharedPreferences.setMockInitialValues({
      'list_status_cache_v1:myanimelist:anime': '{"items":{"9":"on_hold","x":["a"]}}',
      'list_status_cache_v1:myanimelist:manga': 'not json',
    });
    final cache = ListStatusCache();
    await cache.ensureLoaded();
    expect(cache.statusOf(9), 'on_hold');
    expect(cache.countOf(category: 'manga'), 0);
  });
}
