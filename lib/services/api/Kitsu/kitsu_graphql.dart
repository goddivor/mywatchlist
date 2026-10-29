import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';

/// Kitsu answered a GraphQL request with errors and nothing usable in `data`.
class KitsuGraphqlError implements Exception {
  final List<String> messages;
  const KitsuGraphqlError(this.messages);

  @override
  String toString() => 'KitsuGraphqlError(${messages.join('; ')})';
}

/// The decoded answer of one GraphQL request.
///
/// Kitsu answers `200` with both `data` and `errors` when one nullable branch fails (a reaction
/// whose author was deleted, a chapter without a canonical title). Those nodes come back as
/// `null` and are skipped by the parsers; [errors] keeps the messages for logging.
class KitsuGraphqlResponse {
  final Map<String, dynamic> data;
  final List<String> errors;
  const KitsuGraphqlResponse(this.data, this.errors);
}

/// Anime or manga.
enum KitsuMediaKind {
  anime('ANIME', 'Anime', 'anime'),
  manga('MANGA', 'Manga', 'manga');

  const KitsuMediaKind(this.graphql, this.typename, this.path);

  /// `MediaTypeEnum` value.
  final String graphql;

  /// `__typename` of the media.
  final String typename;

  /// JSON:API resource path.
  final String path;

  static KitsuMediaKind fromTypename(String? value) =>
      value == 'Manga' ? KitsuMediaKind.manga : KitsuMediaKind.anime;
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

double? _dbl(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

bool _bool(Object? v) => v == true;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

List<String> _strings(Object? v) =>
    v is List ? [for (final e in v) if (e is String) e] : const [];

/// First non-empty value of a locale map (`{"en": "..."}`), English first.
String? _localized(Object? v) {
  final m = _map(v);
  if (m == null) return null;
  final en = _str(m['en']);
  if (en != null) return en;
  for (final value in m.values) {
    final s = _str(value);
    if (s != null) return s;
  }
  return null;
}

/// The non-null `nodes` of a connection, each mapped by [parse] (a `null` result drops the node).
List<T> _mapNodes<T>(Object? connection, T? Function(Map<String, dynamic>) parse) {
  final nodes = _map(connection)?['nodes'];
  if (nodes is! List) return const [];
  final out = <T>[];
  for (final node in nodes) {
    final m = _map(node);
    if (m == null) continue;
    final parsed = parse(m);
    if (parsed != null) out.add(parsed);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

/// Arguments of one cursor page: `first` items after the opaque cursor [after].
class KitsuPageArgs {
  /// Kitsu requires `first` or `last` on every connection; this is the default page size.
  static const int defaultSize = 20;

  /// The most items Kitsu accepts in one connection page.
  static const int maxSize = 50;

  final int first;
  final String? after;

  const KitsuPageArgs({int first = defaultSize, this.after})
      : first = first < 1 ? 1 : (first > maxSize ? maxSize : first);

  Map<String, Object?> toVariables() => {'first': first, 'after': after};
}

/// One page of a GraphQL connection.
class KitsuConnection<T> {
  final List<T> nodes;

  /// Items in the whole connection, when Kitsu counted them.
  final int? totalCount;
  final bool hasNextPage;
  final String? endCursor;

  const KitsuConnection({
    this.nodes = const [],
    this.totalCount,
    this.hasNextPage = false,
    this.endCursor,
  });

  static const KitsuConnection<Never> empty = KitsuConnection<Never>();

  bool get isEmpty => nodes.isEmpty;

  /// Arguments of the following page, or `null` on the last one.
  KitsuPageArgs? nextPage({int first = KitsuPageArgs.defaultSize}) =>
      hasNextPage && endCursor != null ? KitsuPageArgs(first: first, after: endCursor) : null;

  /// Parses a connection object (`totalCount`, `pageInfo`, `nodes`); [json] may be `null`.
  static KitsuConnection<T> parse<T>(Object? json, T? Function(Map<String, dynamic>) parseNode) {
    final m = _map(json);
    if (m == null) return KitsuConnection<T>(nodes: const []);
    final info = _map(m['pageInfo']);
    return KitsuConnection<T>(
      nodes: _mapNodes(m, parseNode),
      totalCount: _int(m['totalCount']),
      hasNextPage: _bool(info?['hasNextPage']),
      endCursor: _str(info?['endCursor']),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared value types
// ---------------------------------------------------------------------------

class KitsuImage {
  final String url;
  final int? width;
  final int? height;
  const KitsuImage(this.url, {this.width, this.height});

  static KitsuImage? parse(Object? json) {
    final original = _map(_map(json)?['original']);
    final url = _str(original?['url']);
    if (url == null) return null;
    return KitsuImage(url, width: _int(original?['width']), height: _int(original?['height']));
  }
}

class KitsuTitles {
  final String? canonical;
  final String? romanized;
  final String? translated;
  final String? original;
  const KitsuTitles({this.canonical, this.romanized, this.translated, this.original});

  /// The best title to show: canonical, then romanized, translated, original.
  String get display => canonical ?? romanized ?? translated ?? original ?? '';

  static KitsuTitles parse(Object? json) {
    final m = _map(json);
    return KitsuTitles(
      canonical: _str(m?['canonical']),
      romanized: _str(m?['romanized']),
      translated: _str(m?['translated']),
      original: _str(m?['original']),
    );
  }
}

/// A Kitsu user as shown next to a post, a reaction or in a follower list.
class KitsuAuthor {
  final String id;
  final String name;
  final String? slug;
  final KitsuImage? avatar;
  const KitsuAuthor({required this.id, required this.name, this.slug, this.avatar});

  /// What goes in a `/users/<x>` path: the slug, else the id.
  String get handle => slug ?? id;

  static KitsuAuthor? parse(Object? json) {
    final m = _map(json);
    final id = _str(m?['id']);
    final name = _str(m?['name']);
    if (m == null || id == null || name == null) return null;
    return KitsuAuthor(
      id: id,
      name: name,
      slug: _str(m['slug']),
      avatar: KitsuImage.parse(m['avatarImage']),
    );
  }
}

/// A title in a list, a relation, a post header or a favourite.
class KitsuMediaRef {
  final KitsuMediaKind kind;
  final String id;
  final String? slug;
  final KitsuTitles titles;
  final KitsuImage? poster;
  const KitsuMediaRef({
    required this.kind,
    required this.id,
    this.slug,
    this.titles = const KitsuTitles(),
    this.poster,
  });

  static KitsuMediaRef? parse(Object? json) {
    final m = _map(json);
    final id = _str(m?['id']);
    final type = _str(m?['__typename']);
    if (m == null || id == null || (type != 'Anime' && type != 'Manga')) return null;
    return KitsuMediaRef(
      kind: KitsuMediaKind.fromTypename(type),
      id: id,
      slug: _str(m['slug']),
      titles: KitsuTitles.parse(m['titles']),
      poster: KitsuImage.parse(m['posterImage']),
    );
  }
}

// ---------------------------------------------------------------------------
// Media detail
// ---------------------------------------------------------------------------

class KitsuCategory {
  final String id;
  final String slug;
  final String title;
  const KitsuCategory({required this.id, required this.slug, required this.title});

  static KitsuCategory? parse(Map<String, dynamic> m) {
    final slug = _str(m['slug']);
    if (slug == null) return null;
    return KitsuCategory(id: _str(m['id']) ?? slug, slug: slug, title: _localized(m['title']) ?? slug);
  }
}

class KitsuMapping {
  /// `MYANIMELIST_ANIME`, `ANILIST_ANIME`, `ANIDB`, `THETVDB`, `TRAKT`...
  final String site;
  final String externalId;
  const KitsuMapping(this.site, this.externalId);

  static KitsuMapping? parse(Map<String, dynamic> m) {
    final site = _str(m['externalSite']);
    final id = _str(m['externalId']);
    return site == null || id == null ? null : KitsuMapping(site, id);
  }
}

class KitsuRelation {
  /// `SEQUEL`, `PREQUEL`, `SIDE_STORY`, `ADAPTATION`...
  final String kind;
  final KitsuMediaRef media;
  const KitsuRelation(this.kind, this.media);

  static KitsuRelation? parse(Map<String, dynamic> m) {
    final media = KitsuMediaRef.parse(m['destination']);
    return media == null ? null : KitsuRelation(_str(m['kind']) ?? 'OTHER', media);
  }
}

class KitsuStreamingLink {
  final String url;
  final String site;
  final List<String> subs;
  final List<String> dubs;
  final List<String> regions;
  const KitsuStreamingLink({
    required this.url,
    required this.site,
    this.subs = const [],
    this.dubs = const [],
    this.regions = const [],
  });

  static KitsuStreamingLink? parse(Map<String, dynamic> m) {
    final url = _str(m['url']);
    if (url == null) return null;
    return KitsuStreamingLink(
      url: url,
      site: _str(_map(m['streamer'])?['siteName']) ?? Uri.tryParse(url)?.host ?? url,
      subs: _strings(m['subs']),
      dubs: _strings(m['dubs']),
      regions: _strings(m['regions']),
    );
  }
}

/// An episode of an anime or a chapter / volume of a manga.
class KitsuUnit {
  final String id;
  final int number;
  final String? title;
  final String? description;
  final DateTime? releasedAt;

  /// Minutes (an anime episode's `length`).
  final int? length;
  final KitsuImage? thumbnail;
  const KitsuUnit({
    required this.id,
    required this.number,
    this.title,
    this.description,
    this.releasedAt,
    this.length,
    this.thumbnail,
  });

  static KitsuUnit? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final number = _int(m['number']);
    if (id == null || number == null) return null;
    return KitsuUnit(
      id: id,
      number: number,
      title: _str(_map(m['titles'])?['canonical']),
      description: _localized(m['description']),
      releasedAt: _date(m['releasedAt'] ?? m['published']),
      length: _int(m['length']),
      thumbnail: KitsuImage.parse(m['thumbnail']),
    );
  }
}

class KitsuReaction {
  final String id;
  final String text;

  /// Episode or chapter the author was at.
  final int progress;
  final DateTime? createdAt;
  final KitsuAuthor author;
  final int likes;

  /// Only filled by the profile reactions query.
  final KitsuMediaRef? media;
  const KitsuReaction({
    required this.id,
    required this.text,
    required this.progress,
    required this.author,
    this.createdAt,
    this.likes = 0,
    this.media,
  });

  static KitsuReaction? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final text = _str(m['reaction']);
    final author = KitsuAuthor.parse(m['author']);
    if (id == null || text == null || author == null) return null;
    return KitsuReaction(
      id: id,
      text: text,
      progress: _int(m['progress']) ?? 0,
      createdAt: _date(m['createdAt']),
      author: author,
      likes: _int(_map(m['likes'])?['totalCount']) ?? 0,
      media: KitsuMediaRef.parse(m['media']),
    );
  }
}

class KitsuPost {
  final String id;
  final String content;

  /// HTML, ready for a renderer.
  final String? contentHtml;
  final bool isSpoiler;
  final bool isNsfw;
  final DateTime? createdAt;
  final KitsuAuthor author;
  final int likes;
  final int comments;

  /// The title the post is about, when it is a media post.
  final KitsuMediaRef? media;
  const KitsuPost({
    required this.id,
    required this.content,
    required this.author,
    this.contentHtml,
    this.isSpoiler = false,
    this.isNsfw = false,
    this.createdAt,
    this.likes = 0,
    this.comments = 0,
    this.media,
  });

  static KitsuPost? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final author = KitsuAuthor.parse(m['author']);
    if (id == null || author == null) return null;
    return KitsuPost(
      id: id,
      content: _str(m['content']) ?? '',
      contentHtml: _str(m['contentFormatted']),
      isSpoiler: _bool(m['isSpoiler']),
      isNsfw: _bool(m['isNsfw']),
      createdAt: _date(m['createdAt']),
      author: author,
      likes: _int(_map(m['likes'])?['totalCount']) ?? 0,
      comments: _int(_map(m['comments'])?['totalCount']) ?? 0,
      media: KitsuMediaRef.parse(m['media']),
    );
  }
}

class KitsuComment {
  final String id;
  final String content;
  final String? contentHtml;
  final DateTime? createdAt;
  final KitsuAuthor author;
  final int likes;
  final int repliesCount;
  final List<KitsuComment> replies;
  const KitsuComment({
    required this.id,
    required this.content,
    required this.author,
    this.contentHtml,
    this.createdAt,
    this.likes = 0,
    this.repliesCount = 0,
    this.replies = const [],
  });

  static KitsuComment? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final author = KitsuAuthor.parse(m['author']);
    if (id == null || author == null) return null;
    final replies = _mapNodes(m['replies'], parse);
    return KitsuComment(
      id: id,
      content: _str(m['content']) ?? '',
      contentHtml: _str(m['contentFormatted']),
      createdAt: _date(m['createdAt']),
      author: author,
      likes: _int(_map(m['likes'])?['totalCount']) ?? 0,
      repliesCount: _int(_map(m['replies'])?['totalCount']) ?? replies.length,
      replies: replies,
    );
  }
}

class KitsuVoiceActor {
  final String id;
  final String name;
  final KitsuImage? image;
  const KitsuVoiceActor({required this.id, required this.name, this.image});
}

class KitsuCharacterRole {
  final String characterId;
  final String? characterSlug;
  final String name;
  final KitsuImage? image;

  /// `MAIN`, `RECURRING`, `BACKGROUND`, `CAMEO`.
  final String role;

  /// The voice actor for the language asked (Japanese by default), when Kitsu has one.
  final KitsuVoiceActor? voice;
  const KitsuCharacterRole({
    required this.characterId,
    required this.name,
    required this.role,
    this.characterSlug,
    this.image,
    this.voice,
  });

  static KitsuCharacterRole? parse(Map<String, dynamic> m) {
    final c = _map(m['character']);
    final id = _str(c?['id']);
    final name = _str(_map(c?['names'])?['canonical']);
    if (c == null || id == null || name == null) return null;
    final voices = _mapNodes(m['voices'], (v) {
      final p = _map(v['person']);
      final pid = _str(p?['id']);
      final pname = _str(p?['name']);
      return p == null || pid == null || pname == null
          ? null
          : KitsuVoiceActor(id: pid, name: pname, image: KitsuImage.parse(p['image']));
    });
    return KitsuCharacterRole(
      characterId: id,
      characterSlug: _str(c['slug']),
      name: name,
      image: KitsuImage.parse(c['image']),
      role: _str(m['role']) ?? 'BACKGROUND',
      voice: voices.isEmpty ? null : voices.first,
    );
  }
}

class KitsuStaffMember {
  final String personId;
  final String? personSlug;
  final String name;
  final KitsuImage? image;
  final String role;
  const KitsuStaffMember({
    required this.personId,
    required this.name,
    required this.role,
    this.personSlug,
    this.image,
  });

  static KitsuStaffMember? parse(Map<String, dynamic> m) {
    final p = _map(m['person']);
    final id = _str(p?['id']);
    final name = _str(p?['name']);
    if (p == null || id == null || name == null) return null;
    return KitsuStaffMember(
      personId: id,
      personSlug: _str(p['slug']),
      name: name,
      image: KitsuImage.parse(p['image']),
      role: _str(m['role']) ?? '',
    );
  }
}

class KitsuProduction {
  final String companyId;
  final String name;

  /// `PRODUCER`, `LICENSOR`, `STUDIO`, `SERIALIZATION`...
  final String role;
  const KitsuProduction({required this.companyId, required this.name, required this.role});

  static KitsuProduction? parse(Map<String, dynamic> m) {
    final c = _map(m['company']);
    final id = _str(c?['id']);
    final name = _str(c?['name']);
    return id == null || name == null
        ? null
        : KitsuProduction(companyId: id, name: name, role: _str(m['role']) ?? '');
  }
}

class KitsuQuote {
  final String id;
  final List<({String? character, String text})> lines;
  const KitsuQuote(this.id, this.lines);

  static KitsuQuote? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    if (id == null) return null;
    final lines = _mapNodes<({String? character, String text})>(m['lines'], (l) {
      final text = _str(l['content']);
      return text == null
          ? null
          : (character: _str(_map(_map(l['character'])?['names'])?['canonical']), text: text);
    });
    return KitsuQuote(id, lines);
  }
}

/// Everything the native Kitsu title page needs, from one request.
class KitsuMediaDetail {
  final KitsuMediaKind kind;
  final String id;
  final String slug;
  final KitsuTitles titles;
  final String? description;
  final KitsuImage? poster;
  final KitsuImage? banner;

  /// `CURRENT`, `FINISHED`, `TBA`, `UNRELEASED`, `UPCOMING`.
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// `G`, `PG`, `R`, `R18`.
  final String? ageRating;
  final String? ageRatingGuide;
  final bool sfw;

  /// Average rating out of 100.
  final double? averageRating;
  final int? averageRatingRank;
  final int? userCount;
  final int? userCountRank;
  final int? favoritesCount;
  final DateTime? nextRelease;
  final List<String> originCountries;
  final List<String> originLanguages;

  /// `TV`, `movie`, `OVA`, `manga`, `novel`...
  final String? subtype;

  /// Anime only.
  final String? season;
  final int? episodeCount;
  final int? episodeLength;
  final int? totalLength;
  final String? youtubeTrailerVideoId;
  final List<KitsuStreamingLink> streamingLinks;

  /// Manga only.
  final int? chapterCount;
  final int? volumeCount;
  final KitsuConnection<KitsuUnit> units;
  final List<KitsuUnit> volumes;
  final List<KitsuCategory> categories;
  final List<KitsuMapping> mappings;
  final List<KitsuRelation> relations;
  final KitsuConnection<KitsuReaction> reactions;
  final KitsuConnection<KitsuPost> posts;
  final KitsuConnection<KitsuCharacterRole> characters;
  final KitsuConnection<KitsuStaffMember> staff;
  final List<KitsuProduction> productions;
  final List<KitsuQuote> quotes;

  const KitsuMediaDetail({
    required this.kind,
    required this.id,
    required this.slug,
    required this.titles,
    this.description,
    this.poster,
    this.banner,
    this.status,
    this.startDate,
    this.endDate,
    this.ageRating,
    this.ageRatingGuide,
    this.sfw = true,
    this.averageRating,
    this.averageRatingRank,
    this.userCount,
    this.userCountRank,
    this.favoritesCount,
    this.nextRelease,
    this.originCountries = const [],
    this.originLanguages = const [],
    this.subtype,
    this.season,
    this.episodeCount,
    this.episodeLength,
    this.totalLength,
    this.youtubeTrailerVideoId,
    this.streamingLinks = const [],
    this.chapterCount,
    this.volumeCount,
    this.units = const KitsuConnection(),
    this.volumes = const [],
    this.categories = const [],
    this.mappings = const [],
    this.relations = const [],
    this.reactions = const KitsuConnection(),
    this.posts = const KitsuConnection(),
    this.characters = const KitsuConnection(),
    this.staff = const KitsuConnection(),
    this.productions = const [],
    this.quotes = const [],
  });

  /// The id this title has on [site] (`MYANIMELIST_ANIME`, `ANILIST_ANIME`...), if mapped.
  String? externalId(String site) {
    for (final m in mappings) {
      if (m.site == site) return m.externalId;
    }
    return null;
  }

  /// The MAL id, when Kitsu maps the title to MAL.
  int? get malId => int.tryParse(
      externalId(kind == KitsuMediaKind.anime ? 'MYANIMELIST_ANIME' : 'MYANIMELIST_MANGA') ?? '');

  /// The AniList id, when Kitsu maps the title to AniList.
  int? get anilistId => int.tryParse(
      externalId(kind == KitsuMediaKind.anime ? 'ANILIST_ANIME' : 'ANILIST_MANGA') ?? '');

  static KitsuMediaDetail? parse(Object? json) {
    final m = _map(json);
    final id = _str(m?['id']);
    final slug = _str(m?['slug']);
    if (m == null || id == null || slug == null) return null;
    final kind = KitsuMediaKind.fromTypename(_str(m['__typename']));
    final isAnime = kind == KitsuMediaKind.anime;
    return KitsuMediaDetail(
      kind: kind,
      id: id,
      slug: slug,
      titles: KitsuTitles.parse(m['titles']),
      description: _localized(m['description']),
      poster: KitsuImage.parse(m['posterImage']),
      banner: KitsuImage.parse(m['bannerImage']),
      status: _str(m['status']),
      startDate: _date(m['startDate']),
      endDate: _date(m['endDate']),
      ageRating: _str(m['ageRating']),
      ageRatingGuide: _str(m['ageRatingGuide']),
      sfw: m['sfw'] != false,
      averageRating: _dbl(m['averageRating']),
      averageRatingRank: _int(m['averageRatingRank']),
      userCount: _int(m['userCount']),
      userCountRank: _int(m['userCountRank']),
      favoritesCount: _int(m['favoritesCount']),
      nextRelease: _date(m['nextRelease']),
      originCountries: _strings(m['originCountries']),
      originLanguages: _strings(m['originLanguages']),
      subtype: _str(m['subtype']),
      season: _str(m['season']),
      episodeCount: _int(m['episodeCount']),
      episodeLength: _int(m['episodeLength']),
      totalLength: _int(m['totalLength']),
      youtubeTrailerVideoId: _str(m['youtubeTrailerVideoId']),
      streamingLinks: _mapNodes(m['streamingLinks'], KitsuStreamingLink.parse),
      chapterCount: _int(m['chapterCount']),
      volumeCount: _int(m['volumeCount']),
      units: KitsuConnection.parse(isAnime ? m['episodes'] : m['chapters'], KitsuUnit.parse),
      volumes: _mapNodes(m['volumes'], KitsuUnit.parse),
      categories: _mapNodes(m['categories'], KitsuCategory.parse),
      mappings: _mapNodes(m['mappings'], KitsuMapping.parse),
      relations: _mapNodes(m['relationships'], KitsuRelation.parse),
      reactions: KitsuConnection.parse(m['reactions'], KitsuReaction.parse),
      posts: KitsuConnection.parse(m['posts'], KitsuPost.parse),
      characters: KitsuConnection.parse(m['characters'], KitsuCharacterRole.parse),
      staff: KitsuConnection.parse(m['staff'], KitsuStaffMember.parse),
      productions: _mapNodes(m['productions'], KitsuProduction.parse),
      quotes: _mapNodes(m['quotes'], KitsuQuote.parse),
    );
  }
}

/// The rating histogram of a title: how many users gave each of the 2..20 steps (a Kitsu rating
/// is out of 20, half a MAL star each). Steps nobody used are absent from the map.
class KitsuRatingFrequencies {
  final Map<int, int> counts;
  const KitsuRatingFrequencies(this.counts);

  int get total => counts.values.fold(0, (a, b) => a + b);

  /// Count for [step] (2..20), 0 when nobody gave it.
  int operator [](int step) => counts[step] ?? 0;

  /// All 19 steps 2..20 in order, zeros included, ready for a bar chart.
  List<int> get steps => [for (var s = 2; s <= 20; s++) this[s]];

  /// The histogram folded into [buckets] bars of a user's rating system, worst first: 4 (Simple:
  /// steps 2-5, 6-11, 12-16, 17-20, the faces of `KitsuRating.simpleIndex`), 10 (Regular: whole
  /// stars, an odd step goes to the lower half star) or 19 (Advanced: unchanged). Any other
  /// count gives the 19 steps.
  List<int> rebucket(int buckets) {
    if (buckets != 4 && buckets != 10) return steps;
    final out = List<int>.filled(buckets, 0);
    counts.forEach((step, count) {
      if (step < 2 || step > 20) return;
      final i = buckets == 10
          ? (step ~/ 2) - 1
          : step <= 5
              ? 0
              : step <= 11
                  ? 1
                  : step <= 16
                      ? 2
                      : 3;
      out[i] += count;
    });
    return out;
  }

  static KitsuRatingFrequencies parse(Map<String, dynamic> document) {
    final raw = _map(_map(_map(document['data'])?['attributes'])?['ratingFrequencies']);
    final counts = <int, int>{};
    raw?.forEach((key, value) {
      final step = int.tryParse(key);
      final count = _int(value);
      if (step != null && count != null && count > 0) counts[step] = count;
    });
    return KitsuRatingFrequencies(counts);
  }
}

/// A post and the first page of its comments.
class KitsuPostThread {
  final KitsuPost post;
  final KitsuConnection<KitsuComment> comments;
  const KitsuPostThread(this.post, this.comments);
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

class KitsuSiteLink {
  final String site;
  final String url;
  const KitsuSiteLink(this.site, this.url);
}

class KitsuProfileSummary {
  final String id;
  final String name;
  final String? slug;
  final String? about;
  final String? location;
  final String? gender;
  final DateTime? birthday;
  final DateTime? createdAt;
  final String? url;

  /// `AO_PRO`, `PRO`... when the user is a patron.
  final String? proTier;
  final String? proMessage;
  final KitsuImage? avatar;
  final KitsuImage? banner;
  final KitsuPost? pinnedPost;
  final List<KitsuSiteLink> siteLinks;
  final int followers;
  final int following;
  final int posts;
  final int comments;
  final int reactions;
  final int activity;

  /// The favourite character the user set (`waifuOrHusbando` says which word to use).
  final String? waifuName;
  final KitsuImage? waifuImage;
  final String? waifuOrHusbando;
  const KitsuProfileSummary({
    required this.id,
    required this.name,
    this.slug,
    this.about,
    this.location,
    this.gender,
    this.birthday,
    this.createdAt,
    this.url,
    this.proTier,
    this.proMessage,
    this.avatar,
    this.banner,
    this.pinnedPost,
    this.siteLinks = const [],
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.comments = 0,
    this.reactions = 0,
    this.activity = 0,
    this.waifuName,
    this.waifuImage,
    this.waifuOrHusbando,
  });

  static KitsuProfileSummary? parse(Object? json) {
    final m = _map(json);
    final id = _str(m?['id']);
    final name = _str(m?['name']);
    if (m == null || id == null || name == null) return null;
    int count(String key) => _int(_map(m[key])?['totalCount']) ?? 0;
    final waifu = _map(m['waifu']);
    final pinned = _map(m['pinnedPost']);
    return KitsuProfileSummary(
      id: id,
      name: name,
      slug: _str(m['slug']),
      about: _str(m['about']),
      location: _str(m['location']),
      gender: _str(m['gender']),
      birthday: _date(m['birthday']),
      createdAt: _date(m['createdAt']),
      url: _str(m['url']),
      proTier: _str(m['proTier']),
      proMessage: _str(m['proMessage']),
      avatar: KitsuImage.parse(m['avatarImage']),
      banner: KitsuImage.parse(m['bannerImage']),
      pinnedPost: pinned == null ? null : KitsuPost.parse(pinned),
      siteLinks: _mapNodes(m['siteLinks'], (l) {
        final url = _str(l['url']);
        return url == null ? null : KitsuSiteLink(_str(_map(l['site'])?['name']) ?? '', url);
      }),
      followers: count('followers'),
      following: count('following'),
      posts: count('posts'),
      comments: count('comments'),
      reactions: count('mediaReactions'),
      activity: count('libraryEvents'),
      waifuName: _str(_map(waifu?['names'])?['canonical']),
      waifuImage: KitsuImage.parse(waifu?['image']),
      waifuOrHusbando: _str(m['waifuOrHusbando']),
    );
  }
}

/// One line of the activity history.
class KitsuLibraryEvent {
  final String id;

  /// `PROGRESSED`, `UPDATED`, `REACTED`, `RATED`, `ANNOTATED`.
  final String kind;
  final DateTime? createdAt;
  final KitsuMediaRef media;

  /// Field name to `[old, new]`, e.g. `status: [current, planned]`, `progress: [3, 4]`.
  final Map<String, List<Object?>> changes;
  const KitsuLibraryEvent({
    required this.id,
    required this.kind,
    required this.media,
    this.createdAt,
    this.changes = const {},
  });

  /// The new value of [field], if the event changed it.
  Object? changedTo(String field) {
    final change = changes[field];
    return change == null || change.length < 2 ? null : change[1];
  }

  static KitsuLibraryEvent? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final media = KitsuMediaRef.parse(m['media']);
    if (id == null || media == null) return null;
    final changes = <String, List<Object?>>{};
    _map(m['changedData'])?.forEach((key, value) {
      if (value is List) changes[key] = List<Object?>.from(value);
    });
    return KitsuLibraryEvent(
      id: id,
      kind: _str(m['kind']) ?? 'UPDATED',
      media: media,
      createdAt: _date(m['createdAt']),
      changes: changes,
    );
  }
}

/// A favourite: a title, a character or a person.
class KitsuFavourite {
  final String id;

  /// `Anime`, `Manga`, `Character` or `Person`.
  final String type;
  final String itemId;
  final String? slug;
  final String name;
  final KitsuImage? image;
  const KitsuFavourite({
    required this.id,
    required this.type,
    required this.itemId,
    required this.name,
    this.slug,
    this.image,
  });

  static KitsuFavourite? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final item = _map(m['item']);
    final type = _str(item?['__typename']);
    final itemId = _str(item?['id']);
    if (id == null || item == null || type == null || itemId == null) return null;
    final name = switch (type) {
      'Character' => _str(_map(item['names'])?['canonical']),
      'Person' => _str(item['name']),
      _ => _str(_map(item['titles'])?['canonical']),
    };
    if (name == null) return null;
    return KitsuFavourite(
      id: id,
      type: type,
      itemId: itemId,
      slug: _str(item['slug']),
      name: name,
      image: KitsuImage.parse(type == 'Anime' || type == 'Manga' ? item['posterImage'] : item['image']),
    );
  }
}

/// A line of another user's public library.
class KitsuLibraryItem {
  final String id;

  /// `CURRENT`, `PLANNED`, `COMPLETED`, `ON_HOLD`, `DROPPED`.
  final String status;
  final int progress;

  /// Out of 20, `null` when unrated.
  final int? rating;
  final KitsuMediaRef media;
  const KitsuLibraryItem({
    required this.id,
    required this.status,
    required this.progress,
    required this.media,
    this.rating,
  });

  static KitsuLibraryItem? parse(Map<String, dynamic> m) {
    final id = _str(m['id']);
    final media = KitsuMediaRef.parse(m['media']);
    if (id == null || media == null) return null;
    return KitsuLibraryItem(
      id: id,
      status: _str(m['status']) ?? 'CURRENT',
      progress: _int(m['progress']) ?? 0,
      rating: _int(m['rating']),
      media: media,
    );
  }
}

// ---------------------------------------------------------------------------
// Feeds and groups (JSON:API: GraphQL has no feed or group types)
// ---------------------------------------------------------------------------

/// What an activity of a feed is about.
enum KitsuFeedVerb { post, comment, mediaReaction, other }

class KitsuFeedItem {
  final String activityId;
  final KitsuFeedVerb verb;
  final DateTime? time;

  /// `Post:9920640`, `Comment:32229746`, `MediaReaction:365465`.
  final String foreignId;

  /// The numeric id after the colon.
  final String subjectId;

  /// Episode / chapter reached, for reactions.
  final int? progress;

  /// Set when the feed document included the subject (always for posts and comments).
  final KitsuFeedPost? post;
  final KitsuFeedComment? comment;
  const KitsuFeedItem({
    required this.activityId,
    required this.verb,
    required this.foreignId,
    required this.subjectId,
    this.time,
    this.progress,
    this.post,
    this.comment,
  });
}

/// A user as found in a feed document.
class KitsuFeedUser {
  final String id;
  final String name;
  final String? slug;
  final String? avatarUrl;
  const KitsuFeedUser({required this.id, required this.name, this.slug, this.avatarUrl});
}

class KitsuFeedPost {
  final String id;
  final String content;
  final String? contentHtml;
  final bool isSpoiler;
  final bool isNsfw;
  final DateTime? createdAt;
  final int commentsCount;
  final int likesCount;
  final KitsuFeedUser? user;
  const KitsuFeedPost({
    required this.id,
    required this.content,
    this.contentHtml,
    this.isSpoiler = false,
    this.isNsfw = false,
    this.createdAt,
    this.commentsCount = 0,
    this.likesCount = 0,
    this.user,
  });
}

class KitsuFeedComment {
  final String id;
  final String content;
  final String? contentHtml;
  final DateTime? createdAt;
  final KitsuFeedUser? user;
  const KitsuFeedComment({
    required this.id,
    required this.content,
    this.contentHtml,
    this.createdAt,
    this.user,
  });
}

/// One page of a feed; [nextCursor] feeds the next call.
class KitsuFeedPage {
  final List<KitsuFeedItem> items;
  final String? nextCursor;
  const KitsuFeedPage(this.items, this.nextCursor);

  bool get hasMore => nextCursor != null;

  static String? cursorOf(Map<String, dynamic> document) {
    final next = _str(_map(document['links'])?['next']);
    if (next == null) return null;
    return Uri.tryParse(next)?.queryParameters['page[cursor]'];
  }

  static KitsuFeedPage parse(Map<String, dynamic> document) {
    final included = <String, Map<String, dynamic>>{};
    final data = document['data'];
    final included0 = document['included'];
    if (included0 is List) {
      for (final e in included0) {
        final m = _map(e);
        if (m == null) continue;
        included['${m['type']}:${m['id']}'] = m;
      }
    }

    KitsuFeedUser? user(Map<String, dynamic> resource) {
      final ref = _map(_map(_map(resource['relationships'])?['user'])?['data']);
      final u = included['users:${ref?['id']}'];
      final attributes = _map(u?['attributes']);
      final name = _str(attributes?['name']);
      if (u == null || name == null) return null;
      return KitsuFeedUser(
        id: _str(u['id']) ?? '',
        name: name,
        slug: _str(attributes?['slug']),
        avatarUrl: _str(_map(attributes?['avatar'])?['original']),
      );
    }

    // Activities sit in `included`; the activity groups (`data`) only order them.
    final order = <String>[];
    if (data is List) {
      for (final g in data) {
        final refs = _map(_map(_map(g)?['relationships'])?['activities'])?['data'];
        if (refs is List) {
          for (final r in refs) {
            final id = _str(_map(r)?['id']);
            if (id != null) order.add(id);
          }
        }
      }
    }

    final items = <KitsuFeedItem>[];
    for (final id in order) {
      final a = included['activities:$id'];
      final attributes = _map(a?['attributes']);
      final foreignId = _str(attributes?['foreignId']);
      if (a == null || attributes == null || foreignId == null) continue;
      final colon = foreignId.indexOf(':');
      final subjectId = colon < 0 ? foreignId : foreignId.substring(colon + 1);
      final verb = switch (_str(attributes['verb'])) {
        'post' => KitsuFeedVerb.post,
        'comment' => KitsuFeedVerb.comment,
        'media_reaction' => KitsuFeedVerb.mediaReaction,
        _ => KitsuFeedVerb.other,
      };
      KitsuFeedPost? post;
      KitsuFeedComment? comment;
      if (verb == KitsuFeedVerb.post) {
        final p = included['posts:$subjectId'];
        final pa = _map(p?['attributes']);
        if (p != null && pa != null) {
          post = KitsuFeedPost(
            id: subjectId,
            content: _str(pa['content']) ?? '',
            contentHtml: _str(pa['contentFormatted']),
            isSpoiler: _bool(pa['spoiler']),
            isNsfw: _bool(pa['nsfw']),
            createdAt: _date(pa['createdAt']),
            commentsCount: _int(pa['commentsCount']) ?? 0,
            likesCount: _int(pa['postLikesCount']) ?? 0,
            user: user(p),
          );
        }
      } else if (verb == KitsuFeedVerb.comment) {
        final c = included['comments:$subjectId'];
        final ca = _map(c?['attributes']);
        if (c != null && ca != null) {
          comment = KitsuFeedComment(
            id: subjectId,
            content: _str(ca['content']) ?? '',
            contentHtml: _str(ca['contentFormatted']),
            createdAt: _date(ca['createdAt']),
            user: user(c),
          );
        }
      }
      items.add(KitsuFeedItem(
        activityId: id,
        verb: verb,
        foreignId: foreignId,
        subjectId: subjectId,
        time: _date(attributes['time']),
        progress: _int(attributes['progress']),
        post: post,
        comment: comment,
      ));
    }
    return KitsuFeedPage(items, cursorOf(document));
  }
}

class KitsuGroup {
  final String id;
  final String name;
  final String? slug;
  final String? tagline;
  final int membersCount;
  final DateTime? lastActivityAt;
  final bool nsfw;
  final String? avatarUrl;
  const KitsuGroup({
    required this.id,
    required this.name,
    this.slug,
    this.tagline,
    this.membersCount = 0,
    this.lastActivityAt,
    this.nsfw = false,
    this.avatarUrl,
  });

  static KitsuGroup? parse(Map<String, dynamic> resource) {
    final id = _str(resource['id']);
    final a = _map(resource['attributes']);
    final name = _str(a?['name']);
    if (id == null || a == null || name == null) return null;
    return KitsuGroup(
      id: id,
      name: name,
      slug: _str(a['slug']),
      tagline: _str(a['tagline']),
      membersCount: _int(a['membersCount']) ?? 0,
      lastActivityAt: _date(a['lastActivityAt']),
      nsfw: _bool(a['nsfw']),
      avatarUrl: _str(_map(a['avatar'])?['medium']) ?? _str(_map(a['avatar'])?['original']),
    );
  }
}

class KitsuGroupPage {
  final List<KitsuGroup> groups;
  final int? total;

  /// Offset of the next page (`page[offset]`), `null` on the last one.
  final int? nextOffset;
  const KitsuGroupPage(this.groups, this.total, this.nextOffset);
}

// ---------------------------------------------------------------------------
// The client
// ---------------------------------------------------------------------------

/// The one place that talks to the Kitsu GraphQL API.
///
/// Anonymous requests cover everything public (titles, posts, public profiles). Pass
/// `auth: true` to send the user's token through `UserKitsuV2.sendAuthenticated`, which refreshes
/// an expiring token and replays once after a 401: no call builds its own Bearer header. Feeds,
/// groups and the rating histogram are not in the GraphQL schema, so they go through [KitsuHttp]
/// (JSON:API). Reads are the default; the library and favourite mutations of the signed-in user
/// (`KitsuMyLibrary`) go through `execute(auth: true)`, only on the viewer's tap.
class KitsuGraphql {
  KitsuGraphql({KitsuAuthSender? auth, http.Client? client, KitsuHttp? rest})
      : _authOverride = auth,
        _public = client,
        _restOverride = rest;

  /// Replaced by tests.
  static KitsuGraphql instance = KitsuGraphql();

  /// `kitsu.io` answers anonymous scripts; `kitsu.app/api/graphql` answers 403 to them (checked
  /// 2026-10-28), so the app keeps the host of `Constants.kitsuApiUrl`.
  static const String endpoint = 'https://kitsu.io/api/graphql';

  final KitsuAuthSender? _authOverride;
  final http.Client? _public;
  final KitsuHttp? _restOverride;

  KitsuAuthSender get _auth => _authOverride ?? UserKitsuV2.instance.sendAuthenticated;
  KitsuHttp get _rest => _restOverride ?? KitsuHttp.instance;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // -- transport ------------------------------------------------------------

  /// Runs one GraphQL [document] and returns its `data` plus the partial errors.
  ///
  /// Throws [KitsuHttpError] on a non-2xx status, [KitsuSessionExpired] when a signed-in call has
  /// no valid token (or Kitsu answers 401), and [KitsuGraphqlError] when the answer carries errors
  /// and no data at all. Partial errors (a `null` node) are returned in
  /// [KitsuGraphqlResponse.errors] with the rest of the data.
  Future<KitsuGraphqlResponse> execute(
    String document, {
    Map<String, Object?>? variables,
    bool auth = false,
  }) async {
    final body = jsonEncode({'query': document, if (variables != null) 'variables': variables});
    final url = Uri.parse(endpoint);
    final http.Response response;
    if (auth) {
      final sent = await _auth((client, token) => client.post(url,
          headers: {..._headers, 'Authorization': 'Bearer $token'}, body: body));
      if (sent == null || sent.statusCode == 401) throw const KitsuSessionExpired();
      response = sent;
    } else {
      final client = _public;
      response = await (client == null
              ? http.post(url, headers: _headers, body: body)
              : client.post(url, headers: _headers, body: body))
          .timeout(const Duration(seconds: 30));
    }
    return decode(response, auth: auth);
  }

  /// Decodes an HTTP answer to a [KitsuGraphqlResponse] (see [execute] for what it throws).
  @visibleForTesting
  Future<KitsuGraphqlResponse> decode(http.Response response, {bool auth = false}) async {
    if (response.statusCode == 401) throw const KitsuSessionExpired();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw KitsuHttpError(response.statusCode);
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final Map<String, dynamic> json;
    if (text.isEmpty) {
      json = const {};
    } else {
      json = text.length > 32 * 1024 ? await compute(_decodeBody, text) : _decodeBody(text);
    }
    final data = _map(json['data']);
    final errors = <String>[];
    var unauthenticated = false;
    final rawErrors = json['errors'];
    if (rawErrors is List) {
      for (final e in rawErrors) {
        final m = _map(e);
        errors.add(_str(m?['message']) ?? 'unknown error');
        final code = _str(_map(m?['extensions'])?['code'])?.toLowerCase() ?? '';
        if (code.contains('unauthenticated') || code.contains('unauthorized')) {
          unauthenticated = true;
        }
      }
    }
    if (errors.isNotEmpty && unauthenticated && auth) throw const KitsuSessionExpired();
    final hasData = data != null && data.values.any((v) => v != null);
    if (!hasData && errors.isNotEmpty) throw KitsuGraphqlError(errors);
    return KitsuGraphqlResponse(data ?? const {}, errors);
  }

  // -- documents ------------------------------------------------------------

  static const String _image = 'original { url width height }';
  static const String _author = 'id name slug avatarImage { $_image }';
  static const String _mediaCard = '__typename id slug titles { canonical } posterImage { $_image }';
  static const String _pageInfo = 'pageInfo { hasNextPage endCursor }';
  static const String _total = 'totalCount';

  static const String _postFields = '''
id content contentFormatted isSpoiler isNsfw createdAt
author { $_author }
media { $_mediaCard }
likes(first: 1) { totalCount }
comments(first: 1) { totalCount }''';

  static const String _reactionFields = '''
id reaction progress createdAt
author { $_author }
likes(first: 1) { totalCount }''';

  static const String _characterFields = '''
role
character { id slug names { canonical } image { $_image } }
voices(first: 1, locale: "ja_jp") { nodes { person { id name image { $_image } } } }''';

  static const String _staffFields = 'role person { id slug name image { $_image } }';

  static const String _unitFields =
      'id number titles { canonical } description(locales: ["en"]) releasedAt length thumbnail { $_image }';

  static const String _chapterFields = 'id number releasedAt thumbnail { $_image }';

  /// The query of [mediaDetail]: [bySlug] picks `findXBySlug` over `findXById`.
  @visibleForTesting
  static String mediaDetailDocument(KitsuMediaKind kind, {required bool bySlug}) {
    final anime = kind == KitsuMediaKind.anime;
    final root = '${anime ? 'findAnime' : 'findManga'}${bySlug ? 'BySlug' : 'ById'}';
    final arg = bySlug ? r'slug: $key' : r'id: $key';
    final keyType = bySlug ? 'String!' : 'ID!';
    final specific = anime
        ? '''
subtype season episodeCount episodeLength totalLength youtubeTrailerVideoId
streamingLinks(first: 20) { nodes { url subs dubs regions streamer { siteName } } }
episodes(first: \$units) { $_total $_pageInfo nodes { $_unitFields } }'''
        : '''
subtype chapterCount volumeCount
chapters(first: \$units) { $_total $_pageInfo nodes { $_chapterFields } }
volumes(first: 30) { $_total nodes { id number published thumbnail { $_image } } }''';
    return '''
query MediaDetail(\$key: $keyType, \$units: Int!) {
  $root($arg) {
    __typename id slug
    titles { canonical romanized translated original }
    description(locales: ["en"])
    posterImage { $_image }
    bannerImage { $_image }
    status startDate endDate ageRating ageRatingGuide sfw
    averageRating averageRatingRank userCount userCountRank favoritesCount
    nextRelease originCountries originLanguages
    categories(first: 20) { nodes { id slug title(locales: ["en"]) } }
    mappings(first: 30) { nodes { externalSite externalId } }
    relationships(first: 30) { nodes { kind destination { $_mediaCard } } }
    reactions(first: 6, sort: [{ on: UP_VOTES_COUNT, direction: DESCENDING }]) {
      $_total nodes { $_reactionFields }
    }
    posts(first: 5, sort: [{ on: CREATED_AT, direction: DESCENDING }]) {
      $_total nodes { $_postFields }
    }
    characters(first: 12, sort: [{ on: ROLE, direction: ASCENDING }]) {
      $_total nodes { $_characterFields }
    }
    staff(first: 12) { $_total nodes { $_staffFields } }
    productions(first: 12) { nodes { role company { id name } } }
    quotes(first: 5) { nodes { id lines(first: 5) { nodes { content character { names { canonical } } } } } }
    $specific
  }
}''';
  }

  /// A paged connection of a title, through the `Media` interface (anime and manga alike).
  static String _mediaConnection(String field, String args, String nodeFields, {bool total = true}) =>
      '''
query MediaConnection(\$id: ID!, \$type: MediaTypeEnum!, \$first: Int!, \$after: String) {
  findMediaByIdAndType(id: \$id, mediaType: \$type) {
    $field(first: \$first, after: \$after$args) { ${total ? '$_total ' : ''}$_pageInfo nodes { $nodeFields } }
  }
}''';

  @visibleForTesting
  static final String mediaReactionsDocument = _mediaConnection(
      'reactions', ', sort: [{ on: UP_VOTES_COUNT, direction: DESCENDING }]', _reactionFields);
  @visibleForTesting
  static final String mediaPostsDocument = _mediaConnection(
      'posts', ', sort: [{ on: CREATED_AT, direction: DESCENDING }]', _postFields);
  @visibleForTesting
  static final String mediaCharactersDocument = _mediaConnection(
      'characters', ', sort: [{ on: ROLE, direction: ASCENDING }]', _characterFields);
  @visibleForTesting
  static final String mediaStaffDocument = _mediaConnection('staff', '', _staffFields);

  @visibleForTesting
  static String unitsDocument(KitsuMediaKind kind) {
    final anime = kind == KitsuMediaKind.anime;
    final root = anime ? 'findAnimeById' : 'findMangaById';
    final field = anime ? 'episodes' : 'chapters';
    return '''
query MediaUnits(\$id: ID!, \$first: Int!, \$after: String) {
  $root(id: \$id) {
    $field(first: \$first, after: \$after) { $_total $_pageInfo nodes { ${anime ? _unitFields : _chapterFields} } }
  }
}''';
  }

  @visibleForTesting
  static const String postDocument = '''
query Post(\$id: ID!, \$first: Int!, \$after: String) {
  findPostById(id: \$id) {
    $_postFields
    thread: comments(first: \$first, after: \$after, sort: [{ on: CREATED_AT, direction: ASCENDING }]) {
      $_total $_pageInfo
      nodes {
        id content contentFormatted createdAt
        author { $_author }
        likes(first: 1) { totalCount }
        replies(first: 5, sort: [{ on: CREATED_AT, direction: ASCENDING }]) {
          $_total
          nodes { id content contentFormatted createdAt author { $_author } likes(first: 1) { totalCount } }
        }
      }
    }
  }
}''';

  @visibleForTesting
  static const String profileDocument = '''
query Profile(\$slug: String!) {
  findProfileBySlug(slug: \$slug) {
    id name slug about location gender birthday createdAt url proTier proMessage waifuOrHusbando
    avatarImage { $_image }
    bannerImage { $_image }
    waifu { id names { canonical } image { $_image } }
    pinnedPost { $_postFields }
    siteLinks(first: 10) { nodes { url site { name } } }
    followers(first: 1) { $_total }
    following(first: 1) { $_total }
    posts(first: 1) { $_total }
    comments(first: 1) { $_total }
    mediaReactions(first: 1) { $_total }
    libraryEvents(first: 1) { $_total }
  }
}''';

  static String _profileConnection(String field, String args, String nodeFields) => '''
query ProfileConnection(\$slug: String!, \$first: Int!, \$after: String) {
  findProfileBySlug(slug: \$slug) {
    $field(first: \$first, after: \$after$args) { $_total $_pageInfo nodes { $nodeFields } }
  }
}''';

  @visibleForTesting
  static final String profileActivityDocument = _profileConnection(
      'libraryEvents',
      ', sort: [{ on: CREATED_AT, direction: DESCENDING }]',
      'id kind changedData createdAt media { $_mediaCard }');
  @visibleForTesting
  static final String profileReactionsDocument = _profileConnection(
      'mediaReactions',
      ', sort: [{ on: CREATED_AT, direction: DESCENDING }]',
      '$_reactionFields media { $_mediaCard }');
  @visibleForTesting
  static final String profilePostsDocument = _profileConnection(
      'posts', ', sort: [{ on: CREATED_AT, direction: DESCENDING }]', _postFields);
  @visibleForTesting
  static final String profileFollowersDocument =
      _profileConnection('followers', ', sort: [{ on: CREATED_AT, direction: DESCENDING }]', _author);
  @visibleForTesting
  static final String profileFollowingDocument =
      _profileConnection('following', ', sort: [{ on: CREATED_AT, direction: DESCENDING }]', _author);
  @visibleForTesting
  static final String profileFavouritesDocument = _profileConnection('favorites', '', '''
id
item {
  __typename
  ... on Anime { id slug titles { canonical } posterImage { $_image } }
  ... on Manga { id slug titles { canonical } posterImage { $_image } }
  ... on Character { id slug names { canonical } image { $_image } }
  ... on Person { id slug name image { $_image } }
}''');

  @visibleForTesting
  static const String profileLibraryDocument = '''
query ProfileLibrary(\$slug: String!, \$type: MediaTypeEnum, \$status: [LibraryEntryStatusEnum!], \$first: Int!, \$after: String) {
  findProfileBySlug(slug: \$slug) {
    library {
      all(mediaType: \$type, status: \$status, first: \$first, after: \$after, sort: [{ on: UPDATED_AT, direction: DESCENDING }]) {
        $_total $_pageInfo
        nodes { id status progress rating media { $_mediaCard } }
      }
    }
  }
}''';

  @visibleForTesting
  static const String searchProfilesDocument = '''
query SearchProfiles(\$username: String!, \$first: Int!, \$after: String) {
  searchProfileByUsername(username: \$username, first: \$first, after: \$after) {
    $_pageInfo nodes { $_author }
  }
}''';

  @visibleForTesting
  static const String lookupMappingDocument = '''
query LookupMapping(\$site: MappingExternalSiteEnum!, \$id: ID!) {
  lookupMapping(externalSite: \$site, externalId: \$id) {
    ... on Anime { $_mediaCard }
    ... on Manga { $_mediaCard }
  }
}''';

  // -- media ----------------------------------------------------------------

  /// One request for the whole title page. [slug] or [id] must be given; [units] is the size of
  /// the first page of episodes (anime) or chapters (manga). Returns `null` when Kitsu has no such
  /// title.
  Future<KitsuMediaDetail?> mediaDetail(
    KitsuMediaKind kind, {
    String? slug,
    String? id,
    int units = 12,
    bool auth = false,
  }) async {
    assert(slug != null || id != null, 'give a slug or an id');
    final bySlug = slug != null;
    final response = await execute(
      mediaDetailDocument(kind, bySlug: bySlug),
      variables: {'key': bySlug ? slug : id, 'units': units.clamp(1, KitsuPageArgs.maxSize)},
      auth: auth,
    );
    final root = '${kind == KitsuMediaKind.anime ? 'findAnime' : 'findManga'}${bySlug ? 'BySlug' : 'ById'}';
    return KitsuMediaDetail.parse(response.data[root]);
  }

  /// The rating histogram (JSON:API: GraphQL does not expose `ratingFrequencies`).
  Future<KitsuRatingFrequencies> ratingFrequencies(KitsuMediaKind kind, String id) async {
    final document = await _rest.getJson('/${kind.path}/$id',
        query: {'fields[${kind.path}]': 'ratingFrequencies'});
    return KitsuRatingFrequencies.parse(document);
  }

  /// A title found from an id on another site, e.g. `MYANIMELIST_ANIME` and `52991`.
  Future<KitsuMediaRef?> lookupMapping(String site, String externalId) async {
    final response =
        await execute(lookupMappingDocument, variables: {'site': site, 'id': externalId});
    return KitsuMediaRef.parse(response.data['lookupMapping']);
  }

  Future<Map<String, dynamic>?> _mediaRoot(
    String document,
    KitsuMediaKind kind,
    String id,
    KitsuPageArgs page,
  ) async {
    final response = await execute(document,
        variables: {'id': id, 'type': kind.graphql, ...page.toVariables()});
    return _map(response.data['findMediaByIdAndType']);
  }

  Future<KitsuConnection<KitsuReaction>> mediaReactions(KitsuMediaKind kind, String id,
          [KitsuPageArgs page = const KitsuPageArgs()]) async =>
      KitsuConnection.parse(
          (await _mediaRoot(mediaReactionsDocument, kind, id, page))?['reactions'],
          KitsuReaction.parse);

  Future<KitsuConnection<KitsuPost>> mediaPosts(KitsuMediaKind kind, String id,
          [KitsuPageArgs page = const KitsuPageArgs()]) async =>
      KitsuConnection.parse(
          (await _mediaRoot(mediaPostsDocument, kind, id, page))?['posts'], KitsuPost.parse);

  Future<KitsuConnection<KitsuCharacterRole>> mediaCharacters(KitsuMediaKind kind, String id,
          [KitsuPageArgs page = const KitsuPageArgs()]) async =>
      KitsuConnection.parse(
          (await _mediaRoot(mediaCharactersDocument, kind, id, page))?['characters'],
          KitsuCharacterRole.parse);

  Future<KitsuConnection<KitsuStaffMember>> mediaStaff(KitsuMediaKind kind, String id,
          [KitsuPageArgs page = const KitsuPageArgs()]) async =>
      KitsuConnection.parse(
          (await _mediaRoot(mediaStaffDocument, kind, id, page))?['staff'], KitsuStaffMember.parse);

  /// Episodes (anime) or chapters (manga), in order, after the ones [mediaDetail] returned.
  Future<KitsuConnection<KitsuUnit>> mediaUnits(KitsuMediaKind kind, String id,
      [KitsuPageArgs page = const KitsuPageArgs()]) async {
    final response = await execute(unitsDocument(kind), variables: {'id': id, ...page.toVariables()});
    final root = _map(response.data[kind == KitsuMediaKind.anime ? 'findAnimeById' : 'findMangaById']);
    return KitsuConnection.parse(
        root?[kind == KitsuMediaKind.anime ? 'episodes' : 'chapters'], KitsuUnit.parse);
  }

  // -- posts ----------------------------------------------------------------

  /// A post with a page of its comments (each with its first replies); `null` when deleted.
  Future<KitsuPostThread?> post(String id, [KitsuPageArgs page = const KitsuPageArgs()]) async {
    final response = await execute(postDocument, variables: {'id': id, ...page.toVariables()});
    final root = _map(response.data['findPostById']);
    final post = root == null ? null : KitsuPost.parse(root);
    if (root == null || post == null) return null;
    return KitsuPostThread(post, KitsuConnection.parse(root['thread'], KitsuComment.parse));
  }

  // -- profiles -------------------------------------------------------------

  /// The header of a profile by slug (or the user's name); `null` when it does not exist.
  Future<KitsuProfileSummary?> profile(String slug) async {
    final response = await execute(profileDocument, variables: {'slug': slug});
    return KitsuProfileSummary.parse(response.data['findProfileBySlug']);
  }

  Future<KitsuConnection<T>> _profileList<T>(
    String document,
    String slug,
    String field,
    KitsuPageArgs page,
    T? Function(Map<String, dynamic>) parse,
  ) async {
    final response = await execute(document, variables: {'slug': slug, ...page.toVariables()});
    return KitsuConnection.parse(_map(response.data['findProfileBySlug'])?[field], parse);
  }

  Future<KitsuConnection<KitsuLibraryEvent>> profileActivity(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profileActivityDocument, slug, 'libraryEvents', page, KitsuLibraryEvent.parse);

  Future<KitsuConnection<KitsuReaction>> profileReactions(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profileReactionsDocument, slug, 'mediaReactions', page, KitsuReaction.parse);

  Future<KitsuConnection<KitsuPost>> profilePosts(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profilePostsDocument, slug, 'posts', page, KitsuPost.parse);

  Future<KitsuConnection<KitsuAuthor>> profileFollowers(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profileFollowersDocument, slug, 'followers', page, KitsuAuthor.parse);

  Future<KitsuConnection<KitsuAuthor>> profileFollowing(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profileFollowingDocument, slug, 'following', page, KitsuAuthor.parse);

  /// Favourite titles, characters and people; filter by [KitsuFavourite.type] on the client.
  Future<KitsuConnection<KitsuFavourite>> profileFavourites(String slug,
          [KitsuPageArgs page = const KitsuPageArgs()]) =>
      _profileList(profileFavouritesDocument, slug, 'favorites', page, KitsuFavourite.parse);

  /// A public library page. [statuses] are `LibraryEntryStatusEnum` values (`CURRENT`,
  /// `PLANNED`, `COMPLETED`, `ON_HOLD`, `DROPPED`), `null` for every status; [kind] `null` for
  /// anime and manga together.
  Future<KitsuConnection<KitsuLibraryItem>> profileLibrary(
    String slug, {
    KitsuMediaKind? kind,
    List<String>? statuses,
    KitsuPageArgs page = const KitsuPageArgs(),
  }) async {
    final response = await execute(profileLibraryDocument, variables: {
      'slug': slug,
      'type': kind?.graphql,
      'status': statuses,
      ...page.toVariables(),
    });
    final library = _map(_map(response.data['findProfileBySlug'])?['library']);
    return KitsuConnection.parse(library?['all'], KitsuLibraryItem.parse);
  }

  Future<KitsuConnection<KitsuAuthor>> searchProfiles(String username,
      [KitsuPageArgs page = const KitsuPageArgs()]) async {
    final response =
        await execute(searchProfilesDocument, variables: {'username': username, ...page.toVariables()});
    return KitsuConnection.parse(response.data['searchProfileByUsername'], KitsuAuthor.parse);
  }

  // -- feeds and groups (JSON:API) -------------------------------------------

  Future<KitsuFeedPage> _feed(String path, String? cursor, int limit, {Map<String, String>? extra, bool auth = false}) async {
    final query = <String, String>{
      'include': 'subject,subject.user',
      'page[limit]': '${limit.clamp(1, 40)}',
      if (cursor != null) 'page[cursor]': cursor,
      ...?extra,
    };
    return KitsuFeedPage.parse(await _rest.getJson(path, query: query, auth: auth));
  }

  /// The site-wide feed: posts, comments and reactions, newest first.
  Future<KitsuFeedPage> globalFeed({String? cursor, int limit = 20}) =>
      _feed('/feeds/global/global', cursor, limit);

  /// The feed of a group (`596` is the Kitsu News Network).
  Future<KitsuFeedPage> groupFeed(String groupId, {String? cursor, int limit = 20}) =>
      _feed('/feeds/group/$groupId', cursor, limit);

  /// The posts about a title.
  Future<KitsuFeedPage> mediaFeed(KitsuMediaKind kind, String mediaId,
          {String? cursor, int limit = 20}) =>
      _feed('/feeds/media_aggr/${kind.typename}-$mediaId', cursor, limit,
          extra: {'filter[kind]': 'posts'});

  /// The posts and comments of a user, public.
  Future<KitsuFeedPage> userFeed(String userId, {String? cursor, int limit = 20}) =>
      _feed('/feeds/user_aggr/$userId', cursor, limit);

  /// The timeline of the signed-in user (people they follow). Needs the token.
  Future<KitsuFeedPage> timelineFeed(String userId, {String? cursor, int limit = 20}) =>
      _feed('/feeds/timeline/$userId', cursor, limit, auth: true);

  /// The groups directory, most recently active first by default.
  Future<KitsuGroupPage> groups({
    int offset = 0,
    int limit = 20,
    String sort = '-lastActivityAt',
    String? query,
  }) async {
    final size = limit.clamp(1, 20);
    final document = await _rest.getJson('/groups', query: {
      'sort': sort,
      'page[limit]': '$size',
      'page[offset]': '$offset',
      'fields[groups]': 'name,slug,membersCount,tagline,lastActivityAt,nsfw,avatar',
      if (query != null && query.trim().isNotEmpty) 'filter[query]': query.trim(),
    });
    final raw = document['data'];
    final groups = <KitsuGroup>[
      if (raw is List)
        for (final e in raw)
          if (_map(e) case final m? when KitsuGroup.parse(m) != null) KitsuGroup.parse(m)!,
    ];
    final total = _int(_map(document['meta'])?['count']);
    final hasNext = _map(document['links'])?['next'] != null;
    return KitsuGroupPage(groups, total, hasNext ? offset + size : null);
  }
}

Map<String, dynamic> _decodeBody(String body) {
  final value = json.decode(body);
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}
