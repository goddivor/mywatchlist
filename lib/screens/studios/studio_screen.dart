import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart'
    show MediaTile, openMedia;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/studio_page.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The page of one studio (MyAnimeList's producer page): its logo in big over a blurred copy,
/// its facts, its description and its links, then every anime of the studio under a bar that
/// stays pinned once scrolled to (kind tabs and sort). The anime cards show the user's own
/// list status. [name] and [logo] draw the header before the page answers.
class StudioScreen extends StatefulWidget {
  const StudioScreen(
      {super.key, required this.id, required this.name, this.logo});

  final int id;
  final String name;
  final String? logo;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

enum _Sort { score, members, newest, title }

/// How the studio's anime are laid out.
enum StudioAnimeDisplay { grid3, grid2, list }

class _StudioScreenState extends State<StudioScreen> {
  late Future<StudioPage> _page = StudioPages.of(widget.id);
  StudioAnimeType? _type;
  _Sort _sort = _Sort.score;
  bool _aboutOpen = false;
  StudioAnimeDisplay _display = StudioAnimeDisplay.grid3;
  bool _collapsed = false;

  static const String _displayKey = 'studio_anime_display_v1';

  @override
  void initState() {
    super.initState();
    _loadDisplay();
  }

  Future<void> _loadDisplay() async {
    try {
      final saved =
          (await SharedPreferences.getInstance()).getString(_displayKey);
      final display =
          StudioAnimeDisplay.values.where((d) => d.name == saved).firstOrNull;
      if (display != null && mounted) setState(() => _display = display);
    } catch (_) {}
  }

  Future<void> _setDisplay(StudioAnimeDisplay display) async {
    setState(() => _display = display);
    try {
      await (await SharedPreferences.getInstance())
          .setString(_displayKey, display.name);
    } catch (_) {}
  }

  /// The logo takes the screen's width (a square), at most 55 % of its height.
  double _headerHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final side =
        size.width < size.height * 0.55 ? size.width : size.height * 0.55;
    return side;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    final collapsed =
        n.metrics.pixels > _headerHeight(context) - kToolbarHeight * 2;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    return false;
  }

  void _retry() => setState(() => _page = StudioPages.of(widget.id));

  void _openInSearch() => gotoPage(
        context: context,
        newPage: GeneralSearchScreen.byStudio(id: widget.id, name: widget.name),
      );

  List<StudioAnime> _visible(List<StudioAnime> all) {
    final list = [
      for (final a in all)
        if (_type == null || a.type == _type) a
    ];
    int byScore(StudioAnime a, StudioAnime b) =>
        (b.score ?? 0).compareTo(a.score ?? 0);
    list.sort(switch (_sort) {
      _Sort.score => byScore,
      _Sort.members => (a, b) => b.members.compareTo(a.members),
      _Sort.newest => (a, b) => b.startDate.compareTo(a.startDate),
      _Sort.title => (a, b) =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<StudioPage>(
        future: _page,
        builder: (context, snapshot) {
          final page = snapshot.data;
          final logo = page?.logo ?? widget.logo;
          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: _headerHeight(context),
                  // The name shows once the logo has scrolled away.
                  title: AnimatedOpacity(
                    opacity: _collapsed ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Text(page?.name ?? widget.name),
                  ),
                  actions: [
                    IconButton(
                      tooltip: S.current.Stp_In_Search,
                      icon: const Icon(Icons.manage_search_rounded),
                      onPressed: _openInSearch,
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.pin,
                    background:
                        _Header(name: page?.name ?? widget.name, logo: logo),
                  ),
                ),
                if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Failed(onRetry: _retry),
                  )
                else if (page == null)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  SliverToBoxAdapter(child: _details(context, page)),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _AnimeBar(
                      count: page.anime.length,
                      types: {for (final a in page.anime) a.type},
                      selected: _type,
                      sort: _sort,
                      display: _display,
                      onType: (t) => setState(() => _type = t),
                      onSort: (s) => setState(() => _sort = s),
                      onDisplay: _setDisplay,
                    ),
                  ),
                  _display == StudioAnimeDisplay.list
                      ? _list(context, _visible(page.anime))
                      : _grid(context, _visible(page.anime),
                          columns:
                              _display == StudioAnimeDisplay.grid2 ? 2 : 3),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _details(BuildContext context, StudioPage page) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String label(String mal) => switch (mal) {
          'Synonyms' => s.Stp_Fact_Synonyms,
          'Japanese' => s.Stp_Fact_Japanese,
          'Established' => s.Stp_Fact_Established,
          'Member Favorites' => s.Stp_Fact_Favorites,
          _ => mal,
        };
    final about = page.about;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.facts.isNotEmpty)
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                for (final fact in page.facts)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label(fact.label),
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(fact.value, style: theme.textTheme.titleSmall),
                    ],
                  ),
              ],
            ),
          if (about != null && about.isNotEmpty) ...[
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(0.23, 1, 0.32, 1),
              alignment: Alignment.topCenter,
              child: Text(
                about,
                maxLines: _aboutOpen ? null : 5,
                overflow:
                    _aboutOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _aboutOpen = !_aboutOpen),
              child: Text(_aboutOpen ? s.Stp_Show_Less : s.Stp_Show_More),
            ),
          ],
          if (page.links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.Stp_Links, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _StudioLinks(links: page.links),
          ],
        ],
      ),
    );
  }

  Anime _node(StudioAnime a) => Anime(
        id: a.id,
        title: a.title,
        imageUrl: a.imageUrl ?? '',
        score: a.score ?? 0,
        members: a.members,
      );

  Widget _list(BuildContext context, List<StudioAnime> anime) {
    if (anime.isEmpty) return _empty();
    return SliverList.builder(
      itemCount: anime.length,
      itemBuilder: (context, i) {
        final node = _node(anime[i]);
        return MediaTile(item: node, category: 'anime');
      },
    );
  }

  Widget _empty() => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(S.current.Stp_Empty)),
        ),
      );

  Widget _grid(BuildContext context, List<StudioAnime> anime,
      {required int columns}) {
    if (anime.isEmpty) return _empty();
    const spacing = 8.0;
    final width =
        (MediaQuery.sizeOf(context).width - 24 - spacing * (columns - 1)) /
            columns;
    final height = width * 1.5;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverGrid.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: width / (height + 36),
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        itemCount: anime.length,
        itemBuilder: (context, i) {
          final node = _node(anime[i]);
          return AnimeGridCard(
            node: node,
            category: 'anime',
            width: width,
            height: height,
            gridHeight: height + 36,
            showMemberCount: true,
            // Score and members on the cover, and the user's list status (edit button).
            showCardBar: true,
            showEdit: true,
            onTap: () => openMedia(context, node, 'anime'),
          );
        },
      ),
    );
  }
}

/// The logo across the screen's width on white (MAL's logos are drawn for a white page), a
/// shade at the top for the back and search buttons. A tap shows it alone.
class _Header extends StatelessWidget {
  const _Header({required this.name, this.logo});

  final String name;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final url = logo;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return GestureDetector(
      onTap: url == null ? null : () => zoomInImage(context, url, false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top * 0.6, 16, 16),
            child: url == null
                ? Center(
                    child: Text(
                      name.characters.first.toUpperCase(),
                      style:
                          const TextStyle(fontSize: 96, color: Colors.black38),
                    ),
                  )
                : Semantics(
                    image: true,
                    label: name,
                    child: AppImage(url: url, fit: BoxFit.contain),
                  ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: top + 24,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The studio's links as the anime page draws its media links: a row of round buttons, the
/// name in the tooltip.
class _StudioLinks extends StatelessWidget {
  const _StudioLinks({required this.links});

  final List<StudioLink> links;

  static IconData _icon(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('youtube')) return Icons.smart_display_rounded;
    if (host.contains('twitter') || host.contains('x.com'))
      return Icons.alternate_email_rounded;
    if (host.contains('facebook')) return Icons.facebook_rounded;
    if (host.contains('instagram')) return Icons.camera_alt_outlined;
    if (host.contains('tiktok')) return Icons.music_note_rounded;
    return Icons.language_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: links.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final link = links[i];
          return Tooltip(
            message: link.label,
            child: Semantics(
              button: true,
              label: link.label,
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => openLink(context, link.url),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.surfaceContainerHigh,
                  child: Icon(_icon(link.url), color: scheme.onSurface),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The pinned bar over the anime: the count, the kind tabs and the sort.
class _AnimeBar extends SliverPersistentHeaderDelegate {
  _AnimeBar({
    required this.count,
    required this.types,
    required this.selected,
    required this.sort,
    required this.display,
    required this.onType,
    required this.onSort,
    required this.onDisplay,
  });

  final int count;
  final Set<StudioAnimeType> types;
  final StudioAnimeType? selected;
  final _Sort sort;
  final StudioAnimeDisplay display;
  final ValueChanged<StudioAnimeType?> onType;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<StudioAnimeDisplay> onDisplay;

  static const double _height = 104;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_AnimeBar old) =>
      old.count != count ||
      old.selected != selected ||
      old.sort != sort ||
      old.display != display ||
      old.types != types;

  static IconData _displayIcon(StudioAnimeDisplay d) => switch (d) {
        StudioAnimeDisplay.grid3 => Icons.apps_rounded,
        StudioAnimeDisplay.grid2 => Icons.grid_view_rounded,
        StudioAnimeDisplay.list => Icons.view_list_rounded,
      };

  static String _displayLabel(StudioAnimeDisplay d) => switch (d) {
        StudioAnimeDisplay.grid3 => S.current.Sdv_Grid_3,
        StudioAnimeDisplay.grid2 => S.current.Sdv_Grid_2,
        StudioAnimeDisplay.list => S.current.Sdv_List,
      };

  static String _typeLabel(StudioAnimeType t) => switch (t) {
        StudioAnimeType.tv => S.current.Stp_Tv,
        StudioAnimeType.ona => S.current.Stp_Ona,
        StudioAnimeType.ova => S.current.Stp_Ova,
        StudioAnimeType.movie => S.current.Stp_Movie,
        StudioAnimeType.other => S.current.Stp_Other,
      };

  static String _sortLabel(_Sort s) => switch (s) {
        _Sort.score => S.current.Stp_Sort_Score,
        _Sort.members => S.current.Stp_Sort_Members,
        _Sort.newest => S.current.Stp_Sort_Newest,
        _Sort.title => S.current.Stp_Sort_Title,
      };

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final s = S.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      elevation: overlapsContent ? 2 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
            child: Row(
              children: [
                Expanded(
                    child: Text(s.Stp_Anime_Title(count),
                        style: theme.textTheme.titleMedium)),
                PopupMenuButton<StudioAnimeDisplay>(
                  key: const ValueKey('studio-display'),
                  tooltip: s.Sdv_Display,
                  initialValue: display,
                  onSelected: onDisplay,
                  icon: Icon(_displayIcon(display), size: 20),
                  itemBuilder: (_) => [
                    for (final d in StudioAnimeDisplay.values)
                      PopupMenuItem(
                        value: d,
                        child: Row(
                          children: [
                            Icon(_displayIcon(d), size: 20),
                            const SizedBox(width: 12),
                            Text(_displayLabel(d)),
                          ],
                        ),
                      ),
                  ],
                ),
                PopupMenuButton<_Sort>(
                  key: const ValueKey('studio-sort'),
                  tooltip: s.Stp_Sort,
                  initialValue: sort,
                  onSelected: onSort,
                  itemBuilder: (_) => [
                    for (final option in _Sort.values)
                      PopupMenuItem(
                          value: option, child: Text(_sortLabel(option))),
                  ],
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(_sortLabel(sort),
                            style: theme.textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(s.Stp_All, selected == null, () => onType(null)),
                for (final t in StudioAnimeType.values)
                  if (types.contains(t))
                    _chip(_typeLabel(t), selected == t, () => onType(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
            label: Text(label), selected: on, onSelected: (_) => onTap()),
      );
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40),
          const SizedBox(height: 12),
          Text(s.Stp_Failed, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: onRetry, child: Text(s.Stp_Retry)),
        ],
      ),
    );
  }
}
