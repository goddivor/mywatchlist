import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/list_sort_filter.dart';
import 'package:mywatchlist/widgets/common/select/select_option.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

/// Sort keys understood by [sortEntries] (stable: they are saved).
abstract final class ListSortKeys {
  static const updated = 'list_updated_at';
  static const score = 'list_score';
  static const title = 'title';
  static const releaseStart = 'start_date';
  static const releaseEnd = 'end_date';
  static const progress = 'progress';
  static const mean = 'mean';
  static const members = 'num_list_users';
  static const scorers = 'num_scoring_users';
  static const popularity = 'popularity';
  static const total = 'total';
  static const priority = 'priority';
  static const listStart = 'list_start_date';
  static const nextAiring = 'next_airing';
  static const unseen = 'unseen';
}

/// Facet keys understood by [filterEntries].
abstract final class ListFacetKeys {
  static const media = 'media';
  static const release = 'release';
  static const genre = 'genre';
  static const priority = 'priority';
  static const score = 'score';
  static const repeating = 'repeating';
  static const unseen = 'unseen';
}

/// The sort options every tracker can offer (computed on the device), for
/// [isAnime]; the first is the default.
List<ListSortOption> standardSortOptions({required bool isAnime}) => [
      ListSortOption(ListSortKeys.updated, S.current.UserList_Sort_Updated),
      ListSortOption(ListSortKeys.score, S.current.UserList_Sort_My_Score),
      ListSortOption(ListSortKeys.title, S.current.UserList_Sort_Title,
          defaultDirection: SortDirection.ascending),
      ListSortOption(ListSortKeys.progress,
          isAnime ? S.current.UserList_Sort_Episodes_Seen : S.current.UserList_Sort_Chapters_Read),
      if (isAnime)
        ListSortOption(ListSortKeys.unseen, S.current.UserList_Sort_Unseen),
      if (isAnime)
        ListSortOption(ListSortKeys.nextAiring, S.current.UserList_Sort_Next_Airing,
            defaultDirection: SortDirection.ascending),
      ListSortOption(ListSortKeys.priority, S.current.UserList_Sort_Priority),
      ListSortOption(ListSortKeys.mean, S.current.UserList_Sort_Mean),
      ListSortOption(ListSortKeys.members, S.current.UserList_Sort_Members),
      ListSortOption(ListSortKeys.scorers, S.current.UserList_Sort_Scorers),
      ListSortOption(ListSortKeys.popularity, S.current.UserList_Sort_Popularity),
      ListSortOption(ListSortKeys.total,
          isAnime ? S.current.UserList_Sort_Total_Episodes : S.current.UserList_Sort_Total_Chapters),
      ListSortOption(ListSortKeys.releaseStart,
          isAnime ? S.current.UserList_Sort_Aired_From : S.current.UserList_Sort_Published_From),
      ListSortOption(ListSortKeys.releaseEnd,
          isAnime ? S.current.UserList_Sort_Aired_To : S.current.UserList_Sort_Published_To),
      ListSortOption(ListSortKeys.listStart, S.current.UserList_Sort_My_Start),
    ];

/// Translated media type (`tv` → "TV", `light_novel` → "Light novel").
String mediaTypeLabel(String type) => switch (type) {
      'tv' => S.current.UserList_Media_Tv,
      'movie' => S.current.UserList_Media_Movie,
      'ova' => 'OVA',
      'ona' => 'ONA',
      'special' => S.current.UserList_Media_Special,
      'tv_special' => S.current.UserList_Media_Tv_Special,
      'music' => S.current.UserList_Media_Music,
      'cm' => S.current.UserList_Media_Cm,
      'pv' => 'PV',
      'manga' => S.current.UserList_Media_Manga,
      'novel' => S.current.UserList_Media_Novel,
      'light_novel' => S.current.UserList_Media_Light_Novel,
      'one_shot' => S.current.UserList_Media_One_Shot,
      'doujinshi' => S.current.UserList_Media_Doujinshi,
      'manhwa' => S.current.UserList_Media_Manhwa,
      'manhua' => S.current.UserList_Media_Manhua,
      'oel' => 'OEL',
      'unknown' || '' => S.current.UserList_Media_Unknown,
      _ => type.replaceAll('_', ' ').toUpperCase(),
    };

String releaseStateLabel(ReleaseState state, {required bool isAnime}) => switch (state) {
      ReleaseState.releasing =>
        isAnime ? S.current.UserList_Release_Airing : S.current.UserList_Release_Publishing,
      ReleaseState.finished => S.current.UserList_Release_Finished,
      ReleaseState.notYetReleased =>
        isAnime ? S.current.UserList_Release_Not_Aired : S.current.UserList_Release_Not_Published,
      ReleaseState.onHiatus => S.current.UserList_Release_Hiatus,
      ReleaseState.unknown => S.current.UserList_Media_Unknown,
    };

String priorityLabel(int priority) => switch (priority) {
      2 => S.current.UserList_Priority_High,
      1 => S.current.UserList_Priority_Medium,
      _ => S.current.UserList_Priority_Low,
    };

/// Score buckets of the "My score" facet.
const List<String> _scoreBuckets = ['9', '7', '5', '1', '0'];

String _scoreBucketOf(int score) => score >= 9
    ? '9'
    : score >= 7
        ? '7'
        : score >= 5
            ? '5'
            : score >= 1
                ? '1'
                : '0';

String _scoreBucketLabel(String bucket) => switch (bucket) {
      '9' => '9-10',
      '7' => '7-8',
      '5' => '5-6',
      '1' => '1-4',
      _ => S.current.UserList_Not_Scored,
    };

/// Filter facets built from the loaded [entries] (only values that exist).
List<ListFilterFacet> facetsFor(Iterable<ListEntryView> entries,
    {required bool isAnime, DateTime? now}) {
  final media = <String>{};
  final release = <ReleaseState>{};
  final genres = <String>{};
  for (final e in entries) {
    media.add(e.mediaType ?? 'unknown');
    release.add(e.releaseState);
    genres.addAll(e.genres);
  }
  final sortedMedia = media.toList()..sort((a, b) => mediaTypeLabel(a).compareTo(mediaTypeLabel(b)));
  final sortedGenres = genres.toList()..sort();
  return [
    if (sortedMedia.length > 1)
      ListFilterFacet(
        key: ListFacetKeys.media,
        label: S.current.UserList_Facet_Media,
        options: [for (final m in sortedMedia) SelectOption(m, mediaTypeLabel(m))],
        allowExclude: true,
      ),
    if (release.length > 1)
      ListFilterFacet(
        key: ListFacetKeys.release,
        label: isAnime ? S.current.UserList_Facet_Airing : S.current.UserList_Facet_Publishing,
        options: [
          for (final r in ReleaseState.values)
            if (release.contains(r)) SelectOption(r.name, releaseStateLabel(r, isAnime: isAnime)),
        ],
        allowExclude: true,
      ),
    if (sortedGenres.isNotEmpty)
      ListFilterFacet(
        key: ListFacetKeys.genre,
        label: S.current.UserList_Facet_Genres,
        options: [for (final g in sortedGenres) SelectOption(g, g)],
        allowExclude: true,
        matchAll: true,
      ),
    ListFilterFacet(
      key: ListFacetKeys.score,
      label: S.current.UserList_Facet_My_Score,
      options: [for (final b in _scoreBuckets) SelectOption(b, _scoreBucketLabel(b))],
    ),
    ListFilterFacet(
      key: ListFacetKeys.priority,
      label: S.current.UserList_Facet_Priority,
      options: [for (final p in const [2, 1, 0]) SelectOption('$p', priorityLabel(p))],
    ),
    ListFilterFacet(
      key: ListFacetKeys.repeating,
      label: isAnime ? S.current.Edit_Rewatching : S.current.Edit_Rereading,
      options: [SelectOption('yes', isAnime ? S.current.Edit_Rewatching : S.current.Edit_Rereading)],
      allowExclude: true,
    ),
    if (isAnime)
      ListFilterFacet(
        key: ListFacetKeys.unseen,
        label: S.current.UserList_Facet_Unseen,
        options: [SelectOption('yes', S.current.UserList_Has_Unseen)],
        allowExclude: true,
      ),
  ];
}

/// Values of [facet] that [e] has.
Set<String> _valuesOf(ListEntryView e, String facet, DateTime now) => switch (facet) {
      ListFacetKeys.media => {e.mediaType ?? 'unknown'},
      ListFacetKeys.release => {e.releaseState.name},
      ListFacetKeys.genre => e.genres.toSet(),
      ListFacetKeys.priority => {'${e.priority}'},
      ListFacetKeys.score => {_scoreBucketOf(e.score)},
      ListFacetKeys.repeating => e.repeating ? const {'yes'} : const {},
      ListFacetKeys.unseen => e.unseenCount(now) > 0 ? const {'yes'} : const {},
      _ => const {},
    };

/// Facets whose values are ANDed (all of them must match).
const Set<String> _matchAllFacets = {ListFacetKeys.genre};

/// True when [e] matches the [query] text (any of its titles).
bool matchesQuery(ListEntryView e, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  if (e.title.toLowerCase().contains(q)) return true;
  for (final t in e.otherTitles) {
    if (t.toLowerCase().contains(q)) return true;
  }
  return false;
}

/// Entries matching [filter] and [query].
List<ListEntryView> filterEntries(
  List<ListEntryView> entries,
  ListFilter filter, {
  String query = '',
  DateTime? now,
}) {
  if (filter.isEmpty && query.trim().isEmpty) return entries;
  final at = now ?? DateTime.now();
  return [
    for (final e in entries)
      if (matchesQuery(e, query) && _matchesFilter(e, filter, at)) e,
  ];
}

bool _matchesFilter(ListEntryView e, ListFilter filter, DateTime now) {
  for (final entry in filter.included.entries) {
    if (entry.value.isEmpty) continue;
    final values = _valuesOf(e, entry.key, now);
    final ok = _matchAllFacets.contains(entry.key)
        ? values.containsAll(entry.value)
        : entry.value.any(values.contains);
    if (!ok) return false;
  }
  for (final entry in filter.excluded.entries) {
    if (entry.value.isEmpty) continue;
    final values = _valuesOf(e, entry.key, now);
    if (entry.value.any(values.contains)) return false;
  }
  return true;
}

Comparable<dynamic>? _sortValue(ListEntryView e, String key, DateTime now) => switch (key) {
      ListSortKeys.updated => e.updatedAt?.millisecondsSinceEpoch,
      ListSortKeys.score => e.score == 0 ? null : e.score,
      ListSortKeys.title => e.title.toLowerCase(),
      ListSortKeys.releaseStart => _dateKey(e.releaseStart),
      ListSortKeys.releaseEnd => _dateKey(e.releaseEnd),
      ListSortKeys.progress => e.progress,
      ListSortKeys.mean => e.meanScore,
      ListSortKeys.members => e.members,
      ListSortKeys.scorers => e.scoringUsers,
      // A smaller rank is more popular: "descending" lists the most popular first.
      ListSortKeys.popularity => e.popularity == null || e.popularity == 0 ? null : -e.popularity!,
      ListSortKeys.total => e.total == 0 ? null : e.total,
      ListSortKeys.priority => e.priority,
      ListSortKeys.listStart => _dateKey(e.listStartDate),
      ListSortKeys.nextAiring => e.releaseState == ReleaseState.releasing
          ? e.broadcast?.nextAiring(now).millisecondsSinceEpoch
          : null,
      ListSortKeys.unseen => e.unseenCount(now),
      _ => null,
    };

/// `2024-03` → `2024-03-00`, so partial dates sort before full ones of the same month.
String? _dateKey(String? date) {
  if (date == null || date.isEmpty) return null;
  final parts = date.split('-');
  while (parts.length < 3) {
    parts.add('00');
  }
  return parts.take(3).map((p) => p.padLeft(2, '0')).join('-');
}

/// [entries] sorted by [key] in [direction]; entries without a value go last
/// whatever the direction, ties keep the title order.
List<ListEntryView> sortEntries(
  List<ListEntryView> entries,
  String key,
  SortDirection direction, {
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  final keyed = [
    for (var i = 0; i < entries.length; i++) (entries[i], _sortValue(entries[i], key, at), i),
  ];
  final asc = direction == SortDirection.ascending;
  keyed.sort((a, b) {
    final va = a.$2;
    final vb = b.$2;
    if (va == null && vb == null) return a.$3.compareTo(b.$3);
    if (va == null) return 1;
    if (vb == null) return -1;
    final c = va.compareTo(vb);
    if (c != 0) return asc ? c : -c;
    if (key != ListSortKeys.title) {
      final t = a.$1.title.toLowerCase().compareTo(b.$1.title.toLowerCase());
      if (t != 0) return t;
    }
    return a.$3.compareTo(b.$3);
  });
  return [for (final k in keyed) k.$1];
}
