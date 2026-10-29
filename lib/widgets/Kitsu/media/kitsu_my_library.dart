import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_feed.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_graphql.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_http.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_library.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_media.dart' show KitsuDocument;
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// Kitsu's GraphQL word for a list status (`CURRENT`, `ON_HOLD`…).
String kitsuGraphqlStatus(ListEntryStatus status) => switch (status) {
      ListEntryStatus.current => 'CURRENT',
      ListEntryStatus.planned => 'PLANNED',
      ListEntryStatus.completed => 'COMPLETED',
      ListEntryStatus.onHold => 'ON_HOLD',
      ListEntryStatus.dropped => 'DROPPED',
    };

ListEntryStatus? listStatusOfGraphql(Object? value) => switch ('$value'.toUpperCase()) {
      'CURRENT' => ListEntryStatus.current,
      'PLANNED' => ListEntryStatus.planned,
      'COMPLETED' => ListEntryStatus.completed,
      'ON_HOLD' => ListEntryStatus.onHold,
      'DROPPED' => ListEntryStatus.dropped,
      _ => null,
    };

/// The signed-in user's library entry of one title, as the title page, the home's Quick update
/// and the Kitsu edit sheet show it.
@immutable
class KitsuMyEntry {
  /// Library-entry id.
  final String id;
  final ListEntryStatus status;
  final int progress;

  /// Kitsu's `ratingTwenty` (2 to 20), null when not rated.
  final int? rating;
  final int reconsumeCount;
  final bool reconsuming;
  final bool private;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// The user's own reaction to the title (140 characters), null when none.
  final String? reaction;

  /// The next episode or chapter to watch, when Kitsu knows it.
  final KitsuUnit? nextUnit;

  /// Filled by the Quick update list: the title, its banner and its length.
  final KitsuMediaRef? media;
  final KitsuImage? banner;

  /// Episodes or chapters of the title, 0 when unknown.
  final int total;

  const KitsuMyEntry({
    required this.id,
    required this.status,
    this.progress = 0,
    this.rating,
    this.reconsumeCount = 0,
    this.reconsuming = false,
    this.private = false,
    this.notes,
    this.startedAt,
    this.finishedAt,
    this.reaction,
    this.nextUnit,
    this.media,
    this.banner,
    this.total = 0,
  });

  bool get isRated => rating != null && rating! > 0;

  /// The entry with the given fields replaced.
  KitsuMyEntry copyWith({
    ListEntryStatus? status,
    int? progress,
    int? rating,
    bool clearRating = false,
    int? total,
  }) =>
      KitsuMyEntry(
        id: id,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        rating: clearRating ? null : (rating ?? this.rating),
        reconsumeCount: reconsumeCount,
        reconsuming: reconsuming,
        private: private,
        notes: notes,
        startedAt: startedAt,
        finishedAt: finishedAt,
        reaction: reaction,
        nextUnit: nextUnit,
        media: media,
        banner: banner,
        total: total ?? this.total,
      );

  static int? _int(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  /// Parses a GraphQL `LibraryEntry` (fields of [KitsuMyLibrary.entryFields]); null when it is
  /// not one.
  static KitsuMyEntry? parse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final status = listStatusOfGraphql(json['status']);
    if (id == null || status == null) return null;
    final media = json['media'];
    final rating = _int(json['rating']);
    final reaction = json['reaction'];
    final text = reaction is Map ? reaction['reaction'] : null;
    return KitsuMyEntry(
      id: '$id',
      status: status,
      progress: _int(json['progress']) ?? 0,
      rating: rating != null && rating > 0 ? rating : null,
      reconsumeCount: _int(json['reconsumeCount']) ?? 0,
      reconsuming: json['reconsuming'] == true,
      private: json['private'] == true,
      notes: json['notes'] is String && (json['notes'] as String).isNotEmpty ? json['notes'] as String : null,
      startedAt: DateTime.tryParse('${json['startedAt']}'),
      finishedAt: DateTime.tryParse('${json['finishedAt']}'),
      reaction: text is String && text.trim().isNotEmpty ? text.trim() : null,
      nextUnit: json['nextUnit'] is Map<String, dynamic> ? KitsuUnit.parse(json['nextUnit'] as Map<String, dynamic>) : null,
      media: KitsuMediaRef.parse(media),
      banner: media is Map ? KitsuImage.parse(media['bannerImage']) : null,
      total: media is Map ? (_int(media['episodeCount']) ?? _int(media['chapterCount']) ?? 0) : 0,
    );
  }
}

/// A write Kitsu refused (an `errors` list in the mutation's payload).
class KitsuWriteRefused implements Exception {
  final List<String> messages;
  const KitsuWriteRefused(this.messages);

  @override
  String toString() => 'KitsuWriteRefused(${messages.join('; ')})';
}

/// The signed-in user's side of a title: their library entry, their favourite, and the writes
/// behind the library box, the Quick update and the Kitsu edit sheet.
///
/// Reads and writes go through GraphQL with the user's token (`auth: true`, i.e.
/// `sendAuthenticated`); only the favourite lookup reads JSON:API (GraphQL has no "is it my
/// favourite" field). Writes happen only when the user taps; tests replace [instance] with fakes.
class KitsuMyLibrary {
  KitsuMyLibrary({KitsuGraphql? graphql, KitsuHttp? http, KitsuLibrary? library})
      : _graphql = graphql,
        _http = http,
        _library = library;

  /// Replaced by tests.
  static KitsuMyLibrary instance = KitsuMyLibrary();

  final KitsuGraphql? _graphql;
  final KitsuHttp? _http;
  final KitsuLibrary? _library;

  KitsuGraphql get graphql => _graphql ?? KitsuGraphql.instance;
  KitsuHttp get http => _http ?? KitsuHttp.instance;
  KitsuLibrary get library => _library ?? KitsuLibrary.instance;

  static const String _image = 'original { url width height }';

  static const String entryFields = '''
id status progress rating reconsumeCount reconsuming private notes startedAt finishedAt
reaction { reaction }
nextUnit { id number titles { canonical } thumbnail { $_image } }''';

  static const String _quickMedia = '''
__typename id slug titles { canonical } posterImage { $_image } bannerImage { $_image }
... on Anime { episodeCount }
... on Manga { chapterCount }''';

  /// The user's entry of the title, null when it is not in the library.
  Future<KitsuMyEntry?> entryOf(KitsuMediaKind kind, String mediaId) async {
    final root = kind == KitsuMediaKind.anime ? 'findAnimeById' : 'findMangaById';
    final response = await graphql.execute(
      'query MyEntry(\$id: ID!) { $root(id: \$id) { id myLibraryEntry { $entryFields } } }',
      variables: {'id': mediaId},
      auth: true,
    );
    final media = response.data[root];
    return media is Map ? KitsuMyEntry.parse(media['myLibraryEntry']) : null;
  }

  /// The Quick update cards: the user's current anime (or manga), last updated first, each with
  /// its next episode.
  Future<List<KitsuMyEntry>> currentEntries({required KitsuMediaKind kind, int limit = 12}) async {
    final response = await graphql.execute(
      '''
query QuickUpdate(\$type: MediaTypeEnum!, \$n: Int!) {
  currentProfile {
    library {
      current(first: \$n, mediaType: \$type, sort: [{ on: UPDATED_AT, direction: DESCENDING }]) {
        nodes { $entryFields media { $_quickMedia } }
      }
    }
  }
}''',
      variables: {'type': kind.graphql, 'n': limit.clamp(1, 20)},
      auth: true,
    );
    final profile = response.data['currentProfile'];
    if (profile is! Map) throw const KitsuSessionExpired();
    final current = (profile['library'] as Map?)?['current'];
    final nodes = current is Map ? current['nodes'] : null;
    if (nodes is! List) return const [];
    return [
      for (final n in nodes)
        if (KitsuMyEntry.parse(n) case final e? when e.media != null) e,
    ];
  }

  Future<Map<String, dynamic>> _mutate(String document, Map<String, Object?> input, String field) async {
    final response = await graphql.execute(document, variables: {'input': input}, auth: true);
    Object? node = response.data;
    for (final key in field.split('.')) {
      node = node is Map ? node[key] : null;
    }
    if (node is! Map<String, dynamic>) throw KitsuWriteRefused(response.errors);
    final errors = node['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw KitsuWriteRefused([for (final e in errors) e is Map ? '${e['message'] ?? e}' : '$e']);
    }
    return node;
  }

  /// Adds the title to the library with [status]; returns the new entry.
  Future<KitsuMyEntry> add(KitsuMediaKind kind, String mediaId, ListEntryStatus status, {int? progress}) async {
    final node = await _mutate(
      'mutation Add(\$input: LibraryEntryCreateInput!) { libraryEntry { create(input: \$input) { errors { message } libraryEntry { $entryFields } } } }',
      {
        'mediaId': mediaId,
        'mediaType': kind.graphql,
        'status': kitsuGraphqlStatus(status),
        if (progress != null) 'progress': progress,
      },
      'libraryEntry.create',
    );
    final entry = KitsuMyEntry.parse(node['libraryEntry']);
    if (entry == null) throw const KitsuWriteRefused([]);
    return entry;
  }

  /// Changes entry [entryId]. A [rating] of 0 removes the rating. Dates are written as Kitsu's
  /// ISO 8601 timestamps.
  Future<KitsuMyEntry> update(
    String entryId, {
    ListEntryStatus? status,
    int? progress,
    int? rating,
    int? reconsumeCount,
    bool? reconsuming,
    bool? private,
    String? notes,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) async {
    final node = await _mutate(
      'mutation Update(\$input: LibraryEntryUpdateInput!) { libraryEntry { update(input: \$input) { errors { message } libraryEntry { $entryFields } } } }',
      {
        'id': entryId,
        if (status != null) 'status': kitsuGraphqlStatus(status),
        if (progress != null) 'progress': progress,
        if (rating != null) 'rating': rating <= 0 ? null : rating,
        if (reconsumeCount != null) 'reconsumeCount': reconsumeCount,
        if (reconsuming != null) 'reconsuming': reconsuming,
        if (private != null) 'private': private,
        if (notes != null) 'notes': notes,
        if (startedAt != null) 'startedAt': startedAt.toUtc().toIso8601String(),
        if (finishedAt != null) 'finishedAt': finishedAt.toUtc().toIso8601String(),
      },
      'libraryEntry.update',
    );
    final entry = KitsuMyEntry.parse(node['libraryEntry']);
    if (entry == null) throw const KitsuWriteRefused([]);
    return entry;
  }

  /// Removes entry [entryId] from the library.
  Future<void> remove(String entryId) => _mutate(
        'mutation Remove(\$input: GenericDeleteInput!) { libraryEntry { delete(input: \$input) { errors { message } } } }',
        {'id': entryId},
        'libraryEntry.delete',
      );

  /// The id of the user's favourite of the title, null when it is not a favourite.
  Future<String?> favouriteOf(KitsuMediaKind kind, String mediaId) async {
    final userId = await library.userId();
    final json = await http.getJson('/favorites', query: {
      'filter[userId]': userId,
      'filter[itemType]': kind.typename,
      'filter[itemId]': mediaId,
      'fields[favorites]': 'favRank',
      'page[limit]': '1',
    }, auth: true);
    final data = KitsuDocument.from(json).data;
    return data.isEmpty ? null : '${data.first['id']}';
  }

  /// Makes the title a favourite; returns the favourite's id.
  Future<String> addFavourite(KitsuMediaKind kind, String mediaId) async {
    final node = await _mutate(
      'mutation Fav(\$input: FavoriteCreateInput!) { favorite { create(input: \$input) { errors { message } result { id } } } }',
      {'id': mediaId, 'type': kind.graphql},
      'favorite.create',
    );
    final result = node['result'];
    final id = result is Map ? result['id'] : null;
    if (id == null) throw const KitsuWriteRefused([]);
    return '$id';
  }

  /// Removes favourite [favouriteId].
  Future<void> removeFavourite(String favouriteId) => _mutate(
        'mutation Unfav(\$input: FavoriteDeleteInput!) { favorite { delete(input: \$input) { errors { message } } } }',
        {'favoriteId': favouriteId},
        'favorite.delete',
      );

  /// The discussion of one episode (anime) or chapter (manga), newest first, paged by cursor.
  KitsuFeedController unitFeed(KitsuMediaKind kind, String unitId) => KitsuFeedController((cursor) async {
        final path = kind == KitsuMediaKind.anime ? '/feeds/episode_aggr/$unitId' : '/feeds/chapter_aggr/$unitId';
        return KitsuFeedPage.parse(await http.getJson(path, query: {
          'include': 'subject,subject.user',
          'filter[kind]': 'posts',
          'page[limit]': '20',
          if (cursor != null) 'page[cursor]': cursor,
        }));
      });
}
