import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_detail_models.dart' show SimklMediaImages;
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart';

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// Anime watch time of the user (`GET /users/{id}/stats`), all in minutes.
@immutable
class SimklWatchStats {
  /// Time spent watching anime.
  final int totalMins;

  /// Time left on the episodes still to watch of the Watching list.
  final int leftMins;
  final int leftEpisodes;

  /// Anime watched in the last seven days.
  final int lastWeekMins;

  const SimklWatchStats({this.totalMins = 0, this.leftMins = 0, this.leftEpisodes = 0, this.lastWeekMins = 0});

  bool get isEmpty => totalMins == 0 && leftMins == 0 && lastWeekMins == 0;

  /// Null when [data] is not the stats answer.
  static SimklWatchStats? fromJson(Object? data) {
    if (data is! Map) return null;
    final anime = data['anime'] is Map ? data['anime'] as Map : const {};
    var leftMins = 0;
    var leftEpisodes = 0;
    for (final value in anime.values) {
      if (value is! Map) continue;
      leftMins += _int(value['left_to_watch_mins']) ?? 0;
      leftEpisodes += _int(value['left_to_watch_episodes']) ?? 0;
    }
    final week = data['watched_last_week'] is Map ? data['watched_last_week'] as Map : const {};
    return SimklWatchStats(
      totalMins: _int(anime['total_mins']) ?? 0,
      leftMins: leftMins,
      leftEpisodes: leftEpisodes,
      lastWeekMins: _int(week['anime_mins']) ?? 0,
    );
  }
}

/// The title the user is watching now (`GET /users/recently-watched-background/{id}`).
@immutable
class SimklNowWatching {
  final int? simklId;
  final String title;
  final String coverUrl;
  final String? posterUrl;

  const SimklNowWatching({this.simklId, required this.title, required this.coverUrl, this.posterUrl});

  /// Null when the answer has no picture to show.
  static SimklNowWatching? fromJson(Object? data) {
    if (data is! Map) return null;
    final cover = SimklMediaImages.fanart(data['fanart']);
    if (cover == null) return null;
    return SimklNowWatching(
      simklId: _int(data['id']),
      title: _text(data['title']) ?? '',
      coverUrl: cover,
      posterUrl: SimklImages.poster(data['poster']),
    );
  }
}

/// One custom list of a PRO/VIP account.
@immutable
class SimklCustomList {
  final int id;
  final String name;
  final int count;

  const SimklCustomList({required this.id, required this.name, this.count = 0});

  static SimklCustomList? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = _int(raw['id'] ?? raw['list_id']);
    final name = _text(raw['name']) ?? _text(raw['title']);
    if (id == null || name == null) return null;
    return SimklCustomList(
      id: id,
      name: name,
      count: _int(raw['items_count'] ?? raw['count'] ?? raw['total']) ?? 0,
    );
  }

  /// Empty for a free account (`premium_only`) or an unknown shape.
  static List<SimklCustomList> listFrom(Object? data) {
    final list = data is List ? data : (data is Map ? data['lists'] : null);
    if (list is! List) return const [];
    return [for (final raw in list) if (fromJson(raw) case final l?) l];
  }
}

/// The profile extras of Simkl: watch time, the "now watching" cover and the custom lists.
/// Each call counts against Simkl's limits (the stats one is "the most expensive"), so the
/// profile asks them on open and on pull to refresh only; nothing is kept between loads.
class SimklStatsService {
  SimklStatsService({SimklClient? client}) : _client = client ?? SimklClient.instance;

  static SimklStatsService instance = SimklStatsService();

  final SimklClient _client;

  /// `GET /users/{id}/stats`; null when the answer is not usable.
  Future<SimklWatchStats?> watchStats(int accountId) async =>
      SimklWatchStats.fromJson(await _client.getAuth('/users/$accountId/stats'));

  /// `GET /users/recently-watched-background/{id}`; null when nothing was watched.
  Future<SimklNowWatching?> nowWatching(int accountId) async =>
      SimklNowWatching.fromJson(await _client.getAuth('/users/recently-watched-background/$accountId'));

  /// `GET /lists/user/{id}` (PRO and VIP only; a free account gets `premium_only`).
  Future<List<SimklCustomList>> customLists(int accountId) async =>
      SimklCustomList.listFrom(await _client.getAuth('/lists/user/$accountId'));

  /// `GET /lists/{id}`: the titles of one custom list.
  Future<List<SimklMedia>> listItems(int listId) async {
    final data = await _client.getAuth('/lists/$listId');
    final items = data is Map ? (data['items'] ?? data['anime'] ?? data['shows']) : data;
    return SimklMedia.listFrom(items);
  }
}

/// Whether [accountType] (`account.type` of `/users/settings`) is a paid Simkl plan.
bool simklIsPaid(String accountType) {
  final t = accountType.toLowerCase();
  return t == 'pro' || t == 'vip';
}
