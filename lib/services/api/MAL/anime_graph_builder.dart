import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';

/// What one MAL API v2 `GET /anime/{id}` gave the graph builder.
@immutable
class GraphFetch {
  /// The decoded anime (`id`, `title`, `related_anime`…), null when the request failed.
  final Map<String, dynamic>? anime;

  /// MAL answered 429: the builder stops asking and keeps what it has.
  final bool rateLimited;

  const GraphFetch.ok(Map<String, dynamic> this.anime) : rateLimited = false;
  const GraphFetch.failed()
      : anime = null,
        rateLimited = false;
  const GraphFetch.rateLimited()
      : anime = null,
        rateLimited = true;
}

/// The root title could not be read, so there is no graph at all.
class AnimeGraphUnavailable implements Exception {
  final bool rateLimited;
  const AnimeGraphUnavailable({this.rateLimited = false});

  @override
  String toString() =>
      'AnimeGraphUnavailable(${rateLimited ? 'rate limited' : 'failed'})';
}

/// A built graph: the JSON the graph screen reads (`{nodes: [...], edges: [...]}`, the shape
/// of mwl-rust-api's `/anime/{id}/related`) and whether the walk went to the end.
@immutable
class AnimeGraphResult {
  final Map<String, dynamic> json;

  /// False when the walk stopped early (node bound reached, MAL rate limit).
  final bool complete;

  /// The walk stopped because MAL answered 429 (else, when not [complete], the node bound).
  final bool rateLimited;

  const AnimeGraphResult(this.json,
      {required this.complete, this.rateLimited = false});

  int get nodeCount => (json['nodes'] as List?)?.length ?? 0;
}

/// Builds the relation graph of an anime in the app, with the algorithm of mwl-rust-api
/// (`AnimeService::get_related_anime_with_graph`):
///
/// * the title opened follows every valid relation including `other`; the titles reached
///   after it follow valid relations without `other` (`valid_relation`);
/// * a title's unvisited neighbours are fetched 5 at a time, their own edges collected, then
///   every edge whose target is still unknown is added and walked in turn;
/// * an edge whose target is already a node is dropped (`filter_by_nodes`), except the edges
///   of the first ring of each visited title, which are kept as the Rust code keeps them.
///
/// The walk is bounded: at most [maxNodes] titles are fetched, and a 429 from MAL stops every
/// further request; either way the graph loaded so far is returned with `complete: false`.
class AnimeGraphBuilder {
  AnimeGraphBuilder({
    Future<GraphFetch> Function(int id)? fetch,
    this.maxNodes = 120,
    this.concurrency = 5,
  }) : _fetch = fetch ?? fetchMalAnime;

  final Future<GraphFetch> Function(int id) _fetch;
  final int maxNodes;
  final int concurrency;

  /// Fields of `GET /anime/{id}`, as mwl-rust-api asks them (`main_picture` comes by default).
  static const String fields =
      'alternative_titles,mean,media_type,status,start_season,related_anime';

  /// Relation words followed by the walk (`character` never, `other` only from the root).
  static const Set<String> _followed = {
    'alternative_setting',
    'sequel',
    'prequel',
    'alternative_version',
    'side_story',
    'parent_story',
    'summary',
    'full_story',
    'spin_off',
  };

  /// mwl-rust-api's `valid_relation`; an unknown word is not followed.
  static bool validRelation(Object? relation, {required bool includeOthers}) =>
      _followed.contains(relation) || (includeOthers && relation == 'other');

  /// `GET /anime/{id}` through [MalApi.authorizedGet]: the MAL session when the selected
  /// account is MyAnimeList, the app's client id for any other tracker.
  static Future<GraphFetch> fetchMalAnime(int id) async {
    try {
      final response = await MalApi.authorizedGet(
          '${MalApi.animeEndPoint}/$id?fields=$fields');
      if (response.statusCode == 429) return const GraphFetch.rateLimited();
      if (response.statusCode != 200) return const GraphFetch.failed();
      final body = await MwlApi.decodeJson(response.body);
      return body is Map<String, dynamic>
          ? GraphFetch.ok(body)
          : const GraphFetch.failed();
    } catch (e) {
      if (kDebugMode) debugPrint('AnimeGraphBuilder: $id failed: $e');
      return const GraphFetch.failed();
    }
  }

  /// Builds the graph of [rootId]. [onProgress] gets the number of titles found so far each
  /// time it grows. Throws [AnimeGraphUnavailable] when the root itself cannot be read.
  Future<AnimeGraphResult> build(int rootId,
      {void Function(int titles)? onProgress}) async {
    final walk = _Walk(this, onProgress);
    final root = await walk.fetch(rootId);
    if (root == null) {
      throw AnimeGraphUnavailable(rateLimited: walk.rateLimited);
    }
    await walk.visit(rootId, includeOthers: true);
    return AnimeGraphResult(walk.toJson(),
        complete: walk.complete, rateLimited: walk.rateLimited);
  }
}

class _Edge {
  final int source;
  final int target;
  final String relation;
  const _Edge(this.source, this.target, this.relation);

  Map<String, dynamic> toJson() =>
      {'source': source, 'target': target, 'relation_type': relation};
}

/// One run of the algorithm: the nodes (insertion ordered), the edges, the fetched titles.
class _Walk {
  _Walk(this.builder, this.onProgress);

  final AnimeGraphBuilder builder;
  final void Function(int titles)? onProgress;

  final Map<int, Map<String, dynamic>> nodes = {};
  final List<_Edge> edges = [];

  /// Every title asked for, once: the Rust service reads its cache for the same title.
  final Map<int, Future<Map<String, dynamic>?>> _fetched = {};
  bool rateLimited = false;
  bool bounded = false;

  bool get complete => !rateLimited && !bounded;

  Future<Map<String, dynamic>?> fetch(int id) {
    final known = _fetched[id];
    if (known != null) return known;
    if (rateLimited) return Future.value(null);
    if (_fetched.length >= builder.maxNodes) {
      bounded = true;
      return Future.value(null);
    }
    return _fetched[id] = builder._fetch(id).then((result) {
      if (result.rateLimited) rateLimited = true;
      return result.anime;
    });
  }

  void addNode(Map<String, dynamic> anime) {
    final id = anime['id'];
    if (id is! int || nodes.containsKey(id)) return;
    nodes[id] = _node(anime);
    onProgress?.call(nodes.length);
  }

  /// `get_unvisited_edges`: the followed relations of [anime], from [id].
  List<_Edge> edgesOf(int id, Map<String, dynamic> anime,
      {required bool includeOthers}) {
    final related = anime['related_anime'];
    if (related is! List) return const [];
    final result = <_Edge>[];
    for (final entry in related) {
      if (entry is! Map) continue;
      final relation = entry['relation_type'];
      final node = entry['node'];
      final target = node is Map ? node['id'] : null;
      if (target is! int) continue;
      if (!AnimeGraphBuilder.validRelation(relation,
          includeOthers: includeOthers)) {
        continue;
      }
      result.add(_Edge(id, target, relation as String));
    }
    return result;
  }

  /// `filter_by_nodes`: the edges whose target is not a node yet.
  List<_Edge> unvisited(List<_Edge> list) =>
      [for (final e in list) if (!nodes.containsKey(e.target)) e];

  /// `get_related_anime_with_graph`.
  Future<void> visit(int id, {required bool includeOthers}) async {
    final anime = await fetch(id);
    if (anime == null) return;
    addNode(anime);

    final ring = unvisited(edgesOf(id, anime, includeOthers: includeOthers));

    // Neighbours fetched [concurrency] at a time; results kept in the ring's order so the
    // graph does not depend on which answer came first.
    final neighbours = List<Map<String, dynamic>?>.filled(ring.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < ring.length) {
        final i = next++;
        neighbours[i] = await fetch(ring[i].target);
      }
    }

    await Future.wait(
        [for (var w = 0; w < builder.concurrency && w < ring.length; w++) worker()]);

    final combined = <_Edge>[];
    for (var i = 0; i < ring.length; i++) {
      final neighbour = neighbours[i];
      if (neighbour == null) continue;
      combined
          .addAll(edgesOf(ring[i].target, neighbour, includeOthers: false));
    }
    edges.addAll(ring);
    for (final neighbour in neighbours) {
      if (neighbour != null) addNode(neighbour);
    }

    for (final edge in unvisited(combined)) {
      edges.add(edge);
      await visit(edge.target, includeOthers: false);
    }
  }

  /// The node fields of mwl-rust-api's `ContentNodeDTO`.
  static Map<String, dynamic> _node(Map<String, dynamic> anime) => {
        'id': anime['id'],
        'title': anime['title'] ?? '',
        if (anime['main_picture'] is Map) 'main_picture': anime['main_picture'],
        if (anime['mean'] is num) 'mean': anime['mean'],
        if (anime['media_type'] != null) 'media_type': anime['media_type'],
        if (anime['status'] != null) 'status': anime['status'],
        if (anime['start_season'] is Map) 'start_season': anime['start_season'],
        if (anime['alternative_titles'] is Map)
          'alternative_titles': {
            'en': (anime['alternative_titles'] as Map)['en'],
            'ja': (anime['alternative_titles'] as Map)['ja'],
          },
      };

  Map<String, dynamic> toJson() => {
        'nodes': nodes.values.toList(),
        'edges': [for (final e in edges) e.toJson()],
      };
}

/// Where complete graphs are kept between launches.
abstract class AnimeGraphStore {
  /// The saved graph of [id] when it is younger than [maxAge], else null.
  Future<Map<String, dynamic>?> read(int id, Duration maxAge);

  Future<void> write(int id, Map<String, dynamic> json);
}

/// One JSON file per title in the temporary directory (the system may clear it, which only
/// means a new walk).
class FileAnimeGraphStore implements AnimeGraphStore {
  const FileAnimeGraphStore();

  Future<File> _file(int id) async {
    final dir = await getTemporaryDirectory();
    final sep = Platform.pathSeparator;
    return File('${dir.path}${sep}mwl_anime_graph$sep$id.json');
  }

  @override
  Future<Map<String, dynamic>?> read(int id, Duration maxAge) async {
    try {
      final file = await _file(id);
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age >= maxAge) return null;
      final body = await MwlApi.decodeJson(await file.readAsString());
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(int id, Map<String, dynamic> json) async {
    try {
      final file = await _file(id);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json), flush: true);
    } catch (_) {
      // No disk (web, full storage): the graph is built again next time.
    }
  }
}

/// The relation graph of a MAL anime, from the first source that has it: this session, the
/// disk (a few days), mwl-rust-api when `API_URL` is set and answers, else [AnimeGraphBuilder].
///
/// Only complete graphs are cached; a graph cut by the bound or a rate limit is shown but
/// built again next time. [progressOf] tells the screen how many titles the walk found.
class AnimeGraphRepository {
  AnimeGraphRepository({
    AnimeGraphBuilder? builder,
    AnimeGraphStore store = const FileAnimeGraphStore(),
    Future<Map<String, dynamic>?> Function(int id)? remote,
    this.maxAge = const Duration(days: 3),
    this.progressInterval = const Duration(milliseconds: 250),
  })  : _builder = builder ?? AnimeGraphBuilder(),
        _store = store,
        _remote = remote ?? ((id) => MwlApi.i.getAnimeGraph(id));

  static AnimeGraphRepository instance = AnimeGraphRepository();

  final AnimeGraphBuilder _builder;
  final AnimeGraphStore _store;
  final Future<Map<String, dynamic>?> Function(int id) _remote;
  final Duration maxAge;
  final Duration progressInterval;

  final Map<int, Map<String, dynamic>> _session = {};
  final Map<int, Future<AnimeGraphResult>> _running = {};
  final Map<int, ValueNotifier<int>> _progress = {};

  /// Titles found so far by the walk of [id] (0 before it starts).
  ValueListenable<int> progressOf(int id) =>
      _progress.putIfAbsent(id, () => ValueNotifier<int>(0));

  /// Forgets the graphs of this session (the disk keeps its copies).
  void clearSession() => _session.clear();

  /// The graph of [id]; a second call while a walk runs joins it.
  Future<AnimeGraphResult> load(int id) =>
      _running[id] ??= _load(id).whenComplete(() => _running.remove(id));

  Future<AnimeGraphResult> _load(int id) async {
    final session = _session[id];
    if (session != null) return AnimeGraphResult(session, complete: true);

    final saved = await _store.read(id, maxAge);
    if (_hasEdges(saved)) return _keep(id, saved!, toDisk: false);

    Map<String, dynamic>? remote;
    try {
      remote = await _remote(id);
    } catch (_) {
      remote = null;
    }
    if (_hasEdges(remote)) return _keep(id, remote!);

    final progress = _progress.putIfAbsent(id, () => ValueNotifier<int>(0));
    progress.value = 0;
    // The count reaches the screen in batches (at most one rebuild per [progressInterval]),
    // never once per title.
    var latest = 0;
    Timer? flush;
    final AnimeGraphResult result;
    try {
      result = await _builder.build(id, onProgress: (count) {
        latest = count;
        flush ??= Timer(progressInterval, () {
          flush = null;
          progress.value = latest;
        });
      });
    } finally {
      flush?.cancel();
      progress.value = latest;
    }
    if (result.complete && _hasEdges(result.json)) {
      return _keep(id, result.json);
    }
    return result;
  }

  AnimeGraphResult _keep(int id, Map<String, dynamic> json,
      {bool toDisk = true}) {
    _session[id] = json;
    if (toDisk) unawaited(_store.write(id, json));
    return AnimeGraphResult(json, complete: true);
  }

  static bool _hasEdges(Map<String, dynamic>? json) {
    final edges = json?['edges'];
    return edges is List && edges.isNotEmpty;
  }
}
