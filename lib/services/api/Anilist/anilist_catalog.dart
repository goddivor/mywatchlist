import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tag of AniList (`MediaTagCollection`).
@immutable
class AnilistTag {
  final int id;
  final String name;
  final String? description;

  /// AniList's category, e.g. `Theme-Fantasy`, `Setting-Scene`, `Cast-Traits`.
  final String category;
  final bool isGeneralSpoiler;
  final bool isAdult;

  const AnilistTag({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    this.isGeneralSpoiler = false,
    this.isAdult = false,
  });

  static AnilistTag? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! num || name is! String || name.isEmpty) return null;
    final description = json['description'];
    final category = json['category'];
    return AnilistTag(
      id: id.toInt(),
      name: name,
      description: description is String && description.trim().isNotEmpty ? description.trim() : null,
      category: category is String && category.isNotEmpty ? category : 'Other',
      isGeneralSpoiler: json['isGeneralSpoiler'] == true,
      isAdult: json['isAdult'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'isGeneralSpoiler': isGeneralSpoiler,
        'isAdult': isAdult,
      };
}

/// A streaming (anime) or reading (manga) service AniList links titles to
/// (`ExternalLinkSourceCollection(type: STREAMING)`), the values of `licensedById_in`.
@immutable
class AnilistLinkSource {
  final int id;
  final String site;

  /// The language of the service when AniList lists one site per language (`Korean`…).
  final String? language;
  final String? iconUrl;

  const AnilistLinkSource({required this.id, required this.site, this.language, this.iconUrl});

  /// The site, with its language when it has one: AniList lists some sites once per language.
  String get label => language == null ? site : '$site ($language)';

  static AnilistLinkSource? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final site = json['site'];
    if (id is! num || site is! String || site.isEmpty) return null;
    final language = json['language'];
    final icon = json['icon'];
    return AnilistLinkSource(
      id: id.toInt(),
      site: site,
      language: language is String && language.isNotEmpty ? language : null,
      iconUrl: icon is String && icon.isNotEmpty ? icon : null,
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'site': site, 'language': language, 'icon': iconUrl};
}

/// AniList's genres, tags and streaming / reading services, as of [fetchedAt].
@immutable
class AnilistCatalogData {
  final List<String> genres;
  final List<AnilistTag> tags;
  final List<AnilistLinkSource> animeSources;
  final List<AnilistLinkSource> mangaSources;
  final DateTime fetchedAt;

  /// True for the built-in genre list used before AniList ever answered (no tags, no services).
  final bool isFallback;

  const AnilistCatalogData({
    required this.genres,
    required this.tags,
    required this.animeSources,
    required this.mangaSources,
    required this.fetchedAt,
    this.isFallback = false,
  });

  /// What the app shows when AniList has never answered.
  factory AnilistCatalogData.fallback() => AnilistCatalogData(
        genres: AnilistDiscoverService.genres,
        tags: const [],
        animeSources: const [],
        mangaSources: const [],
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isFallback: true,
      );

  /// The genres to offer: `Hentai` (an adult genre) only when [adult] is allowed.
  List<String> genresFor({required bool adult}) =>
      [for (final g in genres) if (adult || g != 'Hentai') g];

  /// The tags to offer: adult tags only when [adult] is allowed.
  List<AnilistTag> tagsFor({required bool adult}) =>
      [for (final t in tags) if (adult || !t.isAdult) t];

  /// The categories of [tags], in AniList's order of first appearance sorted by name.
  List<String> categoriesFor({required bool adult}) {
    final set = <String>{for (final t in tagsFor(adult: adult)) t.category};
    return set.toList()..sort();
  }

  List<AnilistLinkSource> sourcesFor(String category) =>
      category == 'manga' ? mangaSources : animeSources;

  AnilistTag? tagNamed(String name) {
    for (final t in tags) {
      if (t.name == name) return t;
    }
    return null;
  }

  AnilistLinkSource? sourceWithId(int id) {
    for (final s in [...animeSources, ...mangaSources]) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Reads AniList's answer (aliases `genres`, `tags`, `anime`, `manga`).
  factory AnilistCatalogData.fromAnswer(Map<String, dynamic> data, DateTime at) {
    List<AnilistLinkSource> sources(Object? list) {
      final seen = <int>{};
      return [
        if (list is List)
          for (final s in list)
            if (AnilistLinkSource.fromJson(s) case final source? when seen.add(source.id)) source,
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }

    final genres = data['genres'];
    final tags = data['tags'];
    return AnilistCatalogData(
      genres: [
        if (genres is List)
          for (final g in genres)
            if (g is String && g.isNotEmpty) g,
      ],
      tags: [
        if (tags is List)
          for (final t in tags)
            if (AnilistTag.fromJson(t) case final tag?) tag,
      ],
      animeSources: sources(data['anime']),
      mangaSources: sources(data['manga']),
      fetchedAt: at,
    );
  }

  Map<String, dynamic> toJson() => {
        'at': fetchedAt.millisecondsSinceEpoch,
        'genres': genres,
        'tags': [for (final t in tags) t.toJson()],
        'anime': [for (final s in animeSources) s.toJson()],
        'manga': [for (final s in mangaSources) s.toJson()],
      };

  static AnilistCatalogData? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final at = json['at'];
    if (at is! num) return null;
    final data = AnilistCatalogData.fromAnswer(json, DateTime.fromMillisecondsSinceEpoch(at.toInt()));
    return data.genres.isEmpty ? null : data;
  }
}

/// Loads [AnilistCatalogData] in one request (four aliases, one rate-limit token) and keeps it
/// a day, in memory and on the device. A failed refresh keeps serving the last copy; with no
/// copy at all, the built-in genres ([AnilistCatalogData.fallback]).
class AnilistCatalog {
  AnilistCatalog({
    AnilistGraphql? client,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? clock,
  })  : _client = client,
        _prefs = prefs ?? SharedPreferences.getInstance,
        _clock = clock ?? DateTime.now;

  static AnilistCatalog instance = AnilistCatalog();

  static const Duration maxAge = Duration(days: 1);
  static const String storageKey = 'anilist_catalog_v1';

  final AnilistGraphql? _client;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _clock;

  AnilistGraphql get _gql => _client ?? AnilistGraphql.instance;

  AnilistCatalogData? _data;
  Future<AnilistCatalogData>? _loading;

  /// The last loaded catalog, null before the first [load] ends.
  AnilistCatalogData? get cached => _data;

  bool _fresh(AnilistCatalogData d) => !d.isFallback && _clock().difference(d.fetchedAt) < maxAge;

  /// The catalog: the kept copy while it is less than a day old, else AniList's. Never throws.
  Future<AnilistCatalogData> load({bool force = false}) {
    final kept = _data;
    if (!force && kept != null && _fresh(kept)) return Future.value(kept);
    return _loading ??= _load(force).whenComplete(() => _loading = null);
  }

  Future<AnilistCatalogData> _load(bool force) async {
    final stored = _data ?? await _readDisk();
    if (stored != null) _data = stored;
    if (!force && stored != null && _fresh(stored)) return stored;
    try {
      final batch = await _gql.batch(const {
        'genres': 'GenreCollection',
        'tags': 'MediaTagCollection { id name description category isGeneralSpoiler isAdult }',
        'anime': 'ExternalLinkSourceCollection(type: STREAMING, mediaType: ANIME) { id site icon language }',
        'manga': 'ExternalLinkSourceCollection(type: STREAMING, mediaType: MANGA) { id site icon language }',
      });
      final fetched = AnilistCatalogData.fromAnswer(batch.data, _clock());
      if (fetched.genres.isEmpty) throw const AnilistError(200, 'No genres');
      _data = fetched;
      await _writeDisk(fetched);
      return fetched;
    } catch (_) {
      return _data ??= AnilistCatalogData.fallback();
    }
  }

  Future<AnilistCatalogData?> _readDisk() async {
    try {
      final raw = (await _prefs()).getString(storageKey);
      if (raw == null) return null;
      // About 120 KB of JSON: decoded off the UI isolate.
      return await Isolate.run(() => AnilistCatalogData.fromJson(json.decode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(AnilistCatalogData data) async {
    try {
      await (await _prefs()).setString(storageKey, json.encode(data.toJson()));
    } catch (_) {
      // A cache that cannot be written only costs a request next time.
    }
  }
}
