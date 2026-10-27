import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' as constants;
import 'package:mywatchlist/constants/constants.dart' show Constants, showConfirmationDialog;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';

import '../../helpers/pump_app.dart';

/// The fields inside `my_list_status{...}` of a MAL field list.
Set<String> _listStatusFields(String fields) {
  final match = RegExp(r'my_list_status\{([^}]*)\}').firstMatch(fields);
  expect(match, isNotNull, reason: 'no my_list_status{...} in $fields');
  return match!.group(1)!.split(',').toSet();
}

void main() {
  group('showConfirmationDialog', () {
    setUp(() => S.load(const Locale('en')));

    Future<List<bool?>> open(WidgetTester tester) async {
      final results = <bool?>[];
      await pumpInApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showConfirmationDialog(context: context, alertTitle: 'Delete?'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      return results;
    }

    testWidgets('returns false when dismissed by a tap outside', (tester) async {
      final results = await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(results, [false]);
    });

    testWidgets('returns false when dismissed with back', (tester) async {
      final results = await open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(results, [false]);
    });

    testWidgets('returns the answer', (tester) async {
      final results = await open(tester);
      await tester.tap(find.text(S.current.Yes));
      await tester.pumpAndSettle();
      expect(results, [true]);
    });
  });

  group('list status and score labels follow the language', () {
    tearDown(() => S.load(const Locale('en')));

    test('in English', () async {
      await S.load(const Locale('en'));
      expect(myAnimeStatusMap, {
        'watching': 'Watching',
        'completed': 'Completed',
        'on_hold': 'On Hold',
        'dropped': 'Dropped',
        'plan_to_watch': 'Plan to Watch',
      });
      expect(myMangaStatusMap['reading'], 'Reading');
      expect(myMangaStatusMap['plan_to_read'], 'Plan to Read');
      expect(allAnimeStatusMap['all'], 'All');
      expect(combinedStatusMap['plan_to_read'], 'Plan to Read');
      expect(constants.myAnimeStatusMap, myAnimeStatusMap);
      expect(myStarMap[0], 'Select a rating');
      expect(myStarMap[10], 'Masterpiece');
    });

    test('switching to French changes every label, no English left', () async {
      await S.load(const Locale('en'));
      final english = {
        ...myAnimeStatusMap.values,
        ...myMangaStatusMap.values,
        ...allAnimeStatusMap.values,
        ...allMangaStatusMap.values,
        ...myStarMap.values,
      };

      await S.load(const Locale('fr', 'FR'));
      expect(myAnimeStatusMap, {
        'watching': 'En cours',
        'completed': 'Terminé',
        'on_hold': 'En pause',
        'dropped': 'Abandonné',
        'plan_to_watch': 'À regarder',
      });
      expect(myMangaStatusMap, {
        'reading': 'En cours',
        'completed': 'Terminé',
        'on_hold': 'En pause',
        'dropped': 'Abandonné',
        'plan_to_read': 'À lire',
      });
      expect(allAnimeStatusMap['all'], 'Tous');
      expect(allMangaStatusMap['all'], 'Tous');
      expect(combinedStatusMap['plan_to_watch'], 'À regarder');
      expect(constants.myAnimeStatusMap['on_hold'], 'En pause');
      expect(myStarMap[0], 'Choisir une note');
      expect(myStarMap[10], 'Chef-d’œuvre');

      final french = {
        ...myAnimeStatusMap.values,
        ...myMangaStatusMap.values,
        ...allAnimeStatusMap.values,
        ...allMangaStatusMap.values,
        ...myStarMap.values,
      };
      // "Horrible" is the same word in both languages.
      expect(french.intersection(english), {'Horrible'});
      // Every score from 1 to 10 has its own label.
      expect(myStarMap.values.toSet().length, 11);
    });

    test('key order is kept for the pickers', () {
      expect(allAnimeStatusMap.keys.first, 'all');
      expect(allAnimeStatusMap.keys.skip(1), myAnimeStatusMap.keys);
      expect(myStarMap.keys, List.generate(11, (i) => i));
    });
  });

  group('MAL detail fields request the whole list entry', () {
    const common = {'status', 'score', 'updated_at', 'priority', 'start_date', 'finish_date', 'tags', 'comments'};

    test('anime', () {
      expect(_listStatusFields(Constants.malAnimeFields), {
        ...common,
        'num_episodes_watched',
        'is_rewatching',
        'num_times_rewatched',
        'rewatch_value',
      });
    });

    test('manga', () {
      expect(_listStatusFields(Constants.malMangaFields), {
        ...common,
        'num_chapters_read',
        'num_volumes_read',
        'is_rereading',
        'num_times_reread',
        'reread_value',
      });
    });
  });
}
