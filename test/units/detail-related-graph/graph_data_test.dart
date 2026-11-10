import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_data.dart';
import 'package:mywatchlist/widgets/graph/graph_labels.dart';
import 'package:mywatchlist/widgets/graph/graph_share.dart';
import 'package:mywatchlist/widgets/graph/related_groups.dart';

Map<String, dynamic> _node(int id, {int? year, String? season}) => {
      'id': id,
      'title': 'T$id',
      'main_picture': {'medium': 'm$id', 'large': 'l$id'},
      'mean': 8,
      'media_type': 'tv',
      'status': 'finished_airing',
      if (year != null) 'start_season': {'year': year, 'season': season},
    };

Map<String, dynamic> _edge(int s, int t, String r) =>
    {'source': s, 'target': t, 'relation_type': r};

Anime _anime(int id, {String? status}) => Anime(
      id: id,
      title: 'A$id',
      imageUrl: '',
      score: 0,
      members: 0,
      myListStatus: status == null
          ? null
          : MyListStatus(
              status: status,
              score: 0,
              numEpisodesWatched: 0,
              isRewatching: false,
              updatedAt: ''),
    );

void main() {
  setUpAll(() => S.load(const Locale('en')));

  group('AnimeGraphData.fromJson', () {
    test('reads nodes and edges, preferring the large picture', () {
      final data = AnimeGraphData.fromJson({
        'nodes': [_node(1, year: 2009, season: 'spring'), _node(2)],
        'edges': [_edge(1, 2, 'sequel')],
      });
      expect(data.nodes.keys, [1, 2]);
      expect(data.nodes[1]!.imageUrl, 'l1');
      expect(data.nodes[1]!.mean, 8.0);
      expect(data.nodes[1]!.year, 2009);
      expect(data.nodes[2]!.year, isNull);
      expect(data.edges.single.relation, GraphRelation.sequel);
      expect(data.isEmpty, isFalse);
    });

    test('malformed input gives an empty graph, never throws', () {
      expect(AnimeGraphData.fromJson(null).isEmpty, isTrue);
      expect(AnimeGraphData.fromJson('x').isEmpty, isTrue);
      expect(
          AnimeGraphData.fromJson({'nodes': 3, 'edges': 'a'}).isEmpty, isTrue);
    });

    test(
        'drops edges to unknown nodes, self loops and keeps unknown relations as other',
        () {
      final data = AnimeGraphData.fromJson({
        'nodes': [_node(1), _node(2)],
        'edges': [
          _edge(1, 9, 'sequel'),
          _edge(2, 2, 'sequel'),
          _edge(1, 2, 'brand_new')
        ],
      });
      expect(data.edges, [const GraphEdgeData(1, 2, GraphRelation.other)]);
    });
  });

  group('orderedEdges', () {
    final data = AnimeGraphData.fromJson({
      'nodes': [
        _node(1, year: 2009, season: 'spring'),
        _node(2, year: 2010, season: 'winter'),
        _node(3, year: 2008, season: 'fall'),
        _node(4),
      ],
      'edges': [
        _edge(2, 1, 'prequel'),
        _edge(1, 2, 'sequel'),
        _edge(1, 3, 'side_story'),
        _edge(4, 1, 'other'),
      ],
    });

    test('fromSelected keeps the edges as sent', () {
      expect(data.orderedEdges(GraphOrder.fromSelected), data.edges);
    });

    test('bySequel points every edge from the older title to the newer one',
        () {
      final edges = data.orderedEdges(GraphOrder.bySequel);
      // The prequel 2->1 becomes sequel 1->2, which the explicit sequel already gave: kept once.
      expect(edges, contains(const GraphEdgeData(1, 2, GraphRelation.sequel)));
      expect(
          edges.where((e) => e.relation == GraphRelation.sequel), hasLength(1));
      // 3 (2008) is older than 1 (2009): the side story is flipped.
      expect(
          edges, contains(const GraphEdgeData(3, 1, GraphRelation.sideStory)));
      // 4 has no date: unchanged.
      expect(edges, contains(const GraphEdgeData(4, 1, GraphRelation.other)));
    });

    test('releaseKey orders seasons inside a year', () {
      const a = GraphNodeData(id: 1, title: '', year: 2020, season: 'winter');
      const b = GraphNodeData(id: 2, title: '', year: 2020, season: 'fall');
      const c = GraphNodeData(id: 3, title: '', year: 2020);
      expect(a.releaseKey! < b.releaseKey!, isTrue);
      expect(c.releaseKey, a.releaseKey);
      expect(const GraphNodeData(id: 4, title: '').releaseKey, isNull);
    });
  });

  group('groupRelated', () {
    RelatedAnime rel(String type, Anime node, {String? formatted}) =>
        RelatedAnime(
            animenode: node,
            relationType: type,
            relationTypeFormatted: formatted ?? type);

    test('groups by relation in first-seen order, once per title', () {
      final groups = groupRelated([
        rel('sequel', _anime(2)),
        rel('side_story', _anime(3)),
        rel('sequel', _anime(4)),
        rel('sequel', _anime(2)),
      ]);
      expect(groups.map((g) => g.relationType), ['sequel', 'side_story']);
      expect(groups.first.nodes.map((n) => n.id), [2, 4]);
      expect(allRelatedNodes(groups).map((n) => n.id), [2, 4, 3]);
    });

    test('labels are translated and follow the language', () async {
      final related = [rel('side_story', _anime(3), formatted: 'Side story')];
      expect(groupRelated(related).single.label, 'Side story');
      await S.load(const Locale('fr', 'FR'));
      expect(groupRelated(related).single.label, 'Histoire parallèle');
      await S.load(const Locale('en'));
    });

    test('an unknown relation keeps the formatted text from MAL', () {
      expect(
          groupRelated([rel('weird', _anime(3), formatted: 'Weird one')])
              .single
              .label,
          'Weird one');
    });

    test('statusesOf lists only titles that are in the list', () {
      expect(statusesOf([_anime(1, status: 'completed'), _anime(2)]),
          {1: 'completed'});
    });
  });

  test('labels fall back to a readable word', () {
    expect(GraphLabels.mediaType('tv'), 'TV');
    expect(GraphLabels.mediaType('movie'), 'Movie');
    expect(GraphLabels.mediaType('weird_kind'), 'Weird kind');
    expect(GraphLabels.airing('currently_airing'), 'Currently airing');
    expect(GraphLabels.season('fall', 2019), 'Fall 2019');
    expect(GraphLabels.season(null, 2019), '2019');
    expect(GraphLabels.season(null, null), '');
  });

  group('share helpers', () {
    test('capture ratio is sharp when small and bounded when large', () {
      expect(graphCaptureRatio(400, 300), 3);
      expect(graphCaptureRatio(8000, 2000), closeTo(0.512, 0.001));
      expect(graphCaptureRatio(1e9, 10), 0.25);
      expect(graphCaptureRatio(0, 0), 1);
    });

    test('file stems are safe and never empty', () {
      expect(safeFileStem('Bakemonogatari: 2/3!'), 'Bakemonogatari_2_3');
      expect(safeFileStem('???'), 'anime_graph');
      expect(safeFileStem('日本語 タイトル'), '日本語_タイトル');
      expect(safeFileStem('a' * 100).length, 60);
    });
  });
}
