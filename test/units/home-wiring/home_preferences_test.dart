import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saved sections', () {
    test('a section saved before the new fields existed still loads', () {
      final legacy = {
        'type': 1,
        'enabled': true,
        'itemCount': 12,
        'customTitle': null,
        'cacheDurationHours': 4,
      };
      final section = HomeSectionPreference.tryFromJson(legacy)!;
      expect(section.type, SectionType.seasonNow);
      expect(section.itemCount, 12);
      expect(section.season, isNull);
      expect(section.userCategory, 'anime');
    });

    test('the new kinds keep their fields through JSON', () {
      final list = HomeSectionPreference(
          type: SectionType.userList, userCategory: 'manga', userStatus: 'reading');
      final forum = HomeSectionPreference(type: SectionType.forum, boardId: 11, subboardId: 2);
      final season = HomeSectionPreference(
          type: SectionType.seasonNow, season: SeasonType.FALL, year: 2026);
      final prefs = MalHomePreferences(sections: [list, forum, season]);

      final back = MalHomePreferences.fromJson(
          jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>);

      expect(back.sections.map((s) => s.type),
          [SectionType.userList, SectionType.forum, SectionType.seasonNow]);
      expect(back.sections[0].userCategory, 'manga');
      expect(back.sections[0].userStatus, 'reading');
      expect(back.sections[1].boardId, 11);
      expect(back.sections[1].subboardId, 2);
      expect(back.sections[2].season, SeasonType.FALL);
      expect(back.sections[2].year, 2026);
    });

    test('a kind this version does not know is dropped, not a crash', () {
      final back = MalHomePreferences.fromJson({
        'sections': [
          {'type': 999, 'enabled': true, 'itemCount': 5},
          {'type': 0, 'enabled': false, 'itemCount': 8},
        ],
        'tileSize': 42,
      });
      expect(back.sections, hasLength(1));
      expect(back.sections.single.type, SectionType.news);
      expect(back.sections.single.enabled, isFalse);
    });

    test('copy is independent of the original', () {
      final original = HomeSectionPreference(type: SectionType.forum, boardId: 3);
      final copy = original.copy()..boardId = 4;
      expect(original.boardId, 3);
      expect(copy.boardId, 4);
    });
  });

  group('titles', () {
    test('default titles follow the app language', () async {
      final news = HomeSectionPreference(type: SectionType.news);
      final season = HomeSectionPreference(
          type: SectionType.seasonNow, season: SeasonType.FALL, year: 2026);

      await LanguageBloc.apply('en');
      expect(news.getDisplayTitle(), 'Anime News');
      expect(season.getDisplayTitle(), 'Fall 2026 Anime');

      await LanguageBloc.apply('fr_FR');
      expect(news.getDisplayTitle(), 'Actualités anime');
      expect(season.getDisplayTitle(), 'Saison Automne 2026');
      await LanguageBloc.apply('en');
    });

    test('a custom title wins over the default one', () {
      final section = HomeSectionPreference(type: SectionType.news, customTitle: 'Mine');
      expect(section.getDisplayTitle(), 'Mine');
    });

    test('the user list title names the list and the status', () async {
      await LanguageBloc.apply('en');
      final all = HomeSectionPreference(type: SectionType.userList);
      final watching = HomeSectionPreference(type: SectionType.userList, userStatus: 'watching');
      expect(all.getDisplayTitle(), 'My Anime List');
      expect(watching.getDisplayTitle(), contains('My Anime List'));
      expect(watching.getDisplayTitle(), contains('Watching'));
    });
  });

  testWidgets('every kind has an icon and a default title', (tester) async {
    await LanguageBloc.apply('en');
    for (final type in SectionType.values) {
      final section = HomeSectionPreference(type: type);
      expect(section.getIcon(), isA<IconData>());
      expect(section.getDefaultTitle(), isNotEmpty, reason: '$type');
    }
  });
}
