import 'package:flutter/material.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_sections.dart' show RankingsScreen;
import 'package:mywatchlist/screens/search/general_search_screen.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart';
import 'package:mywatchlist/screens/search/search_filters.dart' show SearchCategory;
import 'package:mywatchlist/utils/app_routes.dart';

/// Height of the chip row under the home app bar.
const double kHomeChipsHeight = 35;

/// One shortcut of the chip row: a translated label and what it opens.
class HomeChip {
  final String label;
  final void Function(BuildContext context) onTap;

  const HomeChip(this.label, this.onTap);
}

/// The shortcuts of the home, in DailyAL's order. Labels are read at each call, so a language
/// change applies on the next build.
List<HomeChip> homeChips() {
  final s = S.current;
  return [
    HomeChip(s.Hw_Chip_Categories,
        (context) => AppRoutes.push<void>(context, const RankingsScreen(isAnime: true))),
    HomeChip(s.Hw_Chip_Genres, showHomeGenres),
    HomeChip(
        s.Hw_Chip_Top_Anime,
        (context) => AppRoutes.push<void>(
            context, GeneralSearchScreen.byRanking(RankingType.ALL))),
    HomeChip(
        s.Hw_Chip_Top_Manga,
        (context) => AppRoutes.push<void>(
            context, GeneralSearchScreen.byMangaRanking(MangaRanking.all))),
    HomeChip(
        s.Hw_Chip_Top_Airing,
        (context) => AppRoutes.push<void>(
            context, GeneralSearchScreen.byRanking(RankingType.AIRING))),
    HomeChip(
        s.Hw_Chip_Popular_Anime,
        (context) => AppRoutes.push<void>(
            context, GeneralSearchScreen.byRanking(RankingType.BYPOPULARITY))),
    HomeChip(
        s.Hw_Chip_Popular_Manga,
        (context) => AppRoutes.push<void>(
            context, GeneralSearchScreen.byMangaRanking(MangaRanking.bypopularity))),
  ];
}

/// The horizontal row of shortcuts pinned under the home app bar. [elevated] is true once the
/// page scrolled: the chips get a more solid background so they stay readable over content.
class HomeChipsBar extends StatelessWidget {
  final bool elevated;

  const HomeChipsBar({super.key, this.elevated = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chips = homeChips();
    return SizedBox(
      height: kHomeChipsHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Material(
            color: scheme.surfaceContainerHigh.withValues(alpha: elevated ? 0.7 : 0.92),
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => chip.onTap(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    chip.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: scheme.onSurface),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Opens the genres of the catalog in a bottom sheet (anime or manga); a genre opens the search
/// filtered on it.
Future<void> showHomeGenres(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => _GenresSheet(
        controller: controller,
        onPick: (id, manga) {
          Navigator.of(sheetContext).pop();
          AppRoutes.push<void>(
            context,
            GeneralSearchScreen.byGenre(
              ids: [id],
              category: manga ? SearchCategory.manga : SearchCategory.anime,
            ),
          );
        },
      ),
    ),
  );
}

class _GenresSheet extends StatefulWidget {
  final ScrollController controller;
  final void Function(int id, bool manga) onPick;

  const _GenresSheet({required this.controller, required this.onPick});

  @override
  State<_GenresSheet> createState() => _GenresSheetState();
}

class _GenresSheetState extends State<_GenresSheet> {
  bool _manga = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = SearchCatalog.genreGroups(manga: _manga);
    return CustomScrollView(
      controller: widget.controller,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(S.current.Hw_Chip_Genres, style: theme.textTheme.titleLarge),
                ),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(S.current.Hw_Genres_Anime)),
                    ButtonSegment(value: true, label: Text(S.current.Hw_Genres_Manga)),
                  ],
                  selected: {_manga},
                  onSelectionChanged: (s) => setState(() => _manga = s.first),
                ),
              ],
            ),
          ),
        ),
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(group.title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in group.ids)
                    ActionChip(
                      label: Text(SearchCatalog.genreLabel(id, manga: _manga)),
                      onPressed: () => widget.onPick(id, _manga),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}
