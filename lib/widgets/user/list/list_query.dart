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
  static const season = 'season';
  static const studio = 'studio';
  static const author = 'author';
  static const rating = 'rating';
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

/// Seasons in calendar order (MAL `start_season.season`, AniList `season` lowercased).
const List<String> _seasonOrder = ['winter', 'spring', 'summer', 'fall'];

/// Facet value of the first season of [e] (`2024:spring`), or null when unknown.
String? _seasonKey(ListEntryView e) {
  final season = e.startSeason?.toLowerCase();
  final year = e.startSeasonYear;
  if (season == null || year == null || !_seasonOrder.contains(season)) return null;
  return '$year:$season';
}

String _seasonLabel(String key) {
  final parts = key.split(':');
  final name = switch (parts.last) {
    'winter' => S.current.Explore_Season_Winter,
    'spring' => S.current.Explore_Season_Spring,
    'summer' => S.current.Explore_Season_Summer,
    _ => S.current.Explore_Season_Fall,
  };
  return S.current.Mi_Season_Year(name, parts.first);
}

/// Newest season first.
int _compareSeasons(String a, String b) {
  final pa = a.split(':');
  final pb = b.split(':');
  final year = int.parse(pb.first).compareTo(int.parse(pa.first));
  if (year != 0) return year;
  return _seasonOrder.indexOf(pb.last).compareTo(_seasonOrder.indexOf(pa.last));
}

/// MAL age ratings, mildest first.
const List<String> _ratingOrder = ['g', 'pg', 'pg_13', 'r', 'r+', 'rx'];

String _ratingLabel(String rating) => switch (rating) {
      'g' => S.current.Mi_Rating_G,
      'pg' => S.current.Mi_Rating_Pg,
      'pg_13' => S.current.Mi_Rating_Pg_13,
      'r' => S.current.Mi_Rating_R,
      'r+' => S.current.Mi_Rating_R_Plus,
      'rx' => S.current.Mi_Rating_Rx,
      _ => rating.replaceAll('_', '-').toUpperCase(),
    };

String? _ratingOf(ListEntryView e) {
  final r = e.ageRating?.trim().toLowerCase();
  return r == null || r.isEmpty ? null : r;
}

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
  final seasons = <String>{};
  final studios = <String>{};
  final authors = <String>{};
  final ratings = <String>{};
  for (final e in entries) {
    media.add(e.mediaType ?? 'unknown');
    release.add(e.releaseState);
    genres.addAll(e.genres);
    final season = _seasonKey(e);
    if (season != null) seasons.add(season);
    studios.addAll(e.studios.where((s) => s.isNotEmpty));
    authors.addAll(e.authors.where((a) => a.isNotEmpty));
    final rating = _ratingOf(e);
    if (rating != null) ratings.add(rating);
  }
  final sortedMedia = media.toList()..sort((a, b) => mediaTypeLabel(a).compareTo(mediaTypeLabel(b)));
  final sortedGenres = genres.toList()..sort();
  final sortedSeasons = seasons.toList()..sort(_compareSeasons);
  int byName(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());
  final sortedStudios = studios.toList()..sort(byName);
  final sortedAuthors = authors.toList()..sort(byName);
  int rank(String r) {
    final i = _ratingOrder.indexOf(r);
    return i < 0 ? _ratingOrder.length : i;
  }
  final sortedRatings = ratings.toList()..sort((a, b) => rank(a).compareTo(rank(b)));
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
    if (sortedSeasons.isNotEmpty)
      ListFilterFacet(
        key: ListFacetKeys.season,
        label: S.current.Ltf_Facet_Season,
        options: [for (final k in sortedSeasons) SelectOption(k, _seasonLabel(k))],
        allowExclude: true,
      ),
    if (sortedStudios.isNotEmpty)
      ListFilterFacet(
        key: ListFacetKeys.studio,
        label: S.current.Ltf_Facet_Studio,
        options: [for (final s in sortedStudios) SelectOption(s, s)],
        allowExclude: true,
      ),
    if (sortedAuthors.isNotEmpty)
      ListFilterFacet(
        key: ListFacetKeys.author,
        label: S.current.Ltf_Facet_Author,
        options: [for (final a in sortedAuthors) SelectOption(a, a)],
        allowExclude: true,
      ),
    if (sortedRatings.isNotEmpty)
      ListFilterFacet(
        key: ListFacetKeys.rating,
        label: S.current.Ltf_Facet_Rating,
        options: [for (final r in sortedRatings) SelectOption(r, _ratingLabel(r))],
        allowExclude: true,
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
      ListFacetKeys.season => _seasonKey(e) == null ? const {} : {_seasonKey(e)!},
      ListFacetKeys.studio => e.studios.toSet(),
      ListFacetKeys.author => e.authors.toSet(),
      ListFacetKeys.rating => _ratingOf(e) == null ? const {} : {_ratingOf(e)!},
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

/// Time already watched of [e], rewatches included: the current [ListEntryView.progress], plus
/// one full run per completed rewatch ([ListEntryView.timesRewatched]) and, while a rewatch is
/// in progress ([ListEntryView.repeating]), the first full run its progress restarted from.
/// The extra runs need a known episode total. Null when the length is unknown.
Duration? timeWatchedWithRewatches(ListEntryView e) {
  final base = e.timeWatched;
  if (base == null) return null;
  if (e.total <= 0) return base;
  final runs = (e.timesRewatched > 0 ? e.timesRewatched : 0) + (e.repeating ? 1 : 0);
  return base + Duration(seconds: runs * e.total * e.episodeSeconds);
}

/// The time line of a list tab ([ListTimeSummary.of]), with rewatches counted in the time
/// watched ([timeWatchedWithRewatches]); the time left is unchanged.
ListTimeSummary? listTimeSummary(
  Iterable<ListEntryView> entries,
  ListEntryStatus? status, {
  bool partial = false,
}) {
  final kind = switch (status) {
    ListEntryStatus.current || ListEntryStatus.onHold || ListEntryStatus.planned =>
      ListTimeKind.left,
    _ => ListTimeKind.watched,
  };
  var seconds = 0;
  for (final e in entries) {
    final d = kind == ListTimeKind.left ? e.timeLeft : timeWatchedWithRewatches(e);
    if (d != null) seconds += d.inSeconds;
  }
  if (seconds <= 0) return null;
  return ListTimeSummary(kind, Duration(seconds: seconds), partial: partial);
}
