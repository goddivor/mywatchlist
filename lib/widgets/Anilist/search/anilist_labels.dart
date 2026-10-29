import 'package:intl/intl.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_catalog.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';

/// Translated names of AniList's own values. Unknown values (AniList adds one) fall back to
/// AniList's raw value, readable enough (`SOME_VALUE` → `Some value`).
abstract final class AnilistLabels {
  static String _raw(String v) {
    final words = v.toLowerCase().replaceAll('_', ' ');
    return words.isEmpty ? v : words[0].toUpperCase() + words.substring(1);
  }

  static String kind(AnilistSearchKind kind) {
    final s = S.current;
    return switch (kind) {
      AnilistSearchKind.anime => s.Als_Kind_Anime,
      AnilistSearchKind.manga => s.Als_Kind_Manga,
      AnilistSearchKind.characters => s.Als_Kind_Characters,
      AnilistSearchKind.staff => s.Als_Kind_Staff,
      AnilistSearchKind.studios => s.Als_Kind_Studios,
      AnilistSearchKind.users => s.Als_Kind_Users,
    };
  }

  static String format(String v) {
    final s = S.current;
    return switch (v) {
      'TV' => s.Als_Format_TV,
      'TV_SHORT' => s.Als_Format_TV_SHORT,
      'MOVIE' => s.Als_Format_MOVIE,
      'SPECIAL' => s.Als_Format_SPECIAL,
      'OVA' => s.Als_Format_OVA,
      'ONA' => s.Als_Format_ONA,
      'MUSIC' => s.Als_Format_MUSIC,
      'MANGA' => s.Als_Format_MANGA,
      'NOVEL' => s.Als_Format_NOVEL,
      'ONE_SHOT' => s.Als_Format_ONE_SHOT,
      _ => _raw(v),
    };
  }

  static String status(String v) {
    final s = S.current;
    return switch (v) {
      'RELEASING' => s.Als_Status_RELEASING,
      'FINISHED' => s.Als_Status_FINISHED,
      'NOT_YET_RELEASED' => s.Als_Status_NOT_YET_RELEASED,
      'HIATUS' => s.Als_Status_HIATUS,
      'CANCELLED' => s.Als_Status_CANCELLED,
      _ => _raw(v),
    };
  }

  static String source(String v) {
    final s = S.current;
    return switch (v) {
      'ORIGINAL' => s.Als_Source_ORIGINAL,
      'MANGA' => s.Als_Source_MANGA,
      'LIGHT_NOVEL' => s.Als_Source_LIGHT_NOVEL,
      'WEB_NOVEL' => s.Als_Source_WEB_NOVEL,
      'NOVEL' => s.Als_Source_NOVEL,
      'VISUAL_NOVEL' => s.Als_Source_VISUAL_NOVEL,
      'VIDEO_GAME' => s.Als_Source_VIDEO_GAME,
      'GAME' => s.Als_Source_GAME,
      'COMIC' => s.Als_Source_COMIC,
      'DOUJINSHI' => s.Als_Source_DOUJINSHI,
      'ANIME' => s.Als_Source_ANIME,
      'LIVE_ACTION' => s.Als_Source_LIVE_ACTION,
      'MULTIMEDIA_PROJECT' => s.Als_Source_MULTIMEDIA_PROJECT,
      'PICTURE_BOOK' => s.Als_Source_PICTURE_BOOK,
      'OTHER' => s.Als_Source_OTHER,
      _ => _raw(v),
    };
  }

  static String country(String v) {
    final s = S.current;
    return switch (v) {
      'JP' => s.Als_Country_JP,
      'KR' => s.Als_Country_KR,
      'CN' => s.Als_Country_CN,
      'TW' => s.Als_Country_TW,
      _ => v,
    };
  }

  static String season(String v) {
    final s = S.current;
    return switch (v) {
      'WINTER' => s.Explore_Season_Winter,
      'SPRING' => s.Explore_Season_Spring,
      'SUMMER' => s.Explore_Season_Summer,
      'FALL' => s.Explore_Season_Fall,
      _ => _raw(v),
    };
  }

  /// The name of a sort key (`SCORE`, not `SCORE_DESC`).
  static String sortKey(String key) {
    final s = S.current;
    return switch (key) {
      'POPULARITY' => s.Als_Sort_POPULARITY,
      'SCORE' => s.Als_Sort_SCORE,
      'TRENDING' => s.Als_Sort_TRENDING,
      'FAVOURITES' => s.Als_Sort_FAVOURITES,
      'START_DATE' => s.Als_Sort_START_DATE,
      'END_DATE' => s.Als_Sort_END_DATE,
      'TITLE_ROMAJI' => s.Als_Sort_TITLE_ROMAJI,
      'TITLE_ENGLISH' => s.Als_Sort_TITLE_ENGLISH,
      'TITLE_NATIVE' => s.Als_Sort_TITLE_NATIVE,
      'EPISODES' => s.Als_Sort_EPISODES,
      'DURATION' => s.Als_Sort_DURATION,
      'CHAPTERS' => s.Als_Sort_CHAPTERS,
      'VOLUMES' => s.Als_Sort_VOLUMES,
      'FORMAT' => s.Als_Sort_FORMAT,
      'STATUS' => s.Als_Sort_STATUS,
      'TYPE' => s.Als_Sort_TYPE,
      'UPDATED_AT' => s.Als_Sort_UPDATED_AT,
      'ID' => s.Als_Sort_ID,
      'SEARCH_MATCH' => s.Als_Sort_SEARCH_MATCH,
      _ => _raw(key),
    };
  }

  /// A list status of AniList (`CURRENT`, `PLANNING`…) as the badge writes it.
  static String listStatus(String v, {required bool anime}) {
    final s = S.current;
    return switch (v) {
      'CURRENT' => anime ? s.Als_List_Watching : s.Als_List_Reading,
      'PLANNING' => s.Als_List_Planning,
      'COMPLETED' => s.Als_List_Completed,
      'PAUSED' => s.Als_List_Paused,
      'DROPPED' => s.Als_List_Dropped,
      'REPEATING' => anime ? s.Als_List_Rewatching : s.Als_List_Rereading,
      _ => _raw(v),
    };
  }

  /// `1-12`, `12+`, `≤ 12`; [group] separates thousands (not for years).
  static String range(AnilistRange r, {bool group = true}) {
    final n = group ? NumberFormat.decimalPattern(Intl.getCurrentLocale()) : NumberFormat('0');
    if (r.min != null && r.max != null) {
      return r.min == r.max ? n.format(r.min) : '${n.format(r.min)}-${n.format(r.max)}';
    }
    if (r.min != null) return '${n.format(r.min)}+';
    return '≤ ${n.format(r.max)}';
  }
}

/// One active filter of a query, as a removable chip: its label and the query without it.
typedef AnilistActiveFilter = ({String label, AnilistMediaQuery Function() remove});

/// The active filters of [q], in the filter sheet's order. [catalog] names the streaming
/// services; without it they show as their AniList ids.
List<AnilistActiveFilter> activeAnilistFilters(AnilistMediaQuery q, {AnilistCatalogData? catalog}) {
  final s = S.current;
  final out = <AnilistActiveFilter>[];
  void add(String label, AnilistMediaQuery Function() remove) => out.add((label: label, remove: remove));
  void addRange(String label, AnilistRange r, AnilistMediaQuery Function() remove, {bool group = true}) {
    if (!r.isOpen) add(s.Als_Range(label, AnilistLabels.range(r, group: group)), remove);
  }

  if (q.season != null || q.seasonYear != null) {
    add(
      [if (q.season != null) AnilistLabels.season(q.season!), if (q.seasonYear != null) '${q.seasonYear}']
          .join(' '),
      () => q.copyWith(season: null, seasonYear: null),
    );
  }
  for (final f in q.formats) {
    add(AnilistLabels.format(f), () => q.copyWith(formats: [...q.formats]..remove(f)));
  }
  for (final st in q.allStatuses) {
    add(AnilistLabels.status(st), () => q.copyWith(
          status: q.status == st ? null : q.status,
          statuses: [...q.statuses]..remove(st),
        ));
  }
  for (final g in q.allGenres) {
    add(g, () => q.copyWith(genre: q.genre == g ? null : q.genre, genres: [...q.genres]..remove(g)));
  }
  for (final g in q.genresExcluded) {
    add(s.Als_Not(g), () => q.copyWith(genresExcluded: [...q.genresExcluded]..remove(g)));
  }
  for (final t in q.allTags) {
    add(t, () => q.copyWith(tag: q.tag == t ? null : q.tag, tags: [...q.tags]..remove(t)));
  }
  for (final t in q.tagsExcluded) {
    add(s.Als_Not(t), () => q.copyWith(tagsExcluded: [...q.tagsExcluded]..remove(t)));
  }
  for (final c in q.tagCategories) {
    add(c, () => q.copyWith(tagCategories: [...q.tagCategories]..remove(c)));
  }
  if (q.minimumTagRank != null) {
    add(s.Als_Range(s.Als_Sec_Tag_Rank, '${q.minimumTagRank}%'), () => q.copyWith(minimumTagRank: null));
  }
  for (final id in q.licensedByIds) {
    add(catalog?.sourceWithId(id)?.label ?? '#$id',
        () => q.copyWith(licensedByIds: [...q.licensedByIds]..remove(id)));
  }
  for (final c in q.allCountries) {
    add(AnilistLabels.country(c), () => q.copyWith(
          country: q.country == c ? null : q.country,
          countries: [...q.countries]..remove(c),
        ));
  }
  for (final src in q.sources) {
    add(AnilistLabels.source(src), () => q.copyWith(sources: [...q.sources]..remove(src)));
  }
  addRange(s.Als_Sec_Year, q.years, () => q.copyWith(years: AnilistRange.any), group: false);
  if (q.category == 'manga') {
    addRange(s.Als_Sec_Chapters, q.chapters, () => q.copyWith(chapters: AnilistRange.any));
    addRange(s.Als_Sec_Volumes, q.volumes, () => q.copyWith(volumes: AnilistRange.any));
  } else {
    addRange(s.Als_Sec_Episodes, q.episodes, () => q.copyWith(episodes: AnilistRange.any));
    addRange(s.Als_Sort_DURATION, q.duration, () => q.copyWith(duration: AnilistRange.any));
  }
  addRange(s.Als_Sec_Score, q.score, () => q.copyWith(score: AnilistRange.any));
  if (q.popularityMin != null) {
    add(s.Als_Popularity_Min(NumberFormat.compact(locale: Intl.getCurrentLocale()).format(q.popularityMin)),
        () => q.copyWith(popularityMin: null));
  }
  if (q.onList != null) {
    add(q.onList! ? s.Als_On_List : s.Als_Off_List, () => q.copyWith(onList: null));
  }
  if (q.isLicensed != null) {
    add(q.isLicensed! ? s.Als_Licensed : s.Als_Doujin, () => q.copyWith(isLicensed: null));
  }
  if (q.adult != null) {
    add(q.adult! ? s.Als_Adult_Only : s.Als_Adult_Hide, () => q.copyWith(adult: null));
  }
  return out;
}
