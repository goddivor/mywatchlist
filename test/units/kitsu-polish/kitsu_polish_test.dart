import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart' show KitsuRatingSystem;
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_media_cards.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_my_library.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kitsu-redesign/fakes.dart';

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Quick update', () {
    // Saved from an anonymous read of kitsu.io on 2026-10-29: a public profile's 'current'
    // anime with the same fields as the signed-in query.
    final saved = jsonDecode(File('test/units/kitsu-polish/fixtures/quick_update.json').readAsStringSync());

    test('the query never asks LibraryEntry.reaction, which Kitsu cannot resolve', () {
      expect(KitsuMyLibrary.entryFields, isNot(contains('reaction')));
    });

    test('a library with current entries gives the cards', () async {
      // Kitsu answers a query naming the unresolvable field with an error and no data.
      final fake = FakeKitsu(graphql: {
        'QuickUpdate': (r) => r.body.contains('reaction') ? null : saved,
      });
      final entries = await fake.my.currentEntries(kind: KitsuMediaKind.anime);
      expect(entries, hasLength(2));
      expect(entries.first.status, ListEntryStatus.current);
      expect(entries.first.progress, 3);
      expect(entries.first.total, 11);
      expect(entries.first.nextUnit?.number, 4);
      expect(entries.first.media?.titles.display, 'Kono Subarashii Sekai ni Shukufuku wo! 3');
    });
  });

  group('library page', () {
    test('keeps the exact rating and the reaction of each entry', () {
      final page = KitsuLibrary.parsePage({
        'data': [
          {
            'id': '900',
            'type': 'libraryEntries',
            'attributes': {'status': 'current', 'progress': 2, 'ratingTwenty': 15},
            'relationships': {
              'anime': {'data': {'type': 'anime', 'id': '12'}},
              'mediaReaction': {'data': {'type': 'mediaReactions', 'id': '77'}},
            },
          },
          {
            'id': '901',
            'type': 'libraryEntries',
            'attributes': {'status': 'planned', 'ratingTwenty': null},
            'relationships': {
              'anime': {'data': {'type': 'anime', 'id': '13'}},
              'mediaReaction': {'data': null},
            },
          },
        ],
        'included': [
          {'id': '12', 'type': 'anime', 'attributes': {'canonicalTitle': 'A'}},
          {'id': '13', 'type': 'anime', 'attributes': {'canonicalTitle': 'B'}},
          {'id': '77', 'type': 'mediaReactions', 'attributes': {'reaction': ' Lovely. '}},
        ],
        'links': {},
      }, isAnime: true, titleLang: 'canonical');
      expect(page.extras[12]?.twenty, 15);
      expect(page.extras[12]?.reaction, 'Lovely.');
      expect(page.extras[13]?.twenty, isNull);
      expect(page.extras[13]?.reaction, isNull);
    });
  });

  test('grid chip uses Kitsu short words', () {
    final a = KitsuUserListAdapter(owner: () => 'me');
    expect(a.statusShortLabel(ListEntryStatus.current, isAnime: true), 'Watching');
    expect(a.statusShortLabel(ListEntryStatus.current, isAnime: false), 'Reading');
    expect(a.statusShortLabel(ListEntryStatus.completed, isAnime: true), 'Done');
  });

  test('the histogram has the bars of the rating system', () {
    final r = KitsuRatingFrequencies({2: 1, 3: 2, 8: 4, 12: 8, 20: 16});
    expect(KitsuRatingHistogram.bars(r, KitsuRatingSystem.simple), [3, 4, 8, 16]);
    expect(KitsuRatingHistogram.bars(r, KitsuRatingSystem.regular), hasLength(10));
    expect(KitsuRatingHistogram.bars(r, KitsuRatingSystem.advanced), r.steps);
    expect(KitsuRatingHistogram.twentyOf(3, KitsuRatingSystem.simple), 20);
    expect(KitsuRatingHistogram.twentyOf(9, KitsuRatingSystem.regular), 20);
    expect(KitsuRatingHistogram.twentyOf(18, KitsuRatingSystem.advanced), 20);
  });
}
