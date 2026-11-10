import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One row of the community list of the most loved MyAnimeList characters.
@immutable
class TopChar {
  final int id;
  final int favorites;
  final String? name;

  const TopChar({required this.id, required this.favorites, this.name});
}

/// Where [TopCharacters] keeps the downloaded list between launches.
abstract class TopCharactersStore {
  /// The saved body when it is younger than [maxAge], else null.
  Future<String?> read(Duration maxAge);

  Future<void> write(String body);
}

/// Keeps the list in one file of the temporary directory (a list of about a megabyte does not
/// belong in SharedPreferences, which the app loads whole at start).
class FileTopCharactersStore implements TopCharactersStore {
  const FileTopCharactersStore();

  Future<File> _file() async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}${Platform.pathSeparator}top_mal_characters.json');
  }

  @override
  Future<String?> read(Duration maxAge) async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      return age < maxAge ? await file.readAsString() : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String body) async {
    try {
      await (await _file()).writeAsString(body, flush: true);
    } catch (_) {
      // No disk (web, full storage): the list is simply downloaded again next time.
    }
  }
}

/// The latest Top MAL characters (100 favorites or more), DailyAL `TopCharactersManager`.
///
/// Data source: https://github.com/Joelis57/TopMalCharacters (raw files in `/data`). The
/// character screen reads [favoritesOf] for an instant favorites count and the Explore page can
/// use [topIds]. The download is parsed off the UI isolate and kept for one hour.
///
/// ```dart
/// await TopCharacters.instance.ensureLoaded();
/// final favorites = TopCharacters.instance.favoritesOf(417); // null when below 100
/// ```
class TopCharacters {
  TopCharacters({
    Future<String?> Function(Uri url)? download,
    TopCharactersStore store = const FileTopCharactersStore(),
    Future<List<TopChar>> Function(String body)? parser,
  })  : _download = download ?? _httpDownload,
        _store = store,
        _parser = parser ?? _parseOffIsolate;

  static final TopCharacters instance = TopCharacters();

  static const String _base = 'https://raw.githubusercontent.com/Joelis57/TopMalCharacters/main/data';
  static const List<String> _candidateFiles = ['top_characters.min.json', 'top_characters.json'];

  /// How long a downloaded list is trusted.
  static const Duration maxAge = Duration(hours: 1);

  final Future<String?> Function(Uri url) _download;
  final TopCharactersStore _store;
  final Future<List<TopChar>> Function(String body) _parser;

  final Map<int, TopChar> _byId = {};
  List<int> _sortedIds = const [];
  Future<void>? _loading;
  bool _loaded = false;

  bool get isLoaded => _loaded;

  /// Ids ordered by favorites, most loved first.
  List<int> get topIds => _sortedIds;

  int? favoritesOf(int id) => _byId[id]?.favorites;

  TopChar? characterOf(int id) => _byId[id];

  /// Favorites by character id.
  Map<int, int> favoritesMap() => {for (final e in _byId.entries) e.key: e.value.favorites};

  /// Loads the list once (from disk when fresh, else downloaded); [force] downloads it again.
  /// Concurrent callers share one load. Never throws: offline leaves the list empty.
  Future<void> ensureLoaded({bool force = false}) {
    if (!force && _loaded && _byId.isNotEmpty) return Future.value();
    return _loading ??= _load(force).whenComplete(() => _loading = null);
  }

  Future<void> _load(bool force) async {
    if (!force) {
      final saved = await _store.read(maxAge);
      if (saved != null && saved.isNotEmpty) {
        final rows = await _parser(saved);
        if (rows.isNotEmpty) {
          _apply(rows);
          return;
        }
      }
    }
    for (final file in _candidateFiles) {
      try {
        final body = await _download(Uri.parse('$_base/$file'));
        if (body == null || body.isEmpty) continue;
        final rows = await _parser(body);
        if (rows.isEmpty) continue;
        await _store.write(body);
        _apply(rows);
        return;
      } catch (_) {
        // Try the next file.
      }
    }
    _loaded = true;
  }

  void _apply(List<TopChar> rows) {
    _byId
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r.id, r)));
    _sortedIds = List.unmodifiable(rows.map((r) => r.id));
    _loaded = true;
  }

  /// Parses a downloaded body into rows sorted by favorites (most loved first); rows without an
  /// id or a favorites count are dropped and a body that is not a JSON list gives no rows.
  static List<TopChar> parse(String body) {
    final byId = <int, TopChar>{};
    try {
      final rows = jsonDecode(body);
      if (rows is! List) return const [];
      for (final r in rows) {
        if (r is! Map) continue;
        final id = _asInt(r['mal_id']);
        final favorites = _asInt(r['favorites']);
        if (id == null || favorites == null) continue;
        byId[id] = TopChar(
          id: id,
          favorites: favorites,
          name: r['name'] is String ? r['name'] as String : null,
        );
      }
    } catch (_) {
      return const [];
    }
    return byId.values.toList()..sort((a, b) => b.favorites.compareTo(a.favorites));
  }

  static Future<List<TopChar>> _parseOffIsolate(String body) => compute(parse, body);

  static Future<String?> _httpDownload(Uri url) async {
    final response = await http.get(url);
    return response.statusCode == 200 ? response.body : null;
  }

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
