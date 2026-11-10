import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_catalog.dart' show KitsuRatingSystem;
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Kitsu/media/kitsu_rating.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_cards.dart';
import 'package:mywatchlist/widgets/user/list/cards/entry_parts.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';
import 'package:mywatchlist/widgets/user/list/user_list_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kitsu-redesign/fakes.dart';

/// One library page of two anime: Frieren rated 15/20 with a reaction, Mushishi unrated and
/// planned. Fakes only: nothing reaches Kitsu.
Map<String, dynamic> _page() => {
      'data': [
        {
          'id': '900',
          'type': 'libraryEntries',
          'attributes': {'status': 'current', 'progress': 27, 'ratingTwenty': 15},
          'relationships': {
            'anime': {
              'data': {'type': 'anime', 'id': '12'}
            },
            'mediaReaction': {
              'data': {'type': 'mediaReactions', 'id': '77'}
            },
          },
        },
        {
          'id': '901',
          'type': 'libraryEntries',
          'attributes': {'status': 'planned', 'progress': 0, 'ratingTwenty': null},
          'relationships': {
            'anime': {
              'data': {'type': 'anime', 'id': '13'}
            },
            'mediaReaction': {'data': null},
          },
        },
      ],
      'included': [
        {
          'id': '12',
          'type': 'anime',
          'attributes': {'canonicalTitle': 'Frieren', 'episodeCount': 28, 'averageRating': '88.1'},
        },
        {
          'id': '13',
          'type': 'anime',
          'attributes': {'canonicalTitle': 'Mushishi', 'episodeCount': 26},
        },
        {
          'id': '77',
          'type': 'mediaReactions',
          'attributes': {'reaction': 'Quiet and perfect.'},
        },
      ],
      'links': {},
    };

Widget _app(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeKitsu fake;
  KitsuUserListAdapter adapter({
    KitsuRatingSystem system = KitsuRatingSystem.advanced,
    Future<int?> Function(BuildContext, ListEntryView)? askRating,
  }) =>
      KitsuUserListAdapter(
        library: fake.library,
        owner: () => 'me',
        clock: () => DateTime.utc(2026, 10, 29),
        ratingSystem: () => system,
        askRating: askRating,
      );

  setUp(() {
    fake = FakeKitsu(rest: {
      '/users': (_) => userDoc(),
      '/library-entries/': (r) => {
            'data': {'id': '900', 'type': 'libraryEntries', 'attributes': jsonDecode(r.body)['data']['attributes']}
          },
      '/library-entries': (_) => _page(),
    });
  });

  Future<List<ListEntryView>> load(KitsuUserListAdapter a) async =>
      (await a.fetch(category: 'anime', status: null, offset: 0, limit: 50)).entries;

  test('the page request also asks the reactions, in the same request', () async {
    await load(adapter());
    final pages = fake.requests.where((r) => r.url.path.endsWith('/library-entries')).toList();
    expect(pages, hasLength(1));
    expect(pages.single.url.queryParameters['include'], 'anime,anime.mappings,mediaReaction');
    expect(pages.single.url.queryParameters['fields[mediaReactions]'], 'reaction');
  });

  test('statuses use Kitsu wording', () {
    final a = adapter();
    expect(a.statusLabel(ListEntryStatus.planned, isAnime: true), 'Want to watch');
    expect(a.statusLabel(ListEntryStatus.current, isAnime: false), 'Currently reading');
  });

  test('the rating shows in the account system, from the exact ratingTwenty', () async {
    final advanced = adapter();
    final list = await load(advanced);
    final frieren = list.firstWhere((e) => e.id == 12);
    expect(frieren.score, 8, reason: 'the shared model keeps 0-10');
    expect(advanced.ratingTwentyOf(frieren), 15);
    expect(advanced.userScore(frieren)!.text, '7.5');

    final regular = adapter(system: KitsuRatingSystem.regular);
    await load(regular);
    expect(regular.userScore(frieren)!.text, KitsuRating.text(15, KitsuRatingSystem.regular));
    expect(regular.userScore(frieren)!.icon, Icons.star_rounded);

    final simple = adapter(system: KitsuRatingSystem.simple);
    await load(simple);
    expect(simple.userScore(frieren)!.text, 'Good');

    expect(advanced.userScore(list.firstWhere((e) => e.id == 13)), isNull);
  });

  test('the community score is a percentage', () async {
    final a = adapter();
    final frieren = (await load(a)).firstWhere((e) => e.id == 12);
    expect(a.meanScore(frieren)!.text, '88%');
  });

  testWidgets('a row shows the Kitsu status, rating, percentage and reaction', (tester) async {
    final a = adapter();
    final list = (await tester.runAsync(() => load(a)))!;
    await tester.pumpWidget(_app(ListEntryLookScope(
      look: a,
      child: Column(children: [
        for (final e in list)
          SizedBox(
            height: listRowExtent(DisplaySubType.comfortable),
            child: EntryListTile(
              entry: e,
              subType: DisplaySubType.comfortable,
              actions: EntryActions(
                onOpen: (_) {},
                onEdit: null,
                onStep: null,
                canStep: (_) => false,
                busy: ValueNotifier(const <int>{}),
              ),
              style: const EntryCardStyle(),
              now: DateTime.utc(2026, 10, 29),
              locale: 'en',
            ),
          ),
      ]),
    )));
    expect(find.text('Currently watching'), findsOneWidget);
    expect(find.text('Want to watch'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('88%'), findsOneWidget);
    expect(find.text('Quiet and perfect.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Your reaction: Quiet and perfect')), findsOneWidget);
  });

  testWidgets('the +1 that completes an unrated title asks for a rating and writes it',
      (tester) async {
    var asked = 0;
    final a = adapter(askRating: (context, entry) async {
      asked++;
      return 16;
    });
    await tester.pumpWidget(_app(const SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    const before = ListEntryView(
        id: 13, category: 'anime', title: 'Mushishi', status: ListEntryStatus.current, progress: 25, total: 26);
    final saved = before.copyWith(status: ListEntryStatus.completed, progress: 26);
    final rated = await tester.runAsync(() async {
      await load(a);
      return a.afterStep(context, saved, before: before);
    });
    expect(asked, 1);
    expect(rated!.score, 8);
    expect(a.ratingTwentyOf(rated), 16);
    final patch = fake.requests.lastWhere((r) => r.method == 'PATCH');
    expect(patch.url.path, endsWith('/library-entries/901'));
    expect((jsonDecode(patch.body)['data'] as Map)['attributes'], {'ratingTwenty': 16});
  });

  testWidgets('no prompt when not completing, already rated, or dismissed', (tester) async {
    var asked = 0;
    int? answer;
    final a = adapter(askRating: (context, entry) async {
      asked++;
      return answer;
    });
    await tester.pumpWidget(_app(const SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    const watching = ListEntryView(
        id: 13, category: 'anime', title: 'Mushishi', status: ListEntryStatus.current, progress: 3, total: 26);
    await tester.runAsync(() async {
      await load(a);
      // Not the last episode.
      expect(await a.afterStep(context, watching.copyWith(progress: 4), before: watching), isNull);
      // Frieren is already rated.
      const frieren = ListEntryView(
          id: 12, category: 'anime', title: 'Frieren', status: ListEntryStatus.current, progress: 27, total: 28);
      expect(
          await a.afterStep(context,
              frieren.copyWith(status: ListEntryStatus.completed, progress: 28), before: frieren),
          isNull);
      expect(asked, 0);
      // Dismissed: asked, nothing written.
      expect(
          await a.afterStep(context,
              watching.copyWith(status: ListEntryStatus.completed, progress: 26), before: watching),
          isNull);
    });
    expect(asked, 1);
    expect(fake.requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
}
