import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/MAL/review/review_reactions.dart';
import 'package:mywatchlist/widgets/MAL/review/user_link.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

AnimeReview review({int? score, String? text, List<String>? tags, String? user, String? url, Reactions? reactions}) =>
    AnimeReview(
      score: score,
      review: text,
      tags: tags,
      url: url,
      reactions: reactions,
      user: user == null ? null : User(username: user),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  final reviews = [
    review(score: 9, text: 'Great', tags: ['Recommended'], user: 'a'),
    review(score: 5, text: 'Fine', tags: ['Mixed Feelings'], user: 'b'),
    review(score: 9, text: '  ', user: 'c'),
    review(score: null, text: 'No score', user: 'd'),
  ];

  group('filterReviews', () {
    test('newest keeps the API order, oldest reverses it', () {
      expect(filterReviews(reviews).map((r) => r.user!.username), ['a', 'b', 'c', 'd']);
      expect(filterReviews(reviews, sort: ReviewSort.oldest).map((r) => r.user!.username), ['d', 'c', 'b', 'a']);
    });

    test('sorts by score', () {
      expect(filterReviews(reviews, sort: ReviewSort.highest).first.score, 9);
      expect(filterReviews(reviews, sort: ReviewSort.lowest).first.score, isNull);
    });

    test('filters by score and by any selected tag', () {
      expect(filterReviews(reviews, score: 9).map((r) => r.user!.username), ['a', 'c']);
      expect(filterReviews(reviews, tags: {'Mixed Feelings', 'Other'}).map((r) => r.user!.username), ['b']);
      expect(filterReviews(reviews, score: 9, tags: {'Mixed Feelings'}), isEmpty);
    });
  });

  test('distribution counts scored reviews only and tags keep first-seen order', () {
    expect(reviewScoreDistribution(reviews), {9: 2, 5: 1});
    expect(reviewTags(reviews), ['Recommended', 'Mixed Feelings']);
  });

  test('summary texts skip blanks, cap the count and the length', () {
    expect(reviewTextsForSummary(reviews), ['Great', 'Fine', 'No score']);
    expect(reviewTextsForSummary(reviews, maxReviews: 1), ['Great']);
    expect(reviewTextsForSummary([review(text: 'abcdef')], maxChars: 3), ['abc']);
  });

  group('ReviewSummary.fromJson', () {
    test('reads verdict, pros and cons, also inside data', () {
      final json = {
        'verdict': ' Solid ',
        'pros': [
          {'title': 'Art', 'description': 'Gorgeous'},
          {'title': '', 'description': 'ignored'},
        ],
        'cons': [
          {'title': 'Pacing'},
        ],
      };
      for (final input in [json, {'data': json}]) {
        final summary = ReviewSummary.fromJson(input)!;
        expect(summary.verdict, 'Solid');
        expect(summary.pros.single.title, 'Art');
        expect(summary.cons.single.description, '');
      }
    });

    test('no verdict means no summary', () {
      expect(ReviewSummary.fromJson(null), isNull);
      expect(ReviewSummary.fromJson({'verdict': '  '}), isNull);
      expect(ReviewSummary.fromJson('text'), isNull);
    });
  });

  test('reviewShareFields offers the link first and only the text when there is no link', () {
    final withLink = reviewShareFields(review(score: 8, text: 'Nice', user: 'bob', url: 'https://mal/r/1'));
    expect(withLink.map((f) => f.label), ['Url', 'Reviewer', 'Score', 'Review']);
    expect(buildShareText(withLink), 'https://mal/r/1\nReviewer: bob\nScore: 8/10');
    final noLink = reviewShareFields(review(text: 'Nice'));
    expect(buildShareText(noLink), 'Nice');
    expect(reviewShareFields(review()), isEmpty);
  });

  test('formatReviewDate formats an ISO date and tolerates garbage', () {
    expect(formatReviewDate('2024-01-05T10:00:00+00:00', 'en'), contains('2024'));
    expect(formatReviewDate(null, 'en'), '');
    expect(formatReviewDate('nope', 'en'), '');
  });

  test('sortedReactions drops zeros and orders by count', () {
    final sorted = sortedReactions(Reactions(nice: 2, loveIt: 7, funny: 0, creative: 3));
    expect(sorted.map((e) => e.$1), [ReviewReactionKind.loveIt, ReviewReactionKind.creative, ReviewReactionKind.nice]);
    expect(sortedReactions(null), isEmpty);
  });

  test('placeholder users cannot be opened', () {
    expect(isLinkableUser('bob'), isTrue);
    expect(isLinkableUser('removed-user'), isFalse);
    expect(isLinkableUser('MyAnimeList'), isFalse);
    expect(isLinkableUser(''), isFalse);
    expect(isLinkableUser(null), isFalse);
  });

  group('interest stacks', () {
    test('stackWebUrl completes a path', () {
      expect(stackWebUrl('/stacks/12'), 'https://myanimelist.net/stacks/12');
      expect(stackWebUrl('https://myanimelist.net/stacks/12'), 'https://myanimelist.net/stacks/12');
      expect(stackWebUrl(' '), isNull);
      expect(stackWebUrl(null), isNull);
    });

    test('stackShareFields lists the entries, unselected by default', () {
      final fields = stackShareFields(
        url: 'https://myanimelist.net/stacks/1',
        title: 'Best',
        author: 'bob',
        entries: ['A', 'B', ' '],
        description: 'Desc',
      );
      expect(fields.map((f) => f.label), ['Url', 'Title', 'Created by', 'Entries', 'Description']);
      expect(fields[3].value, '- A\n- B');
      expect(fields[3].selected, isFalse);
    });
  });
}
