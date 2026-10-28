import 'package:flutter/foundation.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user_prof.dart';

class AnilistUser {
  static const String userBaseEndPoint = 'https://graphql.anilist.co';

  /// Authenticated GraphQL request through the account's session (token renewed, one replay on
  /// 401); answers `{'data': …}`.
  Future<Map<String, dynamic>> _authenticatedGraphqlQuery(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final data = await AnilistGraphql.instance
        .query(query, variables: variables ?? const {}, auth: true);
    return {'data': data};
  }

  /// Get the authenticated user's profile information.
  Future<AnilistUserProf> getUserInfo() async {
    const query = '''
    query {
      Viewer {
        id
        name
        avatar {
          large
        }
        bannerImage
        about
        isFollowing
        isBlocked
        bans
      }
    }
    ''';
    final response = await _authenticatedGraphqlQuery(query);
    return AnilistUserProf.fromJson(response['data']['Viewer']);
  }

  /// Get a user's media list (anime or manga).
  Future<Map<String, dynamic>> getUserMediaList({
    required int userId,
    String type = 'ANIME',
    String? status,
  }) async {
    const query = '''
    query (
      \$userId: Int,
      \$type: MediaType,
      \$status: MediaListStatus
    ) {
      MediaListCollection(userId: \$userId, type: \$type, status: \$status) {
        lists {
          name
          entries {
            id
            mediaId
            status
            score
            progress
            media {
              id
              title {
                romaji
                english
              }
              coverImage {
                large
              }
            }
          }
        }
      }
    }
    ''';

    final variables = <String, dynamic>{
      'userId': userId,
      'type': type,
      if (status != null) 'status': status,
    };

    final response = await _authenticatedGraphqlQuery(
      query,
      variables: variables,
    );
    debugPrint('AniList getUserMediaList response for userId: $userId');
    return response;
  }

  /// Save (create or update) a media list entry.
  Future<Map<String, dynamic>> saveMediaListEntry({
    required int mediaId,
    String? status,
    double? score,
    int? progress,
  }) async {
    const query = '''
    mutation (
      \$mediaId: Int,
      \$status: MediaListStatus,
      \$score: Float,
      \$progress: Int
    ) {
      SaveMediaListEntry(
        mediaId: \$mediaId,
        status: \$status,
        score: \$score,
        progress: \$progress
      ) {
        id
        status
        score
        progress
      }
    }
    ''';

    final variables = <String, dynamic>{
      'mediaId': mediaId,
      if (status != null) 'status': status,
      if (score != null) 'score': score,
      if (progress != null) 'progress': progress,
    };

    final response = await _authenticatedGraphqlQuery(
      query,
      variables: variables,
    );
    debugPrint('AniList saveMediaListEntry response for mediaId: $mediaId');
    return response;
  }

  /// Delete a media list entry.
  Future<Map<String, dynamic>> deleteMediaListEntry(int id) async {
    const query = '''
    mutation (\$id: Int) {
      DeleteMediaListEntry(id: \$id) {
        deleted
      }
    }
    ''';

    final response = await _authenticatedGraphqlQuery(
      query,
      variables: {'id': id},
    );
    debugPrint('AniList deleteMediaListEntry response for id: $id');
    return response;
  }

  /// Get the authenticated user's media list entry for a specific media.
  Future<Map<String, dynamic>> getMediaListEntry(int mediaId) async {
    const query = '''
    query (\$mediaId: Int) {
      MediaList(mediaId: \$mediaId) {
        id
        status
        score
        progress
      }
    }
    ''';

    final response = await _authenticatedGraphqlQuery(
      query,
      variables: {'mediaId': mediaId},
    );
    debugPrint('AniList getMediaListEntry response for mediaId: $mediaId');
    return response;
  }

  /// Get a user's anime and manga statistics.
  Future<Map<String, dynamic>> getUserStatistics(int userId) async {
    const query = '''
    query (\$id: Int) {
      User(id: \$id) {
        statistics {
          anime {
            count
            meanScore
            minutesWatched
            episodesWatched
          }
          manga {
            count
            meanScore
            chaptersRead
            volumesRead
          }
        }
      }
    }
    ''';

    final response = await _authenticatedGraphqlQuery(
      query,
      variables: {'id': userId},
    );
    debugPrint('AniList getUserStatistics response for userId: $userId');
    return response;
  }
}
