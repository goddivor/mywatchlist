import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/search/search_catalog.dart' show SearchCatalog;
import 'package:mywatchlist/services/api/MAL/scrapper/studio_page.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart' show ListEntryStatus;

/// The Sort / Filter sheet of a studio page: My List's sheet ([showListSortFilterSheet]) over the
/// studio's anime. Facets come from the studio's own titles (only values that exist): genres
/// (all must match), start year, and the user's list status when the list is known.
abstract final class StudioFilters {
  static const String genre = 'genre';
  static const String year = 'year';
  static const String myList = 'my_list';

  /// The "not on my list" value of [myList].
  static const String offList = 'none';

  static const String sortScore = 'score';
  static const String sortMembers = 'members';
  static const String sortStart = 'start';
  static const String sortTitle = 'title';

  static const ListViewSettings initial = ListViewSettings(sortKey: sortScore);

  static List<ListSortOption> get sorts => [
        ListSortOption(sortScore, S.current.Stp_Sort_Score),
        ListSortOption(sortMembers, S.current.Stp_Sort_Members),
        ListSortOption(sortStart, S.current.Stf_Sort_Start),
        ListSortOption(sortTitle, S.current.Stp_Sort_Title, defaultDirection: SortDirection.ascending),
      ];

  static int? yearOf(StudioAnime a) => a.startDate > 0 ? a.startDate ~/ 10000 : null;

  /// The facets of [anime]; [statusOf] gives the user's list status of an id (null = not on
  /// the list), or is null when the list is unknown (signed out, not loaded).
  static List<ListFilterFacet> facets(List<StudioAnime> anime, {String? Function(int id)? statusOf}) {
    final genres = <int>{for (final a in anime) ...a.genres};
    final years = <int>{for (final a in anime) if (yearOf(a) != null) yearOf(a)!};
    final labels = {for (final g in genres) g: SearchCatalog.genreLabel(g, manga: false)};
    final sortedGenres = genres.toList()
      ..sort((a, b) => labels[a]!.toLowerCase().compareTo(labels[b]!.toLowerCase()));
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));
    final statuses = <String>{
      if (statusOf != null)
        for (final a in anime) statusOf(a.id) ?? offList,
    };
    return [
      if (sortedGenres.isNotEmpty)
        ListFilterFacet(
          key: genre,
          label: S.current.UserList_Facet_Genres,
          options: [for (final g in sortedGenres) SelectOption('$g', labels[g]!)],
          allowExclude: true,
          matchAll: true,
        ),
      if (sortedYears.length > 1)
        ListFilterFacet(
          key: year,
          label: S.current.Srch_Year,
          options: [for (final y in sortedYears) SelectOption('$y', '$y')],
          allowExclude: true,
        ),
      if (statuses.length > 1)
        ListFilterFacet(
          key: myList,
          label: S.current.Stf_My_List,
          options: [
            for (final st in ListEntryStatus.values)
              if (statuses.contains(st.malValue(isAnime: true)))
                SelectOption(st.malValue(isAnime: true), st.label(isAnime: true)),
            if (statuses.contains(offList)) SelectOption(offList, S.current.Stf_Off_List),
          ],
          allowExclude: true,
        ),
    ];
  }

  static Set<String> _valuesOf(StudioAnime a, String facet, String? Function(int id)? statusOf) =>
      switch (facet) {
        genre => {for (final g in a.genres) '$g'},
        year => {if (yearOf(a) != null) '${yearOf(a)}'},
        myList => {if (statusOf != null) statusOf(a.id) ?? offList},
        _ => const {},
      };

  /// [anime] kept by [settings]' filter, in its sort.
  static List<StudioAnime> apply(
    List<StudioAnime> anime,
    ListViewSettings settings, {
    String? Function(int id)? statusOf,
  }) {
    final filter = settings.filter;
    bool keeps(StudioAnime a) {
      for (final entry in filter.included.entries) {
        if (entry.value.isEmpty) continue;
        final values = _valuesOf(a, entry.key, statusOf);
        final ok = entry.key == genre ? values.containsAll(entry.value) : entry.value.any(values.contains);
        if (!ok) return false;
      }
      for (final entry in filter.excluded.entries) {
        if (entry.value.isEmpty) continue;
        if (entry.value.any(_valuesOf(a, entry.key, statusOf).contains)) return false;
      }
      return true;
    }

    final list = [for (final a in anime) if (keeps(a)) a];
    int compare(StudioAnime a, StudioAnime b) => switch (settings.sortKey) {
          sortMembers => a.members.compareTo(b.members),
          sortStart => a.startDate.compareTo(b.startDate),
          sortTitle => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          _ => (a.score ?? 0).compareTo(b.score ?? 0),
        };
    list.sort(settings.direction == SortDirection.ascending ? compare : (a, b) => compare(b, a));
    return list;
  }
}
