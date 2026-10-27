import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show ContentCharactersHtml, ContentCharacterHtml, ReviewHtml, StaffMemberHtml;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart' show AnimeCharacter;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart' as staff;
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart' show ForumTopicsData;
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Sources used by the detail sections when Jikan does not answer.
///
/// Each loader returns data already converted to the Jikan models the widgets
/// display, so a section shows the same cards whatever the source. The
/// loaders are fields so tests can replace them with fakes.
class JikanFallbacks {
  JikanFallbacks._();

  /// Longest wait for a fallback source (the backend retries on its own).
  static const Duration timeout = Duration(seconds: 20);

  /// Reviews of one title from the mwl-api `reviews` route (MAL review
  /// pages parsed by the backend), most voted first.
  static Future<List<AnimeReview>> Function(int id, String category, int page)
      reviews = _mwlReviews;

  /// Forum topics of one title from MyAnimeList's forum page
  /// (`forum/?animeid=` / `mangaid=`).
  static Future<List<AnimeForum>> Function(int id, String category) forum =
      _malForum;

  /// Characters, voice actors and staff from the mwl-api `content/characters`
  /// route (MAL characters page parsed by the backend).
  static Future<ContentCharactersHtml?> Function(int id, String category)
      characters = _mwlCharacters;

  /// Restores the real sources (tests).
  @visibleForTesting
  static void reset() {
    reviews = _mwlReviews;
    forum = _malForum;
    characters = _mwlCharacters;
  }

  static Future<List<AnimeReview>> _mwlReviews(
      int id, String category, int page) async {
    final list = await MwlApi.i
        .getReviewList(id: id, category: category, page: page)
        .timeout(timeout);
    return list.map(reviewFromHtml).toList();
  }

  static Future<List<AnimeForum>> _malForum(int id, String category) async {
    final isManga = category == 'manga';
    final topics = await MalForumApi()
        .getForumTopics(
          animeId: isManga ? null : id,
          mangaId: isManga ? id : null,
          fromHtml: true,
        )
        .timeout(timeout);
    if (topics == null) throw StateError('MAL forum page unavailable');
    return (topics.data ?? const <ForumTopicsData>[])
        .map(forumFromMal)
        .toList();
  }

  static Future<ContentCharactersHtml?> _mwlCharacters(
          int id, String category) =>
      MwlApi.i.getContentCharacters(id, category: category).timeout(timeout);
}

final DateFormat _malReviewDate = DateFormat('MMM d, yyyy', 'en_US');

/// A review parsed from MAL's page, in the Jikan shape. The page shows the
/// date as `Oct 27, 2026`; it becomes an ISO date (null when unreadable).
AnimeReview reviewFromHtml(ReviewHtml html) {
  String? date;
  final raw = html.timeAdded?.trim();
  if (raw != null && raw.isNotEmpty) {
    try {
      date = _malReviewDate.parseLoose(raw).toIso8601String();
    } catch (_) {
      date = null;
    }
  }
  final r = html.reactions;
  int? count(String name) => r[name];
  final overall = r.values.fold<int>(0, (a, b) => a + b);
  final tags = html.tags;
  final id = html.id;
  return AnimeReview(
    malId: id,
    url: id == null ? null : 'https://myanimelist.net/reviews.php?id=$id',
    user: User(
      username: html.username,
      url: html.username == null
          ? null
          : 'https://myanimelist.net/profile/${html.username}',
      images: html.userPicture?.best == null
          ? null
          : Images(jpg: ImageFormat(imageUrl: html.userPicture!.best)),
    ),
    date: date,
    review: html.reviewText,
    score: int.tryParse(html.overallRating?.trim() ?? ''),
    tags: tags,
    isPreliminary: tags.any((t) => t.toLowerCase() == 'preliminary'),
    isSpoiler: false,
    reactions: Reactions(
      overall: overall,
      nice: count('Nice'),
      loveIt: count('Love it'),
      funny: count('Funny'),
      confusing: count('Confusing'),
      informative: count('Informative'),
      wellWritten: count('Well-written'),
      creative: count('Creative'),
    ),
  );
}

/// A topic of MAL's forum (API or page) in the Jikan shape.
AnimeForum forumFromMal(ForumTopicsData topic) {
  final last = topic.lastPostCreatedBy?.name;
  final lastDate =
      topic.lastPostCreatedAt?.toIso8601String() ?? topic.lastPostTimeText;
  return AnimeForum(
    malId: topic.id,
    url: topic.id == null
        ? null
        : 'https://myanimelist.net/forum/?topicid=${topic.id}',
    title: topic.title,
    date: topic.createdAt?.toIso8601String(),
    authorUsername: topic.createdBy?.name,
    // MAL counts the first post; Jikan counts the replies.
    comments: topic.numberOfPosts,
    lastComment: last == null && lastDate == null
        ? null
        : LastComment(authorUsername: last, date: lastDate),
  );
}

Map<String, dynamic> _images(String? url) => {
      'jpg': {'image_url': url},
    };

/// A character of MAL's characters page in the Jikan shape.
AnimeCharacter characterFromHtml(ContentCharacterHtml html) {
  return AnimeCharacter.fromJson({
    'character': {
      'mal_id': html.id,
      'url': 'https://myanimelist.net/character/${html.id}',
      'images': _images(html.image?.best),
      'name': html.name,
    },
    'role': html.role,
    'favorites': html.favorites,
    'voice_actors': [
      for (final va in html.voiceActors)
        {
          'person': {
            'mal_id': va.id,
            'url': 'https://myanimelist.net/people/${va.id}',
            'images': _images(va.image?.best),
            'name': va.name,
          },
          'language': va.language,
        },
    ],
  });
}

/// A staff member of MAL's characters page in the Jikan shape (the page
/// gives the positions as one comma-separated text).
staff.AnimeStaff staffFromHtml(StaffMemberHtml html) {
  final positions = (html.role ?? '')
      .split(',')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return staff.AnimeStaff.fromJson({
    'person': {
      'mal_id': html.id,
      'url': 'https://myanimelist.net/people/${html.id}',
      'images': _images(html.image?.best),
      'name': html.name,
    },
    'positions': positions,
  });
}
