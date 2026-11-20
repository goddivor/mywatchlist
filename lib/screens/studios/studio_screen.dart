import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show gotoPage;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_tiles.dart' show openMedia;
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/services/api/MAL/scrapper/studio_page.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';
import 'package:mywatchlist/widgets/common/image_preview.dart';

/// The page of one studio (MyAnimeList's producer page): its logo in big over a blurred copy,
/// its facts, its description and its links, then every anime of the studio under a bar that
/// stays pinned once scrolled to (kind tabs and sort). The anime cards show the user's own
/// list status. [name] and [logo] draw the header before the page answers.
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key, required this.id, required this.name, this.logo});

  final int id;
  final String name;
  final String? logo;

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

enum _Sort { score, members, newest, title }

class _StudioScreenState extends State<StudioScreen> {
  late Future<StudioPage> _page = StudioPages.of(widget.id);
  StudioAnimeType? _type;
  _Sort _sort = _Sort.score;
  bool _aboutOpen = false;

  void _retry() => setState(() => _page = StudioPages.of(widget.id));

  void _openInSearch() => gotoPage(
        context: context,
        newPage: GeneralSearchScreen.byStudio(id: widget.id, name: widget.name),
      );

  List<StudioAnime> _visible(List<StudioAnime> all) {
    final list = [for (final a in all) if (_type == null || a.type == _type) a];
    int byScore(StudioAnime a, StudioAnime b) => (b.score ?? 0).compareTo(a.score ?? 0);
    list.sort(switch (_sort) {
      _Sort.score => byScore,
      _Sort.members => (a, b) => b.members.compareTo(a.members),
      _Sort.newest => (a, b) => b.startDate.compareTo(a.startDate),
      _Sort.title => (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
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
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                title: Text(page?.name ?? widget.name),
                actions: [
                  IconButton(
                    tooltip: S.current.Stp_In_Search,
                    icon: const Icon(Icons.manage_search_rounded),
                    onPressed: _openInSearch,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _Header(name: page?.name ?? widget.name, logo: logo),
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
                    onType: (t) => setState(() => _type = t),
                    onSort: (s) => setState(() => _sort = s),
                  ),
                ),
                _grid(context, _visible(page.anime)),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
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
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
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
                overflow: _aboutOpen ? TextOverflow.visible : TextOverflow.ellipsis,
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final link in page.links)
                  ActionChip(
                    avatar: Icon(_linkIcon(link.url), size: 18),
                    label: Text(link.label),
                    onPressed: () => openLink(context, link.url),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static IconData _linkIcon(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.contains('youtube')) return Icons.smart_display_outlined;
    if (host.contains('twitter') || host.contains('x.com')) return Icons.alternate_email;
    if (host.contains('facebook') || host.contains('instagram')) return Icons.people_outline;
    return Icons.link;
  }

  Widget _grid(BuildContext context, List<StudioAnime> anime) {
    if (anime.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(S.current.Stp_Empty)),
        ),
      );
    }
    const columns = 3;
    const spacing = 8.0;
    final width = (MediaQuery.sizeOf(context).width - 24 - spacing * (columns - 1)) / columns;
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
          final a = anime[i];
          final node = Anime(
            id: a.id,
            title: a.title,
            imageUrl: a.imageUrl ?? '',
            score: a.score ?? 0,
            members: a.members,
          );
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

/// The logo in big on a white card, over a blurred copy faded into the page.
class _Header extends StatelessWidget {
  const _Header({required this.name, this.logo});

  final String name;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final page = Theme.of(context).scaffoldBackgroundColor;
    final url = logo;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: page),
        if (url != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24, tileMode: TileMode.decal),
            child: Opacity(
              opacity: 0.55,
              child: AppImage(url: url, fit: BoxFit.cover, errorWidget: (_) => const SizedBox.shrink()),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [page.withValues(alpha: 0.35), page],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: top, bottom: 16),
          child: Center(
            child: GestureDetector(
              onTap: url == null ? null : () => zoomInImage(context, url, false),
              child: Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(blurRadius: 18, color: Color(0x40000000))],
                ),
                child: url == null
                    ? Center(
                        child: Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 56, color: Colors.black54),
                        ),
                      )
                    : Semantics(
                        image: true,
                        label: name,
                        child: AppImage(url: url, fit: BoxFit.contain),
                      ),
              ),
            ),
          ),
        ),
      ],
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
    required this.onType,
    required this.onSort,
  });

  final int count;
  final Set<StudioAnimeType> types;
  final StudioAnimeType? selected;
  final _Sort sort;
  final ValueChanged<StudioAnimeType?> onType;
  final ValueChanged<_Sort> onSort;

  static const double _height = 104;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  bool shouldRebuild(_AnimeBar old) =>
      old.count != count || old.selected != selected || old.sort != sort || old.types != types;

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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
                Expanded(child: Text(s.Stp_Anime_Title(count), style: theme.textTheme.titleMedium)),
                PopupMenuButton<_Sort>(
                  key: const ValueKey('studio-sort'),
                  tooltip: s.Stp_Sort,
                  initialValue: sort,
                  onSelected: onSort,
                  itemBuilder: (_) => [
                    for (final option in _Sort.values)
                      PopupMenuItem(value: option, child: Text(_sortLabel(option))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(_sortLabel(sort), style: theme.textTheme.labelLarge),
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
                  if (types.contains(t)) _chip(_typeLabel(t), selected == t, () => onType(t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(label: Text(label), selected: on, onSelected: (_) => onTap()),
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
