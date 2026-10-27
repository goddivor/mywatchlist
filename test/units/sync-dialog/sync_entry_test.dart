import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';

void main() {
  group('StatusMaps', () {
    test('MAL to tracker words', () {
      expect(StatusMaps.toTracker('watching', AccountType.anilist), 'CURRENT');
      expect(StatusMaps.toTracker('reading', AccountType.anilist), 'CURRENT');
      expect(StatusMaps.toTracker('on_hold', AccountType.anilist), 'PAUSED');
      expect(StatusMaps.toTracker('plan_to_read', AccountType.kitsu), 'planned');
      expect(StatusMaps.toTracker('on_hold', AccountType.simkl), 'hold');
      expect(StatusMaps.toTracker('watching', AccountType.myanimelist), isNull);
    });

    test('tracker words back to the MAL key of the right category', () {
      expect(StatusMaps.fromTracker('CURRENT', AccountType.anilist, true),
          'watching');
      expect(StatusMaps.fromTracker('CURRENT', AccountType.anilist, false),
          'reading');
      expect(StatusMaps.fromTracker('planned', AccountType.kitsu, false),
          'plan_to_read');
      expect(StatusMaps.fromTracker('plantowatch', AccountType.simkl, true),
          'plan_to_watch');
      expect(StatusMaps.fromTracker('COMPLETED', AccountType.anilist, false),
          'completed');
      expect(StatusMaps.fromTracker('nonsense', AccountType.kitsu, true),
          isNull);
    });
  });

  group('SyncScores', () {
    test('decimals survive on AniList (POINT_10_DECIMAL)', () {
      expect(SyncScores.toAnilistRaw(7.5), 75);
      expect(SyncScores.toAnilistRaw(8.3), 83);
      expect(SyncScores.toAnilistRaw(10), 100);
    });

    test('Kitsu works in half points', () {
      expect(SyncScores.toKitsuTwenty(7.5), 15);
      expect(SyncScores.toKitsuTwenty(0), isNull);
      expect(SyncScores.toKitsuTwenty(0.5), 2); // Kitsu's minimum rating
      expect(SyncScores.fromKitsuTwenty(15), 7.5);
    });

    test('MAL only keeps whole points', () {
      expect(SyncScores.toMal(7.5), 8);
      expect(SyncScores.toMal(7.4), 7);
    });

    test('format shows a decimal only when there is one', () {
      expect(SyncScores.format(7), '7');
      expect(SyncScores.format(7.5), '7.5');
    });
  });

  group('SyncDates', () {
    test('MAL text to AniList fuzzy dates, partial dates kept partial', () {
      expect(SyncDates.toFuzzy('2019-03-05'),
          {'year': 2019, 'month': 3, 'day': 5});
      expect(SyncDates.toFuzzy('2019-03'),
          {'year': 2019, 'month': 3, 'day': null});
      expect(SyncDates.toFuzzy('2019'),
          {'year': 2019, 'month': null, 'day': null});
      expect(SyncDates.toFuzzy(''), isNull);
      expect(SyncDates.toFuzzy('garbage'), isNull);
    });

    test('fuzzy dates back to MAL text', () {
      expect(SyncDates.fromFuzzy({'year': 2019, 'month': 3, 'day': 5}),
          '2019-03-05');
      expect(SyncDates.fromFuzzy({'year': 2019, 'month': 3, 'day': null}),
          '2019-03');
      expect(SyncDates.fromFuzzy({'year': 2019, 'month': null, 'day': null}),
          '2019');
      expect(SyncDates.fromFuzzy({'year': null}), isNull);
    });

    test('Kitsu timestamps', () {
      expect(SyncDates.toTimestamp('2019-03-05'), '2019-03-05T00:00:00.000Z');
      expect(SyncDates.toTimestamp('2019-03'), isNull);
      expect(SyncDates.fromTimestamp('2019-03-05T08:10:00.000Z'), '2019-03-05');
      expect(SyncDates.fromTimestamp(null), isNull);
    });
  });

  test('compact drops empty values so a sync never erases', () {
    const e = SyncEntry(
      status: 'watching',
      score: 0,
      progress: 0,
      volumes: 0,
      startDate: '',
      repeat: 0,
      notes: '  ',
    );
    final c = e.compact();
    expect(c.status, 'watching');
    expect(c.score, isNull);
    expect(c.progress, 0); // zero progress is a real value
    expect(c.volumes, isNull);
    expect(c.startDate, isNull);
    expect(c.repeat, isNull);
    expect(c.notes, isNull);
  });
}
