import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_api.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_api.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_api.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

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

class TrackerEntryStatus {
  final String? status;
  final int? score;
  final int? progress;
  final String? entryId;

  const TrackerEntryStatus({
    this.status,
    this.score,
    this.progress,
    this.entryId,
  });
}

// ---------------------------------------------------------------------------
// TrackerSyncService
// ---------------------------------------------------------------------------

class TrackerSyncService {
  TrackerSyncService._();
  static final TrackerSyncService _instance = TrackerSyncService._();
  static TrackerSyncService get instance => _instance;

  // -------------------------------------------------------------------------
  // Status mapping: MAL ↔ tracker
  // -------------------------------------------------------------------------

  static const _malToAnilistAnime = {
    'watching': 'CURRENT',
    'completed': 'COMPLETED',
    'on_hold': 'PAUSED',
    'dropped': 'DROPPED',
    'plan_to_watch': 'PLANNING',
  };

  static const _malToAnilistManga = {
    'reading': 'CURRENT',
    'completed': 'COMPLETED',
    'on_hold': 'PAUSED',
    'dropped': 'DROPPED',
    'plan_to_read': 'PLANNING',
  };

  static const _malToKitsuAnime = {
    'watching': 'current',
    'completed': 'completed',
    'on_hold': 'on_hold',
    'dropped': 'dropped',
    'plan_to_watch': 'planned',
  };

  static const _malToKitsuManga = {
    'reading': 'current',
    'completed': 'completed',
    'on_hold': 'on_hold',
    'dropped': 'dropped',
    'plan_to_read': 'planned',
  };

  static const _malToSimklAnime = {
    'watching': 'watching',
    'completed': 'completed',
    'on_hold': 'hold',
    'dropped': 'dropped',
    'plan_to_watch': 'plantowatch',
  };

  static const _malToSimklManga = {
    'reading': 'watching',
    'completed': 'completed',
    'on_hold': 'hold',
    'dropped': 'dropped',
    'plan_to_read': 'plantowatch',
  };

  // Reverse maps (tracker → MAL)
  static final _anilistToMalAnime =
      _malToAnilistAnime.map((k, v) => MapEntry(v, k));
  static final _anilistToMalManga =
      _malToAnilistManga.map((k, v) => MapEntry(v, k));
  static final _kitsuToMalAnime =
      _malToKitsuAnime.map((k, v) => MapEntry(v, k));
  static final _kitsuToMalManga =
      _malToKitsuManga.map((k, v) => MapEntry(v, k));
  static final _simklToMalAnime =
      _malToSimklAnime.map((k, v) => MapEntry(v, k));
  static final _simklToMalManga =
      _malToSimklManga.map((k, v) => MapEntry(v, k));

  String? mapStatusToTracker(
      String malStatus, AccountType tracker, String category) {
    final isAnime = category == 'anime';
    switch (tracker) {
      case AccountType.anilist:
        return (isAnime ? _malToAnilistAnime : _malToAnilistManga)[malStatus];
      case AccountType.kitsu:
        return (isAnime ? _malToKitsuAnime : _malToKitsuManga)[malStatus];
      case AccountType.simkl:
        return (isAnime ? _malToSimklAnime : _malToSimklManga)[malStatus];
      default:
        return null;
    }
  }

  String? mapStatusFromTracker(
      String trackerStatus, AccountType tracker, String category) {
    final isAnime = category == 'anime';
    switch (tracker) {
      case AccountType.anilist:
        return (isAnime ? _anilistToMalAnime : _anilistToMalManga)[
            trackerStatus];
      case AccountType.kitsu:
        return (isAnime ? _kitsuToMalAnime : _kitsuToMalManga)[trackerStatus];
      case AccountType.simkl:
        return (isAnime ? _simklToMalAnime : _simklToMalManga)[trackerStatus];
      default:
        return null;
    }
  }

  // -------------------------------------------------------------------------
  // Score conversion
  // -------------------------------------------------------------------------

  int convertScoreToTracker(int malScore, AccountType tracker) {
    switch (tracker) {
      case AccountType.anilist:
        return malScore * 10; // 0-10 → 0-100
      case AccountType.kitsu:
        return malScore * 2; // 0-10 → 0-20
      case AccountType.simkl:
        return malScore; // 0-10 → 0-10
      default:
        return malScore;
    }
  }

  int convertScoreFromTracker(int trackerScore, AccountType tracker) {
    switch (tracker) {
      case AccountType.anilist:
        return (trackerScore / 10).round(); // 0-100 → 0-10
      case AccountType.kitsu:
        return (trackerScore / 2).round(); // 0-20 → 0-10
      case AccountType.simkl:
        return trackerScore; // 0-10 → 0-10
      default:
        return trackerScore;
    }
  }

  // -------------------------------------------------------------------------
  // Link cache (SharedPreferences)
  // -------------------------------------------------------------------------

  String _linkKey(int malId, String category, AccountType tracker) =>
      'tracker_link_${malId}_${category}_${tracker.name}';

  Future<String?> getLinkId(
      int malId, String category, AccountType tracker) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_linkKey(malId, category, tracker));
  }

  Future<void> saveLinkId(
      int malId, String category, AccountType tracker, String trackerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_linkKey(malId, category, tracker), trackerId);
  }

  Future<void> removeLinkId(
      int malId, String category, AccountType tracker) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_linkKey(malId, category, tracker));
  }

  // -------------------------------------------------------------------------
  // Search
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
      final type = category == 'anime' ? 'ANIME' : 'MANGA';
      final response = await AnilistApi.searchMedia(
        type: type,
        search: query,
        perPage: 15,
      );
      final page = response['data']?['Page'];
      final media = page?['media'] as List<dynamic>? ?? [];
      return media.map((item) {
        final m = item as Map<String, dynamic>;
        final titleMap = m['title'] as Map<String, dynamic>?;
        final coverMap = m['coverImage'] as Map<String, dynamic>?;
        return TrackerSearchResult(
          id: m['id'].toString(),
          title: titleMap?['romaji'] ?? titleMap?['english'] ?? '',
          imageUrl: coverMap?['large'] ?? coverMap?['medium'],
          status: m['status'] as String?,
          score: m['averageScore'] as int?,
          mediaType: m['format'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('AniList search error: $e');
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
      final items = KitsuApi.flattenCollection(response);
      return items.map((m) {
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
      debugPrint('Kitsu search error: $e');
      return [];
    }
  }

  Future<List<TrackerSearchResult>> _searchSimkl(
      String query, String category) async {
    try {
      final api = SimklApi();
      // Simkl search only supports anime; for manga we return empty
      if (category != 'anime') return [];
      final items = await api.searchAnime(query);
      debugPrint('Simkl search raw: ${items.length} results');
      if (items.isNotEmpty) {
        debugPrint('Simkl first result keys: ${items.first.keys}');
        debugPrint('Simkl first result ids: ${items.first['ids']}');
      }
      final results = <TrackerSearchResult>[];
      for (final m in items) {
        final ids = m['ids'] as Map<String, dynamic>?;
        final rawId = ids?['simkl'] ?? ids?['simkl_id'] ?? m['id'];
        if (rawId == null) continue;
        final idStr = rawId.toString();
        if (int.tryParse(idStr) == null) continue; // skip non-integer IDs
        final poster = m['poster'] as String?;
        final imageUrl =
            poster != null ? 'https://simkl.in/posters/${poster}_m.webp' : null;
        results.add(TrackerSearchResult(
          id: idStr,
          title: (m['title'] ?? '') as String,
          imageUrl: imageUrl,
          score: m['ratings']?['simkl']?['rating'] as int?,
        ));
      }
      return results;
    } catch (e) {
      debugPrint('Simkl search error: $e');
      return [];
    }
  }

  // -------------------------------------------------------------------------
  // Get entry status from tracker
  // -------------------------------------------------------------------------

  Future<TrackerEntryStatus?> getEntryStatus(
      AccountType tracker, String trackerId, String category) async {
    switch (tracker) {
      case AccountType.anilist:
        return _getAnilistStatus(trackerId);
      case AccountType.kitsu:
        return _getKitsuStatus(trackerId, category);
      case AccountType.simkl:
        // Simkl doesn't have a simple per-item status lookup
        return null;
      default:
        return null;
    }
  }

  Future<TrackerEntryStatus?> _getAnilistStatus(String mediaId) async {
    try {
      final user = AnilistUser();
      final response = await user.getMediaListEntry(int.parse(mediaId));
      final entry = response['data']?['MediaList'];
      if (entry == null) return null;
      return TrackerEntryStatus(
        status: entry['status'] as String?,
        score: entry['score'] != null ? (entry['score'] as num).toInt() : null,
        progress: entry['progress'] as int?,
        entryId: entry['id']?.toString(),
      );
    } catch (e) {
      debugPrint('AniList getEntryStatus error: $e');
      return null;
    }
  }

  Future<TrackerEntryStatus?> _getKitsuStatus(
      String mediaId, String category) async {
    try {
      final user = KitsuUser();
      final response = await user.getLibraryEntryForMedia(
        mediaId: mediaId,
        mediaType: category,
      );
      if (response == null) return null;
      final attrs = response['attributes'] as Map<String, dynamic>?;
      if (attrs == null) return null;
      final ratingTwenty = attrs['ratingTwenty'];
      return TrackerEntryStatus(
        status: attrs['status'] as String?,
        score: ratingTwenty != null
            ? convertScoreFromTracker(
                (ratingTwenty as num).toInt(), AccountType.kitsu)
            : null,
        progress: attrs['progress'] as int?,
        entryId: response['id']?.toString(),
      );
    } catch (e) {
      debugPrint('Kitsu getEntryStatus error: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Update status on tracker
  // -------------------------------------------------------------------------

  Future<bool> updateStatus(
    AccountType tracker,
    String trackerId,
    String category, {
    String? malStatus,
    int? malScore,
    int? progress,
    int? malId,
  }) async {
    // Reject invalid/stale link IDs
    if (trackerId == 'null' || trackerId.isEmpty) return false;
    switch (tracker) {
      case AccountType.anilist:
        return _updateAnilist(trackerId, category,
            malStatus: malStatus, malScore: malScore, progress: progress);
      case AccountType.kitsu:
        return _updateKitsu(trackerId, category,
            malStatus: malStatus, malScore: malScore, progress: progress);
      case AccountType.simkl:
        return _updateSimkl(trackerId, category,
            malStatus: malStatus, malScore: malScore, malId: malId);
      default:
        return false;
    }
  }

  Future<bool> _updateAnilist(String mediaId, String category,
      {String? malStatus, int? malScore, int? progress}) async {
    try {
      final user = AnilistUser();
      final status = malStatus != null
          ? mapStatusToTracker(malStatus, AccountType.anilist, category)
          : null;
      final score = malScore != null && malScore > 0
          ? convertScoreToTracker(malScore, AccountType.anilist).toDouble()
          : null;
      await user.saveMediaListEntry(
        mediaId: int.parse(mediaId),
        status: status,
        score: score,
        progress: progress,
      );
      return true;
    } catch (e) {
      debugPrint('AniList update error: $e');
      return false;
    }
  }

  Future<bool> _updateKitsu(String mediaId, String category,
      {String? malStatus, int? malScore, int? progress}) async {
    try {
      final parsedMediaId = int.tryParse(mediaId);
      if (parsedMediaId == null) return false;

      final user = KitsuUser();
      final status = malStatus != null
          ? mapStatusToTracker(malStatus, AccountType.kitsu, category)
          : null;
      final ratingTwenty = malScore != null && malScore > 0
          ? convertScoreToTracker(malScore, AccountType.kitsu).toDouble()
          : null;

      // Check if entry already exists
      final existing =
          await user.getLibraryEntryForMedia(mediaId: mediaId, mediaType: category);

      if (existing != null) {
        // Update existing entry
        final entryId = existing['id'].toString();
        await user.updateLibraryEntry(
          entryId: entryId,
          status: status,
          progress: progress,
          ratingTwenty: ratingTwenty,
        );
      } else {
        // Create new entry, then update with score/progress if needed
        try {
          final created = await user.createLibraryEntry(
            mediaId: parsedMediaId,
            mediaType: category,
            status: status ?? 'planned',
          );
          // If we also need to set score or progress, update the created entry
          if ((ratingTwenty != null || progress != null) && created['data'] != null) {
            final entryId = (created['data'] as Map)['id'].toString();
            await user.updateLibraryEntry(
              entryId: entryId,
              ratingTwenty: ratingTwenty,
              progress: progress,
            );
          }
        } catch (_) {
          // 403 often means entry already exists but wasn't found by filter
          // Try fetching again and updating
          final retry = await user.getLibraryEntryForMedia(
              mediaId: mediaId, mediaType: category);
          if (retry != null) {
            final entryId = retry['id'].toString();
            await user.updateLibraryEntry(
              entryId: entryId,
              status: status,
              progress: progress,
              ratingTwenty: ratingTwenty,
            );
          } else {
            rethrow;
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Kitsu update error: $e');
      return false;
    }
  }

  Future<bool> _updateSimkl(String simklId, String category,
      {String? malStatus, int? malScore, int? malId}) async {
    try {
      if (category != 'anime') return false;
      final user = SimklUser();
      final status = malStatus != null
          ? mapStatusToTracker(malStatus, AccountType.simkl, category)
          : null;
      // Build IDs map: prefer MAL ID (most reliable for Simkl), include simkl ID too
      final ids = <String, dynamic>{};
      if (malId != null) ids['mal'] = malId;
      final parsedSimklId = int.tryParse(simklId);
      if (parsedSimklId != null) ids['simkl'] = parsedSimklId;
      if (ids.isEmpty) return false;

      final item = <String, dynamic>{
        'ids': ids,
        if (status != null) 'to': status,
        if (malScore != null && malScore > 0)
          'rating': convertScoreToTracker(malScore, AccountType.simkl),
      };
      // Simkl uses "anime" key for anime in sync endpoints
      debugPrint('Simkl addToList body: ${{
        'anime': [item]
      }}');
      await user.addToList({'anime': [item]});
      return true;
    } catch (e) {
      debugPrint('Simkl update error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Delete entry from tracker
  // -------------------------------------------------------------------------

  Future<bool> deleteEntry(
      AccountType tracker, String trackerId, String category,
      {int? malId}) async {
    if (trackerId == 'null' || trackerId.isEmpty) return false;
    switch (tracker) {
      case AccountType.anilist:
        return _deleteAnilist(trackerId);
      case AccountType.kitsu:
        return _deleteKitsu(trackerId, category);
      case AccountType.simkl:
        return _deleteSimkl(trackerId, category, malId: malId);
      default:
        return false;
    }
  }

  Future<bool> _deleteAnilist(String mediaId) async {
    try {
      // We need the entry ID, not the media ID
      final status = await _getAnilistStatus(mediaId);
      if (status?.entryId == null) return false;
      final user = AnilistUser();
      await user.deleteMediaListEntry(int.parse(status!.entryId!));
      return true;
    } catch (e) {
      debugPrint('AniList delete error: $e');
      return false;
    }
  }

  Future<bool> _deleteKitsu(String mediaId, String category) async {
    try {
      final user = KitsuUser();
      final existing =
          await user.getLibraryEntryForMedia(mediaId: mediaId, mediaType: category);
      if (existing == null) return false;
      await user.deleteLibraryEntry(existing['id'].toString());
      return true;
    } catch (e) {
      debugPrint('Kitsu delete error: $e');
      return false;
    }
  }

  Future<bool> _deleteSimkl(String simklId, String category,
      {int? malId}) async {
    try {
      if (category != 'anime') return false;
      final ids = <String, dynamic>{};
      if (malId != null) ids['mal'] = malId;
      final parsedId = int.tryParse(simklId);
      if (parsedId != null) ids['simkl'] = parsedId;
      if (ids.isEmpty) return false;

      final user = SimklUser();
      await user.removeFromList({
        'anime': [
          {'ids': ids}
        ]
      });
      return true;
    } catch (e) {
      debugPrint('Simkl delete error: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Tracker display name
  // -------------------------------------------------------------------------

  static String trackerName(AccountType tracker) {
    switch (tracker) {
      case AccountType.anilist:
        return 'AniList';
      case AccountType.kitsu:
        return 'Kitsu';
      case AccountType.simkl:
        return 'Simkl';
      case AccountType.myanimelist:
        return 'MyAnimeList';
      default:
        return '';
    }
  }

  static String trackerLogo(AccountType tracker) {
    switch (tracker) {
      case AccountType.anilist:
        return 'assets/images/anilist-icon.png';
      case AccountType.kitsu:
        return 'assets/images/kitsu-icon.png';
      case AccountType.simkl:
        return 'assets/images/simkl-icon.png';
      case AccountType.myanimelist:
        return 'assets/images/mal-icon.png';
      default:
        return '';
    }
  }
}
