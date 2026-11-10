import 'package:flutter/foundation.dart';

/// How two titles of a franchise relate, as the graph backend names it.
enum GraphRelation {
  sequel('sequel'),
  prequel('prequel'),
  alternativeSetting('alternative_setting'),
  alternativeVersion('alternative_version'),
  sideStory('side_story'),
  parentStory('parent_story'),
  summary('summary'),
  fullStory('full_story'),
  spinOff('spin_off'),
  character('character'),
  other('other');

  const GraphRelation(this.wire);

  /// The word the backend sends.
  final String wire;

  /// An unknown word is [other]: a new relation never breaks the graph.
  static GraphRelation parse(Object? word) {
    for (final relation in values) {
      if (relation.wire == word) return relation;
    }
    return other;
  }
}

/// How the graph's edges are oriented before the layout runs.
enum GraphOrder {
  /// Edges as the backend sends them: the layout grows out of the title that was opened.
  fromSelected,

  /// Every edge points from the older title to the newer one.
  bySequel,
}

@immutable
class GraphNodeData {
  final int id;
  final String title;
  final String? imageUrl;
  final double? mean;
  final String? mediaType;
  final String? status;
  final int? year;

  /// `winter`, `spring`, `summer` or `fall`.
  final String? season;

  const GraphNodeData({
    required this.id,
    required this.title,
    this.imageUrl,
    this.mean,
    this.mediaType,
    this.status,
    this.year,
    this.season,
  });

  /// `null` when the node has no usable id.
  static GraphNodeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! int) return null;
    final picture = json['main_picture'];
    final start = json['start_season'];
    final mean = json['mean'];
    final year = start is Map ? start['year'] : null;
    final season = start is Map ? start['season'] : null;
    String? imageUrl;
    if (picture is Map) {
      imageUrl = (picture['large'] ?? picture['medium']) as String?;
    }
    return GraphNodeData(
      id: id,
      title: (json['title'] as String?) ?? '',
      imageUrl: (imageUrl == null || imageUrl.isEmpty) ? null : imageUrl,
      mean: mean is num ? mean.toDouble() : null,
      mediaType: json['media_type'] as String?,
      status: json['status'] as String?,
      year: year is int ? year : null,
      season: season is String ? season : null,
    );
  }

  /// A sortable moment (`year * 12 + month`), `null` when the year is unknown.
  /// A known year with an unknown season counts as its first month.
  int? get releaseKey {
    final y = year;
    if (y == null) return null;
    return y * 12 + (_seasonMonth[season] ?? 0);
  }

  static const Map<String, int> _seasonMonth = {
    'winter': 0,
    'spring': 3,
    'summer': 6,
    'fall': 9
  };
}

@immutable
class GraphEdgeData {
  final int source;
  final int target;
  final GraphRelation relation;

  const GraphEdgeData(this.source, this.target, this.relation);

  static GraphEdgeData? fromJson(Object? json) {
    if (json is! Map) return null;
    final source = json['source'];
    final target = json['target'];
    if (source is! int || target is! int) return null;
    return GraphEdgeData(
        source, target, GraphRelation.parse(json['relation_type']));
  }

  @override
  bool operator ==(Object other) =>
      other is GraphEdgeData &&
      other.source == source &&
      other.target == target &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(source, target, relation);
}

/// The relation graph of one title: titles and the edges between them.
@immutable
class AnimeGraphData {
  final Map<int, GraphNodeData> nodes;
  final List<GraphEdgeData> edges;

  /// False when the graph was cut short (node bound or MAL rate limit): shown, never cached.
  final bool complete;

  /// The graph was cut short because MyAnimeList answered 429.
  final bool rateLimited;

  const AnimeGraphData(this.nodes, this.edges,
      {this.complete = true, this.rateLimited = false});

  /// The same graph marked as cut short or not.
  AnimeGraphData withCompleteness(
          {required bool complete, bool rateLimited = false}) =>
      AnimeGraphData(nodes, edges,
          complete: complete, rateLimited: rateLimited);

  static const AnimeGraphData empty = AnimeGraphData({}, []);

  /// Reads the backend answer (`{nodes: [...], edges: [...]}`); anything malformed gives [empty].
  /// Edges whose ends are not in the node list are dropped, so the layout never meets a node
  /// it cannot draw.
  factory AnimeGraphData.fromJson(Object? json) {
    if (json is! Map) return empty;
    final nodes = <int, GraphNodeData>{};
    final rawNodes = json['nodes'];
    if (rawNodes is List) {
      for (final raw in rawNodes) {
        final node = GraphNodeData.fromJson(raw);
        if (node != null) nodes[node.id] = node;
      }
    }
    final edges = <GraphEdgeData>[];
    final rawEdges = json['edges'];
    if (rawEdges is List) {
      for (final raw in rawEdges) {
        final edge = GraphEdgeData.fromJson(raw);
        if (edge != null &&
            edge.source != edge.target &&
            nodes.containsKey(edge.source) &&
            nodes.containsKey(edge.target)) {
          edges.add(edge);
        }
      }
    }
    return AnimeGraphData(nodes, edges);
  }

  /// A graph with no edge has nothing to draw.
  bool get isEmpty => edges.isEmpty;

  /// The edges to lay out for [order].
  ///
  /// [GraphOrder.fromSelected] keeps them as sent. [GraphOrder.bySequel] turns every prequel
  /// into a sequel pointing the other way and orients the remaining relations from the older
  /// title to the newer one (unchanged when a date is missing), so the layers read as time.
  List<GraphEdgeData> orderedEdges(GraphOrder order) {
    if (order == GraphOrder.fromSelected) return edges;
    final result = <GraphEdgeData>{};
    for (final edge in edges) {
      if (edge.relation == GraphRelation.prequel) {
        result
            .add(GraphEdgeData(edge.target, edge.source, GraphRelation.sequel));
      } else if (edge.relation == GraphRelation.sequel) {
        result.add(edge);
      } else {
        final a = nodes[edge.source]?.releaseKey;
        final b = nodes[edge.target]?.releaseKey;
        final flip = a != null && b != null && a > b;
        result.add(flip
            ? GraphEdgeData(edge.target, edge.source, edge.relation)
            : edge);
      }
    }
    return result.toList();
  }
}
