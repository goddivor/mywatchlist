import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_models.dart' show SimklImages;
import 'package:mywatchlist/services/api/SimKl/simkl_title_language.dart';

// Plain immutable data: everything here crosses isolates (parsed by `Isolate.run`).

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v.trim()) : null);
double? _double(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v.trim()) : null);
String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
List<Object?> _list(Object? v) => v is List ? v : const [];
Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

/// `"24%"` → 24.
double? parsePercent(Object? v) {
  if (v is num) return v.toDouble();
  final s = _text(v);
  if (s == null) return null;
  return double.tryParse(s.replaceAll('%', '').replaceAll(',', '.').trim());
}

/// Picture URLs of Simkl's paths (`"10/108215c95bbe0c40c"`); full URLs are kept.
abstract final class SimklMediaImages {
  /// Background picture (`fanart`), `_mobile` size.
  static String? fanart(Object? path) => _build('fanart', path, 'mobile');

  /// Episode still (`img` of `/anime/episodes`), `_w` size.
  static String? episode(Object? path) => _build('episodes', path, 'w');

  static String? poster(Object? path) => SimklImages.poster(path);

  static String? _build(String folder, Object? path, String size) {
    final p = _text(path);
    if (p == null) return null;
    if (p.startsWith('http')) return p;
    return 'https://simkl.in/$folder/${p}_$size.jpg';
  }
}

/// One rating source of a title (`ratings.simkl`, `ratings.mal`, `ratings.imdb`).
@immutable
class SimklRating {
  final double rating;
  final int? votes;

  const SimklRating(this.rating, this.votes);

  static SimklRating? fromJson(Object? raw) {
    final m = _map(raw);
    final r = _double(m['rating']);
    if (r == null || r <= 0) return null;
    return SimklRating(r, _int(m['votes']));
  }
}

/// Day, time and zone a title airs at (`airs`).
@immutable
class SimklAirs {
  final String? day;
  final String? time;
  final String? timezone;

  const SimklAirs({this.day, this.time, this.timezone});

  bool get isEmpty => day == null && time == null;

  static SimklAirs? fromJson(Object? raw) {
    final m = _map(raw);
    final a = SimklAirs(day: _text(m['day']), time: _text(m['time']), timezone: _text(m['timezone']));
    return a.isEmpty ? null : a;
  }
}

/// A YouTube trailer.
@immutable
class SimklTrailer {
  final String youtubeId;
  final String? name;

  const SimklTrailer(this.youtubeId, this.name);

  String get thumbnail => 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg';
  String get url => 'https://www.youtube.com/watch?v=$youtubeId';
}

/// Another title linked from the record: a relation, a users' recommendation or a similar title.
@immutable
class SimklLinkedTitle {
  final int simklId;
  final String? slug;
  final int? malId;
  final String title;
  final String? enTitle;
  final int? year;
  final String? posterUrl;
  final String? animeType;

  /// Relations only: `sequel`, `prequel`, `side_story`, `summary`…
  final String? relationType;

  /// Recommendations only: share of the users who recommended it (`users_percent`) and how many.
  final double? usersPercent;
  final int? usersCount;

  const SimklLinkedTitle({
    required this.simklId,
    required this.title,
    this.slug,
    this.malId,
    this.enTitle,
    this.year,
    this.posterUrl,
    this.animeType,
    this.relationType,
    this.usersPercent,
    this.usersCount,
  });

  static SimklLinkedTitle? fromJson(Object? raw) {
    final m = _map(raw);
    final ids = _map(m['ids']);
    final id = _int(ids['simkl']) ?? _int(ids['simkl_id']);
    final title = _text(m['title']);
    if (id == null || title == null) return null;
    return SimklLinkedTitle(
      simklId: id,
      slug: _text(ids['slug']),
      malId: _int(ids['mal']),
      title: title,
      enTitle: _text(m['en_title']),
      year: _int(m['year']),
      posterUrl: SimklMediaImages.poster(m['poster']),
      animeType: _text(m['anime_type']),
      relationType: _text(m['relation_type']),
      usersPercent: parsePercent(m['users_percent']),
      usersCount: _int(m['users_count']),
    );
  }

  static List<SimklLinkedTitle> listFrom(Object? raw) =>
      _list(raw).map(SimklLinkedTitle.fromJson).whereType<SimklLinkedTitle>().toList();
}

/// The full record of `GET /anime/{id}` (Simkl API, Cloudflare-cached, not counted).
@immutable
class SimklTitle {
  final int simklId;
  final String? slug;
  final int? malId;
  final String title;
  final String? enTitle;
  final int? year;
  final String? animeType;
  final String? posterUrl;
  final String? fanartUrl;
  final int? rank;
  final double? dropRate;
  final int? runtime;
  final String? certification;
  final String? country;
  final String? originalLanguage;
  final String? overview;
  final List<String> genres;
  final String? network;
  final String? status;
  final String? firstAired;
  final String? lastAired;
  final SimklAirs? airs;
  final int? totalEpisodes;
  final String? seasonNameYear;
  final List<String> studios;
  final List<String> altTitles;

  /// Every external id the record carries (`anilist`, `kitsu`, `imdb`, `tmdb`, `tvdb`, `anidb`,
  /// `mal`...), by key, as text; Simkl's own ids (`simkl`, `simkl_id`, `slug`) are left out.
  final Map<String, String> externalIds;
  final String? titleRomaji;
  final SimklRating? simklRating;
  final SimklRating? malRating;
  final SimklRating? imdbRating;
  final List<SimklTrailer> trailers;
  final List<SimklLinkedTitle> relations;
  final List<SimklLinkedTitle> recommendations;
  final List<SimklLinkedTitle> similar;

  const SimklTitle({
    required this.simklId,
    required this.title,
    this.slug,
    this.malId,
    this.enTitle,
    this.year,
    this.animeType,
    this.posterUrl,
    this.fanartUrl,
    this.rank,
    this.dropRate,
    this.runtime,
    this.certification,
    this.country,
    this.originalLanguage,
    this.overview,
    this.genres = const [],
    this.network,
    this.status,
    this.firstAired,
    this.lastAired,
    this.airs,
    this.totalEpisodes,
    this.seasonNameYear,
    this.studios = const [],
    this.altTitles = const [],
    this.externalIds = const {},
    this.titleRomaji,
    this.simklRating,
    this.malRating,
    this.imdbRating,
    this.trailers = const [],
    this.relations = const [],
    this.recommendations = const [],
    this.similar = const [],
  });

  /// Null for Simkl's `[]` (unknown id) or a record without id and title.
  static SimklTitle? fromJson(Object? raw, {int? fallbackId, SimklTitleLanguage? language}) {
    if (raw is! Map) return null;
    final m = raw.cast<String, Object?>();
    final ids = _map(m['ids']);
    final id = _int(ids['simkl']) ?? _int(ids['simkl_id']) ?? fallbackId;
    final title = _text(m['title']);
    if (id == null || title == null) return null;
    final ratings = _map(m['ratings']);
    final altNames = _list(m['alt_titles']).map((a) => a is Map ? _text(a['name']) : null).whereType<String>().toList();
    final romaji = _text(m['title_romaji']);
    return SimklTitle(
      simklId: id,
      slug: _text(ids['slug']),
      malId: _int(ids['mal']),
      title: SimklTitlePreference.pick(
        language ?? SimklTitlePreference.language,
        title,
        romaji: romaji,
        original: altNames.isEmpty ? null : altNames.first,
      ),
      titleRomaji: romaji,
      externalIds: {
        for (final e in ids.entries)
          if (!const {'simkl', 'simkl_id', 'slug'}.contains(e.key))
            if (_text(e.value is num ? '${e.value}' : e.value) case final v?) e.key: v,
      },
      enTitle: _text(m['en_title']),
      year: _int(m['year']),
      animeType: _text(m['anime_type']),
      posterUrl: SimklMediaImages.poster(m['poster']),
      fanartUrl: SimklMediaImages.fanart(m['fanart']),
      rank: _int(m['rank']),
      dropRate: parsePercent(m['droprate'] ?? m['drop_rate']),
      runtime: _int(m['runtime']),
      certification: _text(m['certification']),
      country: _text(m['country']),
      originalLanguage: _text(m['original_language']),
      overview: _text(m['overview']),
      genres: _list(m['genres']).map(_text).whereType<String>().toList(),
      network: _text(m['network']),
      status: _text(m['status']),
      firstAired: _text(m['first_aired']),
      lastAired: _text(m['last_aired']),
      airs: SimklAirs.fromJson(m['airs']),
      totalEpisodes: _int(m['total_episodes']),
      seasonNameYear: _text(m['season_name_year']),
      studios: _list(m['studios']).map((s) => s is Map ? _text(s['name']) : _text(s)).whereType<String>().toList(),
      altTitles: altNames,
      simklRating: SimklRating.fromJson(ratings['simkl']),
      malRating: SimklRating.fromJson(ratings['mal']),
      imdbRating: SimklRating.fromJson(ratings['imdb']),
      trailers: [
        for (final t in _list(m['trailers']))
          if (t is Map && _text(t['youtube']) != null) SimklTrailer(_text(t['youtube'])!, _text(t['name'])),
      ],
      relations: SimklLinkedTitle.listFrom(m['relations']),
      recommendations: SimklLinkedTitle.listFrom(m['users_recommendations']),
      similar: SimklLinkedTitle.listFrom(m['similar']),
    );
  }

  /// The public page of the title on simkl.com.
  String get pageUrl => SimklImages.page(simklId, slug);
}

/// One row of `GET /anime/episodes/{id}`.
@immutable
class SimklEpisode {
  final String title;
  final int? number;
  final bool isSpecial;
  final bool aired;
  final String? description;
  final String? imageUrl;
  final DateTime? date;
  final int? runtime;

  const SimklEpisode({
    required this.title,
    this.number,
    this.isSpecial = false,
    this.aired = true,
    this.description,
    this.imageUrl,
    this.date,
    this.runtime,
  });

  static SimklEpisode? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, Object?>();
    final number = _int(m['episode']);
    final title = _text(m['title']);
    if (title == null && number == null) return null;
    return SimklEpisode(
      title: title ?? '',
      number: number,
      isSpecial: m['type'] == 'special',
      aired: m['aired'] != false,
      description: _text(m['description']),
      imageUrl: SimklMediaImages.episode(m['img']),
      date: DateTime.tryParse(_text(m['date']) ?? ''),
      runtime: _int(m['runtime']),
    );
  }

  static List<SimklEpisode> listFrom(Object? raw) => _list(raw).map(SimklEpisode.fromJson).whereType<SimklEpisode>().toList();
}

// ---------------------------------------------------------------------------------------------
// Scraped from simkl.com (title page and its reviews / comments / memos sub-pages).
// A null section means its selector did not match: the page hides that section.

/// Watcher statuses of the distribution block.
enum SimklWatcherStatus { watching, planToWatch, completed, onHold, dropped }

/// One bar of the watcher distribution.
@immutable
class SimklWatcherBucket {
  final SimklWatcherStatus status;
  final int users;
  final double? percent;

  const SimklWatcherBucket(this.status, this.users, this.percent);
}

/// Watchers by status, with the total Simkl prints.
@immutable
class SimklWatchers {
  final List<SimklWatcherBucket> buckets;
  final int? total;

  const SimklWatchers(this.buckets, this.total);

  int get sum => buckets.fold(0, (a, b) => a + b.users);
}

/// Counters of the reactions tab bar (null = the tab was not on the page).
@immutable
class SimklCounters {
  final int? reactions;
  final int? reviews;
  final int? comments;
  final int? memos;

  const SimklCounters({this.reactions, this.reviews, this.comments, this.memos});

  bool get isEmpty => reactions == null && reviews == null && comments == null && memos == null;
}

enum SimklReviewTone { positive, neutral, negative }

/// "100% positive reviews, 6 positive, 0 neutral, 0 negative".
@immutable
class SimklReviewSummary {
  final double? positivePercent;
  final int positive;
  final int neutral;
  final int negative;

  const SimklReviewSummary({this.positivePercent, this.positive = 0, this.neutral = 0, this.negative = 0});

  int get total => positive + neutral + negative;
}

/// The sub-scores of a review (Story, Animation, Sound, Character, Enjoyment).
enum SimklReviewAspect { story, animation, sound, character, enjoyment }

@immutable
class SimklReview {
  final String author;
  final String? authorUrl;
  final String? avatarUrl;
  final String? date;
  final String? title;
  final String? url;
  final int? overall;
  final Map<SimklReviewAspect, int> scores;
  final SimklReviewTone? tone;

  /// The excerpt Simkl prints (paragraphs separated by blank lines, "read more" removed).
  final String text;
  final bool truncated;
  final int? helpful;
  final int? helpfulTotal;

  const SimklReview({
    required this.author,
    required this.text,
    this.authorUrl,
    this.avatarUrl,
    this.date,
    this.title,
    this.url,
    this.overall,
    this.scores = const {},
    this.tone,
    this.truncated = false,
    this.helpful,
    this.helpfulTotal,
  });
}

/// Reviews block: the summary (null when the page has no review yet) and the cards.
@immutable
class SimklReviews {
  final SimklReviewSummary? summary;
  final List<SimklReview> items;

  const SimklReviews(this.summary, this.items);
}

@immutable
class SimklComment {
  final String id;
  final String author;
  final String? authorUrl;
  final String? avatarUrl;
  final String text;

  /// Relative time Simkl prints ("2 years ago") and the exact one of its tooltip.
  final String? ago;
  final String? exactTime;
  final int likes;
  final bool spoiler;
  final bool vip;

  /// 0 for a top-level comment, 1+ for replies.
  final int depth;

  const SimklComment({
    required this.id,
    required this.author,
    required this.text,
    this.authorUrl,
    this.avatarUrl,
    this.ago,
    this.exactTime,
    this.likes = 0,
    this.spoiler = false,
    this.vip = false,
    this.depth = 0,
  });
}

@immutable
class SimklMemo {
  final String author;
  final String? authorUrl;
  final String text;
  final int likes;

  /// Rating bucket of its column ("memos with 6-10 stars ratings"): low and high bounds.
  final int? minStars;
  final int? maxStars;

  const SimklMemo({
    required this.author,
    required this.text,
    this.authorUrl,
    this.likes = 0,
    this.minStars,
    this.maxStars,
  });
}

/// An outside link of the About table (Crunchyroll, LiveChart, AniList…).
@immutable
class SimklLink {
  final String name;
  final String url;

  const SimklLink(this.name, this.url);
}

/// Everything read from the title page. Each field is null when its block was not found.
@immutable
class SimklTitlePage {
  final SimklWatchers? watchers;
  final SimklCounters? counters;
  final SimklReviews? reviews;
  final List<String>? tags;
  final List<SimklLink>? links;
  final List<String>? studios;
  final List<String>? producers;
  final List<String>? licensors;

  const SimklTitlePage({
    this.watchers,
    this.counters,
    this.reviews,
    this.tags,
    this.links,
    this.studios,
    this.producers,
    this.licensors,
  });

  static const empty = SimklTitlePage();
}

/// The pages of a title on other sites, from its external ids: AniList, Kitsu, MyAnimeList,
/// IMDb, TMDB, TVDB, AniDB, in that order; an id Simkl gives without a known page is left out.
List<({String name, String url})> simklExternalLinks(Map<String, String> ids, {String? animeType}) {
  final movie = animeType?.toLowerCase() == 'movie';
  String? id(String key) => ids[key];
  return [
    if (id('anilist') case final v?) (name: 'AniList', url: 'https://anilist.co/anime/$v'),
    if (id('kitsu') case final v?) (name: 'Kitsu', url: 'https://kitsu.app/anime/$v'),
    if (id('mal') case final v?) (name: 'MyAnimeList', url: 'https://myanimelist.net/anime/$v'),
    if (id('imdb') case final v?) (name: 'IMDb', url: 'https://www.imdb.com/title/$v/'),
    if (id('tmdb') case final v?) (name: 'TMDB', url: 'https://www.themoviedb.org/${movie ? 'movie' : 'tv'}/$v'),
    if (id('tvdb') case final v?) (name: 'TVDB', url: 'https://thetvdb.com/?tab=series&id=$v'),
    if (id('anidb') case final v?) (name: 'AniDB', url: 'https://anidb.net/anime/$v'),
  ];
}
