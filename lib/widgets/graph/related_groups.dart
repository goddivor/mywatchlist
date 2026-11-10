import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/widgets/graph/graph_labels.dart';

/// The titles related to a page through one relation (all the sequels, all the side stories…).
class RelatedGroup {
  /// MAL's relation word (`sequel`, `side_story`…).
  final String relationType;

  /// Translated name of the relation.
  final String label;
  final List<Anime> nodes;

  const RelatedGroup(this.relationType, this.label, this.nodes);
}

/// Groups [related] by relation, in the order each relation first appears, and translates the
/// relation names. A title listed twice under the same relation is kept once.
List<RelatedGroup> groupRelated(List<RelatedAnime> related) {
  final order = <String>[];
  final nodes = <String, List<Anime>>{};
  final seen = <String, Set<int>>{};
  final fallback = <String, String>{};
  for (final item in related) {
    final key = item.relationType.isNotEmpty
        ? item.relationType
        : item.relationTypeFormatted;
    if (!nodes.containsKey(key)) {
      order.add(key);
      nodes[key] = [];
      seen[key] = {};
      fallback[key] = item.relationTypeFormatted;
    }
    if (seen[key]!.add(item.animenode.id)) nodes[key]!.add(item.animenode);
  }
  return [
    for (final key in order)
      RelatedGroup(
          key, GraphLabels.relation(key, fallback: fallback[key]), nodes[key]!),
  ];
}

/// Every title of [groups] once, in group order.
List<Anime> allRelatedNodes(List<RelatedGroup> groups) {
  final seen = <int>{};
  return [
    for (final group in groups)
      for (final node in group.nodes)
        if (seen.add(node.id)) node,
  ];
}

/// The list status words (MAL's) known from the nodes themselves, by id.
Map<int, String> statusesOf(Iterable<Anime> nodes) => {
      for (final node in nodes)
        if (node.myListStatus != null) node.id: node.myListStatus!.status,
    };
