// Live check of every Tenrai endpoint the app's TenraiApi covers.
//
//   dart run tools/tenrai-live/tenrai_live.dart          (from the repository root)
//   dart run tools/tenrai-live/tenrai_live.dart --only=/top
//
// Reads the path list of lib/services/api/Tenrai/tenrai_api.dart (`TenraiApi.paths`, one entry
// per OpenAPI path), calls each path once on https://api.tenrai.org/v1 with sample ids, and
// prints `path -> status / count`. Exits with 1 when a path has no sample here, or answers
// anything but 200 (the server-key-only paths of `TenraiApi.keyOnlyPaths` must answer 401: the
// app never ships a key).
//
// Read-only GETs on the public tier (no key), at most 2 requests per second (Tenrai allows 4),
// a 429 waits for its Retry-After. A network script, not a build: it needs no lock. Offline
// tests live in test/units/tenrai-client/.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _base = 'https://api.tenrai.org/v1';
const _gap = Duration(milliseconds: 550);
DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

/// Concrete request per OpenAPI path. `{news}`, `{article}` and `{stack}` are replaced by the
/// first id of the matching list, read earlier in the run.
const Map<String, String> _samples = {
  '/anime': '/anime?q=bebop&limit=5',
  '/anime/{id}': '/anime/1',
  '/anime/{id}/full': '/anime/1/full',
  '/anime/{id}/recommendations': '/anime/1/recommendations',
  '/anime/{id}/characters': '/anime/1/characters',
  '/anime/{id}/staff': '/anime/1/staff',
  '/anime/{id}/episodes': '/anime/1/episodes',
  '/anime/{id}/news': '/anime/1/news',
  '/anime/{id}/articles': '/anime/1/articles',
  '/anime/{id}/forum': '/anime/1/forum?filter=episode',
  '/anime/{id}/episodes/{episode_id}': '/anime/1/episodes/1',
  '/anime/{id}/videos': '/anime/1/videos',
  '/anime/{id}/videos/episodes': '/anime/1/videos/episodes',
  '/anime/{id}/pictures': '/anime/1/pictures',
  '/anime/{id}/statistics': '/anime/1/statistics',
  '/anime/{id}/statistics/history': '/anime/1/statistics/history',
  '/anime/{id}/moreinfo': '/anime/1/moreinfo',
  '/anime/{id}/relations': '/anime/1/relations',
  '/anime/{id}/themes': '/anime/1/themes',
  '/anime/{id}/external': '/anime/1/external',
  '/anime/{id}/streaming': '/anime/1/streaming',
  '/anime/{id}/reviews': '/anime/1/reviews',
  '/anime/{id}/stacks': '/anime/1/stacks',
  '/anime/unapproved': '/anime/unapproved?limit=5',
  '/anime/denied': '/anime/denied?limit=5',
  '/anime/deleted': '/anime/deleted?limit=5',
  '/anime/ids': '/anime/ids?type=movie&status=complete',
  '/manga': '/manga?q=berserk&limit=5',
  '/manga/{id}': '/manga/2',
  '/manga/{id}/full': '/manga/2/full',
  '/manga/{id}/recommendations': '/manga/2/recommendations',
  '/manga/{id}/characters': '/manga/2/characters',
  '/manga/{id}/news': '/manga/2/news',
  '/manga/{id}/articles': '/manga/2/articles',
  '/manga/{id}/pictures': '/manga/2/pictures',
  '/manga/{id}/statistics': '/manga/2/statistics',
  '/manga/{id}/statistics/history': '/manga/2/statistics/history',
  '/manga/{id}/moreinfo': '/manga/2/moreinfo',
  '/manga/{id}/relations': '/manga/2/relations',
  '/manga/{id}/external': '/manga/2/external',
  '/manga/{id}/reviews': '/manga/2/reviews',
  '/manga/{id}/forum': '/manga/2/forum?filter=episode',
  '/manga/{id}/stacks': '/manga/2/stacks',
  '/manga/unapproved': '/manga/unapproved?limit=5',
  '/manga/denied': '/manga/denied?limit=5',
  '/manga/adapted': '/manga/adapted?limit=5',
  '/manga/deleted': '/manga/deleted?limit=5',
  '/manga/ids': '/manga/ids?type=oneshot&status=finished',
  '/characters': '/characters?q=lelouch&limit=5',
  '/characters/{id}': '/characters/417',
  '/characters/{id}/full': '/characters/417/full',
  '/characters/{id}/anime': '/characters/417/anime',
  '/characters/{id}/manga': '/characters/417/manga',
  '/characters/{id}/voices': '/characters/417/voices',
  '/characters/{id}/pictures': '/characters/417/pictures',
  '/characters/{id}/articles': '/characters/417/articles',
  '/characters/ids': '/characters/ids',
  '/people': '/people?q=kamiya&limit=5',
  '/people/{id}': '/people/118',
  '/people/{id}/full': '/people/118/full',
  '/people/{id}/anime': '/people/118/anime',
  '/people/{id}/manga': '/people/1868/manga',
  '/people/{id}/voices': '/people/118/voices',
  '/people/{id}/pictures': '/people/118/pictures',
  '/people/{id}/articles': '/people/118/articles',
  '/people/ids': '/people/ids',
  '/producers': '/producers?limit=5',
  '/producers/{id}': '/producers/14',
  '/producers/{id}/full': '/producers/14/full',
  '/producers/{id}/external': '/producers/14/external',
  '/producers/ids': '/producers/ids',
  '/genres/anime': '/genres/anime',
  '/genres/manga': '/genres/manga?filter=themes',
  '/magazines': '/magazines?limit=5',
  '/random/anime': '/random/anime?sfw=true',
  '/random/manga': '/random/manga?sfw=true',
  '/random/characters': '/random/characters',
  '/random/people': '/random/people',
  '/recommendations/anime': '/recommendations/anime?limit=5',
  '/recommendations/manga': '/recommendations/manga?limit=5',
  '/top/anime': '/top/anime?type=tv&filter=airing&limit=5',
  '/top/manga': '/top/manga?type=manga&filter=favorite&limit=5',
  '/top/people': '/top/people?limit=5',
  '/top/characters': '/top/characters?limit=5',
  '/top/reviews': '/top/reviews?type=anime&limit=5',
  '/top/recommendations': '/top/recommendations?type=anime&limit=5',
  '/top/episodes': '/top/episodes?limit=5',
  '/seasons/{year}/{season}': '/seasons/2024/fall?filter=tv&limit=5',
  '/seasons/now': '/seasons/now?filter=tv&limit=5',
  '/seasons/previous': '/seasons/previous?limit=5',
  '/seasons/upcoming': '/seasons/upcoming?limit=5',
  '/seasons': '/seasons',
  '/reviews/anime': '/reviews/anime?limit=5',
  '/reviews/manga': '/reviews/manga?limit=5',
  '/schedules': '/schedules?filter=monday&limit=5',
  '/news': '/news?limit=5',
  '/news/tags': '/news/tags',
  '/news/{id}': '/news/{news}',
  '/articles': '/articles?limit=5',
  '/articles/tags': '/articles/tags',
  '/articles/{id}': '/articles/{article}',
  '/stacks': '/stacks?limit=5',
  '/stacks/{id}': '/stacks/{stack}',
};

/// First ids of the lists, for the detail paths.
final Map<String, String> _firstIds = {};

Future<void> _throttle() async {
  final wait = _last.add(_gap).difference(DateTime.now());
  if (wait > Duration.zero) await Future<void>.delayed(wait);
  _last = DateTime.now();
}

List<String> _apiList(String name) {
  final source = File('lib/services/api/Tenrai/tenrai_api.dart').readAsStringSync();
  final block = RegExp('static const List<String> $name = \\[(.*?)\\];', dotAll: true)
      .firstMatch(source);
  if (block == null) throw StateError('TenraiApi.$name not found');
  return [for (final m in RegExp(r"'([^']+)'").allMatches(block.group(1)!)) m.group(1)!];
}

/// Rows of an answer: `data` list length, `total` for the id lists, 1 for an object.
String _count(Object? body) {
  if (body is! Map) return 'not an object';
  final data = body['data'];
  if (data is List) {
    final pagination = body['pagination'];
    final items = pagination is Map ? pagination['items'] : null;
    final total = body['total'] ?? (items is Map ? items['total'] : null);
    return total != null ? '${data.length} (total $total)' : '${data.length}';
  }
  if (data is Map) return '1 object';
  return 'no data';
}

Future<(int, String)> _get(String path) async {
  for (var attempt = 0;; attempt++) {
    await _throttle();
    try {
      final response = await http.get(Uri.parse('$_base$path')).timeout(const Duration(seconds: 30));
      if (response.statusCode == 429 && attempt < 3) {
        final seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 2;
        stdout.writeln('   429 on $path, waiting $seconds s');
        await Future<void>.delayed(Duration(seconds: seconds));
        continue;
      }
      if (response.statusCode != 200) return (response.statusCode, '-');
      final body = jsonDecode(response.body);
      final data = body is Map ? body['data'] : null;
      if (data is List && data.isNotEmpty && data.first is Map) {
        final id = (data.first as Map)['mal_id'];
        if (id != null) {
          if (path.startsWith('/news?')) _firstIds['news'] = '$id';
          if (path.startsWith('/articles?')) _firstIds['article'] = '$id';
          if (path.startsWith('/stacks?')) _firstIds['stack'] = '$id';
        }
      }
      return (200, _count(body));
    } on TimeoutException {
      return (0, 'timeout');
    } on Exception catch (e) {
      return (0, '$e');
    }
  }
}

Future<void> main(List<String> args) async {
  final only = args
      .where((a) => a.startsWith('--only='))
      .map((a) => a.substring('--only='.length))
      .firstOrNull;
  final paths = _apiList('paths');
  final keyOnly = _apiList('keyOnlyPaths').toSet();
  // Lists first so the detail paths can use their first ids.
  final ordered = [
    ...paths.where((p) => !p.contains('{id}') || p.startsWith('/anime') || p.startsWith('/manga')),
    ...paths.where((p) => p.contains('{id}') && !p.startsWith('/anime') && !p.startsWith('/manga')),
  ];
  var failures = 0;
  var ok = 0;
  stdout.writeln('Tenrai live check: ${paths.length} paths of TenraiApi.paths on $_base');
  for (final path in ordered) {
    if (only != null && !path.startsWith(only)) continue;
    var sample = _samples[path];
    if (sample == null) {
      stdout.writeln('FAIL $path -> no sample request in tools/tenrai-live');
      failures++;
      continue;
    }
    for (final entry in _firstIds.entries) {
      sample = sample!.replaceAll('{${entry.key}}', entry.value);
    }
    if (sample!.contains('{')) {
      stdout.writeln('FAIL $path -> no id from its list');
      failures++;
      continue;
    }
    final (status, count) = await _get(sample);
    final key = keyOnly.contains(path);
    final good = key ? status == 401 : status == 200;
    good ? ok++ : failures++;
    final label = good ? (key ? 'key ' : 'ok  ') : 'FAIL';
    stdout.writeln('$label $path -> $status / ${key && good ? 'server key only, as expected' : count}   ($sample)');
  }
  final extra = _samples.keys.where((k) => !paths.contains(k)).toList();
  if (extra.isNotEmpty) stdout.writeln('Samples without an API path: $extra');
  stdout.writeln('Done: $ok ok, $failures failed.');
  exit(failures == 0 ? 0 : 1);
}
