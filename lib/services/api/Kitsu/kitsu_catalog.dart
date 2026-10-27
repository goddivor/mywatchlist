import 'package:flutter/foundation.dart';
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

/// A page of [KitsuMedia].
class KitsuMediaPage {
  final List<KitsuMedia> items;
  final bool hasMore;
  const KitsuMediaPage(this.items, {required this.hasMore});
}

/// A Kitsu category (genre or theme) with its size.
@immutable
class KitsuCategory {
  final String id;
  final String title;
  final String slug;
  final int mediaCount;

  const KitsuCategory(
      {required this.id, required this.title, required this.slug, required this.mediaCount});
}

/// Read-only catalogue: the rows of the home and explore tabs, the browse screens, the search.
///
/// Media endpoints answer 20 items at most per page. Every request asks for the MyAnimeList
/// mapping (`include=mappings`) so a tap can open the detail screen.
class KitsuCatalog {
  KitsuCatalog({KitsuHttp? http}) : _http = http;

  static KitsuCatalog instance = KitsuCatalog();

  final KitsuHttp? _http;
  KitsuHttp get http => _http ?? KitsuHttp.instance;

  /// Largest page of a media endpoint.
  static const int maxPage = 20;

  static String fields(bool isAnime) =>
      'canonicalTitle,titles,abbreviatedTitles,posterImage,averageRating,userCount,'
      'popularityRank,ratingRank,subtype,status,startDate,endDate,synopsis,mappings,'
      '${isAnime ? 'episodeCount' : 'chapterCount,volumeCount'}';

  String get _titleLang => Preferences.general.preferredTitle.name;

  /// One page of [query].
  Future<KitsuMediaPage> page(KitsuMediaQuery query, {int limit = maxPage, int offset = 0}) async {
    final json = await http.getJson(query.path,
        query: query.params(limit: limit.clamp(1, maxPage), offset: offset));
    final doc = KitsuDocument.from(json);
    return KitsuMediaPage(parse(doc, isAnime: query.isAnime, titleLang: _titleLang),
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
      'fields[categories]': 'title,slug,totalMediaCount',
      'page[limit]': '${limit.clamp(1, maxPage)}',
    });
    return [
      for (final r in KitsuDocument.from(json).data)
        if (kitsuAttrs(r)['slug'] is String)
          KitsuCategory(
            id: '${r['id']}',
            title: '${kitsuAttrs(r)['title'] ?? kitsuAttrs(r)['slug']}',
            slug: kitsuAttrs(r)['slug'] as String,
            mediaCount: (kitsuAttrs(r)['totalMediaCount'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  @visibleForTesting
  static List<KitsuMedia> parse(KitsuDocument doc,
          {required bool isAnime, required String titleLang}) =>
      [
        for (final r in doc.data)
          KitsuMedia.fromResource(r, doc, titleLang: titleLang, isAnime: isAnime),
      ];
}
