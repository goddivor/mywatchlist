import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/tracker_sync_service.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  TrackerSyncService make(FakeClient c, FakeMal m) => TrackerSyncService(
      clients: {AccountType.anilist: c}, mal: m);

  test('MAL to tracker copies the MAL entry, empty fields stay out', () async {
    final mal = FakeMal(const SyncEntry(
        status: 'completed', score: 7.5, progress: 12, notes: ''));
    final other = FakeClient(const SyncEntry(status: 'watching', score: 9));
    final out = await make(other, mal).sync(
      direction: SyncDirection.malToTracker,
      tracker: AccountType.anilist,
      trackerId: '1',
      malId: 5,
      category: 'anime',
    );
    expect(other.writes.single.score, 7.5);
    expect(other.writes.single.status, 'completed');
    expect(other.writes.single.notes, isNull);
    expect(out.tracker.progress, 12);
    expect(mal.writes, isEmpty);
  });

  test('tracker to MAL is the other way round', () async {
    final mal = FakeMal(const SyncEntry(status: 'watching', score: 3));
    final other = FakeClient(const SyncEntry(status: 'completed', score: 8.5));
    final out = await make(other, mal).sync(
      direction: SyncDirection.trackerToMal,
      tracker: AccountType.anilist,
      trackerId: '1',
      malId: 5,
      category: 'anime',
    );
    expect(mal.writes.single.score, 8.5);
    expect(other.writes, isEmpty);
    expect(out.mal.status, 'completed');
  });

  test('a cancelled sync never writes', () async {
    final token = SyncCancelToken();
    final mal = FakeMal(const SyncEntry(status: 'watching'))
      ..onRead = token.cancel; // the user taps Cancel while MAL is read
    final other = FakeClient(null);
    await expectLater(
      make(other, mal).sync(
        direction: SyncDirection.malToTracker,
        tracker: AccountType.anilist,
        trackerId: '1',
        malId: 5,
        category: 'anime',
        cancel: token,
      ),
      throwsA(isA<SyncCancelled>()),
    );
    expect(other.writes, isEmpty);
  });

  test('an empty source says so instead of writing', () async {
    final other = FakeClient(const SyncEntry(status: 'watching'));
    await expectLater(
      make(other, FakeMal(null)).sync(
        direction: SyncDirection.malToTracker,
        tracker: AccountType.anilist,
        trackerId: '1',
        malId: 5,
        category: 'anime',
      ),
      throwsA(isA<SyncSourceEmpty>()),
    );
    expect(other.writes, isEmpty);
  });

  test('no MAL session stops before any request', () async {
    final other = FakeClient(const SyncEntry(status: 'watching'));
    await expectLater(
      make(other, FakeMal(null, connected: false)).sync(
        direction: SyncDirection.trackerToMal,
        tracker: AccountType.anilist,
        trackerId: '1',
        malId: 5,
        category: 'anime',
      ),
      throwsA(isA<SyncAuthRequired>()),
    );
  });

  group('links', () {
    test('an unknown link is found by MAL id and stored', () async {
      final c = FakeClient(null, found: '99');
      final s = make(c, FakeMal(null));
      expect(await s.resolveLink(5, 'anime', AccountType.anilist), '99');
      expect(await s.getLinkId(5, 'anime', AccountType.anilist), '99');
      await s.resolveLink(5, 'anime', AccountType.anilist);
      expect(c.finds, 1, reason: 'the stored link is used the second time');
    });

    test('a link made before this version is kept', () async {
      SharedPreferences.setMockInitialValues(
          {'tracker_link_5_anime_anilist': '42'});
      final c = FakeClient(null, found: '99');
      expect(await make(c, FakeMal(null))
          .resolveLink(5, 'anime', AccountType.anilist), '42');
      expect(c.finds, 0);
    });

    test('unlinking stops the automatic link from coming back', () async {
      final c = FakeClient(null, found: '99');
      final s = make(c, FakeMal(null));
      await s.resolveLink(5, 'anime', AccountType.anilist);
      await s.removeLinkId(5, 'anime', AccountType.anilist);
      expect(await s.resolveLink(5, 'anime', AccountType.anilist), isNull);
      // A manual link still works afterwards.
      await s.saveLinkId(5, 'anime', AccountType.anilist, '7');
      expect(await s.resolveLink(5, 'anime', AccountType.anilist), '7');
    });
  });
}
