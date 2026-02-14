import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';

class RelatedAnimeWidget extends StatefulWidget {
  final List<RelatedAnime> relatedAnimeList;
  final String category;
  final double horizPadding;
  final DisplayType displayType;
  final int id;
  final Map<int, MyListStatus>? statusMap;
  const RelatedAnimeWidget({
    super.key,
    required this.relatedAnimeList,
    this.category = "anime",
    required this.horizPadding,
    required this.id,
    this.displayType = DisplayType.list_horiz,
    this.statusMap,
  });

  @override
  // ignore: library_private_types_in_public_api
  _RelatedAnimeWidgetState createState() => _RelatedAnimeWidgetState();
}

class _RelatedAnimeWidgetState extends State<RelatedAnimeWidget>
    with AutomaticKeepAliveClientMixin {
  Map<String, List<Anime>> animeWidgets = {};
  int pageIndex = 0;
  bool isHoriz = true;
  // dynamic _graph;
  // _SelectedView _selectedView = _SelectedView.list;

  @override
  void initState() {
    super.initState();
    isHoriz = widget.displayType == DisplayType.list_horiz;
    for (var relatedAnime in widget.relatedAnimeList) {
      // Récupère le relationTypeFormatted
      final String relationTypeFormatted = relatedAnime.relationTypeFormatted;

      // Si la clé existe déjà dans le Map, récupère la liste associée, sinon initialise une nouvelle liste
      final baseNodes = animeWidgets[relationTypeFormatted] ?? [];

      // Ajoute le animenode à la liste
      baseNodes.add(relatedAnime.animenode);

      // Réassigne la liste mise à jour dans le Map
      animeWidgets[relationTypeFormatted] = baseNodes;
    }
    if (!isHoriz) {
      _setAnimeGraph();
    }
  }

  void _setAnimeGraph() async {}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<HomePreferencesBloc, HomePreferencesState>(
      builder: (context, homePreferencesState) {
        final preferences = homePreferencesState.preferences;
        return DefaultTabController(
          length: animeWidgets.keys.length,
          child: isHoriz ? _horizView(preferences) : _animeGraph,
        );
      },
    );
  }

  Widget get _animeGraph {
    return const SizedBox();
  }

  Column _horizView(MalHomePreferences preferences) {
    final nodeList = animeWidgets[animeWidgets.keys.elementAt(pageIndex)];
    final tileSize = getTileSizeValues(preferences.tileSize);
    final double cardWidth = tileSize.containerHeight * (2 / 3);
    final double cardHeight = tileSize.containerHeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _relationTypeHeader,
        const SizedBox(height: 20),
        ContentListWidget(
          category: widget.category,
          height: cardHeight,
          items: nodeList ?? [],
          tileWidth: cardWidth,
          tileHeight: cardHeight,
        ),
      ],
    );
  }

  Widget get _relationTypeHeader {
    return SizedBox(
      height: 32,
      child: _tabBar,
    );
  }

  PreferredSizeWidget get _tabBar {
    return TabBar(
      isScrollable: true,
      onTap: (index) => _onTabTapped(index),
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.symmetric(horizontal: widget.horizPadding),
      tabs: animeWidgets.keys
          .map((e) => Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(
                  e,
                  style: const TextStyle(fontSize: 13.0),
                ),
              ))
          .toList(),
    );
  }

  _onTabTapped(int index) {
    setState(() {
      pageIndex = index;
    });
  }

  @override
  bool get wantKeepAlive => true;
}
