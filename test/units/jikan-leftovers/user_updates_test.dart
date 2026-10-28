import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_api/handlers/handler_core.dart';
import 'package:mwl_commons/mwl_commons.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_fallbacks.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart' show statusKey;

import '../../helpers/html_fixtures.dart';

/// User updates without Jikan (gap report D2): Tenrai has no `userupdates`, so
/// the section reads the "Recently Updated By" table of MAL's stats page.
/// The fixtures are trimmed copies of the real tables of anime 3000 and
/// manga 9000, fetched on 2026-10-28 at about 20:26 UTC.
void main() {
  final fetchedAt = DateTime.utc(2026, 10, 28, 20, 26);

  ContentUpdatesHtml fixture(String name) => PageParsers.parseRecentUpdates(
        htmlFixture(File('test/units/jikan-leftovers/fixtures/$name').readAsStringSync()),
        now: fetchedAt,
      );

  group('recently updated table', () {
    test('anime rows: name, score, status, episodes, activity time', () {
      final page = fixture('anime_updates.html');
      expect(page.updates, hasLength(12));
      expect(page.hasNextPage, isTrue);

      final first = page.updates.first;
      expect(first.username, 'Hazuki');
      expect(first.score, isNull);
      expect(first.status, 'Plan to Watch');
      expect(first.episodesSeen, isNull);
      expect(first.activity, '9 hours ago');
      expect(first.date, DateTime.utc(2026, 10, 28, 11, 26).toIso8601String());

      final scored = page.updates[2];
      expect(scored.username, 'YugenSatoshi');
      expect(scored.score, 3);
      expect(scored.episodesSeen, 23);
      expect(scored.episodesTotal, 23);
      expect(scored.chaptersRead, isNull);

      // "Yesterday, 10:34 PM" in Pacific daylight time.
      final yesterday = page.updates[3];
      expect(yesterday.activity, 'Yesterday, 10:34 PM');
      expect(yesterday.date, DateTime.utc(2026, 10, 28, 5, 34).toIso8601String());

      expect(page.updates.every((u) => u.imageUrl == null || u.imageUrl!.startsWith('https://')),
          isTrue);
    });

    test('manga rows: volumes and chapters, dates with and without a year', () {
      final page = fixture('manga_updates.html');
      expect(page.updates, hasLength(8));
      final second = page.updates[1];
      expect(second.username, 'Hennessy_');
      expect(second.score, 5);
      expect(second.volumesRead, 1);
      expect(second.volumesTotal, isNull);
      expect(second.chaptersRead, 1);
      expect(second.chaptersTotal, 1);
      expect(second.episodesSeen, isNull);
      expect(second.date, DateTime.utc(2026, 9, 26, 12, 22).toIso8601String());

      final older = page.updates[5];
      expect(older.activity, 'Dec 11, 2025 7:38 PM');
      expect(older.date, DateTime.utc(2025, 12, 12, 3, 38).toIso8601String());
    });

    test('the placeholder avatar becomes null, a real one is kept', () {
      const row = '<table class="table-recently-updated"><tr><td>Member</td></tr>'
          '<tr><td><div><a href="/profile/a" style="background-image:url(https://cdn.myanimelist.net/images/kaomoji_mal_white.png)"></a></div>'
          '<div><a href="/profile/a">a_user</a></div></td><td>7</td><td>On-Hold</td><td>3 / 12</td><td>Now</td></tr>'
          '<tr><td><div><a href="/profile/b" style="background-image:url(https://cdn.myanimelist.net/s/common/userimages/x.jpg)"></a></div>'
          '<div><a href="/profile/b">b_user</a></div></td><td>-</td><td>Dropped</td><td>- / ?</td><td>2 days ago</td></tr></table>';
      final page = PageParsers.parseRecentUpdates(htmlFixture(row), now: fetchedAt);
      expect(page.updates.map((u) => u.username), ['a_user', 'b_user']);
      expect(page.updates.first.imageUrl, isNull);
      expect(page.updates.first.date, fetchedAt.toIso8601String());
      expect(page.updates.last.imageUrl, 'https://cdn.myanimelist.net/s/common/userimages/x.jpg');
      expect(page.updates.last.episodesSeen, isNull);
      expect(page.hasNextPage, isFalse);
    });

    test('a page without the table is an empty page, not an error', () {
      final page = PageParsers.parseRecentUpdates(htmlFixture('<html><body></body></html>'));
      expect(page.updates, isEmpty);
      expect(page.hasNextPage, isFalse);
    });

    test('JSON round trip (the backend caches and crosses isolates)', () {
      final page = fixture('manga_updates.html');
      final back = ContentUpdatesHtml.fromJson(
          jsonDecode(jsonEncode(page.toJson())) as Map<String, dynamic>);
      expect(back.updates.length, page.updates.length);
      expect(back.updates[1].chaptersTotal, 1);
      expect(back.updates[5].date, page.updates[5].date);
      expect(back.hasNextPage, page.hasNextPage);
    });
  });

  group('activity times', () {
    DateTime? at(String text, DateTime now) => PageParsers.malActivityTime(text, now);

    test('relative texts', () {
      expect(at('31 minutes ago', fetchedAt), DateTime.utc(2026, 10, 28, 19, 55));
      expect(at('1 hour ago', fetchedAt), DateTime.utc(2026, 10, 28, 19, 26));
      expect(at('45 seconds ago', fetchedAt), DateTime.utc(2026, 10, 28, 20, 25, 15));
      expect(at('Today, 1:05 AM', fetchedAt), DateTime.utc(2026, 10, 28, 8, 5));
      expect(at('Today, 12:10 PM', fetchedAt), DateTime.utc(2026, 10, 28, 19, 10));
    });

    test('a date without a year after now belongs to the previous year', () {
      final january = DateTime.utc(2027, 1, 2, 12);
      expect(at('Dec 30, 9:00 AM', january), DateTime.utc(2026, 12, 30, 17));
      expect(at('Jan 1, 9:00 AM', january), DateTime.utc(2027, 1, 1, 17));
    });

    test('daylight saving time follows the US rule', () {
      // 2026: DST from March 8 to November 1.
      expect(at('Mar 7, 2026 12:00 PM', fetchedAt), DateTime.utc(2026, 3, 7, 20));
      expect(at('Mar 9, 2026 12:00 PM', fetchedAt), DateTime.utc(2026, 3, 9, 19));
      expect(at('Nov 2, 2026 12:00 PM', DateTime.utc(2026, 11, 3)),
          DateTime.utc(2026, 11, 2, 20));
    });

    test('unknown texts give null', () {
      expect(at('sometime', fetchedAt), isNull);
      expect(at('Foo 3, 9:00 AM', fetchedAt), isNull);
    });
  });

  group('Jikan shape', () {
    test('a MAL row becomes the AnimeUserUpdate the cards display', () {
      final response = userUpdatesFromHtml(fixture('anime_updates.html'));
      expect(response.data, hasLength(12));
      expect(response.pagination.hasNextPage, isTrue);
      final row = response.data[2];
      expect(row.user?.username, 'YugenSatoshi');
      expect(row.user?.url, 'https://myanimelist.net/profile/YugenSatoshi');
      expect(row.score, 3);
      expect(row.episodesSeen, 23);
      expect(DateTime.tryParse(row.date!), isNotNull);
    });

    test('status texts of MAL and Jikan map to the list keys', () {
      expect(statusKey('On-Hold'), 'on_hold');
      expect(statusKey('Plan to Watch'), 'plan_to_watch');
      expect(statusKey('Plan to Read'), 'plan_to_read');
      expect(statusKey('Watching'), 'watching');
    });

    test('a missing page throws so the race reports it', () async {
      await expectLater(MwlApi.fetchContentUpdates(() async => null), throwsStateError);
      final page = await MwlApi.fetchContentUpdates(() async => {
            'updates': [
              {'username': 'x', 'score': 9, 'status': 'Completed'}
            ],
            'has_next_page': false,
          });
      expect(page.updates.single.score, 9);
    });
  });

  group('routes', () {
    final core = HandlerCore();

    Future<int> status(String pathAndQuery) async =>
        (await core.respond(Uri.parse('http://localhost/$pathAndQuery'))).statusCode;

    test('content/updates refuses bad parameters before any network call', () async {
      expect(await status('content/updates'), 400);
      expect(await status('content/updates?id=abc'), 400);
      expect(await status('content/updates?id=1&category=novel'), 400);
      expect(await status('content/updates?id=1&page=0'), 400);
    });

    test('users/friends needs a username', () async {
      expect(await status('users/friends'), 400);
    });
  });
}
