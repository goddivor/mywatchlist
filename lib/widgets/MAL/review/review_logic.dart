import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/widgets/common/share_builder.dart';

/// Order of the review list.
enum ReviewSort { newest, oldest, highest, lowest }

extension ReviewSortLabel on ReviewSort {
  String get label => switch (this) {
        ReviewSort.newest => S.current.Social_Reviews_Sort_Newest,
        ReviewSort.oldest => S.current.Social_Reviews_Sort_Oldest,
        ReviewSort.highest => S.current.Social_Reviews_Sort_Highest,
        ReviewSort.lowest => S.current.Social_Reviews_Sort_Lowest,
      };

  IconData get icon => switch (this) {
        ReviewSort.newest || ReviewSort.highest => Icons.arrow_downward,
        ReviewSort.oldest || ReviewSort.lowest => Icons.arrow_upward,
      };
}

/// Green from 8, amber from 5, red below: the colour of a review score.
Color reviewScoreColor(int score) =>
    score >= 8 ? Colors.green : (score >= 5 ? Colors.amber : Colors.red);

/// Number of reviews per score (reviews without a score are not counted).
Map<int, int> reviewScoreDistribution(Iterable<AnimeReview> reviews) {
  final result = <int, int>{};
  for (final review in reviews) {
    final score = review.score;
    if (score == null || score <= 0) continue;
    result[score] = (result[score] ?? 0) + 1;
  }
  return result;
}

/// Every tag used by [reviews], in order of first appearance.
List<String> reviewTags(Iterable<AnimeReview> reviews) {
  final tags = <String>{};
  for (final review in reviews) {
    final own = review.tags;
    if (own != null) tags.addAll(own);
  }
  return tags.toList();
}

/// Reviews matching [score] and any of [tags] (both optional), sorted by [sort].
/// [reviews] is expected in the API order (newest first).
List<AnimeReview> filterReviews(
  List<AnimeReview> reviews, {
  ReviewSort sort = ReviewSort.newest,
  int? score,
  Set<String> tags = const {},
}) {
  var result = reviews.where((review) {
    if (score != null && review.score != score) return false;
    if (tags.isNotEmpty) {
      final own = review.tags;
      if (own == null || !own.any(tags.contains)) return false;
    }
    return true;
  }).toList();
  switch (sort) {
    case ReviewSort.newest:
      break;
    case ReviewSort.oldest:
      result = result.reversed.toList();
    case ReviewSort.highest:
      result.sort((a, b) => (b.score ?? 0).compareTo(a.score ?? 0));
    case ReviewSort.lowest:
      result.sort((a, b) => (a.score ?? 0).compareTo(b.score ?? 0));
  }
  return result;
}

/// Texts sent to the summary service: non-empty, at most [maxReviews] reviews of at most
/// [maxChars] characters each, so the request stays small whatever was loaded.
List<String> reviewTextsForSummary(
  Iterable<AnimeReview> reviews, {
  int maxReviews = 12,
  int maxChars = 1500,
}) {
  final texts = <String>[];
  for (final review in reviews) {
    final text = review.review?.trim() ?? '';
    if (text.isEmpty) continue;
    texts.add(text.length > maxChars ? text.substring(0, maxChars) : text);
    if (texts.length >= maxReviews) break;
  }
  return texts;
}

/// "Jan 5, 2024" in [locale]; the ISO day when the date cannot be formatted.
String formatReviewDate(String? iso, String locale) {
  final date = iso == null ? null : DateTime.tryParse(iso);
  if (date == null) return '';
  try {
    return DateFormat.yMMMd(locale).format(date);
  } catch (_) {
    return date.toIso8601String().substring(0, 10);
  }
}

/// The fields offered by the share builder for [review]: link, reviewer, score, text.
List<ShareField> reviewShareFields(AnimeReview review) {
  final url = review.url;
  final user = review.user?.username;
  final score = review.score;
  final text = review.review?.trim();
  return [
    if (url != null && url.isNotEmpty) ShareField(label: S.current.Url, value: url, labelled: false),
    if (user != null && user.isNotEmpty) ShareField(label: S.current.Social_Review_Reviewer, value: user),
    if (score != null && score > 0) ShareField(label: S.current.Score, value: '$score/10'),
    if (text != null && text.isNotEmpty)
      ShareField(label: S.current.Social_Review_Text, value: text, selected: url == null || url.isEmpty),
  ];
}

/// The AI verdict of a set of reviews: [verdict] plus short pros and cons.
class ReviewSummary {
  final String verdict;
  final List<SummaryPoint> pros;
  final List<SummaryPoint> cons;

  const ReviewSummary({required this.verdict, this.pros = const [], this.cons = const []});

  /// Reads the service answer (`{verdict, pros, cons}`, also tolerated inside a `data`
  /// object). Null when there is no verdict to show.
  static ReviewSummary? fromJson(Object? json) {
    if (json is! Map) return null;
    final root = json['data'] is Map ? json['data'] as Map : json;
    final verdict = root['verdict'];
    if (verdict is! String || verdict.trim().isEmpty) return null;
    return ReviewSummary(
      verdict: verdict.trim(),
      pros: _points(root['pros']),
      cons: _points(root['cons']),
    );
  }

  static List<SummaryPoint> _points(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['title'] is String && (item['title'] as String).trim().isNotEmpty)
          SummaryPoint(
            title: (item['title'] as String).trim(),
            description: (item['description'] as String?)?.trim() ?? '',
          ),
    ];
  }
}

class SummaryPoint {
  final String title;
  final String description;

  const SummaryPoint({required this.title, required this.description});
}
