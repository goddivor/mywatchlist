import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mywatchlist/constants/constants.dart';

/// Simkl API client for public endpoints
class SimklApi {
  static const String _baseUrl = Constants.simklApiBaseUrl;
  static final String _clientId = Constants.simklClientId;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'simkl-api-key': _clientId,
  };

  // Search anime - GET /search/anime
  Future<List<Map<String, dynamic>>> searchAnime(String query, {int? page, int? limit}) async {
    final params = <String, String>{
      'q': query,
      'client_id': _clientId,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/search/anime').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data as List);
    }
    throw Exception('Failed to search anime on Simkl');
  }

  // Get anime details - GET /anime/{id}
  Future<Map<String, dynamic>> getAnimeDetails(int id) async {
    final params = <String, String>{'client_id': _clientId, 'extended': 'full'};
    final uri = Uri.parse('$_baseUrl/anime/$id').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get anime details from Simkl');
  }

  // Search TV shows - GET /search/tv
  Future<List<Map<String, dynamic>>> searchTv(String query, {int? page, int? limit}) async {
    final params = <String, String>{
      'q': query,
      'client_id': _clientId,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/search/tv').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to search TV shows on Simkl');
  }

  // Search movies - GET /search/movie
  Future<List<Map<String, dynamic>>> searchMovie(String query, {int? page, int? limit}) async {
    final params = <String, String>{
      'q': query,
      'client_id': _clientId,
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
    final uri = Uri.parse('$_baseUrl/search/movie').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body) as List);
    }
    throw Exception('Failed to search movies on Simkl');
  }
}
