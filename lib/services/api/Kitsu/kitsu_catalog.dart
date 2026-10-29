import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart'
    show KitsuAuthor, KitsuCategory, KitsuGraphql, KitsuImage, KitsuMediaKind, KitsuMediaRef, KitsuReaction, KitsuTitles;
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';

/// One search of the Kitsu catalogue: anime or manga, filters, sort, optional text.
@immutable
class KitsuMediaQuery {
  final bool isAnime;

  /// `filter[...]` values by name without the `filter[]` wrapper (`status`, `subtype`, `categories`…).
  final Map<String, String> filters;

  /// Kitsu `sort` value (`popularityRank`, `ratingRank`, `-userCount`…), null = Kitsu's default.
  final String? sort;
  final String? text;

  const KitsuMediaQuery({
    required this.isAnime,
    this.filters = const {},
    this.sort,
    this.text,
  });

  KitsuMediaQuery withText(String? value) => KitsuMediaQuery(
        isAnime: isAnime,
        filters: filters,
        sort: sort,
        text: value == null || value.trim().isEmpty ? null : value.trim(),
      );

  String get path => isAnime ? '/anime' : '/manga';

  /// Request parameters for the page starting at [offset].
  Map<String, String> params({required int limit, required int offset}) => {
        for (final f in filters.entries) 'filter[${f.key}]': f.value,
        if (text != null) 'filter[text]': text!,
        if (sort != null && text == null) 'sort': sort!,
        'include': 'mappings',
        'fields[mappings]': 'externalSite,externalId',
        'fields[${isAnime ? 'anime' : 'manga'}]': KitsuCatalog.fields(isAnime),
        'page[limit]': '$limit',
        'page[offset]': '$offset',
      };

  @override
  bool operator ==(Object other) =>
      other is KitsuMediaQuery &&
      other.isAnime == isAnime &&
      other.sort == sort &&
      other.text == text &&
      mapEquals(other.filters, filters);

  @override
  int get hashCode => Object.hash(isAnime, sort, text, Object.hashAllUnordered(filters.entries.map((e) => '${e.key}=${e.value}')));

  /// Cache key of this query.
  String get key => '${isAnime ? 'a' : 'm'}|${(filters.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join('&')}|$sort|$text';
}

/// A page of [KitsuMedia] (named apart from the title page widget `KitsuMediaPage`).
class KitsuCatalogPage {
  final List<KitsuMedia> items;
  final bool hasMore;
  const KitsuCatalogPage(this.items, {required this.hasMore});
}

/// Kitsu's score display setting: 5 stars in whole steps, half steps, or 19 steps.
enum KitsuRatingSystem {
  simple,
  regular,
  advanced;

  static KitsuRatingSystem? parse(Object? v) => switch ('$v'.toUpperCase()) {
        'SIMPLE' => simple,
        'REGULAR' => regular,
        'ADVANCED' => advanced,
        _ => null,
      };
}

/// The display settings of the signed-in Kitsu account (`currentAccount`).
@immutable
class KitsuAccountPrefs {
  /// A `TitleLang` name (`en`, `ro`) matching the account's title language, null = not set.
  final String? titleLang;
  final KitsuRatingSystem? ratingSystem;
  final bool sfwFilter;

  const KitsuAccountPrefs({this.titleLang, this.ratingSystem, this.sfwFilter = false});

  /// `TitleLanguagePreferenceEnum`: LOCALIZED shows the English title, CANONICAL and ROMANIZED the
  /// romanized one (Kitsu's canonical title is the romanized Japanese one for most titles).
  static String? titleLangOf(Object? v) => switch ('$v'.toUpperCase()) {
        'LOCALIZED' => 'en',
        'CANONICAL' || 'ROMANIZED' => 'ro',
        _ => null,
      };

  factory KitsuAccountPrefs.fromJson(Map<String, dynamic> json) => KitsuAccountPrefs(
        titleLang: titleLangOf(json['titleLanguagePreference']),
        ratingSystem: KitsuRatingSystem.parse(json['ratingSystem']),
        sfwFilter: '${json['sfwFilterPreference']}'.toUpperCase() == 'SFW',
      );
}

/// Read-only catalogue: the rows of the home and explore tabs, the browse screens, the search.
///
/// Media endpoints answer 20 items at most per page. Every request asks for the MyAnimeList
/// mapping (`include=mappings`) so a tap can open the detail screen.
class KitsuCatalog {
  KitsuCatalog({KitsuHttp? http, KitsuGraphql? graphql})
      : _http = http,
        _graphql = graphql;

  static KitsuCatalog instance = KitsuCatalog();

  final KitsuHttp? _http;
  KitsuHttp get http => _http ?? KitsuHttp.instance;

  final KitsuGraphql? _graphql;
  KitsuGraphql get graphql => _graphql ?? KitsuGraphql.instance;

  KitsuAccountPrefs? _account;

  /// The signed-in account's settings once [loadAccountPrefs] answered, else null.
  KitsuAccountPrefs? get account => _account;

  /// Largest page of a media endpoint.
  static const int maxPage = 20;

  static String fields(bool isAnime) =>
      'canonicalTitle,titles,abbreviatedTitles,posterImage,averageRating,userCount,'
      'popularityRank,ratingRank,subtype,status,startDate,endDate,synopsis,mappings,'
      '${isAnime ? 'episodeCount' : 'chapterCount,volumeCount'}';

  /// The signed-in account's title language wins over the app's (it is the Kitsu default the user
  /// chose on the site); without an account the app's setting applies.
  String get _titleLang => _account?.titleLang ?? Preferences.general.preferredTitle.name;

  /// Reads the account's title language and rating system (needs a Kitsu token). Returns null and
  /// keeps the previous value when the call fails or nobody is signed in.
  Future<KitsuAccountPrefs?> loadAccountPrefs() async {
    try {
      final response = await graphql.execute(
          'query { currentAccount { titleLanguagePreference ratingSystem sfwFilterPreference } }',
          auth: true);
      final node = response.data['currentAccount'];
      if (node is! Map<String, dynamic>) return null;
      return _account = KitsuAccountPrefs.fromJson(node);
    } catch (_) {
      return null;
    }
  }

  /// Forgets the account settings (sign out, other account).
  void clearAccountPrefs() => _account = null;

  /// One page of [query].
  Future<KitsuCatalogPage> page(KitsuMediaQuery query, {int limit = maxPage, int offset = 0}) async {
    final json = await http.getJson(query.path,
        query: query.params(limit: limit.clamp(1, maxPage), offset: offset));
    final doc = KitsuDocument.from(json);
    return KitsuCatalogPage(parse(doc, isAnime: query.isAnime, titleLang: _titleLang),
        hasMore: doc.hasNext);
  }

  /// The trending anime or manga, in Kitsu's order.
  ///
  /// `/trending` does not accept `include`, so the ids it gives are read again in one request
  /// that carries the mappings.
  Future<List<KitsuMedia>> trending({required bool isAnime, int limit = maxPage}) async {
    final json = await http.getJson('/trending/${isAnime ? 'anime' : 'manga'}',
        query: {'limit': '${limit.clamp(1, maxPage)}'});
    final ids = [
      for (final r in KitsuDocument.from(json).data) '${r['id']}',
    ];
    return byIds(ids, isAnime: isAnime);
  }

  /// The trending anime or manga of one category (`category` is the Kitsu category id), as the
  /// site's category page asks for it.
  Future<List<KitsuMedia>> trendingInCategory(String categoryId,
      {required bool isAnime, int limit = maxPage}) async {
    final json = await http.getJson('/trending/${isAnime ? 'anime' : 'manga'}', query: {
      'limit': '${limit.clamp(1, maxPage)}',
      'in_category': 'true',
      'category': categoryId,
    });
    final ids = [for (final r in KitsuDocument.from(json).data) '${r['id']}'];
    return byIds(ids, isAnime: isAnime);
  }

  /// What the people the signed-in user follows are trending on (needs a Kitsu token; empty when
  /// the user follows no one).
  Future<List<KitsuMedia>> trendingAmongFollowing(
      {required bool isAnime, int limit = maxPage}) async {
    final kind = isAnime ? KitsuMediaKind.anime : KitsuMediaKind.manga;
    final response = await graphql.execute(
        r'query($type: MediaTypeEnum!, $n: Int!) { localTrending(mediaType: $type, first: $n) { nodes { id } } }',
        variables: {'type': kind.graphql, 'n': limit.clamp(1, maxPage)},
        auth: true);
    return byIds(_nodeIds(response.data['localTrending']), isAnime: isAnime);
  }

  /// A random title, or null after [tries] attempts without one. Adult titles are never drawn.
  /// With [needsMalPage] (the default, kept for callers that open MyAnimeList) a title Kitsu maps
  /// to no MyAnimeList page is drawn again; the Kitsu screens pass false since every title opens
  /// its native Kitsu page.
  Future<KitsuMedia?> randomMedia({required bool isAnime, int tries = 4, bool needsMalPage = true}) async {
    final kind = isAnime ? KitsuMediaKind.anime : KitsuMediaKind.manga;
    for (var i = 0; i < tries; i++) {
      final response = await graphql.execute(
          r'query($type: MediaTypeEnum!) { randomMedia(mediaType: $type, ageRatings: [G, PG, R]) { id } }',
          variables: {'type': kind.graphql});
      final node = response.data['randomMedia'];
      final id = node is Map ? '${node['id']}' : null;
      if (id == null) continue;
      final found = await byIds([id], isAnime: isAnime);
      if (found.isNotEmpty && (!needsMalPage || found.first.malId != null)) return found.first;
    }
    return null;
  }

  static List<String> _nodeIds(Object? connection) {
    final nodes = connection is Map ? connection['nodes'] : null;
    if (nodes is! List) return const [];
    return [
      for (final n in nodes)
        if (n is Map && n['id'] != null) '${n['id']}',
    ];
  }

  /// The media with [ids], in that order (an unknown id is skipped).
  Future<List<KitsuMedia>> byIds(List<String> ids, {required bool isAnime}) async {
    if (ids.isEmpty) return const [];
    final wanted = ids.take(maxPage).toList();
    final query = KitsuMediaQuery(isAnime: isAnime, filters: {'id': wanted.join(',')});
    final json = await http.getJson(query.path,
        query: query.params(limit: maxPage, offset: 0));
    final items = parse(KitsuDocument.from(json), isAnime: isAnime, titleLang: _titleLang);
    final byId = {for (final m in items) '${m.id}': m};
    return [for (final id in wanted) if (byId[id] != null) byId[id]!];
  }

  /// The biggest categories (adult ones left out).
  Future<List<KitsuCategory>> categories({int limit = 20}) async {
    final json = await http.getJson('/categories', query: {
      'sort': '-totalMediaCount',
      'filter[nsfw]': 'false',
      'fields[categories]': 'title,slug',
      'page[limit]': '${limit.clamp(1, maxPage)}',
    });
    return [
      for (final r in KitsuDocument.from(json).data)
        if (_category(r) case final c?) c,
    ];
  }

  static KitsuCategory? _category(Map<String, dynamic> r) {
    final a = kitsuAttrs(r);
    final slug = a['slug'];
    if (slug is! String || slug.isEmpty) return null;
    return KitsuCategory(id: '${r['id']}', slug: slug, title: '${a['title'] ?? slug}');
  }

  /// The categories user [userId] marked as favourite on Kitsu (empty when none).
  Future<List<KitsuCategory>> favouriteCategories(String userId) async {
    final json = await http.getJson('/category-favorites', query: {
      'filter[userId]': userId,
      'include': 'category',
      'fields[categories]': 'title,slug',
      'page[limit]': '20',
    });
    final doc = KitsuDocument.from(json);
    return [
      for (final r in doc.data)
        if (doc.related(r, 'category') case final res?)
          if (_category(res) case final c?) c,
    ];
  }

  /// A random title of user [userId]'s "Want to watch" (or "Want to read") list, or null when
  /// it is empty. Two requests: the count, then the entry at a random place.
  Future<KitsuMedia?> randomPlanned(String userId, {required bool isAnime, Random? random}) async {
    final kind = isAnime ? 'anime' : 'manga';
    Map<String, String> base(int limit, int offset) => {
          'filter[userId]': userId,
          'filter[kind]': kind,
          'filter[status]': 'planned',
          'page[limit]': '$limit',
          'page[offset]': '$offset',
        };
    final counted = await http.getJson('/library-entries',
        query: {...base(1, 0), 'fields[libraryEntries]': 'status'}, auth: true);
    final count = ((counted['meta'] as Map?)?['count'] as num?)?.toInt() ?? 0;
    if (count <= 0) return null;
    final offset = (random ?? Random()).nextInt(count);
    final json = await http.getJson('/library-entries',
        query: {
          ...base(1, offset),
          'fields[libraryEntries]': 'status,$kind',
          'include': '$kind,$kind.mappings',
          'fields[$kind]': fields(isAnime),
          'fields[mappings]': 'externalSite,externalId',
        },
        auth: true);
    final doc = KitsuDocument.from(json);
    for (final r in doc.data) {
      final media = doc.related(r, kind);
      if (media != null) return KitsuMedia.fromResource(media, doc, titleLang: _titleLang, isAnime: isAnime);
    }
    return null;
  }

  /// The newest reactions of the whole site, with their author and title.
  Future<List<KitsuReaction>> recentReactions({int limit = 10}) async {
    final json = await http.getJson('/media-reactions', query: {
      'sort': '-createdAt',
      'include': 'user,anime,manga',
      'fields[mediaReactions]': 'reaction,upVotesCount,createdAt,user,anime,manga',
      'fields[users]': 'name,slug,avatar',
      'fields[anime]': 'canonicalTitle,titles,slug,posterImage',
      'fields[manga]': 'canonicalTitle,titles,slug,posterImage',
      'page[limit]': '${limit.clamp(1, maxPage)}',
    });
    return parseReactions(KitsuDocument.from(json));
  }

  /// Parses a `/media-reactions` document that included `user`, `anime` and `manga`.
  @visibleForTesting
  static List<KitsuReaction> parseReactions(KitsuDocument doc) {
    KitsuImage? image(Object? v, String size) {
      if (v is! Map) return null;
      final url = v[size] ?? v['original'];
      return url is String && url.isNotEmpty ? KitsuImage(url) : null;
    }

    final out = <KitsuReaction>[];
    for (final r in doc.data) {
      final a = kitsuAttrs(r);
      final text = a['reaction'];
      final user = doc.related(r, 'user');
      final anime = doc.related(r, 'anime');
      final media = anime ?? doc.related(r, 'manga');
      if (text is! String || text.trim().isEmpty || user == null || media == null) continue;
      final u = kitsuAttrs(user);
      final m = kitsuAttrs(media);
      final titles = m['titles'] is Map ? m['titles'] as Map : const {};
      String? str(Object? v) => v is String && v.isNotEmpty ? v : null;
      out.add(KitsuReaction(
        id: '${r['id']}',
        text: text.trim(),
        progress: (a['progress'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${a['createdAt']}'),
        likes: (a['upVotesCount'] as num?)?.toInt() ?? 0,
        author: KitsuAuthor(
          id: '${user['id']}',
          name: str(u['name']) ?? '?',
          slug: str(u['slug']),
          avatar: image(u['avatar'], 'small'),
        ),
        media: KitsuMediaRef(
          kind: anime != null ? KitsuMediaKind.anime : KitsuMediaKind.manga,
          id: '${media['id']}',
          slug: str(m['slug']),
          titles: KitsuTitles(
            canonical: str(m['canonicalTitle']),
            romanized: str(titles['en_jp']),
            translated: str(titles['en']),
            original: str(titles['ja_jp']),
          ),
          poster: image(m['posterImage'], 'small'),
        ),
      ));
    }
    return out;
  }

  @visibleForTesting
  static List<KitsuMedia> parse(KitsuDocument doc,
          {required bool isAnime, required String titleLang}) =>
      [
        for (final r in doc.data)
          KitsuMedia.fromResource(r, doc, titleLang: titleLang, isAnime: isAnime),
      ];
}
