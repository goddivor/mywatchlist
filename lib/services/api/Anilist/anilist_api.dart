import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';

class AnilistApi {
  static const String _baseUrl = Constants.anilistApiUrl;

  /// Helper method for GraphQL POST requests (no auth needed for public queries).
  static Future<Map<String, dynamic>> _graphqlQuery(
    String query, {
    Map<String, dynamic>? variables,
    String? accessToken,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode({
        'query': query,
        if (variables != null) 'variables': variables,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('AniList GraphQL query failed: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('AniList GraphQL query failed: ${response.statusCode}');
    }
  }

  /// Search for media (anime/manga) with various filters.
  static Future<Map<String, dynamic>> searchMedia({
    String? type,
    String? search,
    int? page,
    int? perPage,
    String? sort,
    String? season,
    int? seasonYear,
    List<String>? genres,
  }) async {
    const query = '''
    query (
      \$type: MediaType,
      \$search: String,
      \$page: Int,
      \$perPage: Int,
      \$sort: [MediaSort],
      \$season: MediaSeason,
      \$seasonYear: Int,
      \$genres: [String]
    ) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
          perPage
        }
        media(
          type: \$type,
          search: \$search,
          sort: \$sort,
          season: \$season,
          seasonYear: \$seasonYear,
          genre_in: \$genres
        ) {
          id
          title {
            romaji
            english
            native
          }
          coverImage {
            large
            medium
          }
          bannerImage
          format
          status
          episodes
          chapters
          volumes
          averageScore
          popularity
          description
          startDate {
            year
            month
            day
          }
          endDate {
            year
            month
            day
          }
          genres
          tags {
            name
          }
        }
      }
    }
    ''';

    final variables = <String, dynamic>{
      if (type != null) 'type': type,
      if (search != null) 'search': search,
      if (page != null) 'page': page,
      if (perPage != null) 'perPage': perPage,
      if (sort != null) 'sort': [sort],
      if (season != null) 'season': season,
      if (seasonYear != null) 'seasonYear': seasonYear,
      if (genres != null) 'genres': genres,
    };

    final response = await _graphqlQuery(query, variables: variables);
    debugPrint('AniList searchMedia response received');
    return response;
  }

  /// Get detailed information about a specific media entry.
  static Future<Map<String, dynamic>> getMediaDetails(int id) async {
    const query = '''
    query (\$id: Int) {
      Media(id: \$id) {
        id
        title {
          romaji
          english
          native
          userPreferred
        }
        coverImage {
          extraLarge
          large
          medium
        }
        bannerImage
        type
        format
        status
        description
        season
        seasonYear
        episodes
        duration
        chapters
        volumes
        averageScore
        meanScore
        popularity
        favourites
        genres
        studios {
          nodes {
            id
            name
          }
        }
        tags {
          id
          name
          rank
        }
        startDate {
          year
          month
          day
        }
        endDate {
          year
          month
          day
        }
        nextAiringEpisode {
          airingAt
          timeUntilAiring
          episode
        }
        recommendations {
          nodes {
            mediaRecommendation {
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
        relations {
          edges {
            node {
              id
              title {
                romaji
                english
              }
              coverImage {
                large
              }
              type
              format
            }
            relationType
          }
        }
        characters {
          edges {
            node {
              id
              name {
                full
                native
              }
              image {
                large
              }
            }
            role
            voiceActors(language: JAPANESE) {
              id
              name {
                full
                native
              }
              image {
                large
              }
            }
          }
        }
      }
    }
    ''';

    final response = await _graphqlQuery(query, variables: {'id': id});
    debugPrint('AniList getMediaDetails response for id: $id');
    return response['data']['Media'] as Map<String, dynamic>;
  }

  /// Get trending media.
  static Future<Map<String, dynamic>> getTrending({
    String? type,
    int page = 1,
    int perPage = 20,
  }) async {
    const query = '''
    query (\$type: MediaType, \$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
          perPage
        }
        media(type: \$type, sort: TRENDING_DESC) {
          id
          title {
            romaji
            english
          }
          coverImage {
            large
          }
          averageScore
          popularity
        }
      }
    }
    ''';

    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      if (type != null) 'type': type,
    };

    final response = await _graphqlQuery(query, variables: variables);
    debugPrint('AniList getTrending response received');
    return response;
  }

  /// Get airing schedule for the next 7 days.
  static Future<Map<String, dynamic>> getAiringSchedule({
    int page = 1,
    int perPage = 20,
  }) async {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    final airingAtGreater = now.millisecondsSinceEpoch ~/ 1000;
    final airingAtLesser = weekFromNow.millisecondsSinceEpoch ~/ 1000;

    const query = '''
    query (
      \$page: Int,
      \$perPage: Int,
      \$airingAtGreater: Int,
      \$airingAtLesser: Int
    ) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
          perPage
        }
        airingSchedules(
          airingAt_greater: \$airingAtGreater,
          airingAt_lesser: \$airingAtLesser,
          sort: TIME
        ) {
          id
          airingAt
          timeUntilAiring
          episode
          media {
            id
            title {
              romaji
              english
            }
            coverImage {
              large
            }
            format
            episodes
            averageScore
          }
        }
      }
    }
    ''';

    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
      'airingAtGreater': airingAtGreater,
      'airingAtLesser': airingAtLesser,
    };

    final response = await _graphqlQuery(query, variables: variables);
    debugPrint('AniList getAiringSchedule response received');
    return response;
  }

  /// Get detailed information about a specific character.
  static Future<Map<String, dynamic>> getCharacterDetails(int id) async {
    const query = '''
    query (\$id: Int) {
      Character(id: \$id) {
        id
        name {
          full
          native
          alternative
        }
        image {
          large
        }
        description
        age
        gender
        dateOfBirth {
          year
          month
          day
        }
        favourites
        media {
          edges {
            node {
              id
              title {
                romaji
                english
              }
              coverImage {
                large
              }
              type
            }
          }
        }
      }
    }
    ''';

    final response = await _graphqlQuery(query, variables: {'id': id});
    debugPrint('AniList getCharacterDetails response for id: $id');
    return response['data']['Character'] as Map<String, dynamic>;
  }

  /// Get detailed information about a specific staff member.
  static Future<Map<String, dynamic>> getStaffDetails(int id) async {
    const query = '''
    query (\$id: Int) {
      Staff(id: \$id) {
        id
        name {
          full
          native
        }
        image {
          large
        }
        description
        primaryOccupations
        gender
        dateOfBirth {
          year
          month
          day
        }
        age
        homeTown
        favourites
        staffMedia {
          edges {
            node {
              id
              title {
                romaji
                english
              }
              coverImage {
                large
              }
              type
            }
          }
        }
        characters {
          edges {
            node {
              id
              name {
                full
              }
              image {
                large
              }
            }
          }
        }
      }
    }
    ''';

    final response = await _graphqlQuery(query, variables: {'id': id});
    debugPrint('AniList getStaffDetails response for id: $id');
    return response['data']['Staff'] as Map<String, dynamic>;
  }

  /// Get detailed information about a specific studio.
  static Future<Map<String, dynamic>> getStudioDetails(int id) async {
    const query = '''
    query (\$id: Int) {
      Studio(id: \$id) {
        id
        name
        isAnimationStudio
        favourites
        media {
          nodes {
            id
            title {
              romaji
              english
            }
            coverImage {
              large
            }
            type
            averageScore
          }
        }
      }
    }
    ''';

    final response = await _graphqlQuery(query, variables: {'id': id});
    debugPrint('AniList getStudioDetails response for id: $id');
    return response['data']['Studio'] as Map<String, dynamic>;
  }

  /// Get media recommendations.
  static Future<Map<String, dynamic>> getRecommendations({
    String? type,
    int page = 1,
    int perPage = 20,
  }) async {
    const query = '''
    query (\$page: Int, \$perPage: Int) {
      Page(page: \$page, perPage: \$perPage) {
        pageInfo {
          total
          currentPage
          lastPage
          hasNextPage
          perPage
        }
        recommendations(sort: RATING_DESC) {
          id
          rating
          media {
            id
            title {
              romaji
              english
            }
            coverImage {
              large
            }
            type
            format
            averageScore
          }
          mediaRecommendation {
            id
            title {
              romaji
              english
            }
            coverImage {
              large
            }
            type
            format
            averageScore
          }
        }
      }
    }
    ''';

    final variables = <String, dynamic>{
      'page': page,
      'perPage': perPage,
    };

    final response = await _graphqlQuery(query, variables: variables);
    debugPrint('AniList getRecommendations response received');
    return response;
  }
}
