import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/notifications/notification_models.dart' show animePayload;
import 'package:mywatchlist/services/notifications/notification_payload.dart';

void main() {
  const mal = AccountType.myanimelist;

  group('build and parse round trip', () {
    final built = <NotificationPayload>[
      for (final t in [mal, AccountType.anilist, AccountType.kitsu, AccountType.simkl]) ...[
        NotificationPayload.anime(t, 21),
        NotificationPayload.manga(t, 2),
        NotificationPayload.calendar(t),
        NotificationPayload.bookmarks(t),
        NotificationPayload.notifications(t),
      ],
      NotificationPayload.malMessage(123),
      NotificationPayload.malMessage(123, threadId: 456),
      NotificationPayload.malMessages(),
      NotificationPayload.malHub(),
      NotificationPayload.malHub(itemId: '98'),
      NotificationPayload.malHub(url: 'https://myanimelist.net/forum/?topicid=1#msg2'),
      NotificationPayload.malHub(
          itemId: '98', url: 'https://myanimelist.net/mymessages.php?go=read&id=5&threadid=6'),
    ];
    for (final p in built) {
      test(p.encode(), () {
        final back = NotificationPayload.parse(p.encode());
        expect(back, p);
        expect(back!.isLegacy, isFalse);
      });
    }

    test('the documented strings', () {
      expect(NotificationPayload.anime(AccountType.anilist, 21).encode(), 'anilist:anime:21');
      expect(NotificationPayload.calendar(AccountType.kitsu).encode(), 'kitsu:calendar');
      expect(NotificationPayload.malMessage(123, threadId: 456).encode(),
          'myanimelist:message:123:456');
      expect(NotificationPayload.malHub(url: 'https://a.b/c').encode(),
          'myanimelist:hub::https://a.b/c');
      expect(NotificationPayload.notifications(AccountType.anilist).encode(),
          'anilist:notifications');
    });

    test('the url of a hub payload keeps its colons', () {
      final p = NotificationPayload.parse('myanimelist:hub:98:https://x.y:8080/a:b')!;
      expect(p.id, '98');
      expect(p.extra, 'https://x.y:8080/a:b');
    });

    test('typed accessors', () {
      final p = NotificationPayload.parse('myanimelist:message:123:456')!;
      expect(p.intId, 123);
      expect(p.intExtra, 456);
      expect(NotificationPayload.parse('simkl:calendar')!.intId, isNull);
    });
  });

  group('legacy payloads read as MAL', () {
    test('anime:<id> and manga:<id>', () {
      final a = NotificationPayload.parse('anime:52991')!;
      expect((a.tracker, a.kind, a.intId, a.isLegacy), (mal, PayloadKind.anime, 52991, true));
      final m = NotificationPayload.parse('manga:2')!;
      expect((m.tracker, m.kind, m.intId), (mal, PayloadKind.manga, 2));
      // What the airing planner writes today.
      expect(NotificationPayload.parse(animePayload(7))!.intId, 7);
    });

    test('calendar and bookmarks', () {
      expect(NotificationPayload.parse('calendar')!.kind, PayloadKind.calendar);
      expect(NotificationPayload.parse('calendar')!.tracker, mal);
      expect(NotificationPayload.parse('bookmarks')!.kind, PayloadKind.bookmarks);
      expect(NotificationPayload.parse(' bookmarks ')!.tracker, mal);
    });

    test('MAL hub payloads', () {
      final screen = NotificationPayload.parse('malhub:')!;
      expect((screen.tracker, screen.kind, screen.isLegacy),
          (mal, PayloadKind.notifications, true));
      final item = NotificationPayload.parse('malhub:42|https://myanimelist.net/anime/1')!;
      expect((item.kind, item.id, item.extra),
          (PayloadKind.hub, '42', 'https://myanimelist.net/anime/1'));
      final friend = NotificationPayload.parse('malhub:|https://myanimelist.net/profile/x')!;
      expect((friend.id, friend.extra), (null, 'https://myanimelist.net/profile/x'));
      final pm = NotificationPayload.parse(
          'malhub:|https://myanimelist.net/mymessages.php?go=read&id=5&threadid=6')!;
      expect(pm.kind, PayloadKind.hub);
      expect(pm.extra, 'https://myanimelist.net/mymessages.php?go=read&id=5&threadid=6');
      expect(NotificationPayload.parse('malhub:|')!.kind, PayloadKind.notifications);
      final odd = NotificationPayload.parse('malhub:a:b|https://x.y/z')!;
      expect((odd.id, odd.extra), (null, 'https://x.y/z'));
      expect(NotificationPayload.parse(odd.encode()), isNot(isNull));
    });

    test('a legacy payload encodes to the new format', () {
      expect(NotificationPayload.parse('anime:5')!.encode(), 'myanimelist:anime:5');
      expect(NotificationPayload.parse('malhub:42|u')!.encode(), 'myanimelist:hub:42:u');
    });

    test('the AniList inbox payload is already the new format', () {
      final p = NotificationPayload.parse('anilist:notifications')!;
      expect((p.tracker, p.kind, p.isLegacy),
          (AccountType.anilist, PayloadKind.notifications, false));
    });
  });

  group('rejects', () {
    for (final bad in [
      null,
      '',
      '  ',
      'anime:',
      'anime:0',
      'anime:-3',
      'anime:x',
      'anime:1:2',
      'show:1',
      'none:anime:1',
      'mal:anime:1',
      'anilist',
      'anilist:',
      'anilist:movie:1',
      'anilist:anime',
      'anilist:anime:0',
      'anilist:anime:1:extra',
      'kitsu:calendar:3',
      'simkl:notifications::x',
      'myanimelist:message',
      'myanimelist:message:abc',
      'myanimelist:messages:1',
    ]) {
      test('"$bad"', () => expect(NotificationPayload.parse(bad), isNull));
    }

    test('invalid builds throw', () {
      expect(() => NotificationPayload.anime(AccountType.none, 1), throwsArgumentError);
      expect(() => NotificationPayload.anime(AccountType.anilist, 0), throwsArgumentError);
      expect(() => NotificationPayload.malMessage(0), throwsArgumentError);
      expect(() => NotificationPayload.malHub(itemId: 'a:b'), throwsArgumentError);
      expect(() => NotificationPayload.calendar(AccountType.none), throwsArgumentError);
    });
  });
}
