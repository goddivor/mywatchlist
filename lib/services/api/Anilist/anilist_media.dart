import 'package:flutter/foundation.dart';

/// A title of AniList (anime or manga) as the discovery pages draw it: cover, titles, score
/// and the little a card needs. Built from [fields].
@immutable
class AnilistMedia {
  final int id;

  /// The MyAnimeList id (`idMal`), null when AniList has no link: the detail screen is
  /// MAL-based, so only linked titles open in the app.
  final int? malId;

  /// `anime` or `manga`.
  final String category;
  final String title;
  final String? altTitle;
  final String? coverUrl;
  final String? bannerUrl;

  /// 0-10, null when AniList has no score yet.
  final double? score;

  /// AniList `format` (`TV`, `MOVIE`, `MANGA`…) and `status` (`RELEASING`…), raw.
  final String? format;
  final String? status;
  final int? episodes;
  final int? chapters;
  final List<String> genres;
  final int? seasonYear;
  final int? popularity;

  /// The next episode to air and when (UTC), for releasing anime.
  final int? nextEpisode;
  final DateTime? nextAiringAt;

  const AnilistMedia({
    required this.id,
    this.malId,
    required this.category,
    required this.title,
    this.altTitle,
    this.coverUrl,
    this.bannerUrl,
    this.score,
    this.format,
    this.status,
    this.episodes,
    this.chapters,
    this.genres = const [],
    this.seasonYear,
    this.popularity,
    this.nextEpisode,
    this.nextAiringAt,
  });

  bool get isAnime => category == 'anime';

  /// This title as the card of an airing episode: [episode] shown as the next one.
  AnilistMedia withEpisode(int episode, DateTime at) => AnilistMedia(
        id: id,
        malId: malId,
        category: category,
        title: title,
        altTitle: altTitle,
        coverUrl: coverUrl,
        bannerUrl: bannerUrl,
        score: score,
        format: format,
        status: status,
        episodes: episodes,
        chapters: chapters,
        genres: genres,
        seasonYear: seasonYear,
        popularity: popularity,
        nextEpisode: episode,
        nextAiringAt: at,
      );

  /// Page of the title on anilist.co.
  String get url => 'https://anilist.co/$category/$id';

  /// GraphQL selection every discovery query uses.
  static const String fields = '''
    id idMal type format status episodes chapters genres seasonYear popularity averageScore isAdult
    title { romaji english native }
    coverImage { large extraLarge }
    bannerImage
    nextAiringEpisode { episode airingAt }
  ''';

  /// [titleLang] is a `TitleLang` name (`en`, `ja`, `ro`).
  factory AnilistMedia.fromJson(Map<String, dynamic> json, {String titleLang = 'ro'}) {
    String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final titles = json['title'];
    final romaji = titles is Map ? text(titles['romaji']) : null;
    final english = titles is Map ? text(titles['english']) : null;
    final native = titles is Map ? text(titles['native']) : null;
    final title = switch (titleLang) {
          'en' => english ?? romaji,
          'ja' => native ?? romaji,
          _ => romaji,
        } ??
        romaji ??
        english ??
        native ??
        '';
    final cover = json['coverImage'];
    final next = json['nextAiringEpisode'];
    final average = json['averageScore'];
    final airingAt = next is Map && next['airingAt'] is num
        ? DateTime.fromMillisecondsSinceEpoch((next['airingAt'] as num).toInt() * 1000,
            isUtc: true)
        : null;
    return AnilistMedia(
      id: (json['id'] as num?)?.toInt() ?? 0,
      malId: (json['idMal'] as num?)?.toInt(),
      category: json['type'] == 'MANGA' ? 'manga' : 'anime',
      title: title,
      altTitle: [english, romaji, native].firstWhere((t) => t != null && t != title, orElse: () => null),
      coverUrl: cover is Map ? text(cover['large']) ?? text(cover['extraLarge']) : null,
      bannerUrl: text(json['bannerImage']),
      score: average is num && average > 0 ? average / 10 : null,
      format: text(json['format']),
      status: text(json['status']),
      episodes: (json['episodes'] as num?)?.toInt(),
      chapters: (json['chapters'] as num?)?.toInt(),
      genres: [
        for (final g in (json['genres'] as List? ?? const []))
          if (g is String && g.isNotEmpty) g,
      ],
      seasonYear: (json['seasonYear'] as num?)?.toInt(),
      popularity: (json['popularity'] as num?)?.toInt(),
      nextEpisode: next is Map ? (next['episode'] as num?)?.toInt() : null,
      nextAiringAt: airingAt,
    );
  }
}

/// One page of media.
class AnilistMediaPage {
  final List<AnilistMedia> items;
  final bool hasNext;
  const AnilistMediaPage(this.items, {required this.hasNext});
}
