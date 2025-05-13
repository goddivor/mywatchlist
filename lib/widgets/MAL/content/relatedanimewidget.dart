import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/MAL/home/contentlistwidget.dart';
// import 'package:my_watch_list/widgets/silvers.dart';

// enum _SelectedView {
//   list,
//   graph,
// }

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

  void _setAnimeGraph() async {
    // final now = DateTime.now().millisecondsSinceEpoch / 1000;
    // try {
    //   _graph = await DalApi.i.getAnimeGraph(widget.id);
    //   final then = DateTime.now().millisecondsSinceEpoch / 1000;
    //   if (_graph is AnimeGraph && nullOrEmpty(_graph.edges)) {
    //     throw Error();
    //   }
    //   if ((then - now) > 1) {
    //     showSnackBar(_graphSnackBar(), Duration(seconds: 3));
    //   }
    // } catch (e) {
    //   final then = DateTime.now().millisecondsSinceEpoch / 1000;
    //   _graph = e;
    //   if ((then - now) > 1) {
    //     showSnackBar(_graphSnackBar());
    //   }
    // }
    // if (mounted) setState(() {});
  }

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

  // Widget get _animeGraph {
  //   if (_selectedView == _SelectedView.list) {
  //     return _gridView;
  //   } else {
  //     if (_graph is AnimeGraph) {
  //       return _graphWidget(_graph);
  //     } else {
  //       return _noContentView();
  //     }
  //   }
  // }

  // Widget _noContentView() {
  //   return TitlebarScreen(
  //     Center(child: showNoContent()),
  //     appbarTitle: _appBarTitle,
  //     actions: _getActions(false),
  //     autoIncludeSearch: false,
  //   );
  // }

  // Widget _graphWidget(AnimeGraph data) {
  //   return AnimeGraphWidget(
  //     id: widget.id,
  //     graph: data,
  //     statusMap: widget.statusMap ?? {},
  //     actions: _getActions(true),
  //   );
  // }

  // NestedScrollView get _gridView {
  //   return NestedScrollView(
  //     headerSliverBuilder: (context, innerBoxIsScrolled) => [
  //       SliverAppBarWrapper(
  //         bottom: _tabBar,
  //         expandedHeight: 93,
  //         title: Text(_appBarTitle),
  //         actions: _getActions(innerBoxIsScrolled),
  //       )
  //     ],
  //     body: TabBarView(
  //       children: animeWidgets.values
  //           .map((e) => CustomScrollWrapper([
  //                 SB.lh20,
  //                 _contentListWidget(e),
  //                 SB.lh60,
  //               ]))
  //           .toList(),
  //     ),
  //   );
  // }

  // String get _appBarTitle => '${S.current.Related} ${widget.category}';

  // Widget _graphSnackBar() {
  //   return Row(
  //     children: [
  //       Expanded(
  //         child: Text(
  //           _graph is AnimeGraph
  //               ? S.current.Graph_loaded
  //               : S.current.Couldnt_generate_graph,
  //         ),
  //       ),
  //       SB.w10,
  //       if (_graph is AnimeGraph)
  //         ShadowButton(
  //           onPressed: () => _switchView(),
  //           child: Text(S.current.Switch),
  //         )
  //     ],
  //   );
  // }

  // List<Widget> _getActions(bool innerBoxIsScrolled) {
  //   return [
  //     if (_graph is AnimeGraph)
  //       IconButton(
  //         onPressed: () => _switchView(),
  //         icon: Icon(
  //           _selectedView == _SelectedView.list
  //               ? Icons.graphic_eq
  //               : Icons.list_alt,
  //         ),
  //       ),
  //     if (_graph == null && !innerBoxIsScrolled)
  //       SizedBox(
  //         width: 25,
  //         height: 25,
  //         child: CircularProgressIndicator(
  //           strokeWidth: 1.5,
  //         ),
  //       ),
  //     PopupMenuBuilder(
  //       menuItems: [
  //         shareMenuItem()
  //           ..onTap = () {
  //             openShareBuilder(
  //               context,
  //               animeWidgets.entries
  //                   .map((e) => ShareInput(
  //                         title: e.key,
  //                         content: e.value
  //                             .map((f) => buildShareOutput(
  //                                   buildShareInputs(
  //                                     f.content,
  //                                     DalPathUtils.browserUrl(DalNode(
  //                                       category: widget.category,
  //                                       id: f.content!.id!,
  //                                     )),
  //                                     category: widget.category,
  //                                   ),
  //                                   props: ShareOutputProps(prefix: '\t'),
  //                                 ))
  //                             .reduce((e1, e2) => '$e1 \n$e2'),
  //                       ))
  //                   .toList(),
  //               S.current.Related,
  //               props: ShareOutputProps(termSpace: '\n', forceReducer: true),
  //             );
  //           },
  //         AppbarMenuItem(
  //           S.current.Edit,
  //           createIcon(Icons.edit),
  //           onTap: () => DalPathUtils.launchNodeInBrowser(
  //             DalNode(
  //                 id: widget.id,
  //                 category: widget.category,
  //                 dalSubType: DalSubType.relations,
  //                 queryParams: {
  //                   '${widget.category.equals('anime') ? "aid" : "mid"}':
  //                       widget.id,
  //                 }),
  //             context,
  //           ),
  //         ),
  //       ],
  //     ),
  //   ];
  // }

  // void _switchView() {
  //   setState(() {
  //     _selectedView = _selectedView == _SelectedView.list
  //         ? _SelectedView.graph
  //         : _SelectedView.list;
  //   });
  // }

  Column _horizView(MalHomePreferences preferences) {
    final nodeList = animeWidgets[animeWidgets.keys.elementAt(pageIndex)];
    final tileSize = getTileSizeValues(preferences.tileSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _relationTypeHeader,
        const SizedBox(height: 20),
        ContentListWidget(
          category: widget.category,
          height: tileSize.containerHeight,
          items: nodeList ?? [],
          tileWidth: tileSize.contentWidth,
          tileHeight: tileSize.contentHeight,
        ),
      ],
    );
  }

  // Widget _contentListWidget(List<BaseNode>? nodeList) {
  //   return ContentListWithDisplayType(
  //     category: widget.category,
  //     items: nodeList ?? [],
  //     sortFilterDisplay: SortFilterDisplay.withDisplayType(
  //       DisplayOption(
  //         displayType: DisplayType.grid,
  //         displaySubType: DisplaySubType.compact,
  //       ),
  //     ),
  //   );
  // }

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
