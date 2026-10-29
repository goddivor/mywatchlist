import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_client.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';

/// Runs one request with the tracker's session (`BaseUser.sendAuthenticated`:
/// token renewed, one replay on 401). Null means no usable session.
typedef AuthSender = Future<http.Response?> Function(
  Future<http.Response> Function(http.Client client, String token) send, {
  bool? idempotent,
});

/// One tracker's list, read and written in [SyncEntry] terms.
abstract class TrackerEntryClient {
  AccountType get tracker;

  /// Whether the tracker has this category (Simkl has no manga).
  bool supports({required bool isAnime});

  /// The user's entry for [mediaId]; null when it is not on their list.
  Future<SyncEntry?> read(String mediaId,
      {required bool isAnime, int? malId});

  /// Creates or updates the entry with the non-null fields of [entry] and
  /// returns what the tracker now holds.
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId});

  Future<void> delete(String mediaId, {required bool isAnime, int? malId});

  /// The tracker's id of the media with this MyAnimeList id, null when the
  /// tracker does not know it.
  Future<String?> findByMalId(int malId, {required bool isAnime});
}

abstract class _BaseClient implements TrackerEntryClient {
  _BaseClient(this._auth);
  final AuthSender _auth;

  Future<http.Response> send(
    Future<http.Response> Function(http.Client, String) request, {
    bool? idempotent,
  }) async {
    final response = await _auth(request, idempotent: idempotent);
    if (response == null) throw SyncAuthRequired(tracker);
    return response;
  }

  Never fail(http.Response r) =>
      throw SyncRequestFailed(tracker, r.statusCode, r.body);
}

// ---------------------------------------------------------------------------
// AniList
// ---------------------------------------------------------------------------

class AnilistEntryClient implements TrackerEntryClient {
  /// Every call goes through [AnilistGraphql] (shared rate limiter, error mapping): reads with
  /// `query`, writes with `mutate` (sent once, never replayed after a network failure).
  /// [graphql] defaults to [AnilistGraphql.instance]; [auth] (tests, older callers) builds a
  /// client over that sender instead, without a limiter.
  AnilistEntryClient({AuthSender? auth, AnilistGraphql? graphql})
      : _graphql = graphql ?? (auth == null ? null : _overSender(auth));

  final AnilistGraphql? _graphql;

  AnilistGraphql get _client => _graphql ?? AnilistGraphql.instance;

  static const endpoint = AnilistGraphql.endpoint;

  static AnilistGraphql _overSender(AuthSender send) {
    GraphqlSender over({required bool idempotent}) => (body, {required bool auth}) => send(
          (client, token) => client.post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body,
          ),
          idempotent: idempotent,
        );
    return AnilistGraphql(
        sender: over(idempotent: true), mutationSender: over(idempotent: false));
  }

  @override
  AccountType get tracker => AccountType.anilist;

  @override
  bool supports({required bool isAnime}) => true;

  // POINT_10_DECIMAL makes the score a 0-10 decimal whatever format the user
  // chose on AniList; writes use `scoreRaw` (0-100) for the same reason.
  static const _entryFields = '''
    id status progress progressVolumes repeat notes
    score(format: POINT_10_DECIMAL)
    startedAt { year month day }
    completedAt { year month day }
  ''';

  /// Runs [operation] and maps AniList's errors to the sync's.
  Future<Map<String, dynamic>> _gql(String operation, Map<String, dynamic> vars,
      {bool write = false}) async {
    try {
      final data = write
          ? await _client.mutate(operation, variables: vars)
          : await _client.query(operation, variables: vars, auth: true);
      return {'data': data};
    } on AnilistSessionExpired {
      throw SyncAuthRequired(tracker);
    } on AnilistError catch (e) {
      throw SyncRequestFailed(tracker, e.statusCode, e.message ?? '');
    }
  }

  @override
  Future<SyncEntry?> read(String mediaId,
      {required bool isAnime, int? malId}) async {
    final body = await _gql('''
      query (\$id: Int) { Media(id: \$id) { mediaListEntry { $_entryFields } } }
    ''', {'id': int.parse(mediaId)});
    final entry = body['data']?['Media']?['mediaListEntry'];
    return entry is Map<String, dynamic> ? parseEntry(entry, isAnime) : null;
  }

  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId}) async {
    final status = entry.status == null
        ? null
        : StatusMaps.toTracker(entry.status!, tracker);
    final vars = <String, dynamic>{
      'mediaId': int.parse(mediaId),
      if (status != null) 'status': status,
      if (entry.score != null) 'scoreRaw': SyncScores.toAnilistRaw(entry.score!),
      if (entry.progress != null) 'progress': entry.progress,
      if (!isAnime && entry.volumes != null) 'progressVolumes': entry.volumes,
      if (entry.repeat != null) 'repeat': entry.repeat,
      if (entry.notes != null) 'notes': entry.notes,
      if (SyncDates.toFuzzy(entry.startDate) != null)
        'startedAt': SyncDates.toFuzzy(entry.startDate),
      if (SyncDates.toFuzzy(entry.finishDate) != null)
        'completedAt': SyncDates.toFuzzy(entry.finishDate),
    };
    final body = await _gql('''
      mutation (
        \$mediaId: Int, \$status: MediaListStatus, \$scoreRaw: Int,
        \$progress: Int, \$progressVolumes: Int, \$repeat: Int,
        \$notes: String, \$startedAt: FuzzyDateInput,
        \$completedAt: FuzzyDateInput
      ) {
        SaveMediaListEntry(
          mediaId: \$mediaId, status: \$status, scoreRaw: \$scoreRaw,
          progress: \$progress, progressVolumes: \$progressVolumes,
          repeat: \$repeat, notes: \$notes, startedAt: \$startedAt,
          completedAt: \$completedAt
        ) { $_entryFields }
      }
    ''', vars, write: true);
    final saved = body['data']?['SaveMediaListEntry'];
    if (saved is! Map<String, dynamic>) {
      throw SyncRequestFailed(tracker, 200, 'no entry in the answer');
    }
    return parseEntry(saved, isAnime);
  }

  @override
  Future<void> delete(String mediaId,
      {required bool isAnime, int? malId}) async {
    final current = await read(mediaId, isAnime: isAnime);
    final id = int.tryParse(current?.entryId ?? '');
    if (id == null) return;
    await _gql('''
      mutation (\$id: Int) { DeleteMediaListEntry(id: \$id) { deleted } }
    ''', {'id': id}, write: true);
  }

  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async {
    final body = await _gql('''
      query (\$mal: Int, \$type: MediaType) {
        Media(idMal: \$mal, type: \$type) { id }
      }
    ''', {'mal': malId, 'type': isAnime ? 'ANIME' : 'MANGA'});
    return body['data']?['Media']?['id']?.toString();
  }

  static SyncEntry parseEntry(Map<String, dynamic> m, bool isAnime) {
    final status = m['status'];
    final score = m['score'];
    return SyncEntry(
      status: status is String
          ? StatusMaps.fromTracker(status, AccountType.anilist, isAnime)
          : null,
      score: score is num ? score.toDouble() : null,
      progress: m['progress'] as int?,
      volumes: isAnime ? null : m['progressVolumes'] as int?,
      startDate: SyncDates.fromFuzzy(m['startedAt']),
      finishDate: SyncDates.fromFuzzy(m['completedAt']),
      repeat: m['repeat'] as int?,
      notes: m['notes'] as String?,
      entryId: m['id']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// Kitsu
// ---------------------------------------------------------------------------

class KitsuEntryClient extends _BaseClient {
  KitsuEntryClient({AuthSender? auth})
      : super(auth ?? _defaultAuth(UserKitsuV2.instance.sendAuthenticated));

  static const base = 'https://kitsu.io/api/edge';
  static const _json = 'application/vnd.api+json';

  String? _userId;

  @override
  AccountType get tracker => AccountType.kitsu;

  @override
  bool supports({required bool isAnime}) => true;

  Map<String, String> _headers(String token) => {
        'Content-Type': _json,
        'Accept': _json,
        'Authorization': 'Bearer $token',
      };

  Future<String> _self() async {
    final cached = _userId;
    if (cached != null) return cached;
    final response = await send((c, t) =>
        c.get(Uri.parse('$base/users?filter[self]=true'), headers: _headers(t)));
    if (response.statusCode != 200) fail(response);
    final data = (json.decode(response.body) as Map)['data'];
    if (data is! List || data.isEmpty) fail(response);
    return _userId = (data.first as Map)['id'] as String;
  }

  Future<Map<String, dynamic>?> _find(String mediaId, bool isAnime) async {
    final user = await _self();
    final uri = Uri.parse('$base/library-entries').replace(queryParameters: {
      'filter[userId]': user,
      'filter[${isAnime ? 'animeId' : 'mangaId'}]': mediaId,
      'page[limit]': '1',
    });
    final response = await send((c, t) => c.get(uri, headers: _headers(t)));
    if (response.statusCode != 200) fail(response);
    final data = (json.decode(response.body) as Map)['data'];
    return data is List && data.isNotEmpty
        ? data.first as Map<String, dynamic>
        : null;
  }

  @override
  Future<SyncEntry?> read(String mediaId,
      {required bool isAnime, int? malId}) async {
    final found = await _find(mediaId, isAnime);
    return found == null ? null : parseEntry(found, isAnime);
  }

  static Map<String, dynamic> attributes(SyncEntry e) {
    final status =
        e.status == null ? null : StatusMaps.toTracker(e.status!, AccountType.kitsu);
    final start = SyncDates.toTimestamp(e.startDate);
    final finish = SyncDates.toTimestamp(e.finishDate);
    return {
      if (status != null) 'status': status,
      if (e.progress != null) 'progress': e.progress,
      if (e.score != null) 'ratingTwenty': SyncScores.toKitsuTwenty(e.score!),
      if (e.repeat != null) 'reconsumeCount': e.repeat,
      if (e.notes != null) 'notes': e.notes,
      if (start != null) 'startedAt': start,
      if (finish != null) 'finishedAt': finish,
    };
  }

  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId}) async {
    final attrs = attributes(entry);
    final existing = await _find(mediaId, isAnime);
    final http.Response response;
    if (existing != null) {
      final id = existing['id'].toString();
      response = await send(
        (c, t) => c.patch(Uri.parse('$base/library-entries/$id'),
            headers: _headers(t),
            body: jsonEncode({
              'data': {'id': id, 'type': 'libraryEntries', 'attributes': attrs}
            })),
        idempotent: true,
      );
    } else {
      final user = await _self();
      final kind = isAnime ? 'anime' : 'manga';
      response = await send(
        (c, t) => c.post(Uri.parse('$base/library-entries'),
            headers: _headers(t),
            body: jsonEncode({
              'data': {
                'type': 'libraryEntries',
                'attributes': {'status': 'planned', ...attrs},
                'relationships': {
                  kind: {
                    'data': {'type': kind, 'id': mediaId}
                  },
                  'user': {
                    'data': {'type': 'users', 'id': user}
                  },
                },
              }
            })),
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      fail(response);
    }
    final data = (json.decode(response.body) as Map)['data'];
    if (data is! Map<String, dynamic>) fail(response);
    return parseEntry(data, isAnime);
  }

  @override
  Future<void> delete(String mediaId,
      {required bool isAnime, int? malId}) async {
    final existing = await _find(mediaId, isAnime);
    if (existing == null) return;
    final id = existing['id'];
    final response = await send(
      (c, t) => c.delete(Uri.parse('$base/library-entries/$id'),
          headers: _headers(t)),
      idempotent: true,
    );
    if (response.statusCode != 204 && response.statusCode != 200) fail(response);
  }

  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async {
    final uri = Uri.parse('$base/mappings').replace(queryParameters: {
      'filter[externalSite]': 'myanimelist/${isAnime ? 'anime' : 'manga'}',
      'filter[externalId]': '$malId',
      'include': 'item',
      'page[limit]': '1',
    });
    final response = await send((c, t) => c.get(uri, headers: _headers(t)));
    if (response.statusCode != 200) fail(response);
    final data = (json.decode(response.body) as Map)['data'];
    if (data is! List || data.isEmpty) return null;
    final item = (data.first as Map)['relationships']?['item']?['data'];
    return item is Map ? item['id']?.toString() : null;
  }

  static SyncEntry parseEntry(Map<String, dynamic> m, bool isAnime) {
    final a = (m['attributes'] as Map?) ?? const {};
    final status = a['status'];
    final rating = a['ratingTwenty'];
    return SyncEntry(
      status: status is String
          ? StatusMaps.fromTracker(status, AccountType.kitsu, isAnime)
          : null,
      score: rating is num ? SyncScores.fromKitsuTwenty(rating) : null,
      progress: a['progress'] as int?,
      startDate: SyncDates.fromTimestamp(a['startedAt']),
      finishDate: SyncDates.fromTimestamp(a['finishedAt']),
      repeat: a['reconsumeCount'] as int?,
      notes: a['notes'] as String?,
      entryId: m['id']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// Simkl
// ---------------------------------------------------------------------------

/// Simkl lists anime only. Its API has no single-entry lookup, so the whole
/// anime list is fetched once and kept for [listTtl].
///
/// Every call goes through [SimklClient] (app identification, 429 back-off,
/// the client id of the session's AUTH version); its errors become sync errors.
class SimklEntryClient implements TrackerEntryClient {
  /// [client] wins; [auth] alone (tests) builds a client over that sender.
  SimklEntryClient({SimklClient? client, AuthSender? auth, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _client = client ??
            (auth == null
                ? SimklApi.sessionClient
                : SimklClient(
                    auth: auth,
                    clientId: () => UserSimklV2.instance.apiClientId));

  static const listTtl = Duration(seconds: 60);
  final DateTime Function() _clock;
  final SimklClient _client;

  List<dynamic>? _items;
  DateTime? _fetchedAt;

  @override
  AccountType get tracker => AccountType.simkl;

  @override
  bool supports({required bool isAnime}) => isAnime;

  /// Runs [call], mapping a dead session to [SyncAuthRequired] and an error
  /// answer (429 included) to [SyncRequestFailed].
  Future<dynamic> _run(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on SimklSessionExpired {
      throw SyncAuthRequired(tracker);
    } on SimklHttpError catch (e) {
      throw SyncRequestFailed(tracker, e.statusCode);
    }
  }

  Future<List<dynamic>> _list() async {
    final cached = _items;
    final at = _fetchedAt;
    if (cached != null && at != null && _clock().difference(at) < listTtl) {
      return cached;
    }
    final body = await _run(() => _client.getAuth('/sync/all-items/anime'));
    final items = body is Map && body['anime'] is List
        ? body['anime'] as List
        : <dynamic>[];
    _fetchedAt = _clock();
    return _items = items;
  }

  /// Simkl needs no search: an id `mal:<id>` addresses the entry by its
  /// MyAnimeList id; any other id is Simkl's own.
  static const malPrefix = 'mal:';

  static ({int? simkl, int? mal}) parseId(String mediaId, int? malId) {
    if (mediaId.startsWith(malPrefix)) {
      return (
        simkl: null,
        mal: int.tryParse(mediaId.substring(malPrefix.length)) ?? malId
      );
    }
    return (simkl: int.tryParse(mediaId), mal: malId);
  }

  Map<String, dynamic>? _match(List<dynamic> items, String mediaId, int? malId) {
    final id = parseId(mediaId, malId);
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) continue;
      final ids = (raw['show'] as Map?)?['ids'] as Map?;
      if (ids == null) continue;
      if (id.simkl != null && ids['simkl']?.toString() == '${id.simkl}') {
        return raw;
      }
      if (id.mal != null && ids['mal']?.toString() == '${id.mal}') return raw;
    }
    return null;
  }

  @override
  Future<SyncEntry?> read(String mediaId,
      {required bool isAnime, int? malId}) async {
    if (!isAnime) throw SyncUnsupported(tracker);
    final found = _match(await _list(), mediaId, malId);
    return found == null ? null : parseEntry(found);
  }

  @override
  Future<SyncEntry> write(String mediaId, SyncEntry entry,
      {required bool isAnime, int? malId}) async {
    if (!isAnime) throw SyncUnsupported(tracker);
    final ids = _ids(mediaId, malId);
    if (ids.isEmpty) throw SyncUnsupported(tracker);
    final status = entry.status == null
        ? null
        : StatusMaps.toTracker(entry.status!, tracker);
    final item = <String, dynamic>{
      'ids': ids,
      if (status != null) 'to': status,
      if (entry.hasScore) 'rating': SyncScores.toMal(entry.score!),
    };
    await _run(() => _client.postAuth('/sync/add-to-list', {
          'anime': [item]
        }));
    _items = null;
    final fresh = await read(mediaId, isAnime: true, malId: malId);
    return fresh ?? entry;
  }

  @override
  Future<void> delete(String mediaId,
      {required bool isAnime, int? malId}) async {
    if (!isAnime) throw SyncUnsupported(tracker);
    final ids = _ids(mediaId, malId);
    if (ids.isEmpty) return;
    await _run(() => _client.postAuth('/sync/remove-from-list', {
          'anime': [
            {'ids': ids}
          ]
        }));
    _items = null;
  }

  Map<String, dynamic> _ids(String mediaId, int? malId) {
    final id = parseId(mediaId, malId);
    return {
      if (id.mal != null) 'mal': id.mal,
      if (id.simkl != null) 'simkl': id.simkl,
    };
  }

  /// Simkl matches a MyAnimeList id itself: the link is the id `mal:<id>`.
  @override
  Future<String?> findByMalId(int malId, {required bool isAnime}) async =>
      isAnime ? '$malPrefix$malId' : null;

  /// Simkl keeps status, rating and the watched count; no dates or notes.
  static SyncEntry parseEntry(Map<String, dynamic> m) {
    final status = m['status'];
    final rating = m['user_rating'];
    return SyncEntry(
      status: status is String
          ? StatusMaps.fromTracker(status, AccountType.simkl, true)
          : null,
      score: rating is num && rating > 0 ? rating.toDouble() : null,
      progress: m['watched_episodes_count'] as int?,
      entryId: ((m['show'] as Map?)?['ids'] as Map?)?['simkl']?.toString(),
    );
  }
}

AuthSender _defaultAuth(
  Future<http.Response?> Function(
    Future<http.Response> Function(http.Client, String), {
    bool? idempotent,
    Duration? timeout,
  }) sendAuthenticated,
) =>
    (send, {idempotent}) => sendAuthenticated(send, idempotent: idempotent);
