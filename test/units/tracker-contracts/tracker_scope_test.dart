import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, TitleLang;
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/preferences/tracker_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PreferencesStore> _store([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return PreferencesStore(await SharedPreferences.getInstance());
}

AppPreferences _with(AppPreferences p,
        {TitleLang? title, bool? nsfw, bool? keep, TimezonePref? tz, String? animeTab,
        bool? hideScore, bool? watching}) =>
    p.copyWith(
      general: p.general.copyWith(preferredTitle: title, nsfw: nsfw, keepPagesInMemory: keep),
      content: p.content.copyWith(timezone: tz, hideScore: hideScore),
      list: p.list.copyWith(defaultAnimeTab: animeTab),
      notifications: p.notifications.copyWith(watchingList: watching),
    );

void main() {
  group('TrackerScope', () {
    test('keys end with :<tracker>', () {
      expect(TrackerScope.key('prefs_general_v1', AccountType.anilist), 'prefs_general_v1:anilist');
      expect(TrackerScope.key('home_preferences_v2', AccountType.myanimelist),
          'home_preferences_v2:myanimelist');
      expect(() => TrackerScope.key('x', AccountType.none), throwsArgumentError);
    });

    test('field scope', () {
      expect(TrackerScope.isTrackerField(PreferencesStore.keyGeneral, 'nsfw'), isTrue);
      expect(TrackerScope.isTrackerField(PreferencesStore.keyGeneral, 'preferredTitle'), isTrue);
      expect(TrackerScope.isTrackerField(PreferencesStore.keyGeneral, 'keepPagesInMemory'), isFalse);
      expect(TrackerScope.isTrackerField(PreferencesStore.keyContent, 'timezone'), isFalse);
      expect(TrackerScope.isTrackerField(PreferencesStore.keyList, 'cardProfiles'), isTrue);
      expect(TrackerScope.isTrackerField(PreferencesStore.keyNotifications, 'watchingList'),
          isFalse);
    });

    test('every app field exists in its group', () {
      const d = AppPreferences();
      final json = {
        PreferencesStore.keyGeneral: d.general.toJson(),
        PreferencesStore.keyContent: d.content.toJson(),
        PreferencesStore.keyList: d.list.toJson(),
      };
      TrackerScope.appFields.forEach((group, fields) {
        for (final f in fields) {
          expect(json[group]!.containsKey(f), isTrue, reason: '$group.$f');
        }
      });
    });
  });

  group('readFor / writeFor', () {
    test('before any per-tracker write, every tracker reads the global values', () async {
      final store = await _store();
      await store.write(_with(const AppPreferences(), title: TitleLang.ja, nsfw: true));
      for (final t in TrackerScope.trackers) {
        expect(store.readFor(t), store.read(), reason: t.name);
      }
      await store.migrateToTrackerScope();
      expect(store.readFor(AccountType.kitsu), store.read());
    });

    test('a tracker write does not leak into another tracker', () async {
      final store = await _store();
      const base = AppPreferences();
      await store.writeFor(AccountType.anilist,
          _with(base, title: TitleLang.ja, nsfw: true, animeTab: 'Planning', hideScore: true));

      final anilist = store.readFor(AccountType.anilist);
      expect(anilist.general.preferredTitle, TitleLang.ja);
      expect(anilist.general.nsfw, isTrue);
      expect(anilist.list.defaultAnimeTab, 'Planning');
      expect(anilist.content.hideScore, isTrue);

      for (final t in [AccountType.myanimelist, AccountType.kitsu, AccountType.simkl]) {
        final other = store.readFor(t);
        expect(other.general, base.general, reason: t.name);
        expect(other.content, base.content, reason: t.name);
        expect(other.list, base.list, reason: t.name);
      }
      expect(store.read(), base);
    });

    test('two trackers keep two values', () async {
      final store = await _store();
      const base = AppPreferences();
      await store.writeFor(AccountType.myanimelist, _with(base, title: TitleLang.en));
      await store.writeFor(AccountType.anilist, _with(base, title: TitleLang.ro));
      expect(store.readFor(AccountType.myanimelist).general.preferredTitle, TitleLang.en);
      expect(store.readFor(AccountType.anilist).general.preferredTitle, TitleLang.ro);
    });

    test('app fields and notifications are shared', () async {
      final store = await _store();
      const base = AppPreferences();
      await store.writeFor(
          AccountType.simkl, _with(base, keep: false, tz: TimezonePref.utc, watching: false));
      for (final t in [...TrackerScope.trackers, AccountType.none]) {
        final p = store.readFor(t);
        expect(p.general.keepPagesInMemory, isFalse, reason: t.name);
        expect(p.content.timezone, TimezonePref.utc, reason: t.name);
        expect(p.notifications.watchingList, isFalse, reason: t.name);
      }
    });

    test('the per-tracker copy holds only tracker fields', () async {
      final store = await _store();
      await store.writeFor(AccountType.kitsu, const AppPreferences());
      final own = jsonDecode(store.prefs.getString('prefs_general_v1:kitsu')!) as Map;
      expect(own.containsKey('nsfw'), isTrue);
      expect(own.containsKey('keepPagesInMemory'), isFalse);
      expect(store.prefs.containsKey('prefs_notifications_v1:kitsu'), isFalse);
    });

    test('a tracker-field value sneaked into the global blob after a write stays a fallback',
        () async {
      final store = await _store();
      const base = AppPreferences();
      await store.write(_with(base, title: TitleLang.ja));
      await store.writeFor(AccountType.anilist, _with(base, title: TitleLang.ro));
      expect(store.readFor(AccountType.myanimelist).general.preferredTitle, TitleLang.ja);
      expect(store.readFor(AccountType.anilist).general.preferredTitle, TitleLang.ro);
    });

    test('only changed groups are written', () async {
      final store = await _store();
      const base = AppPreferences();
      await store.writeFor(AccountType.anilist, _with(base, nsfw: true), previous: base);
      expect(store.prefs.containsKey('prefs_general_v1:anilist'), isTrue);
      expect(store.prefs.containsKey('prefs_list_v1:anilist'), isFalse);
      expect(store.prefs.containsKey('prefs_content_v1:anilist'), isFalse);
    });

    test('none reads and writes the global groups', () async {
      final store = await _store();
      final p = _with(const AppPreferences(), nsfw: true);
      await store.writeFor(AccountType.none, p);
      expect(store.read(), p);
      expect(store.readFor(AccountType.none), p);
      expect(store.prefs.getKeys().any((k) => k.contains(':')), isFalse);
    });

    test('an unreadable tracker copy falls back to the global values', () async {
      final store = await _store({'prefs_general_v1:anilist': '{not json'});
      expect(store.readFor(AccountType.anilist), store.read());
    });

    test('clearFor drops the tracker copy only', () async {
      final store = await _store();
      const base = AppPreferences();
      await store.writeFor(AccountType.anilist, _with(base, nsfw: true));
      await store.writeFor(AccountType.kitsu, _with(base, nsfw: true));
      await store.clearFor(AccountType.anilist);
      expect(store.readFor(AccountType.anilist).general.nsfw, isFalse);
      expect(store.readFor(AccountType.kitsu).general.nsfw, isTrue);
    });
  });
}
