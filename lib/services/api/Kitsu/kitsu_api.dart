import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';

/// Kitsu API client for public endpoints (no auth required)
class KitsuApi {
  static const String _baseUrl = Constants.kitsuApiUrl;

  static const Map<String, String> _headers = {
    'Accept': 'application/vnd.api+json',
    'Content-Type': 'application/vnd.api+json',
  };

  // Helper to flatten a JSON:API resource
  static Map<String, dynamic> flattenResource(Map<String, dynamic> resource) {
    return {
      'id': resource['id'],
      'type': resource['type'],
      ...resource['attributes'] as Map<String, dynamic>,
    };
  }

  // Helper to flatten a JSON:API collection response
  static List<Map<String, dynamic>> flattenCollection(Map<String, dynamic> response) {
    final data = response['data'] as List<dynamic>;
    return data.map((item) => flattenResource(item as Map<String, dynamic>)).toList();
  }

  // Search anime - GET /anime
  Future<Map<String, dynamic>> searchAnime({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (query != null) 'filter[text]': query,
      'page[limit]': limit.toString(),
      'page[offset]': offset.toString(),
    };
    final uri = Uri.parse('$_baseUrl/anime').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to search anime on Kitsu');
  }

  // Get anime details - GET /anime/{id}
  Future<Map<String, dynamic>> getAnimeDetails(int id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/anime/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return flattenResource(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to get anime details from Kitsu');
  }

  // Search manga - GET /manga
  Future<Map<String, dynamic>> searchManga({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (query != null) 'filter[text]': query,
      'page[limit]': limit.toString(),
      'page[offset]': offset.toString(),
    };
    final uri = Uri.parse('$_baseUrl/manga').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to search manga on Kitsu');
  }

  // Get manga details - GET /manga/{id}
  Future<Map<String, dynamic>> getMangaDetails(int id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/manga/$id'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return flattenResource(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Failed to get manga details from Kitsu');
  }

  // Get trending anime - GET /trending/anime
  Future<List<Map<String, dynamic>>> getTrendingAnime({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/anime?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return flattenCollection(data as Map<String, dynamic>);
    }
    throw Exception('Failed to get trending anime from Kitsu');
  }

  // Get trending manga - GET /trending/manga
  Future<List<Map<String, dynamic>>> getTrendingManga({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/manga?limit=$limit'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return flattenCollection(data as Map<String, dynamic>);
    }
    throw Exception('Failed to get trending manga from Kitsu');
  }

  // Get categories - GET /categories
  Future<Map<String, dynamic>> getCategories({int limit = 20, int offset = 0}) async {
    final params = <String, String>{
      'page[limit]': limit.toString(),
      'page[offset]': offset.toString(),
    };
    final uri = Uri.parse('$_baseUrl/categories').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get categories from Kitsu');
  }

  // Get genres - GET /genres
  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/genres?page[limit]=100'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return flattenCollection(data as Map<String, dynamic>);
    }
    throw Exception('Failed to get genres from Kitsu');
  }
}
