import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart' show DisplaySubType, HomePageTileSize, getTileSizeValues;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_history.dart';
import 'package:mywatchlist/pages/MAL/mal_explore_page.dart' show ExploreStorage;
import 'package:mywatchlist/screens/explore/explore_sections.dart' show RankingsRow, SeasonalPicker;
import 'package:mywatchlist/screens/search/search_tiles.dart';
import 'package:mywatchlist/services/api/MAL/mal_anime.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/widgets/MAL/home/animegridcard.dart';

/// What the autocomplete knows right now.
@immutable
class SuggestionState {
  final String query;
  final String category;
  final List<Anime> items;
  final bool loading;

  const SuggestionState({
    this.query = '',
    this.category = 'anime',
    this.items = const [],
    this.loading = false,
  });

  static const idle = SuggestionState();

  bool get isActive => query.isNotEmpty;
}

/// The screen shown before a search: autocomplete while typing, then the recent searches, the
/// recently opened titles, Explore's season picker and the ranking picture rows.
class SearchHomeView extends StatelessWidget {
  final SearchHistory history;
  final ValueListenable<SuggestionState> suggestions;

  /// Runs [query] as typed (a past search, a ranking chip, a season).
  final ValueChanged<String> onQuery;
  final ScrollController? controller;

  const SearchHomeView({
    super.key,
    required this.history,
    required this.suggestions,
    required this.onQuery,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        _SuggestionsSliver(suggestions: suggestions, onQuery: onQuery),
        _QueriesSliver(history: history, onQuery: onQuery),
        _RecentSliver(
          stream: history.recentAnimeStream,
          initial: history.recentAnime,
          title: S.current.Srch_Recent_Anime,
          category: 'anime',
          onClear: history.clearRecentAnime,
          onRemove: history.removeRecentAnime,
        ),
        _RecentSliver(
          stream: history.recentMangaStream,
          initial: history.recentManga,
          title: S.current.Srch_Recent_Manga,
          category: 'manga',
          onClear: history.clearRecentManga,
          onRemove: history.removeRecentManga,
        ),
        _SectionHeader(S.current.Srch_By_Season),
        // One season picker for the whole app: Explore's (DailyAL's SeasonalWidget).
        SliverToBoxAdapter(child: ExploreStorage.isolated(const SeasonalPicker())),
        _SectionHeader(S.current.Srch_Anime_Categories),
        const SliverToBoxAdapter(child: RankingsRow(isAnime: true)),
        _SectionHeader(S.current.Srch_Manga_Categories),
        const SliverToBoxAdapter(child: RankingsRow(isAnime: false)),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClear;

  const _SectionHeader(this.title, {this.onClear});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            if (onClear != null)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(S.current.Srch_Clear),
              ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionsSliver extends StatelessWidget {
  final ValueListenable<SuggestionState> suggestions;
  final ValueChanged<String> onQuery;

  const _SuggestionsSliver({required this.suggestions, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SuggestionState>(
      valueListenable: suggestions,
      builder: (context, state, _) {
        if (!state.isActive) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final theme = Theme.of(context);
        return SliverMainAxisGroup(
          slivers: [
            _SectionHeader(S.current.Srch_Suggestions),
            SliverToBoxAdapter(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.search_rounded),
                title: Text(S.current.Srch_Search_For(state.query)),
                trailing: state.loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
                onTap: () => onQuery(state.query),
              ),
            ),
            SliverList.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) =>
                  MediaTile(item: state.items[index], category: state.category, size: MediaTileSize.compact),
            ),
            if (!state.loading && state.items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    S.current.Srch_No_Suggestions,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QueriesSliver extends StatelessWidget {
  final SearchHistory history;
  final ValueChanged<String> onQuery;

  const _QueriesSliver({required this.history, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: history.queryHistoryStream,
      initialData: history.queries,
      builder: (context, snapshot) {
        final queries = snapshot.data ?? const [];
        if (queries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
        return SliverMainAxisGroup(
          slivers: [
            _SectionHeader(S.current.Srch_History, onClear: history.clearQueries),
            SliverList.builder(
              itemCount: queries.length,
              itemBuilder: (context, index) {
                final query = queries[index];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.history_rounded, size: 20, color: muted),
                  title: Text(query),
                  trailing: IconButton(
                    tooltip: S.current.Srch_Remove,
                    icon: Icon(Icons.close_rounded, size: 18, color: muted),
                    onPressed: () => history.removeQuery(query),
                  ),
                  onTap: () => onQuery(query),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _RecentSliver extends StatelessWidget {
  final Stream<List<Anime>> stream;
  final List<Anime> initial;
  final String title;
  final String category;
  final VoidCallback onClear;
  final void Function(int id) onRemove;

  const _RecentSliver({
    required this.stream,
    required this.initial,
    required this.title,
    required this.category,
    required this.onClear,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Anime>>(
      stream: stream,
      initialData: initial,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
        return SliverMainAxisGroup(
          slivers: [
            _SectionHeader(title, onClear: onClear),
            SliverToBoxAdapter(
              child: _RecentList(items: items, category: category, onRemove: onRemove),
            ),
          ],
        );
      },
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<Anime> items;
  final String category;
  final void Function(int id) onRemove;

  const _RecentList({required this.items, required this.category, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final size = context.select<HomePreferencesBloc, HomePageTileSize>(
        (bloc) => bloc.state.preferences.tileSize);
    final tile = getTileSizeValues(size);
    final cardHeight = tile.containerHeight;
    final cardWidth = cardHeight * (2 / 3);
    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: SizedBox(
              width: cardWidth,
              child: AnimeGridCard(
                node: item,
                category: category,
                width: cardWidth,
                height: cardHeight,
                gridHeight: cardHeight,
                showText: false,
                showMemberCount: true,
                displaySubType: DisplaySubType.compact,
                onTap: () => openMedia(context, item, category),
                onClose: () => onRemove(item.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
