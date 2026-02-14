// ignore_for_file: prefer_interpolation_to_compose_strings, unused_element, unused_field

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_anime_videos.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/anime_detailed_html.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/mal_scrapper.dart';
import 'package:mywatchlist/utils/streamutils.dart';
import 'package:mywatchlist/widgets/MAL/content/adaptation_widget.dart';
import 'package:mywatchlist/widgets/MAL/home/animecharacterwidget.dart';
import 'package:mywatchlist/widgets/MAL/content/animepictures.dart';
import 'package:mywatchlist/widgets/MAL/content/animestatisticswidget.dart';
import 'package:mywatchlist/widgets/common/auto_size_copy_text.dart';
import 'package:mywatchlist/widgets/common/background.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:mywatchlist/widgets/MAL/content/intereststackwidget.dart';
import 'package:mywatchlist/widgets/MAL/content/media_platforms.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';
import 'package:mywatchlist/widgets/MAL/content/recommanimewidget.dart';
import 'package:mywatchlist/widgets/MAL/content/relatedanimewidget.dart';
import 'package:mywatchlist/widgets/MAL/content/scorestatisticswidget.dart';
import 'package:mywatchlist/widgets/loading/shimmercolor.dart';
import 'package:mywatchlist/widgets/MAL/content/show_featured.dart';
import 'package:mywatchlist/widgets/MAL/content/show_forum.dart';
import 'package:mywatchlist/widgets/MAL/home/show_news.dart';
import 'package:mywatchlist/widgets/MAL/content/show_reviews.dart';
import 'package:mywatchlist/widgets/common/slivers.dart';
import 'package:mywatchlist/widgets/MAL/content/synopsis_widget.dart';
import 'package:mywatchlist/widgets/MAL/content/userupdate_widget.dart';
import 'package:mywatchlist/widgets/MAL/content/videowidget.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

enum TitleLang { en, ja, ro }

class VisibleSection {
  final String title;
  final Widget child;
  final bool skipTitle;
  final bool isTab;
  final VoidCallback? onViewAll;
  final Widget? additionalWidget;

  VisibleSection(
    this.title,
    this.child, {
    this.isTab = true,
    this.onViewAll,
    this.skipTitle = false,
    this.additionalWidget,
  });
}

class ContentDetailedScreen extends StatefulWidget {
  final Anime? node;
  final int? id;
  final String? heroTag;
  final String category;

  const ContentDetailedScreen({
    super.key,
    required this.node,
    this.id,
    this.category = "anime",
    this.heroTag,
  });

  @override
  State<ContentDetailedScreen> createState() => _ContentDetailedScreenState();
}

class _ContentDetailedScreenState extends State<ContentDetailedScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ScrollController _scrollController;

  var visibleSections = <VisibleSection>[];
  static const horizPadding = 15.0;
  bool isCacheRefreshed = false;
  var visibleTabSections = <String>[];
  final GlobalKey _listKey = GlobalKey();
  late StreamListener<bool> fabListener;
  late Stream<bool> fabIsVisible;
  List<GlobalKey> _globalKeys = [];
  TabController? _tabController;
  AutoScrollController? _autoScrollController;
  TitleLang titleLang = TitleLang.ro;
  NumberFormat userCountFormat =
      NumberFormat.currency(decimalDigits: 0, name: "");
  NumberFormat ratingFormat = NumberFormat.currency(name: "");
  bool showContentEdit = false;
  dynamic contentDetailed;
  dynamic animeDetailedHtml;

  String get _title => widget.node?.title ?? contentDetailed?.title;
  int get _id => (widget.node != null ? widget.node!.id : widget.id)!;
  AnimeVideos? animeVideoV4;
  dynamic _scheduleData;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scrollController = ScrollController();

    _animationController.forward();

    _autoScrollController = AutoScrollController();

    _addFabListener();
    Future.delayed(Duration.zero).then((_) {
      getPageContent();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
    _autoScrollController?.dispose();
    _tabController?.dispose();
    fabListener.dispose();
  }

  void _addFabListener() {
    fabListener = StreamListener<bool>(true);
    fabIsVisible = fabListener.stream;
    _autoScrollController?.addListener(() {
      fabListener.update(_autoScrollController!.position.userScrollDirection ==
          ScrollDirection.forward);
    });
  }

  getPageContent() {
    try {
      getMalApiContent(); // get content from malapi
      getMalApiHtmlContent(); //get content from html (malscraper)
      if (widget.category == "anime") {
        getJikanVideos(); // get videos from jikan (anime only)
      }

      updateVisibleSections();
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void getMalApiContent() async {
    try {
      if (widget.category == "manga") {
        contentDetailed = await MalApi().getMangaDetails(_id);
      } else {
        contentDetailed = await MalApi().getAnimeDetails(_id);
      }
      updateVisibleSections();
      setStatus();
    } catch (e) {
      debugPrint('Error loading MAL details for $_id: $e');
      if (mounted) setState(() {});
    }
  }

  void getJikanVideos() async {
    try {
      animeVideoV4 = await JikanApi().getAnimeVideos(_id);
      updateVisibleSections();
    } catch (e) {
      debugPrint('Error loading Jikan videos for $_id: $e');
    }
  }

  void getMalApiHtmlContent() async {
    try {
      final contentType = widget.category == "manga"
          ? ContentType.manga
          : ContentType.anime;
      animeDetailedHtml =
          (await MalScraper().getAnimeDetailedHtml(contentType, _id));
      updateVisibleSections();
    } catch (e) {
      debugPrint('Error loading HTML details for $_id: $e');
    }
  }

  List<AdaptNode> getAdaptationsFromData(dynamic animeDetails) {
    // Récupère la liste "adaptation" du Map si elle existe
    List<dynamic>? adaptationsJson = animeDetails['adaptation'];

    // Si la liste est null ou vide, retourne une liste vide
    if (adaptationsJson == null) {
      return [];
    }

    // Convertit chaque élément JSON en objet Adaptation
    return adaptationsJson.map((json) => AdaptNode.fromJson(json)).toList();
  }

  List<CharactersVoiceActors> getCharactersVoiceActors(dynamic animeDetails) {
    // Récupère la liste "charactersVoiceActors" du Map si elle existe
    List<dynamic>? charactersVoiceActorsJson =
        animeDetails['charactersVoiceActors'];

    // Si la liste est null ou vide, retourne une liste vide
    if (charactersVoiceActorsJson == null) {
      return [];
    }

    // Convertit chaque élément JSON en objet CharactersVoiceActors
    return charactersVoiceActorsJson
        .map((json) => CharactersVoiceActors.fromJson(json))
        .toList();
  }

  List<MangaCharacters> getMangaCharacters(dynamic animeDetails) {
    List<dynamic>? mangaCharsJson = animeDetails['mangaCharacters'];
    if (mangaCharsJson == null) return [];
    return mangaCharsJson.map((json) => MangaCharacters.fromJson(json)).toList();
  }

  List<InterestStack> getInterestStack(dynamic animeDetails) {
    // Récupère la liste "interestStacks" du Map si elle existe
    List<dynamic>? interestStacksJson = animeDetails['interestStacks'];

    // Si la liste est null ou vide, retourne une liste vide
    if (interestStacksJson == null) {
      return [];
    }

    // Convertit chaque élément JSON en objet InterestStack
    return interestStacksJson
        .map((json) => InterestStack.fromJson(json))
        .toList();
  }

  setStatus() {
    if (contentDetailed != null && mounted) {
      setState(() {
        isCacheRefreshed = true;
      });
    }
  }

  void updateVisibleSections() {
    visibleSections = _contentVisibleSections;
    visibleTabSections =
        visibleSections.where((e) => e.isTab).map((e) => e.title).toList();
    _tabController = TabController(
        length: visibleTabSections.length, vsync: this, initialIndex: 0);
    _globalKeys = List.generate(
      visibleSections.length,
      (index) => GlobalKey(debugLabel: index.toString()),
    );
    _autoScrollController?.addListener(() {
      if (_tabController != null) {
        _tabController!.index = _getCenterItemIndex();
      }
    });
    if (mounted) setState(() {});
  }

  int _getCenterItemIndex() {
    final listViewBoundaries = _listViewBoundaries();
    final listViewBottom = listViewBoundaries[1];
    final listViewCenter = listViewBoundaries[2];

    for (var i = 0; i < visibleTabSections.length; i++) {
      var itemTop = 0.0;
      var itemBottom = 0.0;
      try {
        final itemBox =
            _globalKeys[i].currentContext!.findRenderObject() as RenderBox?;
        itemTop = itemBox!.localToGlobal(Offset.zero).dy;
        itemBottom = itemTop + itemBox.size.height;
      } catch (e) {
        // handle exception if item is not visible
      }

      if (itemTop > listViewBottom) {
        break;
      }

      if (itemTop <= listViewCenter && itemBottom >= listViewCenter) {
        return i;
      }
    }

    return 0; // if no item is in the center of the screen
  }

  List<double> _listViewBoundaries() {
    final listViewBox =
        _listKey.currentContext!.findRenderObject() as RenderBox?;
    final listViewTop = listViewBox!.localToGlobal(Offset.zero).dy;
    final listViewBottom = listViewTop + listViewBox.size.height;
    final listViewCenter = listViewTop + listViewBox.size.height / 2;
    return [listViewTop, listViewBottom, listViewCenter];
  }

  List<VisibleSection> get _contentVisibleSections {
    return TabType.values
        .map(_getSectionForType)
        .where((e) => e != null)
        .map((e) => e!)
        .toList();
  }

  T? _nullIf<T>(bool condition, T Function() child) {
    if (condition) {
      return child();
    } else {
      return null;
    }
  }

  bool get isAnimeVideosBlank {
    if (animeVideoV4 == null && contentDetailed == null) return true;
    if (nullOrEmpty(animeVideoV4?.episodes) &&
        nullOrEmpty(animeVideoV4?.musicVideos) &&
        nullOrEmpty(animeVideoV4?.promo) &&
        nullOrEmpty(contentDetailed?.openingSongs) &&
        nullOrEmpty(contentDetailed?.endingSongs)) {
      return true;
    }
    return false;
  }

  bool get isStreamingBlank {
    return animeDetailedHtml == null ||
        (nullOrEmpty(animeDetailedHtml['availableAt']) &&
            nullOrEmpty(animeDetailedHtml['resources']) &&
            nullOrEmpty(animeDetailedHtml['streamingPlatforms']));
  }

  // Ajouter cette méthode pour convertir les liens de animeDetailedHtml
  List<AnimeLink> _getAnimeLinks() {
    if (animeDetailedHtml == null) return [];

    List<AnimeLink> links = [];

    try {
      // Helper function to safely add links from a list
      void addLinksFromList(dynamic linkList, LinkType type) {
        if (linkList != null && linkList is List) {
          for (var item in linkList) {
            try {
              dynamic link = item;

              // Handle different possible structures
              String? name;
              String? url;
              String? imageUrl;

              if (link is Map<String, dynamic>) {
                name = link['name']?.toString();
                url = link['url']?.toString();
                imageUrl = link['imageUrl']?.toString();
              } else if (link.runtimeType.toString().contains('Link')) {
                // Dynamic access for objects with name, url, and imageUrl properties
                name = link.name;
                url = link.url;
                imageUrl = link.imageUrl;
              }

              if (name != null &&
                  url != null &&
                  name.isNotEmpty &&
                  url.isNotEmpty) {
                links.add(AnimeLink(
                  name: name,
                  url: url,
                  imageUrl: imageUrl,
                  linkType: type,
                ));
              }
            } catch (e) {
              print('Error processing individual link: $e');
            }
          }
        }
      }

      // Process each category
      addLinksFromList(animeDetailedHtml['availableAt'], LinkType.availableAt);
      addLinksFromList(animeDetailedHtml['resources'], LinkType.resources);
      addLinksFromList(
          animeDetailedHtml['streamingPlatforms'], LinkType.streaming);
    } catch (e) {
      print('Error getting anime links: $e');
    }

    return links;
  }

  Widget get _buildMediaWidget {
    final sp = AddtionalMediaPlatforms(
      _getAnimeLinks(),
      relatedLinks: _scheduleData?.relatedLinks,
    );
    final vW = VideosWidget(
      videos: animeVideoV4,
      horizPadding: horizPadding,
      endingSongs: contentDetailed?.endingSongs,
      openingSongs: contentDetailed?.openingSongs,
    );
    if (isAnimeVideosBlank) return sp;
    if (isStreamingBlank) return vW;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [sp, SB.h20, vW],
    );
  }

  bool get _isManga => widget.category == "manga";

  VisibleSection? _getSectionForType(TabType tabType) {
    return switch (tabType) {
      TabType.Synopsis => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Synopsis',
            SysonpsisWidget(
              synopsis: contentDetailed.synopsis,
              genres: contentDetailed.genres,
              background: contentDetailed.background,
              category: widget.category,
              horizPadding: horizPadding,
            ),
          ),
        ),
      TabType.Media => _isManga
          ? _nullIf(
              !isStreamingBlank,
              () => VisibleSection(
                'Media',
                _buildMediaWidget,
              ),
            )
          : _nullIf(
              contentDetailed != null && !isAnimeVideosBlank || !isStreamingBlank,
              () => VisibleSection(
                'Media',
                _buildMediaWidget,
              ),
            ),
      TabType.Related => _nullIf(
          !nullOrEmpty(contentDetailed?.relatedAnime) ||
              !nullOrEmpty(contentDetailed?.relatedManga),
          () => VisibleSection(
            'Related',
            RelatedAnimeWidget(
              relatedAnimeList: [
                ...?contentDetailed?.relatedAnime,
                ...?contentDetailed?.relatedManga
                    ?.map((rm) => RelatedAnime(
                          animenode: rm.manganode,
                          relationType: rm.relationType,
                          relationTypeFormatted: rm.relationTypeFormatted,
                        )),
              ],
              horizPadding: horizPadding,
              id: _id,
            ),
          ),
        ),
      TabType.Adaptations => _nullIf(
          animeDetailedHtml != null &&
              (getAdaptationsFromData(animeDetailedHtml)).isNotEmpty,
          () => VisibleSection(
            'Adaptations',
            AdaptationsWidget(
              nodes: getAdaptationsFromData(animeDetailedHtml),
            ),
          ),
        ),
      TabType.Reviews => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Reviews',
            ShowAnimeReviews(
              animeId: _id,
              category: widget.category,
            ),
          ),
        ),
      TabType.Recommendations => _nullIf(
          !nullOrEmpty(contentDetailed?.recommendations),
          () => VisibleSection(
            'Recommendations',
            RecommendedAnimeWidget(
              category: widget.category,
              horizPadding: horizPadding,
              recommAnime: contentDetailed.recommendations,
            ),
          ),
        ),
      TabType.Interest_Stacks => _nullIf(
          animeDetailedHtml != null,
          () => VisibleSection(
            'Interest Stacks',
            InterestStackContentList(
              horizPadding: horizPadding,
              interestStacks: getInterestStack(animeDetailedHtml),
            ),
          ),
        ),
      TabType.Characters => _nullIf(
          animeDetailedHtml != null,
          () => VisibleSection(
            'Characters',
            _isManga
                ? AnimeCharacterWidget(
                    mangaCharacterList: getMangaCharacters(animeDetailedHtml),
                    horizPadding: horizPadding,
                  )
                : AnimeCharacterWidget(
                    animeCharacterList: getCharactersVoiceActors(animeDetailedHtml),
                    horizPadding: horizPadding,
                  ),
          ),
        ),
      TabType.Forums => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Forums',
            ShowAnimeForum(animeId: _id, category: widget.category),
          ),
        ),
      TabType.Pictures => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Pictures',
            AnimePictures(
              pictures: contentDetailed.pictures,
            ),
          ),
        ),
      TabType.Related_Anime => null,
      TabType.News => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'News',
            ShowAnimeNews(animeId: _id, category: widget.category),
          ),
        ),
      TabType.Featured_Articles => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Featured Articles',
            ShowAnimeFeatured(
              animeId: _id,
              animeName: contentDetailed?.title ?? widget.node?.title ?? "",
              category: widget.category,
            ),
          ),
        ),
      TabType.User_Updates => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'User Updates',
            UserUpdatesPage(
              horizPadding: horizPadding,
              category: widget.category,
              id: _id,
            ),
          ),
        ),
      TabType.More_Info => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'More Info',
            MoreInfoWidget(
              anime: contentDetailed,
              additionalTitles: animeDetailedHtml != null
                  ? animeDetailedHtml['additionalTitles']
                  : null,
              horizPadding: horizPadding,
              category: widget.category,
            ),
          ),
        ),
      TabType.Stats => _nullIf(
          contentDetailed?.statistics != null,
          () => VisibleSection(
            'Stats',
            AnimeStatisticsWidget(stats: contentDetailed.statistics),
          ),
        ),
      TabType.ScoreStats => _nullIf(
          contentDetailed != null,
          () => VisibleSection(
            'Score stats',
            ScoreStatisticsWidget(
              horizPadding: horizPadding,
              category: widget.category,
              id: _id,
            ),
          ),
        ),
    };
  }

  Widget _buildVisibleSection(int index) {
    final section = visibleSections[index];
    final sectionWidget = Column(
      children: [
        if (index != 0 && !section.skipTitle)
          Padding(
            padding: const EdgeInsets.only(
              left: horizPadding + 10,
              top: 25,
              right: horizPadding + 10,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                text(section.title, fontSize: 22),
                if (section.onViewAll != null ||
                    section.additionalWidget != null) ...[
                  const Expanded(child: SizedBox.shrink()),
                  if (section.additionalWidget != null) ...[
                    section.additionalWidget!,
                    const SizedBox(width: 15),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(right: horizPadding),
                    child: PlainButton(
                      padding:
                          const EdgeInsets.symmetric(horizontal: horizPadding),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onPressed: section.onViewAll,
                      child: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ]
              ],
            ),
          ),
        const SizedBox(height: 20),
        section.child,
      ],
    );

    if (section.isTab) {
      final titleIndex = visibleTabSections.indexOf(section.title);
      return wrapScrollTag(
        controller: _autoScrollController!,
        index: titleIndex,
        child: SizedBox(
          key: _globalKeys[titleIndex],
          child: sectionWidget,
        ),
      );
    } else {
      return sectionWidget;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !showContentEdit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && showContentEdit && mounted) {
          setState(() {
            showContentEdit = false;
          });
        }
      },
      child: Scaffold(
        floatingActionButtonLocation:
            showContentEdit ? FloatingActionButtonLocation.centerFloat : null,
        floatingActionButton: _buildFloatingActionButton(),
        floatingActionButtonAnimator: NoScalingAnimation(),
        body: Stack(
          children: [
            CustomScrollView(
              key: _listKey,
              controller: _autoScrollController,
              slivers: [
                //let's start with the appbar
                _appBar,
                //now the contentbody
                contentDetailedBody,
                //little space a the bottom
                const SliverWrapper(SizedBox(height: 80)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar get _appBar {
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      expandedHeight: 460,
      toolbarHeight: 40.0,
      title: scrollStreamWidget(Text(animeTitle), (viseble) => !viseble),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: ShimmerConditionally(
          showShimmer: contentDetailed == null,
          baseColor: Theme.of(context).scaffoldBackgroundColor,
          highlightColor:
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .3),
          child: animeHeader,
        ),
      ),
      bottom: tabBarWidget,
      actions: [
        IconButton(
            onPressed: () => (), // implement goto search page here
            icon: const Icon(Icons.search)),
        //add appmenuwiget here
      ],
    );
  }

  PreferredSizeWidget get tabBarWidget {
    final tabBar = TabBar(
      isScrollable: true,
      controller: _tabController,
      tabAlignment: TabAlignment.start,
      onTap: (index) => _autoScrollController?.scrollToIndex(
        index,
        preferPosition: AutoScrollPosition.middle,
      ),
      tabs: visibleTabSections.map((title) => Tab(text: title)).toList(),
    );
    if (contentDetailed == null) {
      return const PreferredSize(
        preferredSize: Size(double.infinity, 40),
        child: ShimmerColor(SizedBox.shrink()),
      );
    } else {
      return tabBar;
    }
  }

  Widget get contentDetailedBody {
    if (contentDetailed == null) {
      return const SliverWrapper(SysonpsisWidget());
    }
    return SliverList(
        delegate: SliverChildBuilderDelegate(
      (context, index) => _buildVisibleSection(index),
      childCount: visibleSections.length,
    ));
  }

  Widget get animeHeader {
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 35),
        _titleWidget,
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: SizedBox()),
            Expanded(flex: 9, child: animeCard),
            Expanded(child: Container()),
            Expanded(flex: 7, child: animeDetailsHeader)
          ],
        ),
        const SizedBox(height: 15),
      ],
    );
    return Stack(children: [
      Background(
        context: context,
        forceBg: true,
        url: contentDetailed?.mainPicture?.large,
      ),
      if (contentDetailed != null)
        Material(
          color: Colors.transparent,
          child: headerContent,
        ),
      if (contentDetailed == null) headerContent
    ]);
  }

  Widget get _titleWidget {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        height: 40.0,
        width: double.infinity,
        child: Center(
          child: AutoSizeCopyText(
            animeTitle, // change with animeTitle later
            style: const TextStyle(fontSize: 24),
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String get animeTitle => titleLang == TitleLang.ro
      ? (contentDetailed?.title?.toString() ?? widget.node?.title ?? "?")
      : contentDetailed?.alternativeTitles == null
          ? '?'
          : titleLang == TitleLang.en
              ? contentDetailed.alternativeTitles.en.toString().equals("")
                  ? (widget.node?.title ?? contentDetailed?.title?.toString())
                  : contentDetailed.alternativeTitles.en.toString()
              : contentDetailed.alternativeTitles.ja.toString().equals("")
                  ? (widget.node?.title ?? contentDetailed?.title?.toString())
                  : contentDetailed.alternativeTitles.ja;

  Widget _heroWrapper(Widget child) {
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: child,
      );
    } else {
      return child;
    }
  }

  String get _url =>
      widget.node?.imageUrl ?? contentDetailed?.mainPicture?.large ?? "";

  Widget get animeCard {
    final urlList = [_url];
    if (!nullOrEmpty(contentDetailed?.pictures)) {
      final list = (contentDetailed.pictures as List<Picture>)
          .map((e) => e.large)
          .whereType<String>();
      urlList.addAll(list);
    }
    return _heroWrapper(
      SizedBox(
        height: 320.0,
        child: Stack(
          children: [
            InkWell(
              onTap: () => zoomInImageList(context, urlList),
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: urlList.first,
                placeholder: (context, url) => loadingInner(),
                errorWidget: (context, url, error) => loadingError(),
                imageBuilder: (context, imageProvider) => Ink(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      image: DecorationImage(
                          fit: BoxFit.cover, image: imageProvider)),
                ),
              ),
            ),
            Positioned(top: 5, right: 5, child: langChangeWidget()),
            Positioned(bottom: 5, right: 5, child: _moreInfoButton()),
          ],
        ),
      ),
    );
  }

  SizedBox _moreInfoButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: ShadowButton(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        onPressed: () => (),
        backgroundColor:
            Theme.of(context).cardColor, // I'll add _openMoreInfo() later
        child: Icon(
          Icons.info,
          color: Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }

  Widget get animeDetailsHeader {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contentDetailed?.rank == null ? "# ?" : "# ${contentDetailed.rank}",
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(
            height: 7,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                height: 22,
                child: Image.asset("assets/images/star.png"),
              ),
              const SizedBox(
                width: 5,
              ),
              Expanded(
                child: Text(
                    "${contentDetailed?.mean == null ? "?" : ratingFormat.format(contentDetailed.mean)} ",
                    style: const TextStyle(fontSize: 26)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
              "${contentDetailed?.numScoringUsers == null ? "?" : userCountFormat.format(contentDetailed.numScoringUsers)} ${Intl.message(
                'users',
                name: 'Users',
                desc: '',
                args: [],
              )}",
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(
            height: 10,
          ),
          Text(
            (contentDetailed?.mediaType == null
                    ? "?"
                    : contentDetailed.mediaType.toUpperCase()) +
                " " +
                (widget.category.equals("anime")
                    ? (((contentDetailed?.numEpisodes != null &&
                            contentDetailed.numEpisodes == 0)
                        ? ""
                        : ("(${contentDetailed?.numEpisodes == null ? "?" : contentDetailed.numEpisodes.toString()} eps)")))
                    : (((contentDetailed?.numVolumes != null &&
                            contentDetailed.numVolumes == 0)
                        ? ""
                        : ("(${contentDetailed?.numVolumes == null ? "?" : contentDetailed.numVolumes.toString()} vols)")))),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withValues(alpha: .7)),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            widget.category.equals("anime")
                ? Intl.message(
                    'Aired',
                    name: 'Aired',
                    desc: '',
                    args: [],
                  )
                : Intl.message(
                    'Serialization',
                    name: 'Serialization',
                    desc: '',
                    args: [],
                  ),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: .7)),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            widget.category.equals("anime")
                ? ("${contentDetailed?.startSeason?.season?.toString().capitalise() ?? "?"} ${contentDetailed?.startSeason?.year?.toString() ?? "?"}")
                : ((contentDetailed?.serialization == null ||
                        contentDetailed.serialization.length == 0)
                    ? "?"
                    : (contentDetailed?.serialization
                            ?.map((e) => e.name)
                            ?.reduce(
                                (value, element) => value + "," + element)) ??
                        "?"),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            Intl.message(
              'Popularity',
              name: 'Popularity',
              desc: '',
              args: [],
            ),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: .7)),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            "# ${contentDetailed?.popularity?.toString() ?? '?'}",
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Text(
            widget.category.equals("anime")
                ? Intl.message(
                    'Studios',
                    name: 'Studios',
                    desc: '',
                    args: [],
                  )
                : Intl.message(
                    'Authors',
                    name: 'Authors',
                    desc: '',
                    args: [],
                  ),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: .7)),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            widget.category.equals("anime")
                ? ((contentDetailed?.studios == null ||
                        contentDetailed.studios.length == 0)
                    ? "?"
                    : contentDetailed.studios
                        .map((e) => e.name)
                        .reduce((value, element) => value + "," + element))
                : ((contentDetailed?.authors == null ||
                        contentDetailed.authors.length == 0)
                    ? "?"
                    : contentDetailed.authors
                        .map((e) => e.author.firstName)
                        .reduce((value, element) => value + "," + element)),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Text(
            Intl.message(
              'Members',
              name: 'Members',
              desc: '',
              args: [],
            ),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withValues(alpha: .7)),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            userCountFormat.format(contentDetailed?.numListUsers ?? 0.0),
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget langChangeWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          height: 25,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                child: ShadowButton(
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      titleLang == TitleLang.ro ? null : Colors.transparent,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12))),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        titleLang = TitleLang.ro;
                      });
                    }
                  },
                  child: Text(
                    "TI",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: titleLang == TitleLang.ro ? null : Colors.white),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: ShadowButton(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0)),
                  backgroundColor:
                      titleLang == TitleLang.en ? null : Colors.transparent,
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        titleLang = TitleLang.en;
                      });
                    }
                  },
                  child: Text(
                    "EN",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: titleLang == TitleLang.en ? null : Colors.white),
                  ),
                ),
              ),
              SizedBox(
                width: 30,
                child: ShadowButton(
                  padding: EdgeInsets.zero,
                  backgroundColor:
                      titleLang == TitleLang.ja ? null : Colors.transparent,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12))),
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        titleLang = TitleLang.ja;
                      });
                    }
                  },
                  child: Text(
                    "JA",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: titleLang == TitleLang.ja ? null : Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget scrollStreamWidget(Widget child, bool Function(bool) onChange) {
    return StreamBuilder<bool>(
      stream: fabIsVisible,
      initialData: fabListener.initialData,
      builder: (context, snapshot) {
        final visible = snapshot.data ?? true;
        if (onChange(visible)) {
          return child;
        } else {
          return const SizedBox.shrink();
        }
      },
    );
  }

  //widget buildfloatingActionbtn it's a FloatingActionButton
  Widget _buildFloatingActionButton() {
    if (contentDetailed == null) {
      return FloatingActionButton(
        child: loadingCenter(),
        onPressed: () {},
      );
    } else {
      final editIcon = Icon(showContentEdit ? Icons.close : Icons.edit);
      if (showContentEdit) {
        return FloatingActionButton(
          heroTag: 'compact-floating',
          onPressed: _onButtonPressed,
          child: editIcon,
        );
      } else {
        return FloatingActionButton.extended(
          heroTag: 'extended-floating',
          onPressed: _onButtonPressed,
          isExtended: true,
          icon: contentDetailed.myListStatus?.status != null
              ? text(combinedStatusMap[
                  contentDetailed.myListStatus.status as String]!)
              : const SizedBox(),
          label: editIcon,
          backgroundColor:
              getAnimeStatusColor(contentDetailed.myListStatus?.status),
          // foregroundColor: Colors.white,
        );
      }
    }
  }

  //_onButtonPressed to setstate
  _onButtonPressed() {
    if (mounted) {
      setState(() {
        showContentEdit = !showContentEdit;
      });
    }
  }
}

class NoScalingAnimation extends FloatingActionButtonAnimator {
  late double _x;
  late double _y;

  @override
  Offset getOffset(
      {required Offset begin, required Offset end, required double progress}) {
    _x = begin.dx + (end.dx - begin.dx) * progress;
    _y = begin.dy + (end.dy - begin.dy) * progress;
    return Offset(_x, _y);
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) {
    return Tween<double>(begin: 1.0, end: 1.0).animate(parent);
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    return Tween<double>(begin: 1.0, end: 1.0).animate(parent);
  }
}
