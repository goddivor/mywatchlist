// Query parameter values of Tenrai's OpenAPI document that Jikan's own enums
// (lib/services/api/Jikan/jikan_api.dart) do not already cover. Each value is
// the exact string the API expects ([value]).

/// `true`, `false` or `only` (e.g. `unapproved`, `spoilers`, `preliminary`).
enum TenraiTriState {
  yes('true'),
  no('false'),
  only('only');

  const TenraiTriState(this.value);
  final String value;
}

enum TenraiSeason {
  winter('winter'),
  spring('spring'),
  summer('summer'),
  fall('fall');

  const TenraiSeason(this.value);
  final String value;

  /// The season named [name] (`winter`, `spring`, `summer`, `fall`), or null.
  static TenraiSeason? tryParse(String name) {
    for (final season in values) {
      if (season.value == name.toLowerCase()) return season;
    }
    return null;
  }
}

enum TenraiMangaType {
  manga('manga'),
  novel('novel'),
  lightNovel('lightnovel'),
  oneShot('oneshot'),
  doujin('doujin'),
  manhwa('manhwa'),
  manhua('manhua');

  const TenraiMangaType(this.value);
  final String value;
}

/// Manga publishing status; [finished] is accepted by `/manga/ids` only.
enum TenraiMangaStatus {
  publishing('publishing'),
  complete('complete'),
  finished('finished'),
  upcoming('upcoming'),
  discontinued('discontinued'),
  hiatus('hiatus');

  const TenraiMangaStatus(this.value);
  final String value;
}

enum TenraiMangaOrderBy {
  malId('mal_id'),
  title('title'),
  startDate('start_date'),
  endDate('end_date'),
  chapters('chapters'),
  volumes('volumes'),
  score('score'),
  scoredBy('scored_by'),
  rank('rank'),
  popularity('popularity'),
  members('members'),
  favorites('favorites');

  const TenraiMangaOrderBy(this.value);
  final String value;
}

enum TenraiNewsOrderBy {
  publishedAt('published_at'),
  comments('comments');

  const TenraiNewsOrderBy(this.value);
  final String value;
}

enum TenraiArticleOrderBy {
  publishedAt('published_at'),
  views('views');

  const TenraiArticleOrderBy(this.value);
  final String value;
}

/// Tenrai's forum endpoints only list episode (anime) or chapter (manga) threads.
enum TenraiForumFilter {
  episode('episode');

  const TenraiForumFilter(this.value);
  final String value;
}

enum TenraiAnimeForumOrderBy {
  episodeNumber('episode_number'),
  createdOn('created_on'),
  commentCount('comment_count'),
  lastPost('last_post');

  const TenraiAnimeForumOrderBy(this.value);
  final String value;
}

enum TenraiMangaForumOrderBy {
  chapterNumber('chapter_number'),
  createdOn('created_on'),
  commentCount('comment_count'),
  lastPost('last_post');

  const TenraiMangaForumOrderBy(this.value);
  final String value;
}

enum TenraiReviewSentiment {
  recommended('recommended'),
  mixedFeelings('mixed_feelings'),
  notRecommended('not_recommended');

  const TenraiReviewSentiment(this.value);
  final String value;
}

enum TenraiReviewSort {
  newest('newest'),
  oldest('oldest'),
  mostHelpful('most_helpful');

  const TenraiReviewSort(this.value);
  final String value;
}

enum TenraiStackOrderBy {
  createdAt('created_at'),
  restackCount('restack_count');

  const TenraiStackOrderBy(this.value);
  final String value;
}

/// Order of the unapproved and denied entry lists.
enum TenraiPendingOrderBy {
  malId('mal_id'),
  title('title');

  const TenraiPendingOrderBy(this.value);
  final String value;
}

enum TenraiDeletedOrderBy {
  malId('mal_id'),
  title('title'),
  score('score'),
  members('members');

  const TenraiDeletedOrderBy(this.value);
  final String value;
}

enum TenraiAdaptedFilter {
  all('all'),
  airing('airing'),
  upcoming('upcoming');

  const TenraiAdaptedFilter(this.value);
  final String value;
}

enum TenraiCharacterOrderBy {
  malId('mal_id'),
  name('name'),
  favorites('favorites');

  const TenraiCharacterOrderBy(this.value);
  final String value;
}

enum TenraiPersonOrderBy {
  malId('mal_id'),
  name('name'),
  birthday('birthday'),
  favorites('favorites');

  const TenraiPersonOrderBy(this.value);
  final String value;
}

enum TenraiMagazineOrderBy {
  malId('mal_id'),
  name('name'),
  count('count');

  const TenraiMagazineOrderBy(this.value);
  final String value;
}

enum TenraiTopAnimeFilter {
  airing('airing'),
  upcoming('upcoming'),
  byPopularity('bypopularity'),
  favorite('favorite');

  const TenraiTopAnimeFilter(this.value);
  final String value;
}

enum TenraiTopMangaFilter {
  publishing('publishing'),
  upcoming('upcoming'),
  byPopularity('bypopularity'),
  favorite('favorite');

  const TenraiTopMangaFilter(this.value);
  final String value;
}

enum TenraiTopEpisodeOrderBy {
  score('score'),
  votes('votes'),
  comments('comments');

  const TenraiTopEpisodeOrderBy(this.value);
  final String value;
}

enum TenraiSeasonOrderBy {
  score('score'),
  members('members'),
  startDate('start_date'),
  malId('mal_id'),
  episodes('episodes'),
  favorites('favorites'),
  endDate('end_date'),
  scoredBy('scored_by'),
  title('title');

  const TenraiSeasonOrderBy(this.value);
  final String value;
}

enum TenraiScheduleDay {
  monday('monday'),
  tuesday('tuesday'),
  wednesday('wednesday'),
  thursday('thursday'),
  friday('friday'),
  saturday('saturday'),
  sunday('sunday'),
  unknown('unknown'),
  other('other');

  const TenraiScheduleDay(this.value);
  final String value;
}
