import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';

/// Manages search history: query strings + recently viewed anime/manga.
/// Uses SharedPreferences for persistence and StreamControllers for reactive updates.
class SearchHistory {
  static const String _queryHistoryKey = 'search_query_history';
  static const String _recentAnimeKey = 'search_recent_anime';
  static const String _recentMangaKey = 'search_recent_manga';
  static const String _displayTypeKey = 'search_display_type';
  static const String _displaySubTypeKey = 'search_display_sub_type';
  static const String _gridAxisCountKey = 'search_grid_axis_count';
  static const String _gridHeightKey = 'search_grid_height';
  static const int maxQueries = 7;
  static const int maxRecentItems = 24;

  static SearchHistory? _instance;
  static SearchHistory get instance => _instance ??= SearchHistory._();

  SearchHistory._();

  final _queryController = StreamController<List<String>>.broadcast();
  final _recentAnimeController = StreamController<List<Anime>>.broadcast();
  final _recentMangaController = StreamController<List<Anime>>.broadcast();

  Stream<List<String>> get queryHistoryStream => _queryController.stream;
  Stream<List<Anime>> get recentAnimeStream => _recentAnimeController.stream;
  Stream<List<Anime>> get recentMangaStream => _recentMangaController.stream;

  List<String> _queries = [];
  List<Anime> _recentAnime = [];
  List<Anime> _recentManga = [];

  List<String> get queries => _queries;
  List<Anime> get recentAnime => _recentAnime;
  List<Anime> get recentManga => _recentManga;

  // Display settings
  DisplayType displayType = DisplayType.grid;
  DisplaySubType displaySubType = DisplaySubType.compact;
  int gridAxisCount = 3;
  double gridHeight = 200;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    _queries = prefs.getStringList(_queryHistoryKey) ?? [];

    final animeJson = prefs.getStringList(_recentAnimeKey) ?? [];
    _recentAnime = animeJson
        .map((s) {
          try {
            return Anime.fromMAlJson(json.decode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Anime>()
        .toList();

    final mangaJson = prefs.getStringList(_recentMangaKey) ?? [];
    _recentManga = mangaJson
        .map((s) {
          try {
            return Anime.fromMAlJson(json.decode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Anime>()
        .toList();

    // Load display settings
    final dtIndex = prefs.getInt(_displayTypeKey);
    if (dtIndex != null && dtIndex < DisplayType.values.length) {
      displayType = DisplayType.values[dtIndex];
    }
    final dstIndex = prefs.getInt(_displaySubTypeKey);
    if (dstIndex != null && dstIndex < DisplaySubType.values.length) {
      displaySubType = DisplaySubType.values[dstIndex];
    }
    gridAxisCount = prefs.getInt(_gridAxisCountKey) ?? 3;
    gridHeight = prefs.getDouble(_gridHeightKey) ?? 200;

    _loaded = true;
    _notifyAll();
  }

  // --- Query history ---

  Future<void> addQuery(String query) async {
    query = query.trim();
    if (query.isEmpty || query.length < 3 || query.startsWith('#')) return;

    _queries.remove(query);
    _queries.insert(0, query);
    if (_queries.length > maxQueries) {
      _queries = _queries.sublist(0, maxQueries);
    }

    _queryController.add(_queries);
    await _saveQueries();
  }

  Future<void> removeQuery(String query) async {
    _queries.remove(query);
    _queryController.add(_queries);
    await _saveQueries();
  }

  Future<void> clearQueries() async {
    _queries.clear();
    _queryController.add(_queries);
    await _saveQueries();
  }

  Future<void> _saveQueries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_queryHistoryKey, _queries);
  }

  // --- Recent anime ---

  Future<void> addRecentAnime(Anime anime) async {
    _recentAnime.removeWhere((a) => a.id == anime.id);
    _recentAnime.insert(0, anime);
    if (_recentAnime.length > maxRecentItems) {
      _recentAnime = _recentAnime.sublist(0, maxRecentItems);
    }

    _recentAnimeController.add(_recentAnime);
    await _saveRecentAnime();
  }

  Future<void> removeRecentAnime(int animeId) async {
    _recentAnime.removeWhere((a) => a.id == animeId);
    _recentAnimeController.add(_recentAnime);
    await _saveRecentAnime();
  }

  Future<void> clearRecentAnime() async {
    _recentAnime.clear();
    _recentAnimeController.add(_recentAnime);
    await _saveRecentAnime();
  }

  Future<void> _saveRecentAnime() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recentAnime.map((a) => json.encode(a.toJson())).toList();
    await prefs.setStringList(_recentAnimeKey, list);
  }

  // --- Recent manga ---

  Future<void> addRecentManga(Anime manga) async {
    _recentManga.removeWhere((a) => a.id == manga.id);
    _recentManga.insert(0, manga);
    if (_recentManga.length > maxRecentItems) {
      _recentManga = _recentManga.sublist(0, maxRecentItems);
    }

    _recentMangaController.add(_recentManga);
    await _saveRecentManga();
  }

  Future<void> removeRecentManga(int mangaId) async {
    _recentManga.removeWhere((a) => a.id == mangaId);
    _recentMangaController.add(_recentManga);
    await _saveRecentManga();
  }

  Future<void> clearRecentManga() async {
    _recentManga.clear();
    _recentMangaController.add(_recentManga);
    await _saveRecentManga();
  }

  Future<void> _saveRecentManga() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recentManga.map((a) => json.encode(a.toJson())).toList();
    await prefs.setStringList(_recentMangaKey, list);
  }

  Future<void> saveDisplaySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayTypeKey, displayType.index);
    await prefs.setInt(_displaySubTypeKey, displaySubType.index);
    await prefs.setInt(_gridAxisCountKey, gridAxisCount);
    await prefs.setDouble(_gridHeightKey, gridHeight);
  }

  void _notifyAll() {
    _queryController.add(_queries);
    _recentAnimeController.add(_recentAnime);
    _recentMangaController.add(_recentManga);
  }

  void dispose() {
    _queryController.close();
    _recentAnimeController.close();
    _recentMangaController.close();
  }
}
