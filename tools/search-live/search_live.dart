// Live check of every search source that works without Jikan.
//
//   dart run tools/search-live/search_live.dart            (from the repository root)
//   dart run tools/search-live/search_live.dart --only=studio
//
// Runs each search filter of the app once against the real MyAnimeList site, through the same
// mwl-api routes the app calls in process (`search/content`, `companies`, `studios`,
// `magazines`) and, when `assets/.env` holds a MAL_CLIENT_ID, the official MAL API paths the app
// uses for text, seasons and rankings. Prints `filter -> count` and exits with 1 when any filter
// returns nothing or fails.
//
// Read-only GETs, no login, never touches anyone's list, at most one request per second. It is a
// network script, not a build: it needs no lock. Offline unit tests live in
// test/units/search-sources/ (saved pages); this script is the proof that the live site still
// matches them.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mwl_api/handlers/handler_core.dart';
import 'package:mwl_commons/mwl_commons.dart';

const _gap = Duration(milliseconds: 1100);
DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

Future<void> _throttle() async {
  final wait = _last.add(_gap).difference(DateTime.now());
  if (wait > Duration.zero) await Future<void>.delayed(wait);
  _last = DateTime.now();
}

final _core = HandlerCore();
final _results = <(String, String, int?, String?)>[];
String? _only;

/// Extra detail printed under the line of the current check.
String? _note;

/// One route of the in-process backend, as the app calls it (cache off).
Future<Map<String, dynamic>?> _route(String endpoint) async {
  await _throttle();
  final separator = endpoint.contains('?') ? '&' : '?';
  final uri = Uri.parse('http://0.0.0.0:8080/$endpoint${separator}fromCache=false');
  final body = await _core.handleRequestAsString(uri).timeout(const Duration(seconds: 40));
  if (body == null || body.isEmpty) return null;
  final json = jsonDecode(body);
  return json is Map<String, dynamic> ? json : null;
}

Future<void> _check(String group, String label, Future<int?> Function() run) async {
  if (_only != null && !'$group $label'.toLowerCase().contains(_only!)) return;
  int? count;
  String? error;
  try {
    count = await run();
  } catch (e) {
    error = '$e'.split('\n').first;
  }
  _results.add((group, label, count, error));
  final shown = error != null ? 'FAILED ($error)' : (count == null ? 'FAILED (no answer)' : '$count');
  stdout.writeln('${group.padRight(9)} ${label.padRight(58)} -> $shown');
  if (_note != null) stdout.writeln('          $_note');
  _note = null;
}

/// `search/content` with the app's filter keys.
Future<int?> _search(String category, {String q = '', Map<String, Object> f = const {}, int page = 1}) async {
  final params = <String, String>{
    'category': category,
    'q': q,
    'page': '$page',
    for (final e in f.entries) e.key: e.value is List ? (e.value as List).join(',') : '${e.value}',
  };
  final json = await _route('search/content?${Uri(queryParameters: params).query}');
  final data = json?['data'];
  if (data is! Map) return null;
  final result = MalSearchPageHtml.fromJson(Map<String, dynamic>.from(data));
  return result.items.length;
}

Future<int?> _companies({String q = '', int page = 1}) async {
  final json = await _route('companies?${Uri(queryParameters: {'q': q, 'page': '$page'}).query}');
  final data = json?['data'];
  if (data is! Map) return null;
  final result = CompanyPageHtml.fromJson(Map<String, dynamic>.from(data));
  final logos = result.items.where((c) => c.logo != null).length;
  final first = result.items.isEmpty ? '' : ', first: ${result.items.first.name}';
  _note = '(with a logo: $logos, next page: ${result.hasNext}$first)';
  return result.items.length;
}

String? _clientId() {
  final file = File('assets/.env');
  if (!file.existsSync()) return null;
  for (final line in file.readAsLinesSync()) {
    final at = line.indexOf('=');
    if (at > 0 && line.substring(0, at).trim() == 'MAL_CLIENT_ID') {
      final value = line.substring(at + 1).trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
      return value.isEmpty ? null : value;
    }
  }
  return null;
}

/// The official MAL API with the app's client id (public data, no user token).
Future<int?> _official(String clientId, String path) async {
  await _throttle();
  final response = await http
      .get(Uri.parse('https://api.myanimelist.net/v2/$path'), headers: {'X-MAL-CLIENT-ID': clientId})
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) throw StateError('HTTP ${response.statusCode}');
  final data = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
  return data is List ? data.length : null;
}

Future<void> main(List<String> args) async {
  for (final arg in args) {
    if (arg.startsWith('--only=')) _only = arg.substring(7).toLowerCase();
  }
  // The backend logs every request; keep the report readable.
  await runZoned(_run, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      if (!line.startsWith('[MWL-API]')) parent.print(zone, line);
    },
  ));
}

Future<void> _run() async {
  final started = DateTime.now();
  stdout.writeln('search-live ${started.toUtc().toIso8601String()}  (MyAnimeList, 1 request/s at most)');
  stdout.writeln('');

  // --- Anime: MAL search page (anime.php) --------------------------------------------------
  const a = 'anime';
  await _check(a, 'text "frieren"', () => _search(a, q: 'frieren'));
  await _check(a, 'studio Arch (producer 1966)', () => _search(a, f: {'producer': 1966}));
  await _check(a, 'studio MAPPA (569) + type tv + genre Action', () => _search(a, f: {'producer': 569, 'type': 'tv', 'genres_in': [1]}));
  await _check(a, 'genre Action (1)', () => _search(a, f: {'genres_in': [1]}));
  await _check(a, 'genre Action, page 2', () => _search(a, f: {'genres_in': [1]}, page: 2));
  await _check(a, 'genre Action, Adventure excluded (2)', () => _search(a, f: {'genres_in': [1], 'genres_out': [2]}));
  await _check(a, 'genres Comedy + Romance (4, 22)', () => _search(a, f: {'genres_in': [4, 22]}));
  await _check(a, 'genre excluded only: Comedy (4)', () => _search(a, f: {'genres_out': [4]}));
  await _check(a, 'theme Isekai (62)', () => _search(a, f: {'genres_in': [62]}));
  await _check(a, 'demographic Shounen (27)', () => _search(a, f: {'genres_in': [27]}));
  for (final type in ['tv', 'movie', 'ova', 'special', 'ona', 'music']) {
    await _check(a, 'type $type', () => _search(a, f: {'type': type}));
  }
  for (final status in ['airing', 'complete', 'upcoming']) {
    await _check(a, 'status $status', () => _search(a, f: {'status': status}));
  }
  for (final rating in ['g', 'pg', 'pg13', 'r17', 'r', 'rx']) {
    await _check(a, 'rating $rating', () => _search(a, f: {'rating': rating}));
  }
  await _check(a, 'minimum score 8', () => _search(a, f: {'score': 8}));
  await _check(a, 'start date from 2024-04-01', () => _search(a, f: {'start_date': '2024-04-01'}));
  await _check(a, 'end date until 2010-12-31', () => _search(a, f: {'end_date': '2010-12-31'}));
  await _check(a, 'letter A', () => _search(a, f: {'letter': 'A'}));
  for (final order in ['title', 'start_date', 'end_date', 'episodes', 'score', 'scored_by', 'rank', 'popularity', 'members', 'favorites']) {
    await _check(a, 'order by $order, descending', () => _search(a, f: {'order_by': order, 'sort': 'desc'}));
  }
  await _check(a, 'order by score, ascending', () => _search(a, f: {'order_by': 'score', 'sort': 'asc'}));
  await _check(a, 'text "gundam" + type movie + score 7', () => _search(a, q: 'gundam', f: {'type': 'movie', 'score': 7}));

  // --- Manga: MAL search page (manga.php) --------------------------------------------------
  const m = 'manga';
  await _check(m, 'text "berserk"', () => _search(m, q: 'berserk'));
  await _check(m, 'magazine Shounen Jump (Weekly) (83)', () => _search(m, f: {'magazines': 83}));
  await _check(m, 'magazine Shounen Jump (Weekly) (83), page 2', () => _search(m, f: {'magazines': 83}, page: 2));
  await _check(m, 'genre Action (1)', () => _search(m, f: {'genres_in': [1]}));
  await _check(m, 'genre Romance, Comedy excluded', () => _search(m, f: {'genres_in': [22], 'genres_out': [4]}));
  await _check(m, 'demographic Seinen (41)', () => _search(m, f: {'genres_in': [41]}));
  for (final type in ['manga', 'novel', 'lightnovel', 'oneshot', 'doujin', 'manhwa', 'manhua']) {
    await _check(m, 'type $type', () => _search(m, f: {'type': type}));
  }
  for (final status in ['publishing', 'complete', 'hiatus', 'discontinued', 'upcoming']) {
    await _check(m, 'status $status', () => _search(m, f: {'status': status}));
  }
  await _check(m, 'minimum score 8', () => _search(m, f: {'score': 8}));
  await _check(m, 'start date from 2020-01-01', () => _search(m, f: {'start_date': '2020-01-01'}));
  await _check(m, 'end date until 2000-12-31', () => _search(m, f: {'end_date': '2000-12-31'}));
  await _check(m, 'letter B', () => _search(m, f: {'letter': 'B'}));
  for (final order in ['title', 'start_date', 'end_date', 'chapters', 'volumes', 'score', 'scored_by', 'rank', 'popularity', 'members', 'favorites']) {
    await _check(m, 'order by $order, descending', () => _search(m, f: {'order_by': order, 'sort': 'desc'}));
  }

  // --- Characters and people (character.php, people.php) ------------------------------------
  await _check('character', 'text "luffy"', () => _search('character', q: 'luffy'));
  await _check('person', 'text "kana"', () => _search('person', q: 'kana'));
  await _check('person', 'text "kana", page 2', () => _search('person', q: 'kana', page: 2));

  // --- Too short: answered without asking MAL (not a filter, shown for the record) ------------
  final short = await _route('search/content?category=anime&q=na&page=1');
  stdout.writeln('${'guard'.padRight(9)} ${'text "na" (MAL needs 3 characters)'.padRight(58)} -> '
      'tooShort=${(short?['data'] as Map?)?['tooShort']}');

  // --- Studios directory (/company) and the producer tables ---------------------------------
  const s = 'studios';
  await _check(s, 'directory page 1 (most favorited)', () => _companies());
  await _check(s, 'directory page 41 (offset 2000)', () => _companies(page: 41));
  await _check(s, 'search "arch"', () => _companies(q: 'arch'));
  await _check(s, 'search "studio", page 2', () => _companies(q: 'studio', page: 2));
  await _check(s, 'route studios (anime.php producer names)', () async {
    final data = (await _route('studios'))?['data'];
    if (data is Map) _note = '(Arch listed: ${data['1966']})';
    return data is Map ? data.length : null;
  });
  await _check(s, 'route magazines (manga.php magazine names)', () async {
    final data = (await _route('magazines'))?['data'];
    return data is Map ? data.length : null;
  });
  await _check(s, 'MalScraper.getStudioList page (/anime/producer)', () async {
    await _throttle();
    final response = await http.get(Uri.parse('https://myanimelist.net/anime/producer')).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw StateError('HTTP ${response.statusCode}');
    final list = HtmlParsers.parseProducer(html.parse(response.body));
    final eightBit = list.categories.expand((c) => c.genres).where((g) => g.id == 441).firstOrNull;
    _note = '(8bit read as "${eightBit?.name}" with ${eightBit?.count} anime)';
    return list.categories.fold<int>(0, (n, c) => n + c.genres.length);
  });

  // --- Official MAL API (text, seasons, rankings), as the app calls it -----------------------
  final clientId = _clientId();
  if (clientId == null) {
    stdout.writeln('official  (skipped: no MAL_CLIENT_ID in assets/.env)');
  } else {
    const o = 'official';
    await _check(o, 'anime text "frieren"', () => _official(clientId, 'anime?q=frieren&limit=30'));
    await _check(o, 'manga text "berserk"', () => _official(clientId, 'manga?q=berserk&limit=30'));
    await _check(o, 'season fall 2024', () => _official(clientId, 'anime/season/2024/fall?limit=30'));
    await _check(o, 'anime ranking airing', () => _official(clientId, 'anime/ranking?ranking_type=airing&limit=30'));
    await _check(o, 'manga ranking manga', () => _official(clientId, 'manga/ranking?ranking_type=manga&limit=30'));
    await _check(o, 'anime by id 52991', () async {
      await _throttle();
      final r = await http.get(Uri.parse('https://api.myanimelist.net/v2/anime/52991?fields=id'),
          headers: {'X-MAL-CLIENT-ID': clientId}).timeout(const Duration(seconds: 20));
      return r.statusCode == 200 ? 1 : 0;
    });
  }

  final failed = _results.where((r) => r.$4 != null || (r.$3 ?? 0) <= 0).toList();
  stdout.writeln('');
  stdout.writeln('${_results.length} filters, ${_results.length - failed.length} with results, '
      '${failed.length} empty or failed, ${DateTime.now().difference(started).inSeconds} s');
  for (final r in failed) {
    stdout.writeln('  EMPTY/FAILED: ${r.$1} ${r.$2}');
  }
  exitCode = failed.isEmpty ? 0 : 1;
}
