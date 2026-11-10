import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Simkl's list status words and their tracker-neutral [ListEntryStatus].
abstract final class SimklStatus {
  static const watching = 'watching';
  static const planToWatch = 'plantowatch';
  static const hold = 'hold';
  static const completed = 'completed';
  static const dropped = 'dropped';

  static ListEntryStatus? parse(Object? value) => switch (value) {
        'watching' => ListEntryStatus.current,
        'plantowatch' => ListEntryStatus.planned,
        'hold' => ListEntryStatus.onHold,
        'completed' => ListEntryStatus.completed,
        'dropped' || 'notinteresting' => ListEntryStatus.dropped,
        _ => null,
      };

  static String api(ListEntryStatus status) => switch (status) {
        ListEntryStatus.current => watching,
        ListEntryStatus.planned => planToWatch,
        ListEntryStatus.onHold => hold,
        ListEntryStatus.completed => completed,
        ListEntryStatus.dropped => dropped,
      };
}

/// Picture URLs of Simkl (`poster` values are paths without host or size).
abstract final class SimklImages {
  static String? poster(Object? path, {String size = 'm'}) {
    final p = path is String ? path.trim() : '';
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return 'https://simkl.in/posters/${p}_$size.jpg';
  }

  /// Background picture (`fanart`, `_mobile` size, 16:9).
  static String? fanart(Object? path) {
    final p = path is String ? path.trim() : '';
    if (p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return 'https://simkl.in/fanart/${p}_mobile.jpg';
  }

  /// The public page of a title, for the rare ones without a MyAnimeList id.
  static String page(int simklId, [String? slug]) =>
      'https://simkl.com/anime/$simklId${slug == null || slug.isEmpty ? '' : '/$slug'}';
}

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
double? _double(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
double? _percent(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v.replaceAll('%', '').replaceAll(',', '.').trim()) : null);
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

/// The first official alternative title (Simkl lists the original-language one first).
String? _firstOfficial(Object? alt) {
  if (alt is! List) return null;
  for (final a in alt) {
    if (a is Map && (a['type'] == null || a['type'] == 'official')) {
      final name = _text(a['name']);
      if (name != null) return name;
    }
  }
  return null;
}

/// One title of a Simkl discover or search answer (trending, premieres, airing, search).
@immutable
class SimklMedia {
  final int simklId;

  /// MyAnimeList id when the answer carries it (otherwise resolved on tap).
  final int? malId;
  final String? slug;
  final String title;
  final String? posterUrl;
  final int? year;
  final double? rating;
  final String? overview;
  final String? animeType;
  final List<String> genres;

  /// Feed answers (trending, best): users who watched the title, the share who dropped it
  /// (percent) and Simkl's rank, the way DailyAL cards show members and rank.
  final int? watchers;
  final double? dropRate;
  final int? rank;

  /// Background picture of the CDN feeds (`fanart`), null when Simkl has none.
  final String? fanartUrl;

  /// The streamer or channel (`network`) and the number of episodes of the whole title.
  final String? network;
  final int? totalEpisodes;

  /// The romanised and the original-script titles when the answer carries them; [title] is
  /// Simkl's default. See [retitled].
  final String? titleRomaji;
  final String? titleNative;

  /// Calendar answers: this episode ends the title (`finale_type` of the calendar file).
  final bool finale;

  /// Airing answers: the episode number and its air time.
  final int? episode;
  final DateTime? airDate;

  const SimklMedia({
    required this.simklId,
    this.malId,
    this.slug,
    required this.title,
    this.posterUrl,
    this.year,
    this.rating,
    this.overview,
    this.animeType,
    this.genres = const [],
    this.watchers,
    this.dropRate,
    this.rank,
    this.fanartUrl,
    this.network,
    this.totalEpisodes,
    this.titleRomaji,
    this.titleNative,
    this.finale = false,
    this.episode,
    this.airDate,
  });

  /// The same item titled for [lang] (the Simkl profile's title language).
  SimklMedia retitled(SimklTitleLanguage lang) {
    final next = SimklTitlePreference.pick(lang, title, romaji: titleRomaji, original: titleNative);
    if (next == title) return this;
    return SimklMedia(
      simklId: simklId,
      malId: malId,
      slug: slug,
      title: next,
      posterUrl: posterUrl,
      year: year,
      rating: rating,
      overview: overview,
      animeType: animeType,
      genres: genres,
      watchers: watchers,
      dropRate: dropRate,
      rank: rank,
      fanartUrl: fanartUrl,
      network: network,
      totalEpisodes: totalEpisodes,
      titleRomaji: titleRomaji,
      titleNative: titleNative,
      finale: finale,
      episode: episode,
      airDate: airDate,
    );
  }

  /// Null when the item has no Simkl id or no title.
  static SimklMedia? fromJson(Object? raw) {
    if (raw is! Map) return null;
    // Some answers wrap the title in `show`.
    final m = raw['show'] is Map ? {...raw, ...(raw['show'] as Map)} : raw;
    final ids = m['ids'] is Map ? m['ids'] as Map : const {};
    final id = _int(ids['simkl_id'] ?? ids['simkl'] ?? m['simkl_id'] ?? m['id']);
    final title = _text(m['title']) ?? _text(m['en_title']);
    if (id == null || title == null) return null;
    final ratings = m['ratings'];
    double? rating;
    if (ratings is Map) {
      for (final key in const ['simkl', 'mal', 'imdb']) {
        final r = ratings[key];
        final value = r is Map ? _double(r['rating']) : null;
        if (value != null && value > 0) {
          rating = value;
          break;
        }
      }
    }
    final date = _text(m['release_date']) ?? _text(m['date']);
    final episode = m['episode'];
    final genres = m['genres'];
    return SimklMedia(
      simklId: id,
      malId: _int(ids['mal']),
      slug: _text(ids['slug']),
      title: title,
      posterUrl: SimklImages.poster(m['poster']),
      year: _int(m['year']) ?? (date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null),
      rating: rating,
      overview: _text(m['overview']),
      animeType: _text(m['anime_type']),
      genres: genres is List ? [for (final g in genres) if (g is String && g.isNotEmpty) g] : const [],
      watchers: _int(m['watched']) ?? _int(m['watchers']),
      dropRate: _percent(m['drop_rate'] ?? m['droprate']),
      rank: _int(m['rank']),
      fanartUrl: SimklImages.fanart(m['fanart']),
      network: _text(m['network']),
      totalEpisodes: _int(m['total_episodes']),
      titleRomaji: _text(m['title_romaji']),
      titleNative: _firstOfficial(m['alt_titles']),
      finale: _text(m['finale_type']) != null,
      episode: episode is Map ? _int(episode['episode']) : _int(episode),
      airDate: DateTime.tryParse(_text(m['date']) ?? '')?.toUtc(),
    );
  }

  static List<SimklMedia> listFrom(Object? data) {
    final list = data is List
        ? data
        : data is Map
            ? (data['anime'] ?? data['results'] ?? data['items'])
            : null;
    if (list is! List) return const [];
    final seen = <int>{};
    return [
      for (final raw in list)
        if (fromJson(raw) case final item? when seen.add(item.simklId)) item,
    ];
  }
}

/// Parses `GET /sync/all-items/anime` into list entries (top level so `compute` can run it).
List<ListEntryView> parseSimklAnimeList(Object? data) {
  final list = data is Map ? data['anime'] : null;
  if (list is! List) return const [];
  final entries = <ListEntryView>[];
  for (final raw in list) {
    final entry = simklEntryFromJson(raw);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

/// One `anime` item of the user's list; null when it has no Simkl id or title.
ListEntryView? simklEntryFromJson(Object? raw) {
  if (raw is! Map) return null;
  final show = raw['show'];
  if (show is! Map) return null;
  final ids = show['ids'] is Map ? show['ids'] as Map : const {};
  final id = _int(ids['simkl'] ?? ids['simkl_id']);
  final title = _text(show['title']);
  if (id == null || title == null) return null;
  final total = _int(raw['total_episodes_count']) ?? 0;
  final notAired = _int(raw['not_aired_episodes_count']) ?? 0;
  final genres = show['genres'];
  final poster = SimklImages.poster(show['poster']);
  final type = _text(raw['anime_type']) ?? _text(show['anime_type']);
  final year = _int(show['year']);
  return ListEntryView(
    id: id,
    malId: _int(ids['mal']),
    category: 'anime',
    title: title,
    imageUrl: poster,
    largeImageUrl: poster,
    mediaType: type?.toLowerCase().replaceAll(' ', '_'),
    // Episodes not aired yet: the title is still airing.
    releaseState: notAired > 0
        ? ReleaseState.releasing
        : total > 0
            ? ReleaseState.finished
            : ReleaseState.unknown,
    total: total,
    genres: genres is List ? [for (final g in genres) if (g is String && g.isNotEmpty) g] : const [],
    releaseStart: year?.toString(),
    status: SimklStatus.parse(raw['status']),
    score: (_int(raw['user_rating']) ?? 0).clamp(0, 10),
    progress: _int(raw['watched_episodes_count']) ?? 0,
    updatedAt: DateTime.tryParse(_text(raw['last_watched_at']) ?? _text(raw['user_rated_at']) ?? '')?.toUtc(),
  );
}

/// What the profile shows, computed from the whole list (Simkl's stats endpoint needs the
/// account id and answers in minutes only).
@immutable
class SimklListStats {
  final Map<ListEntryStatus, int> byStatus;
  final int entries;
  final int episodesWatched;
  final double? meanScore;
  final int scored;

  /// Per score 1-10, the counts for [statusOrder].
  final Map<int, List<int>> scoreByStatus;
  final List<ListEntryView> recent;

  const SimklListStats({
    required this.byStatus,
    required this.entries,
    required this.episodesWatched,
    required this.meanScore,
    required this.scored,
    required this.scoreByStatus,
    required this.recent,
  });

  /// Chart slot order, shared with the MAL profile.
  static const statusOrder = [
    ListEntryStatus.current,
    ListEntryStatus.completed,
    ListEntryStatus.onHold,
    ListEntryStatus.dropped,
    ListEntryStatus.planned,
  ];

  static SimklListStats from(List<ListEntryView> list) {
    final byStatus = {for (final s in statusOrder) s: 0};
    final scoreByStatus = <int, List<int>>{};
    var episodes = 0;
    var scoreSum = 0;
    var scored = 0;
    for (final e in list) {
      final status = e.status;
      if (status != null) byStatus[status] = (byStatus[status] ?? 0) + 1;
      episodes += e.progress;
      if (e.score > 0) {
        scoreSum += e.score;
        scored++;
        final slot = status == null ? -1 : statusOrder.indexOf(status);
        if (slot >= 0) {
          scoreByStatus.putIfAbsent(e.score, () => List.filled(statusOrder.length, 0))[slot]++;
        }
      }
    }
    final recent = [...list.where((e) => e.updatedAt != null)]
      ..sort((a, b) => b.updatedAt!.compareTo(a.updatedAt!));
    return SimklListStats(
      byStatus: byStatus,
      entries: list.length,
      episodesWatched: episodes,
      meanScore: scored == 0 ? null : scoreSum / scored,
      scored: scored,
      scoreByStatus: scoreByStatus,
      recent: recent.take(10).toList(),
    );
  }
}
