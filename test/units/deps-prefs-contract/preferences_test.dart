import 'dart:ui' show Locale;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mwl_commons/mwl_commons.dart' show LinkType;
import 'package:mywatchlist/constants/constants.dart' show DisplayType, TabType, TitleLang;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

/// A value different from the default in every field of every group.
AppPreferences _customized() {
  const card = ContentCardProps(
    id: 'compact',
    profileName: 'Compact',
    height: 96,
    fields: [
      CustomizableField(
          type: CustomizableFieldType.title, position: FieldPosition(top: 10, left: 80)),
      CustomizableField(
          type: CustomizableFieldType.genre,
          position: FieldPosition(bottom: 4, right: 4),
          hidden: true),
    ],
  );
  final animeTabs = ContentPreferences.defaultAnimeTabs.reversed
      .map((t) => t.tabType == TabType.News ? t.copyWith(visible: false) : t)
      .toList();
  return const AppPreferences().copyWith(
    general: const GeneralPreferences().copyWith(
      preferredTitle: TitleLang.ja,
      startupPage: StartupPage.userList,
      nsfw: true,
      showAnimeMangaCard: true,
      allowYoutubePlayer: true,
      keepPagesInMemory: true,
      showPriority: true,
      autoTranslateSynopsis: true,
      showOnlyLastQuote: false,
      autoAddStartEndDate: false,
      showAiringInfo: true,
      statsChartColors: [0xFF00FF00, -1, 0xFF0000FF, -1, 0xFFFF0000],
      preferredLinkType: LinkType.resources,
      detailsExpanded: false,
      defaultDisplayType: DisplayType.grid,
      userListAnimeSort: 'list_score',
      userListMangaSort: 'anime_title',
      showDubStatus: true,
      dubLanguage: 'french',
      dubIconStyle: 2,
      dubMinSourceCount: 3,
    ),
    content: const ContentPreferences().copyWith(
      showCountdownOnDetail: false,
      showDetailBackground: false,
      showPrivateNotes: true,
      hideScore: true,
      globalSeasonalFilter: true,
      timezone: TimezonePref.jst,
      defaultAnimeAddStatus: 'plan_to_watch',
      defaultMangaAddStatus: 'plan_to_read',
      animeTabs: animeTabs,
    ),
    list: const ListPreferences().copyWith(
      defaultCategory: ListCategory.manga,
      defaultAnimeTab: 'completed',
      defaultMangaTab: 'reading',
      cardProfiles: [card],
    ),
    notifications: NotificationPreferences(
      subscribedAt: DateTime.utc(2026, 10, 27, 8, 30),
      dailyReleases: false,
      watchingList: false,
      planToWatchList: false,
      largeImage: false,
    ),
  );
}

void main() {
  setUp(Preferences.reset);

  group('defaults', () {
    test('match DailyAL', () async {
      final prefs = PreferencesStore(await _prefs()).read();
      expect(prefs, const AppPreferences());
      expect(prefs.general.preferredTitle, TitleLang.ro);
      expect(prefs.general.showOnlyLastQuote, isTrue);
      expect(prefs.general.autoAddStartEndDate, isTrue);
      expect(prefs.general.preferredLinkType, LinkType.streaming);
      expect(prefs.general.statsChartColors, List.filled(5, themeChartColor));
      expect(prefs.content.showCountdownOnDetail, isTrue);
      expect(prefs.content.defaultAnimeAddStatus, 'watching');
      expect(prefs.content.defaultMangaAddStatus, 'reading');
      expect(prefs.content.timezone, TimezonePref.local);
      expect(prefs.notifications.enabled, isFalse);
      expect(prefs.notifications.largeImage, isTrue);
    });

    test('every anime and manga section is listed once, ScoreStats after Stats', () {
      final anime = defaultAnimeTabOrder;
      expect(anime.toSet().length, anime.length);
      expect(anime.indexOf(TabType.ScoreStats), anime.indexOf(TabType.Stats) + 1);
      expect(defaultMangaTabOrder, isNot(contains(TabType.Media)));
      expect(defaultMangaTabOrder, contains(TabType.Related_Anime));
    });
  });

  group('persistence round trip', () {
    test('every field survives write then read', () async {
      final shared = await _prefs();
      final store = PreferencesStore(shared);
      final custom = _customized();
      expect(custom.general, isNot(const GeneralPreferences()));

      await store.write(custom);
      final reread = PreferencesStore(await SharedPreferences.getInstance()).read();

      expect(reread, custom);
      expect(reread.content.visibleTabs(manga: false), isNot(contains(TabType.News)));
      expect(reread.content.animeTabs.first.tabType, TabType.More_Info);
      expect(reread.list.cardProfile('compact')?.fields.last.hidden, isTrue);
      expect(reread.notifications.subscribedAt, DateTime.utc(2026, 10, 27, 8, 30));
    });

    test('bloc saves each change and a new bloc starts from it', () async {
      final shared = await _prefs();
      final bloc = PreferencesBloc(store: PreferencesStore(shared));
      expect(Preferences.current, const AppPreferences());

      bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: true)));
      bloc.add(ContentPreferencesChanged((p) => p.copyWith(timezone: TimezonePref.utc)));
      bloc.add(ListPreferencesChanged((p) => p.copyWith(defaultAnimeTab: 'watching')));
      bloc.add(NotificationPreferencesChanged(
          (p) => p.copyWith(subscribedAt: DateTime.utc(2026), largeImage: false)));
      await bloc.stream.firstWhere((s) => !s.notifications.largeImage);

      // Non-widget getter follows the bloc.
      expect(Preferences.general.nsfw, isTrue);
      expect(Preferences.content.timezone, TimezonePref.utc);
      expect(Preferences.notifications.enabled, isTrue);
      await bloc.close();
      expect(Preferences.bloc, isNull);

      final restarted = PreferencesBloc(store: PreferencesStore(shared));
      expect(restarted.state.general.nsfw, isTrue);
      expect(restarted.state.content.timezone, TimezonePref.utc);
      expect(restarted.state.list.defaultAnimeTab, 'watching');
      expect(restarted.state.notifications.largeImage, isFalse);
      await restarted.close();
    });

    test('an unchanged value writes nothing', () async {
      final shared = await _prefs();
      final bloc = PreferencesBloc(store: PreferencesStore(shared));
      bloc.add(GeneralPreferencesChanged((p) => p.copyWith(nsfw: false)));
      await Future<void>.delayed(Duration.zero);
      expect(shared.getString(PreferencesStore.keyGeneral), isNull);
      await bloc.close();
    });

    test('reset puts only the given groups back to defaults', () async {
      final shared = await _prefs();
      await PreferencesStore(shared).write(_customized());
      final bloc = PreferencesBloc(store: PreferencesStore(shared));
      bloc.add(const PreferencesReset({PreferencesGroup.general}));
      final state = await bloc.stream.first;
      expect(state.general, const GeneralPreferences());
      expect(state.content, _customized().content);
      expect(PreferencesStore(shared).read().general, const GeneralPreferences());
      await bloc.close();
    });

    test('unsubscribed keeps the lists and clears the date', () {
      final on = _customized().notifications;
      final off = on.unsubscribed();
      expect(off.enabled, isFalse);
      expect(off.watchingList, on.watchingList);
    });
  });

  group('key migration', () {
    test('legacy timezone_pref is moved into the content group', () async {
      final shared = await _prefs({PreferencesStore.legacyKeyTimezone: 'jst'});
      final store = PreferencesStore(shared);
      expect(store.read().content.timezone, TimezonePref.jst);

      await store.migrateLegacy();
      expect(shared.containsKey(PreferencesStore.legacyKeyTimezone), isFalse);
      expect(PreferencesStore(shared).read().content.timezone, TimezonePref.jst);

      await store.migrateLegacy(); // idempotent
      expect(PreferencesStore(shared).read().content.timezone, TimezonePref.jst);
    });

    test('a saved content group wins over the legacy key', () async {
      final shared = await _prefs({
        PreferencesStore.legacyKeyTimezone: 'jst',
        PreferencesStore.keyContent: jsonEncode({'timezone': 'utc'}),
      });
      final store = PreferencesStore(shared);
      await store.migrateLegacy();
      expect(store.read().content.timezone, TimezonePref.utc);
      expect(shared.containsKey(PreferencesStore.legacyKeyTimezone), isFalse);
    });

    test('saved detail tabs keep their order and gain the new sections', () async {
      final shared = await _prefs({
        PreferencesStore.keyContent: jsonEncode({
          'animeTabs': [
            {'tabType': 'Stats', 'visibility': true},
            {'tabType': 'Synopsis', 'visibility': false},
            {'tabType': 'Removed_Tab', 'visibility': true},
            {'tabType': 'Synopsis', 'visibility': true},
          ],
        }),
      });
      final tabs = PreferencesStore(shared).read().content.animeTabs;
      expect(tabs[0], const DetailTabPreference(TabType.Stats));
      expect(tabs[1], const DetailTabPreference(TabType.ScoreStats));
      expect(tabs[2], const DetailTabPreference(TabType.Synopsis, visible: false));
      expect(tabs.map((t) => t.tabType).toSet(), defaultAnimeTabOrder.toSet());
      expect(tabs.length, defaultAnimeTabOrder.length);
    });

    test('corrupted or mistyped values fall back field by field', () async {
      final shared = await _prefs({
        PreferencesStore.keyGeneral:
            jsonEncode({'nsfw': 'yes', 'showPriority': true, 'statsChartColors': [1, 2]}),
        PreferencesStore.keyList: '{not json',
        PreferencesStore.keyNotifications: jsonEncode({'subscribedAt': 'tomorrow'}),
      });
      final prefs = PreferencesStore(shared).read();
      expect(prefs.general.nsfw, isFalse);
      expect(prefs.general.showPriority, isTrue);
      expect(prefs.general.statsChartColors, [1, 2, -1, -1, -1]);
      expect(prefs.list, const ListPreferences());
      expect(prefs.notifications.subscribedAt, isNull);
    });

    test('DailyAL card fields (title/description keys) are read', () {
      final card = ContentCardProps.fromJson({
        'id': 'dal',
        'profileName': 'DAL',
        'height': 140,
        'fields': [
          {
            'type': 3,
            'title': 'Mean Score',
            'description': 'Mean score of the item',
            'position': {'top': 5, 'left': 100},
          },
          {'type': 999, 'position': {}},
        ],
      });
      expect(card.height, 140.0);
      expect(card.fields, [
        const CustomizableField(
            type: CustomizableFieldType.mean_score, position: FieldPosition(top: 5, left: 100)),
      ]);
    });
  });

  test('every card field has a localized label and description', () async {
    await S.load(const Locale('en'));
    for (final type in CustomizableFieldType.values) {
      expect(type.label, isNotEmpty);
      expect(type.description, isNotEmpty);
    }
    expect(ContentCardProps.defaultObject().fields.map((f) => f.type).toSet(),
        hasLength(CustomizableFieldType.values.length - 1)); // list_status is opt-in
  });
}
