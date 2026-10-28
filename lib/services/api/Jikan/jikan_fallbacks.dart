import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mwl_commons/mwl_commons.dart'
    show
        ContentCharactersHtml,
        ContentCharacterHtml,
        ContentUpdateHtml,
        ContentUpdatesHtml,
        ReviewHtml,
        StaffMemberHtml;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_character.dart' show AnimeCharacter;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_forum.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_review.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_staff.dart' as staff;
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart' as updates;
import 'package:mywatchlist/services/api/Jikan/jikan_anime_news.dart' show AnimeNews;
import 'package:mywatchlist/services/api/Jikan/jikan_client.dart';
import 'package:mywatchlist/services/api/Jikan/mal_news_page.dart';
import 'package:mywatchlist/services/api/MAL/mal_forum_api.dart';
import 'package:mywatchlist/services/api/MAL/models/forum/forum_models.dart' show ForumTopicsData;
import 'package:mywatchlist/services/api/jikan_source.dart' show JikanSource;
import 'package:mywatchlist/services/api/mwl_api.dart';

/// Which source answered a [JikanFallbacks.race].
enum RaceWinner { jikan, fallback }

/// Answer of a [JikanFallbacks.race] and the source that gave it.
class RaceResult<T> {
  final T value;
  final RaceWinner winner;

  const RaceResult(this.value, this.winner);

  bool get fromJikan => winner == RaceWinner.jikan;
}

/// Both sources of a [JikanFallbacks.race] failed, or none answered within
/// the budget.
class NoSourceAnswered implements Exception {
  final Object? jikanError;
  final Object? fallbackError;
  final bool timedOut;

  const NoSourceAnswered({this.jikanError, this.fallbackError, this.timedOut = false});

  @override
  String toString() => timedOut
      ? 'NoSourceAnswered: no answer within the budget'
      : 'NoSourceAnswered: jikan=$jikanError, fallback=$fallbackError';
}

/// Sources used by the detail sections when Jikan does not answer.
///
/// Each loader returns data already converted to the Jikan models the widgets
/// display, so a section shows the same cards whatever the source. The
/// loaders are fields so tests can replace them with fakes.
class JikanFallbacks {
  JikanFallbacks._();

  /// Longest wait for a fallback source (the backend retries on its own).
  static const Duration timeout = Duration(seconds: 12);

  /// Jikan's head start in a [race]: the fallback starts when Jikan has not
  /// answered by then (at once when Jikan failed or is known to be down).
  static Duration headStart = const Duration(seconds: 3);

  /// Longest wait of a whole [race] (owner's target: about 12 s).
  static Duration budget = const Duration(seconds: 12);

  /// Jikan against a fallback source. The [jikan] leg goes through
  /// [JikanClient], which hands the request to Tenrai (same schema) when Jikan
  /// is down or slower than [JikanSource.hedgeAfter] (2.5 s, before the 3 s
  /// [headStart]), so Tenrai is the fast second source and the fallback
  /// (usually a MyAnimeList page) the third. Jikan runs first; the fallback starts
  /// after [headStart], or at once when Jikan fails or while the Jikan client
  /// skips requests after a timeout ([JikanClient.isUnreachable], then Jikan
  /// is not asked at all; with failover that means Tenrai failed too). The first answer wins; when both fail, or nothing
  /// answered within [budget], it throws [NoSourceAnswered].
  static Future<RaceResult<T>> race<T>({
    required Future<T> Function() jikan,
    required Future<T> Function() fallback,
  }) {
    final completer = Completer<RaceResult<T>>();
    Object? jikanError;
    Object? fallbackError;
    var jikanDone = false;
    var fallbackStarted = false;
    var fallbackDone = false;
    Timer? headTimer;
    Timer? budgetTimer;

    void finish(RaceResult<T>? result, [Object? error]) {
      if (completer.isCompleted) return;
      headTimer?.cancel();
      budgetTimer?.cancel();
      if (result != null) {
        completer.complete(result);
      } else {
        completer.completeError(error!);
      }
    }

    void failIfBothDone() {
      if (jikanDone && fallbackDone) {
        finish(null, NoSourceAnswered(jikanError: jikanError, fallbackError: fallbackError));
      }
    }

    void startFallback() {
      if (fallbackStarted || completer.isCompleted) return;
      fallbackStarted = true;
      headTimer?.cancel();
      Future<T>.sync(fallback).then(
        (value) => finish(RaceResult(value, RaceWinner.fallback)),
        onError: (Object e) {
          fallbackDone = true;
          fallbackError = e;
          failIfBothDone();
        },
      );
    }

    budgetTimer = Timer(budget, () => finish(null, const NoSourceAnswered(timedOut: true)));
    if (JikanClient.instance.isUnreachable) {
      jikanDone = true;
      jikanError = 'Jikan skipped (unreachable)';
      startFallback();
    } else {
      headTimer = Timer(headStart, startFallback);
      Future<T>.sync(jikan).then(
        (value) => finish(RaceResult(value, RaceWinner.jikan)),
        onError: (Object e) {
          jikanDone = true;
          jikanError = e;
          if (fallbackDone) {
            failIfBothDone();
          } else {
            startFallback();
          }
        },
      );
    }
    return completer.future;
  }

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

  /// News of one title from MyAnimeList's own page (`<category>/<id>/_/news`,
  /// parsed on the device off the UI isolate); the page has no next pages.
  static Future<List<AnimeNews>> Function(int id, String category) news =
      MalNewsPage.fetch;

  /// Members' latest list updates of one title from the "Recently Updated
  /// By" table of MAL's stats page (mwl-api `content/updates`, parsed off the
  /// UI isolate). Tenrai has no `userupdates`, so this is the only source
  /// while Jikan is down.
  static Future<updates.AnimeUserUpdatesResponse> Function(
      int id, String category, int page) userUpdates = _mwlUserUpdates;

  /// Restores the real sources and timings (tests).
  @visibleForTesting
  static void reset() {
    news = MalNewsPage.fetch;
    userUpdates = _mwlUserUpdates;
    reviews = _mwlReviews;
    forum = _malForum;
    characters = _mwlCharacters;
    headStart = const Duration(seconds: 3);
    budget = const Duration(seconds: 12);
    _forumMemo.clear();
  }

  /// Recent forum loads, so the forum section asking again right after a
  /// failed race shares that answer instead of waiting a second time.
  static final Map<String, _Memo<List<AnimeForum>>> _forumMemo = {};
  static const Duration _memoTtl = Duration(seconds: 20);

  static Future<List<AnimeReview>> _mwlReviews(
      int id, String category, int page) async {
    final list = await MwlApi.i
        .getReviewList(id: id, category: category, page: page)
        .timeout(timeout);
    return list.map(reviewFromHtml).toList();
  }

  static Future<updates.AnimeUserUpdatesResponse> _mwlUserUpdates(
      int id, String category, int page) async {
    final html = await MwlApi.i
        .getContentUpdates(id, category, page: page, timeout: timeout);
    return userUpdatesFromHtml(html);
  }

  static Future<List<AnimeForum>> _malForum(int id, String category) {
    final key = '$category:$id';
    final generation = JikanClient.instance.retryGeneration;
    final memo = _forumMemo[key];
    if (memo != null && memo.isFresh(generation)) return memo.future;
    _forumMemo.removeWhere((_, m) => !m.isFresh(generation));
    final future = _loadMalForum(id, category);
    _forumMemo[key] = _Memo(future, DateTime.now().add(_memoTtl), generation);
    future.then<void>((_) {}, onError: (_) {});
    return future;
  }

  static Future<List<AnimeForum>> _loadMalForum(int id, String category) async {
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

class _Memo<T> {
  final Future<T> future;
  final DateTime expires;
  final int generation;

  _Memo(this.future, this.expires, this.generation);

  bool isFresh(int currentGeneration) =>
      generation == currentGeneration && DateTime.now().isBefore(expires);
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

/// A page of MAL's "Recently Updated By" table in the Jikan `userupdates`
/// shape.
updates.AnimeUserUpdatesResponse userUpdatesFromHtml(ContentUpdatesHtml html) {
  return updates.AnimeUserUpdatesResponse(
    data: html.updates.map(userUpdateFromHtml).toList(),
    pagination: updates.Pagination(hasNextPage: html.hasNextPage),
  );
}

/// One row of MAL's "Recently Updated By" table in the Jikan shape.
updates.AnimeUserUpdate userUpdateFromHtml(ContentUpdateHtml html) {
  final image = html.imageUrl;
  return updates.AnimeUserUpdate(
    user: updates.User(
      username: html.username,
      url: 'https://myanimelist.net/profile/${Uri.encodeComponent(html.username)}',
      images: image == null
          ? null
          : updates.Images(jpg: updates.ImageFormat(imageUrl: image)),
    ),
    score: html.score,
    status: html.status,
    episodesSeen: html.episodesSeen,
    episodesTotal: html.episodesTotal,
    volumesRead: html.volumesRead,
    volumesTotal: html.volumesTotal,
    chaptersRead: html.chaptersRead,
    chaptersTotal: html.chaptersTotal,
    date: html.date,
  );
}
