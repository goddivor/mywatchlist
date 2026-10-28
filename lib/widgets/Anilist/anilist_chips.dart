import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/home/home_chips.dart' show kHomeChipsHeight;

/// Opens the grid of the titles AniList returns for [query] under [title].
void openAnilistBrowse(BuildContext context, String title, AnilistMediaQuery query) =>
    AppRoutes.push<void>(context, AnilistBrowseScreen(title: title, query: query));

/// Opens AniList's search.
void openAnilistSearch(BuildContext context, {String category = 'anime'}) =>
    AppRoutes.push<void>(
      context,
      AnilistBrowseScreen(
        title: '',
        query: AnilistMediaQuery(category: category, sort: 'SEARCH_MATCH'),
        searchable: true,
      ),
    );

/// The shortcut row under the AniList home app bar: rankings and the genres sheet.
class AnilistChipsBar extends StatelessWidget {
  const AnilistChipsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chips = <(String, void Function(BuildContext))>[
      (s.Hw_Chip_Genres, showAnilistGenres),
      (
        s.Hw_Chip_Top_Anime,
        (c) => openAnilistBrowse(
            c, s.Hw_Chip_Top_Anime, const AnilistMediaQuery(category: 'anime', sort: 'SCORE_DESC'))
      ),
      (
        s.Hw_Chip_Top_Manga,
        (c) => openAnilistBrowse(
            c, s.Hw_Chip_Top_Manga, const AnilistMediaQuery(category: 'manga', sort: 'SCORE_DESC'))
      ),
      (
        s.Hw_Chip_Top_Airing,
        (c) => openAnilistBrowse(
            c,
            s.Hw_Chip_Top_Airing,
            const AnilistMediaQuery(
                category: 'anime', sort: 'SCORE_DESC', status: 'RELEASING'))
      ),
      (
        s.Hw_Chip_Popular_Anime,
        (c) => openAnilistBrowse(c, s.Hw_Chip_Popular_Anime,
            const AnilistMediaQuery(category: 'anime', sort: 'POPULARITY_DESC'))
      ),
      (
        s.Hw_Chip_Popular_Manga,
        (c) => openAnilistBrowse(c, s.Hw_Chip_Popular_Manga,
            const AnilistMediaQuery(category: 'manga', sort: 'POPULARITY_DESC'))
      ),
    ];
    return SizedBox(
      height: kHomeChipsHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (label, onTap) = chips[i];
          return Material(
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onTap(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    label,
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

/// The genres of AniList in a bottom sheet (anime or manga); a genre opens its titles by
/// popularity. AniList's genre names are its own keys, shown as AniList writes them.
Future<void> showAnilistGenres(BuildContext context, {String category = 'anime'}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => _GenresSheet(
      category: category,
      onPick: (genre, picked) {
        Navigator.of(sheet).pop();
        openAnilistBrowse(
          context,
          genre,
          AnilistMediaQuery(category: picked, sort: 'POPULARITY_DESC', genre: genre),
        );
      },
    ),
  );
}

class _GenresSheet extends StatefulWidget {
  final String category;
  final void Function(String genre, String category) onPick;

  const _GenresSheet({required this.category, required this.onPick});

  @override
  State<_GenresSheet> createState() => _GenresSheetState();
}

class _GenresSheetState extends State<_GenresSheet> {
  late String _category = widget.category;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(s.Hw_Chip_Genres, style: theme.textTheme.titleLarge)),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 'anime', label: Text(s.Hw_Genres_Anime)),
                  ButtonSegment(value: 'manga', label: Text(s.Hw_Genres_Manga)),
                ],
                selected: {_category},
                onSelectionChanged: (v) => setState(() => _category = v.first),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final genre in AnilistDiscoverService.genres)
                ActionChip(
                  label: Text(genre),
                  onPressed: () => widget.onPick(genre, _category),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
