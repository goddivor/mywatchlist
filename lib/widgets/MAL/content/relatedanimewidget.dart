import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
import 'package:mywatchlist/widgets/graph/anime_graph_screen.dart';
import 'package:mywatchlist/widgets/graph/related_grid_screen.dart';
import 'package:mywatchlist/widgets/graph/related_groups.dart';

/// "Related" section of a detail page: one tab per relation over a horizontal row of cards, a
/// "view all" grid with the user's list statuses, and (for an anime) the relation graph of the
/// whole franchise, which can be shared as an image.
class RelatedAnimeWidget extends StatefulWidget {
  final List<RelatedAnime> relatedAnimeList;

  /// `anime` or `manga`, the category of the page this section belongs to. The relation graph
  /// exists for anime only.
  final String category;
  final double horizPadding;

  /// MAL id of the page this section belongs to.
  final int id;

  /// Name of the page's title, used to name the shared image.
  final String? title;

  const RelatedAnimeWidget({
    super.key,
    required this.relatedAnimeList,
    this.category = 'anime',
    required this.horizPadding,
    required this.id,
    this.title,
  });

  @override
  State<RelatedAnimeWidget> createState() => _RelatedAnimeWidgetState();
}

class _RelatedAnimeWidgetState extends State<RelatedAnimeWidget>
    with AutomaticKeepAliveClientMixin {
  late List<RelatedGroup> _groups = groupRelated(widget.relatedAnimeList);
  int _tab = 0;

  @override
  void didUpdateWidget(RelatedAnimeWidget old) {
    super.didUpdateWidget(old);
    if (!identical(old.relatedAnimeList, widget.relatedAnimeList)) {
      _groups = groupRelated(widget.relatedAnimeList);
      if (_tab >= _groups.length) _tab = 0;
    }
  }

  bool get _hasGraph => widget.category == 'anime';

  void _openGraph() {
    AppRoutes.push(
      context,
      AnimeGraphScreen(
        id: widget.id,
        title: widget.title,
        fallbackStatuses: statusesOf(allRelatedNodes(_groups)),
      ),
    );
  }

  void _openGrid() {
    AppRoutes.push(
      context,
      RelatedGridScreen(
        category: widget.category,
        groups: _groups,
        onOpenGraph: _hasGraph ? _openGraph : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_groups.isEmpty) return const SizedBox.shrink();
    return BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
      buildWhen: (a, b) => a.preferences.tileSize != b.preferences.tileSize,
      builder: (context, state) {
        final tile = getTileSizeValues(state.preferences.tileSize);
        final cardHeight = tile.containerHeight;
        final cardWidth = cardHeight * (2 / 3);
        final group = _groups[_tab.clamp(0, _groups.length - 1)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 12),
            ContentListWidget(
              key: ValueKey(group.relationType),
              category: widget.category,
              height: cardHeight,
              items: group.nodes,
              tileWidth: cardWidth,
              tileHeight: cardHeight,
            ),
          ],
        );
      },
    );
  }

  Widget _header() {
    return DefaultTabController(
      length: _groups.length,
      initialIndex: _tab.clamp(0, _groups.length - 1),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.symmetric(horizontal: widget.horizPadding),
                dividerHeight: 0,
                onTap: (index) => setState(() => _tab = index),
                tabs: [
                  for (final group in _groups)
                    Tab(
                        height: 36,
                        child: Text(group.label,
                            style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
            IconButton(
              tooltip: S.current.Rg_View_All,
              visualDensity: VisualDensity.compact,
              onPressed: _openGrid,
              icon: const Icon(Icons.grid_view_rounded),
            ),
            if (_hasGraph)
              IconButton(
                tooltip: S.current.Rg_Graph,
                visualDensity: VisualDensity.compact,
                onPressed: _openGraph,
                icon: const Icon(Icons.hub_outlined),
              ),
            SizedBox(
                width: widget.horizPadding > 4 ? widget.horizPadding - 4 : 0),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
