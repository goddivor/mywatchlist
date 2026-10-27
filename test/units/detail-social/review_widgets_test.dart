import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/review/review_detail_page.dart';
import 'package:mywatchlist/widgets/MAL/review/review_item.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_summary.dart';

import '../../helpers/pump_app.dart';

AnimeReview sample() => AnimeReview(
      score: 8,
      review: 'A very long review text',
      isSpoiler: true,
      isPreliminary: true,
      episodesWatched: 12,
      date: '2024-01-05T10:00:00+00:00',
      reactions: Reactions(nice: 4, loveIt: 9),
      user: User(username: 'bob'),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  testWidgets('ReviewItem shows the reviewer, the score, the tags and the text', (tester) async {
    var opened = false;
    await pumpInApp(
      tester,
      SizedBox(width: 300, height: 340, child: ReviewItem(review: sample(), onTap: () => opened = true)),
    );
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Spoiler'), findsOneWidget);
    expect(find.text('Preliminary'), findsOneWidget);
    expect(find.text('A very long review text'), findsOneWidget);
    await tester.tap(find.text('A very long review text'));
    expect(opened, isTrue);
  });

  testWidgets('ReviewDetailPage has no scroll view around the page and shows the progress', (tester) async {
    await pumpInApp(tester, SizedBox(width: 400, height: 700, child: ReviewDetailPage(review: sample())));
    expect(find.text('12 episodes watched'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    // The text is the only scrollable part.
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('ReviewDetailPage says chapters for a manga', (tester) async {
    await pumpInApp(
      tester,
      SizedBox(width: 400, height: 700, child: ReviewDetailPage(review: sample(), category: 'manga')),
    );
    expect(find.text('12 chapters read'), findsOneWidget);
  });

  group('ReviewSummaryEntry', () {
    testWidgets('renders nothing when the feature is off or there are no reviews', (tester) async {
      await pumpInApp(
        tester,
        ReviewSummaryEntry(id: 1, category: 'anime', texts: const ['a'], enabled: false, loader: (_, __, ___) async => null),
      );
      expect(find.text('AI summary'), findsNothing);
      await pumpInApp(
        tester,
        ReviewSummaryEntry(id: 1, category: 'anime', texts: const [], enabled: true, loader: (_, __, ___) async => null),
      );
      expect(find.text('AI summary'), findsNothing);
    });

    testWidgets('opens the sheet and shows verdict, pros and cons', (tester) async {
      List<String>? sent;
      await pumpInApp(
        tester,
        ReviewSummaryEntry(
          id: 5,
          category: 'manga',
          texts: const ['one', 'two'],
          enabled: true,
          loader: (id, category, texts) async {
            sent = texts;
            return const ReviewSummary(
              verdict: 'A fine series',
              pros: [SummaryPoint(title: 'Art', description: 'Lovely')],
              cons: [SummaryPoint(title: 'Pacing', description: 'Slow')],
            );
          },
        ),
      );
      await tester.tap(find.text('AI summary'));
      await tester.pumpAndSettle();
      expect(sent, ['one', 'two']);
      expect(find.text('A fine series'), findsOneWidget);
      expect(find.text('Art'), findsOneWidget);
      expect(find.text('Pacing'), findsOneWidget);
      expect(find.textContaining('Based on 2 reviews'), findsOneWidget);
    });

    testWidgets('a failed summary offers a retry that asks again', (tester) async {
      var calls = 0;
      await pumpInApp(
        tester,
        ReviewSummaryEntry(
          id: 5,
          category: 'anime',
          texts: const ['one'],
          enabled: true,
          loader: (_, __, ___) async {
            calls++;
            return calls == 1 ? null : const ReviewSummary(verdict: 'Second time');
          },
        ),
      );
      await tester.tap(find.text('AI summary'));
      await tester.pumpAndSettle();
      expect(find.text('The summary could not be generated'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Second time'), findsOneWidget);
    });
  });
}
