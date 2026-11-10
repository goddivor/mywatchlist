import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/MAL/review/review_filter_bar.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';

AnimeReview _review(String user, int overall) => AnimeReview(
      user: User(username: user),
      reactions: Reactions(overall: overall),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  test('reviews open on the helpful sort', () {
    expect(const ReviewFilters().sort, ReviewSort.helpful);
  });

  test('helpful puts the most reacted first and keeps the API order on ties', () {
    final reviews = [_review('a', 1), _review('b', 5), _review('c', 1), _review('d', 9)];
    final sorted = filterReviews(reviews, sort: ReviewSort.helpful);
    expect(sorted.map((r) => r.user!.username), ['d', 'b', 'a', 'c']);
  });
}
