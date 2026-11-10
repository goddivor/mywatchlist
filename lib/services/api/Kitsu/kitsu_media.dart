import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart' show Anime;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ReleaseState;

/// A decoded JSON:API document: the primary [data] resources and an index of the `included` ones.
class KitsuDocument {
  final List<Map<String, dynamic>> data;
  final Map<String, Map<String, dynamic>> included;
  final Map<String, dynamic> meta;
  final bool hasNext;

  const KitsuDocument(this.data, this.included, this.meta, this.hasNext);

  factory KitsuDocument.from(Map<String, dynamic> json) {
    final data = json['data'];
    final included = <String, Map<String, dynamic>>{};
    final inc = json['included'];
    if (inc is List) {
      for (final r in inc) {
        if (r is Map<String, dynamic>) included['${r['type']}:${r['id']}'] = r;
      }
    }
    final links = json['links'];
    final meta = json['meta'];
    return KitsuDocument(
      data is List
          ? [for (final r in data) if (r is Map<String, dynamic>) r]
          : data is Map<String, dynamic>
              ? [data]
              : const [],
      included,
      meta is Map<String, dynamic> ? meta : const {},
      links is Map && links['next'] is String,
    );
  }

  /// The included resource a to-one relationship of [resource] points at.
  Map<String, dynamic>? related(Map<String, dynamic> resource, String name) {
    final ref = _ref(resource, name);
    return ref == null ? null : included['${ref['type']}:${ref['id']}'];
  }

  /// The included resources a to-many relationship of [resource] points at.
  List<Map<String, dynamic>> relatedAll(Map<String, dynamic> resource, String name) {
    final rel = (resource['relationships'] as Map?)?[name];
    final refs = rel is Map ? rel['data'] : null;
    if (refs is! List) return const [];
    return [
      for (final r in refs)
        if (r is Map && included['${r['type']}:${r['id']}'] != null)
          included['${r['type']}:${r['id']}']!,
    ];
  }

  static Map? _ref(Map<String, dynamic> resource, String name) {
    final rel = (resource['relationships'] as Map?)?[name];
    final data = rel is Map ? rel['data'] : null;
    return data is Map ? data : null;
  }
}

Map<String, dynamic> kitsuAttrs(Map<String, dynamic> resource) {
  final a = resource['attributes'];
  return a is Map<String, dynamic> ? a : const {};
}

/// An anime or manga of the Kitsu catalogue, with its MyAnimeList id when Kitsu maps one.
///
/// The app's detail screens are MyAnimeList screens, so [malId] is what a tap opens.
@immutable
class KitsuMedia {
  final int id;
  final bool isAnime;
  final String title;
  final List<String> otherTitles;
  final String? posterUrl;
  final String? largePosterUrl;

  /// Kitsu's subtype (`TV`, `movie`, `OVA`… or `manga`, `novel`, `manhwa`…).
  final String? subtype;
  final ReleaseState releaseState;

  /// Mean score on 0-10 (Kitsu gives a percentage), null when nobody rated it.
  final double? meanScore;
  final int userCount;
  final int? popularityRank;
  final int? ratingRank;
  final int total;
  final int totalVolumes;
  final String? startDate;
  final String? endDate;
  final String? synopsis;
  final int? malId;

  const KitsuMedia({
    required this.id,
    required this.isAnime,
    required this.title,
    this.otherTitles = const [],
    this.posterUrl,
    this.largePosterUrl,
    this.subtype,
    this.releaseState = ReleaseState.unknown,
    this.meanScore,
    this.userCount = 0,
    this.popularityRank,
    this.ratingRank,
    this.total = 0,
    this.totalVolumes = 0,
    this.startDate,
    this.endDate,
    this.synopsis,
    this.malId,
  });

  String get category => isAnime ? 'anime' : 'manga';

  /// `titleLang` is a `TitleLang` name: `en`, `ja` or `ro`.
  factory KitsuMedia.fromResource(
    Map<String, dynamic> resource,
    KitsuDocument doc, {
    required String titleLang,
    bool? isAnime,
  }) {
    final a = kitsuAttrs(resource);
    final anime = isAnime ?? resource['type'] == 'anime';
    final titles = a['titles'] is Map ? a['titles'] as Map : const {};
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final canonical = text(a['canonicalTitle']);
    final en = text(titles['en']) ?? text(titles['en_us']);
    final romaji = text(titles['en_jp']);
    final ja = text(titles['ja_jp']);
    final title = switch (titleLang) {
          'en' => en ?? romaji,
          'ja' => ja ?? romaji,
          _ => romaji ?? en,
        } ??
        canonical ??
        '';
    final poster = a['posterImage'];
    String? pic(String key) => poster is Map ? text(poster[key]) : null;
    final rating = double.tryParse('${a['averageRating'] ?? ''}');
    int? intOrNull(Object? v) => v is num ? v.toInt() : null;

    final site = anime ? 'myanimelist/anime' : 'myanimelist/manga';
    int? malId;
    for (final m in doc.relatedAll(resource, 'mappings')) {
      final ma = kitsuAttrs(m);
      if (ma['externalSite'] == site) {
        malId = int.tryParse('${ma['externalId']}');
        if (malId != null) break;
      }
    }
    return KitsuMedia(
      id: int.tryParse('${resource['id']}') ?? 0,
      isAnime: anime,
      title: title,
      otherTitles: [
        for (final t in {canonical, en, romaji, ja, ...?_abbreviated(a['abbreviatedTitles'])})
          if (t != null && t != title) t,
      ],
      posterUrl: pic('small') ?? pic('medium') ?? pic('large'),
      largePosterUrl: pic('large') ?? pic('original') ?? pic('medium'),
      subtype: text(a['subtype']),
      releaseState: releaseStateOf(text(a['status'])),
      meanScore: rating == null || rating <= 0 ? null : rating / 10,
      userCount: intOrNull(a['userCount']) ?? 0,
      popularityRank: intOrNull(a['popularityRank']),
      ratingRank: intOrNull(a['ratingRank']),
      total: intOrNull(anime ? a['episodeCount'] : a['chapterCount']) ?? 0,
      totalVolumes: anime ? 0 : (intOrNull(a['volumeCount']) ?? 0),
      startDate: text(a['startDate']),
      endDate: text(a['endDate']),
      synopsis: text(a['synopsis']),
      malId: malId,
    );
  }

  static Iterable<String?>? _abbreviated(Object? v) =>
      v is List ? v.whereType<String>() : null;

  /// Kitsu's `status` (`current`, `finished`, `tba`, `unreleased`, `upcoming`).
  static ReleaseState releaseStateOf(String? status) => switch (status) {
        'current' => ReleaseState.releasing,
        'finished' => ReleaseState.finished,
        'tba' || 'unreleased' || 'upcoming' => ReleaseState.notYetReleased,
        _ => ReleaseState.unknown,
      };

  /// The MyAnimeList media type word of [subtype] (`tv`, `light_novel`…).
  String? get malMediaType {
    final s = subtype?.toLowerCase();
    if (s == null) return null;
    return switch (s) {
      'novel' => 'light_novel',
      'oneshot' => 'one_shot',
      'doujin' => 'doujinshi',
      'oel' => 'manga',
      _ => s,
    };
  }

  /// The MyAnimeList status word of [releaseState].
  String? get malStatus => switch (releaseState) {
        ReleaseState.releasing => isAnime ? 'currently_airing' : 'currently_publishing',
        ReleaseState.finished => isAnime ? 'finished_airing' : 'finished',
        ReleaseState.notYetReleased => isAnime ? 'not_yet_aired' : 'not_yet_published',
        _ => null,
      };

  /// The card model the home rows draw, keyed by the MAL id; null when Kitsu maps none.
  Anime? toAnime() {
    final mal = malId;
    if (mal == null) return null;
    return Anime(
      id: mal,
      title: title,
      imageUrl: largePosterUrl ?? posterUrl ?? '',
      score: meanScore ?? 0,
      members: userCount,
      rank: ratingRank,
      popularity: popularityRank,
      synopsis: synopsis,
      numEpisodes: isAnime ? total : null,
      numVolumes: isAnime || totalVolumes == 0 ? null : totalVolumes,
      startDate: startDate,
      endDate: endDate,
      mediaType: malMediaType,
      status: malStatus,
    );
  }
}
