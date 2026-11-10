import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_api.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_media.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_api.dart';
import 'package:mywatchlist/widgets/user/sync/mal_side.dart';
import 'package:mywatchlist/widgets/user/sync/sync_entry.dart';
import 'package:mywatchlist/widgets/user/sync/sync_errors.dart';
import 'package:mywatchlist/widgets/user/sync/tracker_clients.dart';

/// A media found on another tracker, to link a MyAnimeList entry to.
class TrackerSearchResult {
  final String id;
  final String title;
  final String? imageUrl;
  final String? status;
  final int? score;
  final String? mediaType;

  const TrackerSearchResult({
    required this.id,
    required this.title,
    this.imageUrl,
    this.status,
    this.score,
    this.mediaType,
  });
}

/// The two directions of a sync between MyAnimeList and another tracker.
enum SyncDirection {
  /// MyAnimeList is the source, the tracker is overwritten.
  malToTracker,

  /// The tracker is the source, MyAnimeList is overwritten.
  trackerToMal,
}

/// What a sync did: the entry each side holds afterwards.
class SyncOutcome {
  final SyncEntry mal;
  final SyncEntry tracker;
  const SyncOutcome({required this.mal, required this.tracker});
}

/// Links between a MyAnimeList entry and its twin on another tracker, and the
/// syncs between them. All tracker traffic goes through
/// [TrackerEntryClient]s (which use `BaseUser.sendAuthenticated`).
class TrackerSyncService {
  TrackerSyncService({
    Map<AccountType, TrackerEntryClient>? clients,
    MalEntrySide? mal,
  })  : _clients = clients ??
            {
              AccountType.anilist: AnilistEntryClient(),
              AccountType.kitsu: KitsuEntryClient(),
              AccountType.simkl: SimklEntryClient(),
            },
        mal = mal ?? const MalApiSide();

  static final TrackerSyncService instance = TrackerSyncService();

  final Map<AccountType, TrackerEntryClient> _clients;
  final MalEntrySide mal;

  /// The client of [tracker]; null for MyAnimeList and `none`.
  TrackerEntryClient? clientFor(AccountType tracker) => _clients[tracker];

  // -------------------------------------------------------------------------
  // Links (SharedPreferences, same keys as before so existing links survive)
  // -------------------------------------------------------------------------

  /// Stored in place of an id when the user unlinked: no automatic re-link.
  static const _unlinked = '-';

  String _linkKey(int malId, String category, AccountType tracker) =>
      'tracker_link_${malId}_${category}_${tracker.name}';

  /// The stored link; null when none, or when the user unlinked.
  Future<String?> getLinkId(
      int malId, String category, AccountType tracker) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_linkKey(malId, category, tracker));
    return (id == null || id == _unlinked || id == 'null' || id.isEmpty)
        ? null
        : id;
  }

  Future<void> saveLinkId(
      int malId, String category, AccountType tracker, String trackerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_linkKey(malId, category, tracker), trackerId);
  }

  /// Unlinks and stops the automatic link from coming back.
  Future<void> removeLinkId(
      int malId, String category, AccountType tracker) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_linkKey(malId, category, tracker), _unlinked);
  }

  /// The stored link or, when there is none and the user did not unlink, the
  /// tracker's own media for this MyAnimeList id (AniList and Kitsu know the
  /// mapping, Simkl takes the MAL id). The found link is stored.
  Future<String?> resolveLink(
      int malId, String category, AccountType tracker) async {
    final stored = await getLinkId(malId, category, tracker);
    if (stored != null) return stored;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_linkKey(malId, category, tracker)) == _unlinked) {
      return null;
    }
    final client = _clients[tracker];
    final isAnime = category == 'anime';
    if (client == null || !client.supports(isAnime: isAnime)) return null;
    try {
      final found = await client.findByMalId(malId, isAnime: isAnime);
      if (found != null) await saveLinkId(malId, category, tracker, found);
      return found;
    } on SyncAuthRequired {
      rethrow;
    } catch (e) {
      debugPrint('Automatic link on ${tracker.name} failed (${e.runtimeType})');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Reading and writing
  // -------------------------------------------------------------------------

  TrackerEntryClient _client(AccountType tracker) {
    final c = _clients[tracker];
    if (c == null) throw SyncUnsupported(tracker);
    return c;
  }

  /// The user's entry on [tracker]; null when the media is not on their list.
  Future<SyncEntry?> readTracker(
      AccountType tracker, String trackerId, String category,
      {int? malId}) {
    final isAnime = category == 'anime';
    final c = _client(tracker);
    if (!c.supports(isAnime: isAnime)) throw SyncUnsupported(tracker);
    return c.read(trackerId, isAnime: isAnime, malId: malId);
  }

  /// Saves an edit of the tracker's own entry (the editor sheet). Unlike a
  /// sync, a zero score is sent: it clears the score.
  Future<SyncEntry> saveTracker(
      AccountType tracker, String trackerId, String category, SyncEntry entry,
      {int? malId}) {
    final isAnime = category == 'anime';
    final c = _client(tracker);
    if (!c.supports(isAnime: isAnime)) throw SyncUnsupported(tracker);
    return c.write(trackerId, entry, isAnime: isAnime, malId: malId);
  }

  Future<void> deleteTracker(
      AccountType tracker, String trackerId, String category,
      {int? malId}) {
    final isAnime = category == 'anime';
    return _client(tracker)
        .delete(trackerId, isAnime: isAnime, malId: malId);
  }

  /// Copies one side onto the other. [cancel] stops it at its next step; a
  /// write is never started after a cancel.
  ///
  Future<SyncOutcome> sync({
    required SyncDirection direction,
    required AccountType tracker,
    required String trackerId,
    required int malId,
    required String category,
    SyncCancelToken? cancel,
  }) async {
    final isAnime = category == 'anime';
    final client = _client(tracker);
    if (!client.supports(isAnime: isAnime)) throw SyncUnsupported(tracker);
    if (!mal.connected) throw const SyncAuthRequired(AccountType.myanimelist);
    final token = cancel ?? SyncCancelToken();

    switch (direction) {
      case SyncDirection.malToTracker:
        final source = await mal.read(malId, isAnime: isAnime);
        token.check();
        if (source == null) throw const SyncSourceEmpty(AccountType.myanimelist);
        final written = await client.write(trackerId, source.compact(),
            isAnime: isAnime, malId: malId);
        return SyncOutcome(mal: source, tracker: written);
      case SyncDirection.trackerToMal:
        final source = await client.read(trackerId,
            isAnime: isAnime, malId: malId);
        token.check();
        if (source == null) throw SyncSourceEmpty(tracker);
        final written =
            await mal.write(malId, source.compact(), isAnime: isAnime);
        return SyncOutcome(mal: written, tracker: source);
    }
  }

  // -------------------------------------------------------------------------
  // Search (to link by hand)
  // -------------------------------------------------------------------------

  Future<List<TrackerSearchResult>> search(
      AccountType tracker, String query, String category) async {
    switch (tracker) {
      case AccountType.anilist:
        return _searchAnilist(query, category);
      case AccountType.kitsu:
        return _searchKitsu(query, category);
      case AccountType.simkl:
        return _searchSimkl(query, category);
      default:
        return [];
    }
  }

  Future<List<TrackerSearchResult>> _searchAnilist(
      String query, String category) async {
    try {
      final response = await AnilistApi.searchMedia(
        type: category == 'anime' ? 'ANIME' : 'MANGA',
        search: query,
        perPage: 15,
      );
      final media = response['data']?['Page']?['media'] as List<dynamic>? ?? [];
      return media.map((item) {
        final m = item as Map<String, dynamic>;
        final titleMap = m['title'] as Map<String, dynamic>?;
        final coverMap = m['coverImage'] as Map<String, dynamic>?;
        return TrackerSearchResult(
          id: m['id'].toString(),
          title: titleMap?['romaji'] ?? titleMap?['english'] ?? '',
          imageUrl: coverMap?['large'] ?? coverMap?['medium'],
          status: m['status'] as String?,
          // 0-100 like Kitsu's average: weightedScore, else the deprecated averageScore.
          score: switch (AnilistMedia.scoreOf(m)) {
            final double v => (v * 10).round(),
            null => null,
          },
          mediaType: m['format'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('AniList search failed (${e.runtimeType})');
      return [];
    }
  }

  Future<List<TrackerSearchResult>> _searchKitsu(
      String query, String category) async {
    try {
      final api = KitsuApi();
      final response = category == 'anime'
          ? await api.searchAnime(query: query, limit: 15)
          : await api.searchManga(query: query, limit: 15);
      return KitsuApi.flattenCollection(response).map((m) {
        final posterImage = m['posterImage'] as Map<String, dynamic>?;
        return TrackerSearchResult(
          id: m['id'].toString(),
          title: (m['canonicalTitle'] ?? m['titles']?['en_jp'] ?? '') as String,
          imageUrl: posterImage?['small'] ?? posterImage?['medium'],
          status: m['status'] as String?,
          score: m['averageRating'] != null
              ? (double.tryParse(m['averageRating'].toString()) ?? 0).round()
              : null,
          mediaType: m['subtype'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Kitsu search failed (${e.runtimeType})');
      return [];
    }
  }

  Future<List<TrackerSearchResult>> _searchSimkl(
      String query, String category) async {
    try {
      // Simkl lists anime only.
      if (category != 'anime') return [];
      final items = await SimklApi().searchAnime(query);
      final results = <TrackerSearchResult>[];
      for (final m in items) {
        final ids = m['ids'] as Map<String, dynamic>?;
        final rawId = ids?['simkl'] ?? ids?['simkl_id'] ?? m['id'];
        if (rawId == null || int.tryParse(rawId.toString()) == null) continue;
        final poster = m['poster'] as String?;
        results.add(TrackerSearchResult(
          id: rawId.toString(),
          title: (m['title'] ?? '') as String,
          imageUrl:
              poster != null ? 'https://simkl.in/posters/${poster}_m.webp' : null,
          score: (m['ratings']?['simkl']?['rating'] as num?)?.round(),
        ));
      }
      return results;
    } catch (e) {
      debugPrint('Simkl search failed (${e.runtimeType})');
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // Display
  // -------------------------------------------------------------------------

  static String trackerName(AccountType tracker) => switch (tracker) {
        AccountType.anilist => 'AniList',
        AccountType.kitsu => 'Kitsu',
        AccountType.simkl => 'Simkl',
        AccountType.myanimelist => 'MyAnimeList',
        _ => '',
      };

  static String trackerLogo(AccountType tracker) => switch (tracker) {
        AccountType.anilist => 'assets/images/anilist-icon.png',
        AccountType.kitsu => 'assets/images/kitsu-icon.png',
        AccountType.simkl => 'assets/images/simkl-icon.png',
        AccountType.myanimelist => 'assets/images/mal-icon.png',
        _ => '',
      };
}
