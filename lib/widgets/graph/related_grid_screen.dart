import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/contentdetailedscreen.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/graph/related_groups.dart';

const Set<String> _mangaMediaTypes = {
  'manga',
  'light_novel',
  'one_shot',
  'doujinshi',
  'manhwa',
  'manhua',
  'novel'
};

/// `manga` for a manga-like media type, [fallback] otherwise.
String relatedCategoryOf(Anime node, String fallback) {
  final type = node.mediaType;
  if (type == null) return fallback;
  return _mangaMediaTypes.contains(type) ? 'manga' : 'anime';
}

/// Every related title of a page as a grid, one tab per relation (and "All" first). Each card
/// carries the user's list status (from the status cache), so a franchise reads at a glance:
/// what is watched, what is planned, what is not in the list yet.
class RelatedGridScreen extends StatelessWidget {
  final String category;
  final List<RelatedGroup> groups;

  /// Opens the relation graph; the app bar shows the button only when given.
  final VoidCallback? onOpenGraph;

  const RelatedGridScreen(
      {super.key,
      required this.category,
      required this.groups,
      this.onOpenGraph});

  @override
  Widget build(BuildContext context) {
    final all = allRelatedNodes(groups);
    final tabs = <_Tab>[
      if (groups.length > 1) _Tab(S.current.Rg_All, all),
      for (final group in groups) _Tab(group.label, group.nodes),
    ];
    final theme = Theme.of(context);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category == 'manga'
                  ? S.current.Rg_Related_Manga
                  : S.current.Rg_Related_Anime),
              Text(
                S.current.Rg_Related_Count(all.length),
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            if (onOpenGraph != null)
              IconButton(
                  tooltip: S.current.Rg_Graph,
                  onPressed: onOpenGraph,
                  icon: const Icon(Icons.hub_outlined)),
          ],
          bottom: tabs.length > 1
              ? TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final tab in tabs)
                      Tab(text: '${tab.label} (${tab.nodes.length})')
                  ],
                )
              : null,
        ),
        body: TabBarView(
          children: [
            for (final tab in tabs)
              _RelatedGrid(category: category, nodes: tab.nodes),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final List<Anime> nodes;
  const _Tab(this.label, this.nodes);
}

class _RelatedGrid extends StatelessWidget {
  final String category;
  final List<Anime> nodes;

  const _RelatedGrid({required this.category, required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return Center(child: Text(S.current.Rg_Nothing_Here));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 170,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final itemCategory = relatedCategoryOf(node, category);
        return AnimeGridCard(
          key: ValueKey('$itemCategory:${node.id}'),
          node: node,
          category: itemCategory,
          aspectRatio: 2 / 3,
          showCardBar: true,
          showMemberCount: true,
          displaySubType: DisplaySubType.compact,
          onTap: () => AppRoutes.push(context,
              ContentDetailedScreen(node: node, category: itemCategory)),
        );
      },
    );
  }
}
