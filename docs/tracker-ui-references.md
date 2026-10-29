# Tracker UI references

Owner rule (2026-10-29): each tracker is its own app. AniList, Kitsu and Simkl screens are designed from their own data and from the best third-party apps built on them, in their own files. DailyAL is the UI reference for MyAnimeList screens only. Every item of a tracker opens that tracker's native page, mapped to MyAnimeList or not.

Each part below was researched on 2026-10-29 from the apps' source code, websites and store listings, with a link on each claim. For every screen it says what the best apps show, then gives the recommended MWL layout as an ordered list of blocks with the data field behind each. A unit building a tracker screen follows the matching section.

- [AniList](#anilist-ui-reference-for-mywatchlist)
- [Kitsu](#kitsu-ui-reference-for-mywatchlist-mwl)
- [Simkl](#simkl-ui-reference-for-mywatchlist-mwl)

---

# AniList UI reference for MyWatchList

Research date: 2026-10-29. Read-only; nothing in the MWL repo was changed.
Goal: design MWL's AniList screens from AniList's own data and from the best third-party AniList clients, not from the MAL/DailyAL layout.

## 0. Sources and how they were read

| App | Platform / stack | Popularity signal | Status | How it was read |
|---|---|---|---|---|
| **AniHyou** | Android (Compose, M3) + iOS | 626 GitHub stars, Play Store + F-Droid ([repo](https://github.com/axiel7/AniHyou-android), [F-Droid](https://f-droid.org/packages/com.axiel7.anihyou)) | active (commit a6650b7, 2026-10-27) | source cloned; screens, `.graphql` operations |
| **Dartotsu** | **Flutter**, Android/iOS/desktop; rewrite of Dantotsu | 545 stars ([repo](https://github.com/aayush2622/Dartotsu)) | active (3bcb5b2, 2026-10-28) | source cloned; AniList screen builders |
| **Otraku** | **Flutter**, Android/iOS | 464 stars ([repo](https://github.com/lotusprey/otraku)) | active (928c7af, 2026-09-22) | source cloned |
| **AL-chan** | Android (Kotlin, views) | 325 stars ([repo](https://github.com/zend10/AL-chan)) | maintained (3724c00, 2026-03-31) | source cloned; adapters/strings |
| AniSync | Android (Compose) | 158 stars, F-Droid ([listing](https://f-droid.org/en/packages/com.anisync.android/)) | active | store listing only |
| Animite | Android (Compose) | 523 stars ([repo](https://github.com/imashnake0/Animite)) | active, early | README only (credits AniHyou, Katana, AniTrend as its references) |
| Dantotsu (original) | Android | well known | GitHub repo DMCA'd 2025-03 ([AlternativeTo](https://alternativeto.net/software/dantotsu/about), [DMCA notice](https://git.randommeaninglesscharacters.com/github/dmca/src/branch/master/2025/03/2025-03-11-crunchyroll.md)) | not readable; Dartotsu is its Flutter successor |
| anilist.co (first party) | web | n/a | AniList ships no native app I could find; the website is the first-party reference | layout described from the site; fields checked against the live schema |

Popularity ranking from `gh search repos anilist client --sort stars` (2026-10-29): AniHyou > Dartotsu > Animite > Otraku > AL-chan > ... AniHyou is the strongest single reference (most complete, Material 3, actively maintained). Otraku and Dartotsu matter most technically because they are Flutter like MWL.

**Schema** facts below come from live introspection of `https://graphql.anilist.co` on 2026-10-29 (API docs: [docs.anilist.co](https://docs.anilist.co/reference/object/media)). Important finding: **`Media.averageScore` is deprecated ("Use weightedScore")**. MWL still queries `averageScore` in 11 places (`lib/services/api/Anilist/anilist_media.dart`, `anilist_api.dart`, `lib/services/tracker_sync_service.dart`). AniHyou already uses `weightedScore` ([MediaDetails.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/mediadetails/MediaDetails.graphql)).

Note on the repo: `work/handoffs/anilist-media-page.md` still says "native title page reusing the MAL detail layout and widgets". That contradicts the owner's "each tracker is its own app" rule written in the same file. This reference assumes the owner rule wins (AniList's own layout; shared low-level widgets like images/chips are fine). `docs/tracker-ui-references.md`, which the handoffs point to, does not exist yet; this file can seed it.

---

## 1. What AniList has that MAL does not (design opportunities)

All fields verified in the live schema.

| AniList feature | Field(s) | MAL equivalent |
|---|---|---|
| Banner image per title and per user | `Media.bannerImage`, `User.bannerImage` | none |
| Dominant cover colour (accent/fallback) | `Media.coverImage.color` | none |
| Weighted score + mean score, both 0-100 | `weightedScore`, `meanScore` | one `mean` 0-10 |
| Rankings by context: all time, year, season, per format, rated vs popular | `rankings { rank type(RATED/POPULAR) format year season allTime context }` | one global rank + popularity rank |
| Status distribution (current/planning/completed/dropped/paused counts) | `stats.statusDistribution { status amount }` | partial (MAL stats page, scraped) |
| Score distribution (10..100 in 10 buckets) | `stats.scoreDistribution { score amount }` | scraped only |
| Tags with relevance % (rank), category, spoiler flags, adult flag | `tags { name description category rank isGeneralSpoiler isMediaSpoiler isAdult }` | genres/themes only, no % |
| Official streaming episodes with thumbnails | `streamingEpisodes { title thumbnail url site }` | none |
| External links typed (INFO / STREAMING / SOCIAL) with brand colour + icon + language | `externalLinks { site url type language color icon notes }` | `external`/`streaming` (no colour/type) |
| Airing countdown and full schedule | `nextAiringEpisode { airingAt timeUntilAiring episode }`, `airingSchedule` | broadcast day/time only |
| Daily trends (score/popularity/watchers per day and per episode) | `trends { date trending averageScore popularity inProgress episode }`, `Page.mediaTrends` | none |
| Hashtag, country of origin, licensed flag | `hashtag`, `countryOfOrigin`, `isLicensed` | none |
| Favourites for media, characters, staff, studios (toggle + ordered) | `isFavourite`, `favourites`, `User.favourites { anime manga characters staff studios }`, `ToggleFavourite`, `UpdateFavouriteOrder` | read-only via scraping |
| User-chosen score format | `MediaListOptions.scoreFormat`: `POINT_100`, `POINT_10_DECIMAL`, `POINT_10`, `POINT_5` (stars), `POINT_3` (smileys) | always 0-10 |
| Advanced scoring (named sub-scores) | `MediaListTypeOptions.advancedScoring`, `advancedScoringEnabled`, entry `advancedScores` | none |
| Custom lists, section order, split completed by format | `MediaListTypeOptions.customLists`, `sectionOrder`, `splitCompletedSectionByFormat`, entry `customLists`, `hiddenFromStatusLists` | none |
| Entry priority, private, repeat, notes, start/complete dates | `MediaList.priority private repeat notes startedAt completedAt` | priority/rewatch/notes exist; no private |
| `REPEATING` list status | `MediaListStatus.REPEATING` | `is_rewatching` flag |
| Activity feed: list activities, text posts, messages; likes, replies, pin, subscribe, lock | `ListActivity`, `TextActivity`, `MessageActivity`: `likeCount isLiked likes replies isPinned isSubscribed` | none |
| 20 notification types (airing, follows, likes, replies, mentions, threads, media changes, submissions) | `NotificationType` enum | none |
| Following users' entries on a title ("Following" / social) | `Page.mediaList(mediaId, isFollowing: true)` | none |
| Recommendations with user votes (+1/-1) and submit | `Recommendation { rating userRating }`, `SaveRecommendation` | read-only |
| Reviews with summary, 0-100 score, up/down votes | `Review { summary score rating ratingAmount userRating }`, `RateReview` | reviews (no voting via API) |
| User statistics: by score, length, format, status, country, release year, start year, genre, tag, voice actor, staff, studio; each with count, minutes, mean score | `User.statistics.anime/manga {...}` | basic counts only |
| Character alt names incl. spoiler names | `Character.name.alternativeSpoiler` | none |
| Staff: years active, hometown, occupations, death date, language | `Staff.yearsActive homeTown primaryOccupations dateOfDeath languageV2` | partial |
| Search filters: tag include/exclude with min tag rank, tag category, licensed-by (streaming service), score/popularity/episode/duration/chapter ranges, country, source, on-list, adult | `Page.media(...)` args: `tag_in tag_not_in minimumTagRank tagCategory_in licensedById_in weightedScore_greater/lesser popularity_greater episodes_greater/lesser duration_greater/lesser countryOfOrigin source_in onList isAdult ...` | far fewer |

---

## 2. Title detail page (anime / manga)

### What the best apps do

**AniHyou** ([MediaDetailsView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/MediaDetailsView.kt)):
1. Top app bar: back, **favourite heart** (`isFavourite`, `ToggleFavourite`), overflow menu (share `siteUrl`, per-title airing notifications).
2. **Banner** full-width (`bannerImage`; tap = full-screen); fallback is a block filled with `coverImage.color`.
3. Cover (`coverImage.large`, tap = `extraLarge` full screen) beside title (`title.userPreferred`, long-press copies) and three icon lines: format, duration or episode count, status.
4. **Stat row** of vertical number/caption pairs: "Ep N in 2d 4h" (`nextAiringEpisode`), weighted score `NN%` (`weightedScore`), mean score `NN%` (`meanScore`), popularity, favourites.
5. Genre AssistChips (tap = search by genre).
6. Synopsis (HTML, collapsed with expand button), translate button, user custom-link menu.
7. **Segmented tab group with icons**: Info, Staff & Characters, Relations, Stats, Reviews ([MediaDetailsType.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/MediaDetailsType.kt)).
8. Extended FAB "Add" / current status ("Watching") opens the list editor sheet.

Info tab ([MediaInformationView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/composables/MediaInformationView.kt)), in order: Information table (airing, episodes/chapters, duration, volumes, start/end date, season, source, romaji/english/native titles, synonyms, studios, producers) · **Tags** FlowRow, first 10 then "more", each chip shows `rank%` with `description` on long-press, spoiler tags hidden behind a "Show spoiler" toggle in the section header · **Trailer** thumbnail (`trailer.thumbnail`, opens YouTube/Dailymotion) · **"Continue watching"**: the streaming episode matching `progress + 1` from `streamingEpisodes` · **Episodes** LazyRow of `streamingEpisodes` thumbnails · **Streaming sites** (`externalLinks` where `type == STREAMING`) · **External links** (others) · **Openings / Endings** (theme songs fetched from MAL by `idMal`, with a music-streaming sheet).

Stats tab ([MediaStatsView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/composables/MediaStatsView.kt), [MediaStats.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/mediadetails/MediaStats.graphql)): **Rankings** (each tappable: opens search filtered on that season/year, sorted by score or popularity) · **Status distribution** (stacked horizontal bar + legend) · **Score distribution** (10-bar chart) · **Following** (users you follow with their status and score in their own format: [MediaFollowing.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/mediadetails/MediaFollowing.graphql)).

Relations tab ([MediaRelationsView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/composables/MediaRelationsView.kt)): Related LazyRow (cover, `relationType(version: 3)` label, own list status) · Recommendations LazyRow sorted `RATING_DESC` with **up/down vote** (`rating`, `userRating`) and an **Add recommendation** button (`SaveRecommendation`).

Reviews tab ([ReviewThreadListView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/mediadetails/src/main/java/com/axiel7/anihyou/feature/mediadetails/composables/ReviewThreadListView.kt)): Threads row, Reviews row, and Activity (title-scoped activity feed: `activities(mediaId:)`).

**Otraku** ([media_header.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/media/media_header.dart), [media_overview_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/media/media_overview_view.dart)):
- Collapsing header: banner + cover + title + a **text rail** of small labels: `Adult` (highlighted), format, **your list status**, "Ep N in 3h" (highlighted), and **"N episodes behind"** (highlighted, computed `nextAiringEpisode.episode - 1 - progress`).
- Scrollable tab bar: Overview, Related, Characters, Staff, Reviews, Threads, **Followed**, Activities, Recommendations, Statistics.
- Overview order: description · one card with 4 icon tiles (favourites, popularity, weighted %, mean) · key/value table (release, status, episodes, duration, chapters, volumes, season, source, country, hashtag) · genres · tags · studios · producers · **external links as chips with a colour square from `externalLinks.color`** and the country/language code · titles table (romaji, english, native, synonyms).
- Statistics tab: **rank grid** (star icon = rated, heart = popular, tap = discover with that season/year and sort) + score and status distributions ([media_stats_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/media/media_stats_view.dart)).
- Floating actions: Add / Edit (with status) + favourite ([media_floating_actions.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/media/media_floating_actions.dart)).

**AL-chan** ([MediaRvAdapter.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/media/MediaRvAdapter.kt)): one long scroll instead of tabs: synopsis · characters row · info · genres · tags · opening/ending themes · stats · relations · recommendations · trailers · links · staff. Separate **Media Stats** screen: stats header, rankings, status distribution, score distribution ([MediaStatsRvAdapter.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/media/mediastats/MediaStatsRvAdapter.kt)); separate **Media Social** screen: following users' entries + title activity ([MediaSocialRvAdapter.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/media/mediasocial/MediaSocialRvAdapter.kt)).

**Dartotsu** ([Screens/Detail.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Api/Services/Anilist/Screens/Detail.dart), [DetailStats.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Screen/Detail/Components/DetailStats.dart)): stat pills (score shown as `meanScore/10` with one decimal, popularity compacted "12.3K", favourites, episode duration, airing countdown) · synopsis · names (romaji/english) and synonyms chips · genres · characters row · staff row · **prequel/sequel row first**, then other relations · recommendations · details table (episodes/chapters, format, source, studio, author, season, country, aired range) · tags. Also **manga release forecast** from MangaUpdates ([MangaForecast.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Screen/Detail/Components/MangaForecast.dart)) and theme songs ([ThemesSection.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Screen/Detail/Components/ThemesSection.dart)).

**anilist.co**: banner, cover with "Add to List" dropdown + heart, description; tabs Overview / Watch / Characters / Staff / Reviews / Stats / Social; left sidebar with airing countdown, format, episodes, duration, status, dates, season, scores %, popularity, favourites, studios, producers, source, hashtag, genres, titles, synonyms; rankings ("#12 Highest Rated 2024", "#3 Most Popular Fall 2024") under the cover; tags with % and spoiler toggle; external & streaming links; Overview body: relations, characters (with VA), staff, status distribution, score distribution, watch (streaming episodes), trailer, recommendations, reviews. Stats tab additionally shows "Recent activity" charts from `trends`.

### Recommended MWL AniList title page

Single `CustomScrollView` with a collapsing header and a pinned scrollable `TabBar`. One query for header + Overview, other tabs lazy.

| # | Block | Data |
|---|---|---|
| 1 | **Collapsing banner** (16:9-ish, image fades into surface; fallback gradient from cover colour). App bar: back, favourite heart with count on long-press, share, overflow (open on anilist.co, open on MAL if `idMal`, copy title) | `bannerImage`, `coverImage.color`, `isFavourite`, `favourites`, `siteUrl`, `idMal` |
| 2 | Cover overlapping the banner (tap = full screen) + title (long-press = copy; secondary line = native/english per `User.options.titleLanguage`) | `coverImage.extraLarge/large`, `title{userPreferred romaji english native}` |
| 3 | **Label rail** under title (Otraku style): format · year/season · status · `18+` if adult · your status · **"Ep 7 in 2d 3h"** · **"2 behind"** | `format`, `season`, `seasonYear`, `status(version:2)`, `isAdult`, `mediaListEntry.status/progress`, `nextAiringEpisode` |
| 4 | **Stat row** (4 tiles): weighted `82%` · mean `84%` · popularity `312K` · favourites `21K`. Show % (AniList's native unit), not /10 | `weightedScore`, `meanScore`, `popularity`, `favourites` |
| 5 | **Top ranking chips** (1-2, tappable to filtered search): "#4 Rated 2024", "#1 Popular Fall 2024" | `rankings` (prefer `allTime`, then year, then season) |
| 6 | **My entry card** (only if on list): status, progress bar `7/12`, +1 button, score in the user's format, dates; tap = editor | `mediaListEntry{status score progress progressVolumes repeat startedAt completedAt}`, `Viewer.mediaListOptions.scoreFormat` |
| 7 | **Continue watching** card: next official streaming episode thumbnail | `streamingEpisodes` matched on `progress+1` |
| 8 | Synopsis (HTML, 5 lines, expand) | `description(asHtml:true)` |
| 9 | Genre chips | `genres` |
| 10 | Tabs: **Overview · Characters · Staff · Relations · Stats · Social · Reviews** | see below |
| 11 | FAB: "Add" or current status | `mediaListEntry` |

Overview tab: Information table (episodes/chapters/volumes, duration, start-end, season, source, country, studios (main, tappable), producers, hashtag, licensed) · Tags (FlowRow, `name rank%`, top 10 + more, spoiler toggle in header, long-press shows `description`, tap = search by tag) · Relations row (prequel/sequel first, `relationType(version:2)`) · Characters preview row (main role, with JP VA) · Trailer · Episodes row (`streamingEpisodes`) · Where to watch (STREAMING links as coloured chips with `icon`/`color`, `language`) · External links (INFO/SOCIAL) · Titles (romaji/english/native/synonyms) · Recommendations row (vote buttons).
Characters tab: `characters(sort:[ROLE, RELEVANCE, ID], page)` edges: `role`, `node{name image}`, `voiceActors(language:)` with a language selector (AniSync and Otraku both offer VA language filtering).
Staff tab: `staff(sort:[RELEVANCE])` edges with `role`.
Relations tab: full relations grouped by `relationType` + recommendations grid with votes and "Recommend a title" (`SaveRecommendation`).
Stats tab: rankings list · status distribution stacked bar with counts · score distribution 10 bars (coloured red to green as on anilist.co) · optional trend line of score/watchers per episode (`trends(sort: EPISODE_DESC, releasing: true)`).
Social tab: **Following** (avatar, name, status, score rendered in *their* `mediaListOptions.scoreFormat`) · title activity (`Page.activities(mediaId:)`) · threads (`Page.threads(mediaCategoryId:)`).
Reviews tab: `reviews(sort:[RATING_DESC])`: summary, score/100, `rating/ratingAmount` helpful.

---

## 3. My List (user collection)

### What the best apps do

**AniHyou** ([usermedialist](https://github.com/axiel7/AniHyou-android/tree/master/feature/usermedialist)): status chosen from a **bottom-sheet picker** (statuses + custom lists, `ListSelectSheet`) instead of a tab strip; 4 **list styles** STANDARD / COMPACT / MINIMAL / GRID, configurable separately per status ([ListStyle.kt](https://github.com/axiel7/AniHyou-android/blob/master/core/model/src/main/java/com/axiel7/anihyou/core/model/ListStyle.kt)); standard row = cover, title, **airing text** ("Ep 8 in 1d"), progress bar + `progress/total`, score badge in user format, status badge, **notes / repeat / priority indicators**, **+1 button** ([StandardUserMediaListItem.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/usermedialist/src/main/java/com/axiel7/anihyou/feature/usermedialist/composables/StandardUserMediaListItem.kt)); sort asc/desc on every `MediaListSort`; random pick; search in list; priority colours setting. Score fetched with `score(format: $scoreFormat)` so the server converts ([UserMediaList.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/medialist/UserMediaList.graphql)).

**Otraku** ([collection](https://github.com/lotusprey/otraku/tree/main/lib/feature/collection)): anime and manga collections are **bottom-nav tabs** of their own; list switch between status lists *and* custom lists; **preview mode** (loads only Current first, full collection on demand); views detailed/simple grid; filters: format, status, country, notes with/without, private/public, sort; row shows format, airing countdown, **episodes behind**, notes, repeats, score, progress with +1 that asks "mark completed?" at the last episode ([collection_list.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/collection/collection_list.dart)).

**AL-chan**: list customisation (colours, background) and section order reset ([CustomiseFragment.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/customise/CustomiseFragment.kt)); "You are N behind" string.

### Recommended MWL AniList My List

| # | Block | Data |
|---|---|---|
| 1 | App bar: Anime/Manga switch, search-in-list, sort menu (all `MediaListSort`, asc/desc), view style menu (Standard / Compact / Grid), random | `MediaListCollection(userId, type)` |
| 2 | List selector: horizontal chip/tab strip built from the user's **`sectionOrder`** (so it matches anilist.co), including **custom lists** and, if `splitCompletedSectionByFormat`, "Completed TV / Movie / ..." | `lists{name status isCustomList isSplitCompletedList entries}`, `mediaListOptions.animeList{sectionOrder customLists splitCompletedSectionByFormat}` |
| 3 | Filter sheet: format, airing status, country, genre, year, has-notes, private | entry `media{format status countryOfOrigin genres startDate}`, `notes`, `private` |
| 4 | **Row (standard)**: cover · title · label line (format · `Ep 8 in 1d` · **`2 behind`**) · progress bar `7/12` (+ volumes for manga) · score in user format (stars for POINT_5, smiley for POINT_3, `8.5` for POINT_10_DECIMAL, `85` for POINT_100) · small icons for notes, repeat count, private, priority · **+1** button | `progress progressVolumes score(format:) repeat notes private priority media{episodes chapters volumes nextAiringEpisode coverImage{large color}}` |
| 5 | Grid: cover with progress overlay + score badge (keep the DailyAL grid look only if the owner wants cross-tracker consistency; otherwise AniHyou grid) | same |
| 6 | +1 at the last episode → prompt "Mark completed?" and set `completedAt` today; first +1 from Planning → set status Current and `startedAt` (Otraku/AniHyou behaviour) | `SaveMediaListEntry` |

---

## 4. List entry editor

**AniHyou** ([EditMediaSheet.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/editmedia/src/main/java/com/axiel7/anihyou/feature/editmedia/EditMediaSheet.kt), [ScoreView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/editmedia/src/main/java/com/axiel7/anihyou/feature/editmedia/composables/ScoreView.kt)): bottom sheet: Cancel/Save · status chips · progress row with −/+ (episodes or chapters) · volumes row · **score control by format** (slider/number for POINT_100, POINT_10, POINT_10_DECIMAL; 5-star bar for POINT_5; 3 faces for POINT_3) · start/end date pickers · priority (low/medium/high) · repeat count · custom lists dialog · hide from status lists · private · notes · Delete. Auto-sets start date when leaving Planning ([EditMediaViewModel.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/editmedia/src/main/java/com/axiel7/anihyou/feature/editmedia/EditMediaViewModel.kt)).

**Otraku** ([edit_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/edit/edit_view.dart), [score_field.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/edit/score_field.dart)): same fields plus **advanced scores** and contextual messages: "Status changed", "Start date set", "Completion date and progress changed" when one change implies another.

**Recommended MWL editor** (bottom sheet, `SaveMediaListEntry`): status segmented (Current/Planning/Completed/Repeating/Paused/Dropped, anime vs manga wording) · progress stepper (`progress`, max `episodes/chapters`) · volumes stepper (manga) · **score widget switched on `scoreFormat`** · advanced scores (only if `advancedScoringEnabled`; names from `advancedScoring`; mean fills main score) · started / completed date pickers with "today" shortcut · repeat count · priority · custom lists checkboxes (`customLists`) · hide from status lists · private · notes · delete (`DeleteMediaListEntry`). Auto rules: Planning→progress>0 ⇒ Current + `startedAt`; progress == total ⇒ Completed + `completedAt`; show a one-line snackbar of what was auto-changed.

---

## 5. Profile

### What the best apps do

**AniHyou** ([ProfileView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/profile/src/main/java/com/axiel7/anihyou/feature/profile/ProfileView.kt), [ProfileInfoType.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/profile/src/main/java/com/axiel7/anihyou/feature/profile/ProfileInfoType.kt)): banner (`bannerImage`) + avatar + name + **donator badge** (`donatorBadge`, `donatorTier`) + Follow/Following button and "Follows you" (`isFollowing`, `isFollower`) + "View anime/manga list" buttons; accent from `options.profileColor`; tabs **About · Activity · Stats · Favourites · Social**. Stats ([UserStatsView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/profile/src/main/java/com/axiel7/anihyou/feature/profile/stats/UserStatsView.kt)) has sub-pages Overview / Genres / Tags / Staff / Voice actors / Studios with an anime/manga chip; Overview = count, days watched, days planned, mean score, standard deviation, episode count, then distributions (score, length, format, status, country, release year, watch year) with a "titles / time / mean" switch ([UserStatsAnimeOverview.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/stats/UserStatsAnimeOverview.graphql)). Favourites grids per type with **drag-to-reorder** (`UpdateFavouriteOrder`).

**Otraku** ([user_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/user/user_view.dart), [user_header.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/user/user_header.dart)): header with banner, avatar, **"Following each other / Following you / Following them"**, moderator roles, joined date; buttons to Anime, Manga, Activities, Social, Favourites, Statistics, Reviews. Statistics use pie charts (format, status, country) and bar charts (score, length, years) ([statistics_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/statistics/statistics_view.dart)).

**AL-chan** ([ProfileRvAdapter.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/profile/ProfileRvAdapter.kt)): bio · **Affinity** (score correlation with another user) · **Tendency** (auto-generated taste summary from stats) · favourite anime/manga/characters/staff/studios rows.

### Recommended MWL AniList profile

| # | Block | Data |
|---|---|---|
| 1 | Banner + avatar + name; accent = `profileColor`; donator badge; joined date | `bannerImage avatar{large} name options{profileColor} donatorBadge donatorTier createdAt` |
| 2 | Actions: Follow / Following, "Follows you", Message (other users); Settings (self) | `isFollowing isFollower`, `ToggleFollow` |
| 3 | 3-tile summary: anime days watched · manga chapters read · mean score | `statistics.anime{minutesWatched meanScore}`, `statistics.manga{chaptersRead}` |
| 4 | Tabs: **Overview · Activity · Favourites · Stats · Social** | |
| 5 | Overview: About (markdown/HTML), **genre overview** (top 5 genres as chips with counts), recent activity (3), quick links to Anime list / Manga list / Reviews | `about(asHtml:true)`, `statistics.anime.genres(limit:5, sort:COUNT_DESC)`, `Page.activities(userId:)` |
| 6 | Favourites: 5 grids (anime, manga, characters, staff, studios), reorder on own profile | `favourites{anime manga characters staff studios}`, `UpdateFavouriteOrder` |
| 7 | Stats: anime/manga switch; Overview numbers (count, episodes, days, days planned, mean, std dev); score bars; length bars; format/status/country donuts; release year and watch (start) year bars; each with titles/hours/mean toggle; sub-pages Genres, Tags, Voice actors, Staff, Studios as ranked lists with cover strips | `statistics.anime{count episodesWatched minutesWatched meanScore standardDeviation scores lengths formats statuses countries releaseYears startYears genres tags voiceActors staff studios}` |
| 8 | Social: Following / Followers lists | `Page.following(userId)`, `Page.followers(userId)` |
| 9 | Activity: user's feed (see §8) | `Page.activities(userId:)` |

---

## 6. Home

### What the best apps do

**AniHyou** ([HomeView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/home/src/main/java/com/axiel7/anihyou/feature/home/HomeView.kt), [CurrentView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/home/src/main/java/com/axiel7/anihyou/feature/home/current/CurrentView.kt), [CurrentListType.kt](https://github.com/axiel7/AniHyou-android/blob/master/core/model/src/main/java/com/axiel7/anihyou/core/model/CurrentListType.kt)): Home has two modes: **Current** (rows: *Airing* = your watching titles with an episode coming, *Behind* = aired episodes you have not watched, *Watching*, *Reading*, *Next season* = your planning titles of next season; each row item has +1) and **Activity** feed with Following/Global toggle. Plus an airing home-screen widget.

**Dartotsu** ([GetHomePageData.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Api/Services/Anilist/Queries/GetHomePageData.dart), [GetMissingSequels.dart](https://github.com/aayush2622/Dartotsu/blob/main/lib/Api/Services/Anilist/Queries/GetMissingSequels.dart), [Home components](https://github.com/aayush2622/Dartotsu/tree/main/lib/Screen/Home/Components)): user-reorderable sections: Continue Watching, Continue Reading, Favourite Anime/Manga, Planned Anime/Manga, Repeating, **Recommended** (recommendations from your completed titles, minus what is on your list), **Missing Sequel** (sequels of completed titles not on your list, from `relations` of your collection), Hidden media; header = banner + avatar + stat pills + bell with unread count.

**AL-chan** ([HomeRvAdapter.kt](https://github.com/zend10/AL-chan/blob/master/app/src/main/java/com/zen/alchan/ui/home/HomeRvAdapter.kt)): header, menu, **Releasing today**, trending anime, trending manga, social.

**Otraku** ([home_model.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/home/home_model.dart)): bottom nav Feed · Anime · Manga · Discover · Profile (Feed is the start tab).

### Recommended MWL AniList home

| # | Block | Data |
|---|---|---|
| 1 | Header: user banner strip + avatar, bell with unread badge | `Viewer{bannerImage avatar unreadNotificationCount}` |
| 2 | **Airing on my list** (next 7 days, countdown on card, ordered by `airingAt`) | `Page.airingSchedules(mediaId_in: <current ids>, notYetAired: true, sort: TIME)` or `MediaListCollection(status: CURRENT){ media{nextAiringEpisode} }` |
| 3 | **Behind** (aired episodes not watched: `nextAiringEpisode.episode - 1 > progress`, or finished and `progress < episodes`), with +1 | `MediaListCollection(status_in:[CURRENT,REPEATING])` |
| 4 | Continue watching / Continue reading (by `updatedAt`) | `MediaList.updatedAt` |
| 5 | **Missing sequels** | collection `media.relations(relationType: SEQUEL)` minus collection ids |
| 6 | Your planning titles that start this season / next season | `MediaListCollection(status: PLANNING){ media{season seasonYear status} }` |
| 7 | Recommended for you | `recommendations` of top-scored completed entries, `onList: false` filter client-side |
| 8 | Trending now (anime, manga) | `Page.media(sort: TRENDING_DESC)` |
| 9 | Friends' activity preview (3 items, "see all" → feed) | `Page.activities(isFollowing: true)` |

Make sections reorderable/hideable (Dartotsu, AL-chan both allow it).

---

## 7. Discover / Search / Filters / Calendar

### What the best apps do

**AniHyou** ([explore](https://github.com/axiel7/AniHyou-android/tree/master/feature/explore), [SearchMedia.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/media/SearchMedia.graphql), [ChartType.kt](https://github.com/axiel7/AniHyou-android/blob/master/core/model/src/main/java/com/axiel7/anihyou/core/model/media/ChartType.kt)): Explore = search bar + entry chips (Season, Calendar, Top 100, Top popular, Upcoming, Airing, Top movies; manga: Top 100, Popular, Popular manhwa, Upcoming, Publishing) + rows Trending now / Top popular / Newly added. Search types: anime, manga, characters, staff, studios, users. Filter chips row: sort, format (multi), status, **genres & tags include/exclude** sheet, year range, season, country, source, on my list, adult; **saved filters** ([SavedFiltersSheet.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/explore/src/main/java/com/axiel7/anihyou/feature/explore/search/composables/SavedFiltersSheet.kt)); also episode/duration/chapter/volume and score ranges and `minimumTagRank` in the query. Recommendations feed with up/down votes. Calendar: weekday tabs, grid or list, "on my list" toggle ([CalendarView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/calendar/src/main/java/com/axiel7/anihyou/feature/calendar/CalendarView.kt)).

**Otraku** ([discover_model.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/discover/discover_model.dart), [discover_media_filter_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/discover/discover_media_filter_view.dart)): one Discover tab with a type switch: anime, manga, characters, staff, studios, users, **reviews**, **recommendations**; filters include **"Watchable on / Readable on"** (licensed streaming/reading service = `licensedById_in`), licensing (licensed / doujin), list presence (in / not in my list), age (adult / non-adult), country, source, season, status, format; characters/staff filter "show birthdays today"; default filter can be saved.

### Recommended MWL AniList discover

| # | Block | Data |
|---|---|---|
| 1 | Search bar with type chips: Anime · Manga · Characters · Staff · Studios · Users | `Page.media/characters/staff/studios/users(search:)` |
| 2 | Shortcut chips: This season · Next season · Calendar · Top 100 · Popular · Upcoming · Top movies (manga: Top 100 · Popular · Manhwa · Publishing) | `Page.media(season seasonYear sort:[POPULARITY_DESC])`, `sort: SCORE_DESC`, `status: NOT_YET_RELEASED`, `format: MOVIE`, `countryOfOrigin: KR` |
| 3 | Rows: Trending now · Popular this season · Upcoming next season · All-time popular · Top 100 (with rank numbers) | `sort: TRENDING_DESC` etc. |
| 4 | Results: grid of covers with weighted %, format · year, own status badge | `weightedScore format startDate{year} mediaListEntry{status}` |
| 5 | Filter sheet: sort (score, popularity, trending, favourites, start date, title, search match) · format multi · status · season + year range · **genres include/exclude** · **tags include/exclude + min tag rank slider + tag category** · **streaming service** · country · source · episodes, duration, chapters ranges · score range · on my list (any/yes/no) · licensed/doujin · adult (if `displayAdultContent`) · save as default / saved filters | `Page.media` args (see §1), `GenreCollection`, `MediaTagCollection`, `ExternalLinkSourceCollection(type: STREAMING)` |
| 6 | Calendar page: weekday tabs, "only my list" toggle, rows with time and episode number | `Page.airingSchedules(airingAt_greater, airingAt_lesser, sort: TIME)` |
| 7 | Recommendations feed (pairs, vote) and Reviews feed | `Page.recommendations(sort: ID_DESC)`, `Page.reviews(sort: CREATED_AT_DESC)` |

---

## 8. Activity feed / social

**AniHyou** ([ActivityFeedView.kt](https://github.com/axiel7/AniHyou-android/blob/master/feature/home/src/main/java/com/axiel7/anihyou/feature/home/activity/ActivityFeedView.kt), [ActivityFeed.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/activity/ActivityFeed.graphql)): Following/Global filter chip; type filter; cards: list activity ("Watched episode 5 of X" with cover, avatar, relative time) and text activity (markdown), like count + heart (`ToggleLike`), reply count; detail page with replies and reply composer; publish text activity.

**Otraku** ([activity](https://github.com/lotusprey/otraku/tree/main/lib/feature/activity)): groups Global / Followed / Self; filter by type; actions like, reply, **pin**, **subscribe**, edit, remove; post status or message.

**AL-chan**: activity + replies view types; friends' activity on Home and on title pages.

**Recommended MWL feed**: top chips `Following | Global` + type multi-select (Status, Anime list, Manga list, Messages); card = avatar · name · relative time · body (list: "Watched episode 5 of" + title + small cover; text: rendered markdown with spoiler blocks and images) · bottom row: ❤ count (tap toggles, long-press shows likers) · 💬 count · overflow (subscribe, pin on own, delete own, copy link). FAB: new status post. Detail: activity + replies, reply composer, reply likes. Data: `Page.activities(isFollowing, type_in, sort:[ID_DESC], hasRepliesOrTypeText)`, `ListActivity{status progress media}`, `TextActivity{text}`, `MessageActivity{message messenger recipient}`, `likeCount isLiked replyCount isSubscribed isPinned`, mutations `ToggleLikeV2`, `SaveTextActivity`, `SaveActivityReply`, `ToggleActivitySubscription`, `ToggleActivityPin`, `DeleteActivity`. AniList merges consecutive list activities server-side (`UserOptions.activityMergeTime`).

---

## 9. Character and staff pages

**AniHyou** ([CharacterDetails.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/character/CharacterDetails.graphql), [StaffDetails.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/staff/StaffDetails.graphql)): tabs Info / Media. Character info: image, name, native, alternatives, **spoiler alternative names hidden**, birthday, age, gender, blood type, favourites + heart, description (markdown with spoilers); Media tab: appearances with role and the voice actor per title. Staff: + occupations, years active, hometown, date of death; tabs Info / Media (staff roles) / Characters (voiced roles), "on my list" filter.

**Otraku** ([character](https://github.com/lotusprey/otraku/tree/main/lib/feature/character), [staff](https://github.com/lotusprey/otraku/tree/main/lib/feature/staff)): Overview / Anime / Manga tabs for characters; Overview / Characters / Roles for staff; filters: sort and **list presence** (in / not in my list); favourites add/remove.

**Recommended MWL**:
- Character: header (image, name, native, favourite heart + count) · info table (birthday, age, gender, blood type; only non-empty rows) · alternative names (spoiler names behind tap) · description (AniList markdown with `~!spoiler!~`) · tabs Anime / Manga: grid, role badge (Main/Supporting/Background), voice actor under each anime card with language picker, sort (popularity, start date, score), "on my list" filter. Data: `Character{name{full native alternative alternativeSpoiler} image description gender dateOfBirth age bloodType favourites isFavourite media(sort, type, onList){edges{characterRole node voiceActors(language)}}}`.
- Staff: header (image, name, native, language, heart) · info (occupations, birth, death, age, years active, hometown, gender) · description · tabs **Voiced characters** (character + title; `characterMedia`), **Production roles** (`staffMedia` with `staffRole`, grouped by year), filters type / on my list / sort.
- Studio: name, heart, favourites, titles grid grouped by year (`Studio{media(sort: START_DATE_DESC, isMain)}`).

---

## 10. Notifications

**AniHyou** ([NotificationQuery.graphql](https://github.com/axiel7/AniHyou-android/blob/master/core/network/src/main/graphql/operations/viewer/NotificationQuery.graphql), [NotificationTypeGroup.kt](https://github.com/axiel7/AniHyou-android/blob/master/core/model/src/main/java/com/axiel7/anihyou/core/model/notification/NotificationTypeGroup.kt)): filter chips All / Airing / Activity / Forum / Follows / Media; item = image (media cover or user avatar) + text + relative time, unread highlighted; background worker posts system notifications for unread ones.

**Otraku** ([notifications_view.dart](https://github.com/lotusprey/otraku/blob/main/lib/feature/notification/notifications_view.dart)): same filter groups (All, Airing, Activity, Forum, Follows, Media) covering all 20 types, including media additions/changes/merges/deletions and submission updates.

**AniSync** ([F-Droid](https://f-droid.org/en/packages/com.anisync.android/)): local airing alerts 12 h and 2 h before release, premiere alerts for planning titles.

**Recommended MWL**: chips All · Airing · Activity · Forum · Follows · Media · list of items: leading image (cover for AIRING/MEDIA_*, avatar otherwise), text built per type ("Episode 6 of X aired", "Y liked your activity", "Y replied", "Z started following you", "X was added to the site", "data changed: reason"), relative time, unread dot until opened; tap routes (title page, activity detail, thread, profile). Data: `Page.notifications(type_in, resetNotificationCount: true)` with fragments for each of the 20 `NotificationType` values; badge from `Viewer.unreadNotificationCount`. Respect `UserOptions.notificationOptions` / `airingNotifications` in settings.

---

## 11. Score display rules (all screens)

AniList stores scores per user format. Rules taken from AniHyou/Otraku behaviour and the schema:
- Media-level scores (`weightedScore`, `meanScore`, review `score`) are 0-100: show as **`82%`** (AniHyou, Otraku, anilist.co). Dartotsu shows `8.2`; avoid this so AniList pages do not look like MAL.
- User entry scores: request `score(format: <viewer scoreFormat>)` and render: POINT_100 `85`, POINT_10_DECIMAL `8.5`, POINT_10 `8`, POINT_5 ★★★★☆, POINT_3 one of 3 faces (😞 😐 🙂 as icons). Score `0` = not scored (hide).
- Other users' scores (Following tab, activity) render in *their* `mediaListOptions.scoreFormat`.
- Colour scale for % (anilist.co convention): < 50 red, 50-74 orange/amber, ≥ 75 green.

## 12. Cross-screen conventions worth copying

- Banner + `coverImage.color` as the page accent, `profileColor` on profiles.
- One "label rail" vocabulary everywhere a title appears: format · year · `Ep N in Xd` · `N behind` · own status.
- Every title card opens the AniList title page (owner bug in `anilist-media-page` handoff).
- Spoilers: tags (`isMediaSpoiler`, `isGeneralSpoiler`), character names (`alternativeSpoiler`), markdown `~!...!~` all hidden behind a tap.
- Adult content gated by `UserOptions.displayAdultContent` (search and lists).
- Title language from `UserOptions.titleLanguage` (use `title.userPreferred`); staff name language from `staffNameLanguage`.
- Long-press to copy titles/names (AniHyou, AniSync).


---

# Kitsu UI reference for MyWatchList (MWL)

Research date 2026-10-29. Read-only on the MWL repo. Purpose: design MWL's Kitsu screens from Kitsu's own data and the best Kitsu apps, not from MAL/DailyAL.

## 0. Sources studied

| Code | Source | Version read | Why it matters |
|---|---|---|---|
| **WEB** | Official site kitsu.app, Ember app, branch `the-future` of [hummingbird-me/kitsu-web](https://github.com/hummingbird-me/kitsu-web/tree/the-future) | commit `df0f97c`, 2024-09-08 | This is what kitsu.app serves today (the report found the Ember `client/config/environment` meta in the live bundle: MWL report `docs/kitsu-simkl-report-2026-10-28.md` §1.1). |
| **NEXT** | Unreleased React rewrite, branch `react` (default) of [kitsu-web](https://github.com/hummingbird-me/kitsu-web/tree/react) | commit `2791b69`, 2025-02-01 | Kitsu's own direction: GraphQL-only, banner + poster layout. Only the anime Summary page is built. |
| **APP** | Official mobile app (React Native), branch `develop` of [hummingbird-me/kitsu-mobile](https://github.com/hummingbird-me/kitsu-mobile/tree/develop) | commit `2f2a552`, 2024-09-22 | Official phone UI: media page, profile, library, quick update, feed, notifications. JSON:API only. |
| **KTN** | Kitsune, unofficial Android client, [Drumber/Kitsune](https://github.com/Drumber/Kitsune) ([F-Droid](https://f-droid.org/en/packages/io.github.drumber.kitsune/)) | commit `701dfc7`, 2026-08-23; v2.1.0 on F-Droid 2026-07-28 (adds feeds, posts, comments, reactions, groups, follows, notifications, user search) | The most complete and most recent Kitsu app, Material 3, Android: closest model for MWL. |
| **NKM** | Nekome, unofficial Android client, [Chesire/Nekome](https://github.com/Chesire/Nekome) ([F-Droid](https://f-droid.org/packages/com.chesire.nekome/)) | commit `191def4`, 2024-08-15 | Minimal list-first tracker (Compose, Material 3): useful only for the library row and the +1 flow. |
| **API** | Live anonymous calls to `https://kitsu.io/api/edge` and GraphQL introspection of `https://kitsu.io/api/graphql` (today), plus the MWL report `docs/kitsu-simkl-report-2026-10-28.md` | 2026-10-29 | Field names below are checked against the live schema. |

Path shorthands used in links: `WEB:` = `kitsu-web/the-future/app/`, `APP:` = `kitsu-mobile/develop/src/`, `KTN:` = `Kitsune/master/app/src/main/`.

Note: `kitsu.app/api/graphql` answered with a non-JSON body to curl today; `kitsu.io/api/graphql` answered 200 with the schema. Keep `kitsu.io` for GraphQL (or fall back to it).

---

## 1. What Kitsu has that MAL does not (design drivers)

| Kitsu feature | Data | Where Kitsu shows it | Source |
|---|---|---|---|
| **Score as a percentage** ("88% Community Approval", "Kitsu Score 88%"), coloured by quartile (≤25, ≤50, ≤75, ≤100) | `averageRating` (string, 0–100) | web title block, app header, Kitsune stats card | [WEB media-rating.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/media/media-rating.js), [translations "{rating}% Community Approval"](https://github.com/hummingbird-me/kitsu-web/blob/the-future/translations/en-AU.yaml), [APP SceneHeader](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/SceneHeader/component.tsx) |
| **Two ranks**: "Rank #2 (Highest Rated Anime)" (star icon) and "Rank #788 (Most Popular Anime)" (heart icon), each a link to the matching Explore list | `ratingRank`, `popularityRank` (JSON:API); `averageRatingRank`, `userCountRank` (GraphQL) | web under categories, app header next to the score | [WEB media-rankings.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/media-rankings.hbs), [APP SceneHeader](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/SceneHeader/component.tsx) |
| **Rating distribution** (19 buckets, rating out of 20, keys "2"…"20") | `ratingFrequencies` (**JSON:API only**, not in GraphQL `Anime`) | Kitsune: bar chart "Ratings" with a switch Simple / Regular / Advanced and a recomputed average ("6.75 / 10") | live `GET /anime/46474`; [KTN DetailsFragment.showRatingChart](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/details/DetailsFragment.kt), [KTN RatingFrequenciesUtil](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/util/rating/RatingFrequenciesUtil.kt) |
| **Three user rating systems**: Simple (awful / meh / good / great = 1, 4, 7, 10 out of 20 bands), Regular (0.5–5 stars), Advanced (1–10 by 0.5) | entry `ratingTwenty` (2–20); account `ratingSystem` | every rating control and read-out | [WEB simple-rating.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/library-entry/simple-rating.js), [WEB readonly-rating.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/library-entry/readonly-rating.js), [KTN LocalRatingSystemPreference](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/data/source/local/user/model/LocalRatingSystemPreference.kt) |
| **Media reactions** (140-char takes, upvotes, "by user · 2 h ago", the episode the author was at) | `/media-reactions` (`reaction`, `upVotesCount`, `createdAt`, `progress` in GraphQL, `include=user`); vote `POST /media-reaction-votes` | web: rotating **reaction ticker** over the cover (one top reaction every 10 s), 6-item block sorted Best/New, full tab; app: Reactions row + tab; library grid poster overlay shows *your* reaction | [WEB reaction-ticker.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/media/reaction-ticker.js), [WEB media-reactions.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/media/media-reactions.js), [APP ReactionBox](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/ReactionBox/component.tsx) |
| **Where to watch** (streamer logos, sub/dub languages, regions) | `streamingLinks` (`url`, `subs`, `dubs`, `regions`, `streamer.siteName`) | web sidebar under the poster "Where to watch"; app Summary right under Progress; Kitsune "Streaming Links" logo row | [WEB media-sidebar.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/media-sidebar.hbs), [APP Summary renderStreamingLinks](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Summary/component.tsx) |
| **Franchise** with a role per item (sequel, prequel, side story, adaptation…) sorted by start date | `/media-relationships?filter[source_id]&filter[source_type]&include=destination` (`role`); GraphQL `relationships{kind destination}` | web "More from this Series" (4 posters) + Franchise tab; app list "TV · Sequel · 2023" | [WEB media-related.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/media/media-related.js), [WEB franchise.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/franchise.hbs), [APP Franchise](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Franchise/component.tsx) |
| **Per-title feed** (posts about the title) and **per-episode / per-chapter discussion** | `GET /feeds/media_aggr/Anime-{id}?filter[kind]=posts`, `GET /feeds/episode_aggr/{episodeId}`, `/feeds/chapter_aggr/{chapterId}` | web bottom of Summary ("Post about {title}…") and each episode page; app Summary bottom; Kitsune "Posts" button on the page and on each episode sheet | [WEB media/show/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/index.hbs), [WEB units/show.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/units/show.hbs), [KTN sheet_media_unit_details.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/sheet_media_unit_details.xml) |
| **Episode list with thumbnails**, titles, air date, length, synopsis, watched state | `/episodes` / GraphQL `episodes{number titles releasedAt length thumbnail description}` | web grid of 16:9 thumbnails with "Completed" overlay; app numbered list with a check circle per episode | [WEB unit-thumbnail.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/units/unit-thumbnail.hbs), [APP Episodes](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Episodes/component.tsx), [KTN item_episode.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_episode.xml) |
| **Hierarchical categories** (tags like "Elf", "Fantasy" with parents) as colourful chips | `categories` (GraphQL: `slug title root parent`, sorted by `ANCESTRY`) | web tag list under the synopsis; app horizontal coloured pills; Kitsune chip group | [NEXT Anime/Summary](https://github.com/hummingbird-me/kitsu-web/blob/react/src/pages/Anime/Summary/index.tsx), [APP SceneHeader](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/SceneHeader/component.tsx) |
| **Cover (banner) image** per title and per user, plus poster | `coverImage` / GraphQL `bannerImage`; user `coverImage` | full-width banner at the top of title and profile pages (web, app parallax, NEXT, Kitsune collapsing toolbar) | [WEB media/show.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show.hbs), [APP MediaPages](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/index.tsx) |
| **Profile stats with percentile** ("5.3 days spent watching anime. 510 completed. More than 38% of users.") and a **category donut** | `stats` kinds `anime-amount-consumed` (`time`, `completed`, `media`, `units`, `percentiles.time/units`), `anime-category-breakdown` (`categories` map, `total`) | web sidebar; app Summary tab; Kitsune About tab, anime/manga sub-tabs | [WEB time-spent.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/stats/time-spent.hbs), [WEB user-stats.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/users/user-stats.js), [KTN item_profile_stats.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_profile_stats.xml) |
| **Library activity events** with old → new values | `/library-events` (`kind`, `changedData`), GraphQL `libraryEvents` | app profile Summary "Library activity" row (poster + "Watched ep. 5" or the rating) | [APP ProfilePages/pages/Summary.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/ProfilePages/pages/Summary.tsx) |
| **Social layer**: follows, posts with likes / comments / spoiler and NSFW gates / pinned post, groups, global and following feeds, notifications incl. "Episode 5 of X aired" | `/feeds/*`, `/posts`, `/comments`, `/post-likes`, `/groups`, `/feeds/notifications/{id}` | everywhere on web and apps | [WEB dashboard.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/dashboard.hbs), [APP utils/notifications.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/utils/notifications.tsx) |
| **Waifu / husbando** on the profile, favourite **characters** | user `waifu` (include), `waifuOrHusbando`; `/favorites?filter[itemType]=Character` | web About box, app About tab, Kitsune About | [WEB about-me.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/about-me.hbs) |
| **Library status counts in one call** | `GET /library-entries?...&page[limit]=1` → `meta.statusCounts {current, planned, completed, onHold, dropped}` + `meta.count` | web library sidebar counts | live call (user 286143); [WEB library-sidebar.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/library/library-sidebar.hbs) |
| Library extras: notes, private flag, rewatch count + "Start rewatch", started/finished dates, volumes owned, `reactionSkipped` | library entry attributes `notes private reconsumeCount reconsuming startedAt finishedAt progressedAt volumesOwned reactionSkipped` | web edit modal, app edit screen | live call; [WEB library-edit strings](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/modals/library-edit.hbs) |
| External ids of a title | GraphQL `mappings{externalSite externalId}` | Kitsune bottom sheet "mappings" (links to MAL, AniList, AniDB…) | [KTN MediaMappingsBottomSheet](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/details/MediaMappingsBottomSheet.kt) |

Things Kitsu does **not** have (do not design for them): no per-title member status distribution (watching/completed/dropped counts per title), no "recommendations" list, no structured long reviews after 2019 (legacy `reviews`, superseded by reactions), no forum boards (groups replace them), no airing schedule endpoint (only `nextRelease` per title and the `aired` notification). Characters/staff are often empty for recent titles (the official app even disabled its Characters tab "until we improve our character db", [APP MediaPages fetchOther](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/index.tsx)); hide those sections when empty, as the web does (`shouldRender=false`, [WEB featured-characters.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/media/featured-characters.js)).

---

## 2. Title detail page (media page)

### 2.1 What Kitsu shows

**Web (kitsu.app)** — [media/show.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show.hbs), [show/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/index.hbs), [media-sidebar.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/media-sidebar.hbs), [media-summary.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/media-summary.hbs), [media-information.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/media-information.hbs)
1. Full-width **cover image** (`coverImage`) with a dark overlay; on it, the **reaction ticker** (avatar + one top reaction, rotates every 10 s through the 6 most upvoted) and a "…" menu (hide this title's posts from my feed).
2. **Tab bar** over the cover's bottom edge: Summary · Episodes/Chapters · Characters · Reactions · Franchise.
3. Sticky **left sidebar**: poster (`posterImage.large`) with a **heart** (favourite) on its corner; **library state box** (not in library → add buttons; current → progress +1, rating; completed/dropped → rating + "Add reaction" + "Rewatch"; "Edit library entry" button); **Where to watch** logos (`streamingLinks.streamer.siteName`).
4. Main column (Summary tab): title (`canonicalTitle` without year) + year; **"88% Community Approval"** (`averageRating`, quartile colour); synopsis with "read more" at 480 chars; **category tags** (link to browse by category); **rankings** ("Rank #2 (Highest Rated Anime)", "Rank #788 (Most Popular Anime)", links to Explore lists); **Reactions** block (header + sort Best/New + "Write/Edit reaction" when in library; 6 cards; "More reactions"); **Feed** of posts about the title (composer "Post about {title}…", filter all/media/user).
5. Right column (desktop): **trailer** thumbnail (`youtubeVideoId`, opens modal); **Anime details** list: English / Japanese / romaji titles, synonyms (`abbreviatedTitles`), type (`subtype`), episodes (`episodeCount`), status, aired "Oct 1, 2023 to Mar 22, 2024", **season** (link to season browse), then "More info": age rating + guide, producers / licensors / studios (`animeProductions.role`), serialization (manga), duration "11 hours total (28 episodes, 24 minutes each)"; **Characters** (4 portraits, Japanese cast by default, `sort=-featured`); **More from this Series** (4 posters).
6. Tabs: **Episodes** = grid of 16:9 thumbnails ("Episode 1" + title, "Completed" overlay when `progress ≥ number`, poster fallback when no thumbnail), infinite scroll ([unit-grid.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/media/units/unit-grid.hbs)); **episode page** = thumbnail, number, title, length, air date, description, then the episode discussion feed ([units/show.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/units/show.hbs)); **Characters** = grid of character + voice actor, language dropdown from `/anime/{id}/_languages` ([characters.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/characters.hbs)); **Reactions** = full infinite list; **Franchise** = poster grid with title, "TV · 2023", role ("Sequel") and a status dropdown on each poster ([franchise.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/show/franchise.hbs)).

**Official app** — [MediaPages/index.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/index.tsx), [Summary](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Summary/component.tsx), [SceneHeader](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/SceneHeader/component.tsx), [MediaDetails](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/MediaDetails/component.tsx)
1. Parallax **cover** (masked top and bottom), fixed back header.
2. Header: poster, title, subtitle "TV · 2023 · 28 Eps"; main button = library status ("Add to library" → Watching / Want to watch / Completed / On hold / Dropped / Remove); "…" = Add to favourites, Share link, View cover image, View YouTube trailer.
3. Synopsis (4 lines, "view more"); **"KITSU SCORE 88%"** big, next to "★ Rank #2 (Rating)" and "♥ Rank #788 (Popularity)"; horizontal coloured **category pills** (tap → category results).
4. Tabs: Summary · Episodes (or Chapters) · Reactions · Franchise (Characters commented out).
5. Summary order: **Progress** card ("Progress · Watching", check circle, "Ep 5 of 28", progress bar, "Edit entry") → **streaming logos** → **Episodes** row (landscape cards "Ep. 3 of 28", only episodes that have videos) → **Details** (Studios, Episodes "28 (24 minutes each)", Status, Premiered, Age rating "PG-13 - Teens 13 or older", alternative titles, synonyms) → **Reactions** row (by upvotes) → **More from this series** row → **Posts** feed (10 per page, "Load more").
6. Episodes tab: numbered list "01 The Journey's End", a check circle per row that sets progress to that number, ascending/descending toggle ([Episodes](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Episodes/component.tsx)).
7. Franchise tab: list sorted by start date, subtitle "TV · Sequel · 2023".

**Kitsune** — [fragment_details.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/fragment_details.xml), [section_details_stats.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/section_details_stats.xml), [section_details_info.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/section_details_info.xml), [DetailsFragment.kt](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/details/DetailsFragment.kt)
1. Collapsing toolbar with the **cover**; actions: favourite heart (animated), Share, Open on kitsu.app.
2. Poster + title + "2002 • TV"; stats: "Kitsu Score 83.03%", "Rank #100", "Popularity #100", "Currently airing"; buttons **Add to library** / **Edit**.
3. Category chips → description (read more) → **Details** table (English, Japanese, romaji, synonyms, type, status, aired/published, season, TBA, age rating, serialization, chapters, volumes, episodes, length, producers, licensors, studios).
4. Three buttons: **Episodes** (or Chapters), **Characters**, **Posts**; trailer row.
5. **Reactions** (preview cards: avatar, user, "2 hours ago", text, upvote count; "+" to write; "See all").
6. **More from this series** row → **Streaming links** logo row → **Ratings** bar chart (from `ratingFrequencies`) with a rating-system menu and the recomputed average.
7. Episode tap → bottom sheet (thumbnail, title, "Episode 2", date, "23 minutes", description, **Posts** button = episode feed) ([sheet_media_unit_details.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/sheet_media_unit_details.xml)); episode rows have a thumbnail and a watched checkbox ([item_episode.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_episode.xml)).

**Kitsu's next UI (React)** confirms the direction: banner image with the poster overlapping, title from `titles.preferred` (follows the account's title-language setting), factoids "TV · 2023 · Finished · 28 episodes", tabs Summary · Episodes · Characters · **Staff** · Reactions · Franchise · **Quotes**, left column poster + library box (green "Completed", blue "Want to watch", purple "Watching"), main column description card + categories, right column top 6 reactions sorted by upvotes then date ([Anime/Banner](https://github.com/hummingbird-me/kitsu-web/blob/react/src/pages/Anime/Banner/index.tsx), [Anime/Summary](https://github.com/hummingbird-me/kitsu-web/blob/react/src/pages/Anime/Summary/index.tsx), [Media/LibraryBox](https://github.com/hummingbird-me/kitsu-web/blob/react/src/pages/Media/LibraryBox/index.tsx)).

### 2.2 Recommended MWL Kitsu title page

One scrolling page with a collapsing cover; sections hide when empty. GraphQL for the bulk (one call, ~5 KB per the report), JSON:API for `ratingFrequencies`, `popularityRank`/`ratingRank` and feeds.

| # | Block | Data (GraphQL `findAnimeById`/`findAnimeBySlug`, else JSON:API) |
|---|---|---|
| 1 | **Collapsing cover** (fallback: blurred poster); app bar actions: favourite heart, share, open on kitsu.app, "Open on MyAnimeList" only when a mapping exists | `bannerImage.original.url` (JSON:API `coverImage.original`, `coverImageTopOffset`); `favoritesCount`; `mappings{externalSite externalId}` |
| 2 | **Identity row**: poster overlapping the cover, title, factoids "TV · 2023 · Finished · 28 eps · 24 min" | `posterImage`, `titles{preferred canonical}` (use `preferred` when signed in), `subtype`, `startDate`, `status`, `episodeCount`/`chapterCount`, `episodeLength` |
| 3 | **Score strip**: big "88%" coloured by quartile, "★ #2 Highest rated", "♥ #788 Most popular", "21,409 users", "731 favourites"; each rank taps to the matching Explore list | `averageRating`, `averageRatingRank` (JSON:API `ratingRank`), `userCountRank` (`popularityRank`), `userCount`, `favoritesCount` |
| 4 | **Library box** (signed-in Kitsu account): status button; when current: "Ep 5 / 28" + progress bar + **+1**; rating in the user's Kitsu rating system; when completed: rating + "Write a reaction" + "Rewatch"; "Edit" opens the full sheet | GraphQL `myLibraryEntry{status progress rating reconsumeCount}` (token) or `/library-entries?filter[userId]&filter[animeId]&include=mediaReaction`; account `ratingSystem` |
| 5 | **Top reaction ticker** (one line under the box, rotates; tap = Reactions section) | `reactions(first:6, sort:[{on:UP_VOTES_COUNT,direction:DESCENDING}])` |
| 6 | **Where to watch**: logo chips, each with sub/dub flags, tap opens the URL | `streamingLinks(first:10){nodes{url subs dubs regions streamer{siteName}}}` |
| 7 | **Next episode** line when airing ("Ep 6 · Fri 15:00") | `nextRelease`, `episodes(last:1)` / `status` |
| 8 | **Synopsis** (4 lines, expand) + **category chips** (tap → Kitsu browse by category) | `description` (GraphQL map, take `en`) / `synopsis`; `categories(first:20){nodes{slug title}}` |
| 9 | **Trailer** thumbnail | `youtubeTrailerVideoId` |
| 10 | **Episodes** horizontal row of 16:9 thumbnails ("Ep 3 · title", watched tick when `progress ≥ number`), "See all" → episodes screen | `episodes(first:12){totalCount nodes{number titles{canonical} thumbnail{original{url}} releasedAt length}}`; manga: `chapters` (sparse) |
| 11 | **Rating distribution** bar chart, bucketed in the user's rating system, with the recomputed average | JSON:API `GET /anime/{id}?fields[anime]=ratingFrequencies` |
| 12 | **Reactions**: 3 cards (avatar, name, "at ep 2", relative time, text, ▲ count), sort Best/New, "Write" when in library, "See all" | `reactions(...){nodes{reaction progress createdAt author{name slug avatarImage} likes(first:1){totalCount}}}`; full list `/media-reactions?filter[animeId]&sort=-upVotesCount|-createdAt&include=user` |
| 13 | **Franchise** poster row with role label ("Sequel", "Adaptation · Manga"), sorted by start date, "See all" | `relationships(first:20){nodes{kind destination{__typename slug titles posterImage startDate subtype}}}` |
| 14 | **Details** table, collapsed after 6 rows: alt titles, synonyms, type, status, aired, season (link), age rating + guide, studios / producers / licensors, total length, origin country/language | `titles{alternatives localized}`, `ageRating`, `ageRatingGuide`, `season`, `productions(first:10){nodes{role company{name}}}`, `totalLength`, `originCountries`, `originLanguages` |
| 15 | **Characters** (hidden when empty, Japanese VA by default) | `characters(first:10, sort:[{on:ROLE,direction:ASCENDING}]){nodes{role character{names image} voices(first:1, locale:"ja_jp")}}` |
| 16 | **Discussion**: 3 latest posts (spoiler/NSFW gated, likes, comment count), "See all" → title feed (already built by `kitsu-community`) | `posts(first:3, sort:[{on:CREATED_AT,direction:DESCENDING}])` or `/feeds/media_aggr/Anime-{id}?filter[kind]=posts` |

**Episodes screen** (from block 10): list, each row = thumbnail 16:9, "Episode 3", title, air date, length, watched checkbox that sets `progress` (confirm when going backwards); sort toggle; tap → bottom sheet with description and "Discussion" (episode feed `feeds/episode_aggr/{episodeId}`). Models: [APP Episodes](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/MediaPages/pages/Episodes/component.tsx), [KTN item_episode.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_episode.xml).

What to drop compared with the MAL page: MAL statistics (watching/completed counts per title), MAL recommendations, MAL reviews, MAL forum topics, "score 8.85 / 10" display. Use Kitsu's percentage and its two ranks instead.

---

## 3. User library (My List)

### 3.1 What Kitsu shows

**Web** — [users/library.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/users/library.hbs), [library-sidebar.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/library/library-sidebar.hbs), [library-grid/library-entry.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/library/library-grid/library-entry.hbs), [library-list.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/library/library-list.hbs), [library-sorting.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/users/library/library-sorting.js)
- Search box; **grid / list** toggle; sort: watched (last progressed), started, finished, added, progress, rating, title, length, with a direction arrow.
- Sidebar: anime/manga switch; **All / Currently watching / Want to watch / Completed / On hold / Dropped, each with its count** (`meta.statusCounts`); Manage: import, export, reset; an "issues" card that nudges the user to write reactions for completed titles without one ("Fix", modal with a skip button).
- **Grid card**: poster; hover overlay = *your reaction text* (or "Add reaction") + "Edit"; thin progress bar at the poster's bottom; under it "Ep 5" or "Not started" and the rating (stars, or simple face icon) tappable to change.
- **List row**: status colour stripe, bulk-select checkbox, tiny poster + title + reaction icon, rating, progress cell (+1), volumes for manga, edit.
- Edit modal: status, progress, volumes, rating, rewatch count + "Start rewatch", started, finished, notes, private, remove.

**Official app** — [ProfilePages/pages/Library](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/ProfilePages/pages/Library/component.tsx), [UserLibraryListCard](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/UserLibrary/components/UserLibraryListCard/component.tsx)
- Overview: one horizontal row per status (Watching, Want to watch, Completed, On hold, Dropped), empty message "You haven't marked any anime as … yet!".
- Status list card: poster 65×75, title, "…" status menu, progress bar, **counter** (− value +, capped at the episode count), **rating** control in the account's rating system; swipe left = "Edit entry"; a "Moved to Completed" banner on the card after a status change.

**Kitsune** — [fragment_library.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/fragment_library.xml), [item_library_entry.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_library_entry.xml)
- Chip row: kind (All/Anime/Manga) + status chips (Watching, Planned, Completed, On hold, Dropped); list grouped by status separators; pull to refresh; offline cache with a "not synchronized" label on pending rows; menu: sync, search, database request.
- Row: poster, title, "2002 • TV", rating button (shows the rating, opens a rating sheet), "12/24" or "Not started", **−1 / +1** buttons, progress bar. Home screen widget for the library.

**Nekome** — row: poster, title, "TV 2002-10-03", progress "5 / 24", **+1** icon; reaching the last episode opens a **rating dialog** before completing (`IncrementSeriesWithRating`); filter by status, sort Default / Title / Start date / End date / Rating ([CollectionScreen.kt](https://github.com/Chesire/Nekome/blob/master/features/series/src/main/java/com/chesire/nekome/app/series/collection/ui/CollectionScreen.kt), [SortOption.kt](https://github.com/Chesire/Nekome/blob/master/core/preferences/src/main/java/com/chesire/nekome/core/preferences/flags/SortOption.kt)).

### 3.2 Recommended MWL Kitsu library

Keep MWL's My List shell (memory rule: grid cards copy DailyAL, rest of My List stays MWL), but the Kitsu adapter should fill it with Kitsu data:

| # | Block | Data |
|---|---|---|
| 1 | Anime / Manga switch | `filter[kind]=anime|manga` |
| 2 | **Status tabs with counts**: Watching / Want to watch / Completed / On hold / Dropped (Kitsu wording: "Want to watch", not "Plan to watch"; manga: Reading / Want to read) | `GET /library-entries?filter[userId]&filter[kind]&page[limit]=1` → `meta.statusCounts` (one call for all five counts) |
| 3 | Sort menu: last progressed, last added, started, finished, title, rating, progress, length; direction toggle | `sort=-progressedAt`, `-createdAt`, `startedAt`, `finishedAt`, `rating`, `progress`; title and length client-side or `sort=anime.titles.canonical` |
| 4 | **Card / row**: poster, title (user's title language), "TV · 2023", progress "5 / 28" + bar, **+1**, the user's rating rendered in their Kitsu system (face for Simple, stars for Regular, "7.5" for Advanced); a small "reaction" glyph when the entry has one | `progress`, `media.episodeCount`, `ratingTwenty`, account `ratingSystem`, `include=media,mediaReaction` |
| 5 | Optional community badge on the card: "88%" | `media.averageRating` (already in the include) |
| 6 | **+1 reaching the last episode**: sheet "Completed? Rate it" (rating control + optional 140-char reaction) — Kitsu's own nudge, and Nekome's flow | `PATCH /library-entries/{id}` (`status: completed`, `ratingTwenty`), `POST /media-reactions` |
| 7 | **Edit sheet**: status, progress, volumes (manga), rating, rewatch count + "Start rewatch" (sets `reconsuming`, progress 0), started, finished, notes, private, remove | `status progress volumesOwned ratingTwenty reconsumeCount reconsuming startedAt finishedAt notes private` |
| 8 | Overflow: import/export links open kitsu.app settings (no API) | `https://kitsu.app/settings/imports` |

---

## 4. Profile

### 4.1 What Kitsu shows

**Web** — [users.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/users.hbs), [users/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/users/index.hbs), [about-me.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/about-me.hbs), [user-stats.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/user-stats.hbs), [category-breakdown-graph.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/stats/category-breakdown-graph.hbs), [user-favorites.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/users/user-favorites.hbs)
1. **Cover** (`coverImage`) with large round avatar, name + badge (PRO/staff `title`), Follow button (or Edit profile), "…" (block, report); **profile link badges** (Discord, Twitter, MAL… from `profileLinks`/`siteLinks`).
2. Tabs: Activity · Library · Reviews (legacy, only if `reviewsCount > 0`) · **Reactions (count)** · **Followers (count)** · **Following (count)** · Groups.
3. Activity tab: left = unread groups; centre = **user feed** (`feeds/user_aggr/{id}`) with the **pinned post** first and a composer "Post to {user}"; right = **About me** (about text, waifu/husbando with image, gender, location, birthday, "Joined March 2017, 9 years ago"), **Anime stats / Manga stats** (category donut with the top category % in the centre + legend of up to N categories with bars; badge icon + "5.3 days spent watching anime." + "510 completed. More than 38% of users." + tooltip "8 months, 3 days, 5 hours"), **Favourites** (Anime / Manga tabs of posters, then Characters).

**Official app** — [ProfilePages/index.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/ProfilePages/index.tsx), [Summary.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/ProfilePages/pages/Summary.tsx), [About](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/ProfilePages/pages/About/component.tsx), [UserStats](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Profiles/components/UserStats/component.tsx)
- Parallax cover, avatar, name, about text, "53 Following · 94 Followers".
- Tabs: Summary · Feed · About · Library · Groups · Reactions.
- Summary: **Library activity** row (poster + caption "Watched ep. 5" / "Completed" / the rating stars) from `/library-events?filter[userId]&sort=-createdAt&include=libraryEntry.media` → **Reactions** row (boxed cards) → **Anime stats** and **Manga stats** (donut + time spent + percentile).
- About: Gender, Location, Birthday, Joined, Waifu/Husbando card. Groups: memberships `group-members?filter[query_user]&include=group.category`.

**Kitsune** — [fragment_profile.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/fragment_profile.xml), [fragment_profile_about.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/fragment_profile_about.xml), [item_profile_stats.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_profile_stats.xml)
- Collapsing cover + avatar; tabs **About · Posts**; FAB "post on wall".
- About: user title ("Moderator"), "12 Following" / "39 Followers" buttons (lists), Follow button, About me, waifu row, **profile link chips**, **stats** pager Anime/Manga (pie chart with tapped-slice tooltip "Action 42%", "5.3 days spent watching anime.", "5 days, 7 hours, 34 minutes in total", "24 completed. More than 38% of users."), Favourite anime / manga / characters rows.

### 4.2 Recommended MWL Kitsu profile

| # | Block | Data |
|---|---|---|
| 1 | **Cover** + avatar + name + PRO/title badge; Follow / Edit on kitsu.app | GraphQL `findProfileBySlug{bannerImage avatarImage name proTier}`; JSON:API users `coverImage avatar title proTier` |
| 2 | Counters row (tappable): Following · Followers · Reactions · Posts · Library | `followingCount followersCount mediaReactionsCount postsCount` + `meta.count` of the library; GraphQL `followers(first:20){totalCount}` |
| 3 | **About** card (collapsed to 3 lines): about text, waifu/husbando thumbnail + label, location, birthday, gender, joined date, **link chips** | `about waifu{names image} waifuOrHusbando location birthday gender createdAt siteLinks(first:10){nodes{url site{name}}}` |
| 4 | **Anime stats card**: "5.3 days" headline (largest unit), full breakdown on tap, "510 completed", "more than 38% of users", category donut (top 6 + other, names from `/categories`) | `stats` kinds `anime-amount-consumed` (`time` s, `completed`, `media`, `units`, `percentiles.time`), `anime-category-breakdown` (`categories`, `total`); GraphQL `stats{animeAmountConsumed{time completed media units} animeCategoryBreakdown{total categories}}` |
| 5 | **Manga stats card** (chapters read, percentile on units) | `manga-amount-consumed`, `manga-category-breakdown` |
| 6 | **Recent activity** row: poster + "Ep 5", "Completed", or the rating, newest first | `libraryEvents(first:20, sort:[{on:CREATED_AT,direction:DESCENDING}]){nodes{kind changedData createdAt media{...}}}` |
| 7 | **Favourites**: chips Anime / Manga / Characters / People, poster or portrait grid | `/favorites?filter[userId]&filter[itemType]=Anime|Manga|Character|Person&include=item` |
| 8 | Tabs below (or sub-pages): **Posts** (user feed with pinned post), **Reactions** (cards with the media poster), **Library** (for other users: their public library), **Groups**, **Followers / Following** | `feeds/user_aggr/{id}` + `pinnedPost`; `/media-reactions?filter[userId]&include=anime,manga`; GraphQL `library{current(first:20,mediaType:ANIME)}`; `/group-members?filter[query_user]`; `/follows?filter[follower]|[followed]` |

---

## 5. Home / Explore

### 5.1 What Kitsu shows

**Web Explore** — [explore/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/explore/index.hbs), [explore-section.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/explore/explore-section.hbs), [explore/category/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/explore/category/index.hbs)
- Order: search → **Trending this week** (`/trending/anime`) → **Top airing** (`sort=-user_count`, `filter[status]=current`) → **Top upcoming** (`status=upcoming`) → **two random rows from the user's favourite categories** (trending in category) → **Highest rated** (`-average_rating`) → **Most popular** (`-user_count`). Each row = posters with a quick status dropdown on hover, "View more". Sidebar: category tree.
- Category page: category name + description + "favourite category" button; rows Newly released (`-start_date`, current), Trending in category (`/trending/anime?in_category=true&category=`), Most popular; related categories.

**Web Dashboard (home when signed in)** — [dashboard.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/dashboard.hbs), [quick-update.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/dashboard/quick-update.hbs), [quick-update/item.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/dashboard/quick-update/item.hbs)
- **Quick update** carousel at the top: current entries (filter dropdown anime/manga/all), each card = next episode thumbnail, title, progress bar, a text box "Write a post about Episode 6…", **"✓ Episode 6"** button (or "Complete" on the last), link to the **episode discussion**, edit icon; completed cards turn into a rating box; empty cards invite to Explore.
- Below: feed switch **👀 Following / 🌎 Global** (old flags also 📺 Anime / 📙 Manga interest feeds), groups with unread posts, site announcements.

**Official app** — Quick Update screen (same idea: episode landscape image, title, progress bar, mark watched, post about the episode, [QuickUpdateCard](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/QuickUpdateScreen/QuickUpdateCard/component.tsx)); Search home ([TopsList](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Search/Lists/TopsList/index.tsx)): Top airing, Top upcoming, Highest rated, Most popular, **Anime by season** (illustrated season tiles for the past 2 years + next season), **by streaming service**, **by category** (8 illustrated tiles: Action, Adventure, Comedy, Slice of life, Fantasy, Romance, Sci-fi, Sports).

**Kitsune** — Home = Explore with Anime / Manga tabs, five rows (Trending, Top airing, Top upcoming, Highest rated, Most popular), each header taps to a full list ([HomeExploreFragment.kt](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/main/HomeExploreFragment.kt), [section_main_explore.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/section_main_explore.xml)).

### 5.2 Recommended MWL Kitsu home

| # | Block | Data |
|---|---|---|
| 1 | **Continue watching** (Kitsu quick update): cards with the **next episode thumbnail** and title, "Ep 6 / 28" bar, **✓ Ep 6** button (Complete + rate on the last), tap on the thumbnail → episode discussion | `/library-entries?filter[userId]&filter[status]=current&sort=-progressedAt&include=media` + `/episodes?filter[mediaId]&filter[number]=progress+1` (or GraphQL `episodes` on each media) |
| 2 | **Kitsu News** (group 596 feed, 3 posts) | `GET /feeds/group/596?include=subject,subject.user&page[limit]=3` (report B2) |
| 3 | **Trending this week** | `GET /trending/anime?limit=20` (GraphQL alternative: `globalTrending(mediaType:ANIME, first:20)`) |
| 4 | **Airing now, most followed** | `/anime?filter[status]=current&sort=-userCount` |
| 5 | **Popular with people you follow** (signed in) | GraphQL `localTrending(mediaType:ANIME, first:20)` (token) |
| 6 | **Trending in your favourite categories** (2 rows, random) | `/category-favorites?filter[userId]&include=category` then `/trending/anime?in_category=true&category={id}` |
| 7 | **Upcoming** | `filter[status]=upcoming&sort=-userCount` |
| 8 | **Highest rated** / **Most popular** | `sort=-averageRating`, `sort=-userCount` |
| 9 | **Recent reactions** (horizontal cards: poster + reaction + ▲) | `/media-reactions?sort=-createdAt&include=user,anime&page[limit]=10` |
| 10 | "Surprise me" chip | GraphQL `randomMedia(mediaType:ANIME, ageRatings:[G,PG,R])` |

Poster cards on Kitsu rows show the poster only (no score); MWL may add the "88%" in a corner but should keep it small.

---

## 6. Search and filters

### 6.1 What Kitsu shows

- **Web browse** ([media/index.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/media/index.hbs), [controllers/media/index.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/controllers/media/index.js), [translations](https://github.com/hummingbird-me/kitsu-web/blob/the-future/translations/en-AU.yaml)): year **range slider** (to ∞), **average rating range slider** in %, episodes/chapters range, seasons, **Streamers (U.S.)**, age rating, types (subtype), categories (tree with multi-select); sort Popularity / Average rating / Date / Recently added; text search disables the sort.
- **Official app search**: Algolia with three tabs **Anime · Manga · Users** (keys from `/algolia-keys`) ([SearchScreen](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Search/SearchScreen/index.tsx)); empty query shows the TopsList (season tiles, streamers, categories).
- **Kitsune search** ([fragment_search.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/fragment_search.xml), [SearchViewModel.kt](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/search/SearchViewModel.kt), [FacetFragment.kt](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/ui/search/filter/FacetFragment.kt)): toggle **Media / Users**; Algolia facets **kind, year (range), averageRating (range), season, subtype, streamers, ageRating, categories** with counts per value; sort popularity / average rating / release date, asc or desc ([KitsuJsonApi.kt](https://github.com/Drumber/Kitsune/blob/master/app/src/main/java/io/github/drumber/kitsune/config/KitsuJsonApi.kt)).

### 6.2 Recommended MWL Kitsu search

| # | Block | Data |
|---|---|---|
| 1 | Search field + segmented **Anime · Manga · Users** | GraphQL `searchAnimeByTitle` / `searchMangaByTitle` / `searchProfileByUsername(username, first:20)` |
| 2 | Empty state = **browse home**: season tiles (current, next, last 6), streamer logos, category tiles | `filter[season]&filter[seasonYear]`; `filter[streamers]=Crunchyroll`; `/categories?sort=-totalMediaCount` |
| 3 | **Filter sheet**: year range, **average rating range in %**, episode count range, season, type (TV, Movie, OVA, ONA, Special, Music), status, age rating (G, PG, R, R18), **streamer**, categories (multi) | JSON:API `filter[seasonYear]=2020..2024`, `filter[averageRating]=70..`, `filter[episodeCount]=1..13`, `filter[season]`, `filter[subtype]`, `filter[status]`, `filter[ageRating]`, `filter[streamers]`, `filter[categories]=fantasy,elf` |
| 4 | Sort: Popularity, Average rating, Start date, Recently added | `sort=-userCount`, `-averageRating`, `-startDate`, `-createdAt` |
| 5 | Result row: poster, title, "TV · 2023 · 28 eps", "88%", "#2" rank, quick add | `averageRating`, `ratingRank`, `subtype`, `startDate`, `episodeCount` |

---

## 7. Feed, posts and groups (Forum tab)

### 7.1 What Kitsu shows

- **Web feed** ([stream-feed/list.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/stream-feed/list.hbs), [list.js](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/components/stream-feed/list.js)): composer, "N new activities" banner, filter **All / Media / User / Followed activity**, pinned post, items of four kinds: **post**, **media reaction** (poster + title + reaction + author + ▲, [items/media-reaction.hbs](https://github.com/hummingbird-me/kitsu-web/blob/the-future/app/templates/components/stream-feed/items/media-reaction.hbs)), **library update** ("moved this to Completed", "rated it"), **follow**. Posts: spoiler / NSFW gates ("Spoilers for Episode 5 of X — click to view"), media tag, embeds, image grid, likes with likers, comments with replies, menu (pin, edit, delete, report, hide posts from this user/title/group).
- **Official app**: Feed tabs **Following / Global**, post cards with likes (first 4 likers' avatars), latest 2 comments, comment box ([feedStreams.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Feed/feedStreams.tsx), [Post](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/screens/Feed/components/Post/component.tsx)).
- **Kitsune**: tabs Global / Following, FAB create post; post card = pinned label, avatar, author, time, overflow, **content-warning card** (spoiler/NSFW, tap to view), text with "read more", image with "+3", embed, **media tag** card, like count + liker avatars "+5", comment count ([item_post.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_post.xml)).
- **Groups**: web groups directory with categories, sort, group page (feed, rules, members, leaders); official app profile Groups tab.

### 7.2 Recommended MWL Kitsu Forum tab

Already delivered by `kitsu-community` (Latest, News, Groups, post threads). Gaps to close, in priority order:
1. Feed item kinds beyond posts: **media reaction** cards and **library update** lines (verbs `media_reaction`, `updated`, `rated`, `progressed`) from the same `feeds/global/global` activities.
2. **Following** tab for the signed-in user: `feeds/timeline/{userId}` (token), plus filter All / Media / User.
3. Post card fields: spoiler gate naming the unit (`spoiledUnit.number`), media tag (`media`), liker avatars (`/post-likes?filter[postId]&include=user&page[limit]=4`), comment count, pinned label.

---

## 8. Notifications

### 8.1 What Kitsu shows

- Feed `GET /feeds/notifications/{userId}` (grouped activities), mark `POST …/_seen` and `…/_read` ([APP store/feed/actions.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/store/feed/actions.tsx)).
- Verbs and texts ([APP utils/notifications.tsx](https://github.com/hummingbird-me/kitsu-mobile/blob/develop/src/utils/notifications.tsx)): `follow` "followed you", `post` "mentioned you in a post", `post_like` "liked your post", `comment_like` "liked your comment", `invited` "invited you to a group", `vote` "liked your reaction", **`aired` "Episode 5 of Frieren aired." / "Chapter 120 of X released."** (actor = the media, avatar = its poster), `comment` "replied to your post / comment", "mentioned you in a comment"; grouped as "Alice and 3 others liked your post".
- Web settings expose the same families: mentions, replies, likes, follows, posts on my profile, reaction upvotes ([translations](https://github.com/hummingbird-me/kitsu-web/blob/the-future/translations/en-AU.yaml)).
- Kitsune row: unread dot, avatar, summary "Username started following you", excerpt of the related post, relative time ([item_notification.xml](https://github.com/Drumber/Kitsune/blob/master/app/src/main/res/layout/item_notification.xml)).

### 8.2 Recommended MWL Kitsu notifications

| # | Block | Data |
|---|---|---|
| 1 | Filter chips: All · Airing · Social | client-side on `activities[].verb` |
| 2 | Row: unread dot, avatar (user) or poster (airing), "Alice and 3 others liked your post", excerpt, relative time; tap → post / profile / title / episode | `/feeds/notifications/{userId}?include=actor,target,subject` (token); `isRead`, `isSeen` on groups |
| 3 | On open: `_seen`; on tap or "mark all": `_read` | `POST /feeds/notifications/{userId}/_seen`, `/_read` |
| 4 | The **aired** verb can feed MWL's own airing notifications for Kitsu accounts (no schedule endpoint exists otherwise) | verb `aired`, `subject.number`, `actor.canonicalTitle` |

---

## 9. Data mapping cheat sheet (field → UI)

| UI element | JSON:API (`/api/edge`) | GraphQL (`/api/graphql`) |
|---|---|---|
| Score % | `averageRating` | `averageRating` |
| Rank (rating) / (popularity) | `ratingRank` / `popularityRank` | `averageRatingRank` / `userCountRank` |
| Users / favourites | `userCount` / `favoritesCount` | same |
| Rating histogram | `ratingFrequencies` | — (not exposed) |
| Cover / poster | `coverImage` / `posterImage` | `bannerImage` / `posterImage` |
| Title in user's language | `titles` + account `titleLanguagePreference` | `titles{preferred canonical localized}` |
| Trailer | `youtubeVideoId` | `youtubeTrailerVideoId` |
| Next episode | `nextRelease` | `nextRelease` |
| Season | derived from `startDate` | `season` |
| Streaming | `/anime/{id}/streaming-links?include=streamer` | `streamingLinks` |
| Episodes | `/episodes?filter[mediaId]&sort=number` | `episodes` |
| Franchise | `/media-relationships?...&include=destination` (`role`) | `relationships` (`kind`) |
| Reactions | `/media-reactions?filter[animeId]&include=user` | `reactions` |
| Title posts | `/feeds/media_aggr/Anime-{id}` | `posts` |
| Episode posts | `/feeds/episode_aggr/{episodeId}` | — |
| My entry | `/library-entries?filter[userId]&filter[animeId]` | `myLibraryEntry` (token) |
| Status counts | `meta.statusCounts` | `library{current{totalCount}}…` |
| Profile stats | `/users/{id}?include=stats` | `stats{…}` |
| Library events | `/library-events?filter[userId]` | `libraryEvents` |
| Notifications | `/feeds/notifications/{userId}` | — (no `Notification` type) |
| Groups | `/groups`, `/feeds/group/{id}` | — (no `Group` type) |

GraphQL type field lists checked by introspection today: `Anime` has `ageRating ageRatingGuide averageRating averageRatingRank bannerImage categories characters description endDate episodeCount episodeLength episodes favoritesCount mappings myLibraryEntry nextRelease originCountries originLanguages posterImage posts productions quotes reactions relationships season sfw slug staff startDate status streamingLinks subtype tba titles totalLength userCount userCountRank youtubeTrailerVideoId`; `Profile` has `about avatarImage bannerImage birthday comments favorites followers following gender library libraryEvents location mediaReactions name pinnedPost posts proTier siteLinks slug stats waifu waifuOrHusbando`; `Episode` has `description length number releasedAt thumbnail titles`; `MediaReaction` has `author hasLiked likes media progress reaction`; `Post` has `author comments content contentFormatted isNsfw isSpoiler likes media targetProfile`. `Notification` and `Group` do not exist in GraphQL.

---

## 10. Design rules distilled

1. **Lead with Kitsu's identity**: cover image on title and profile pages, percentage score, the two ranks, coloured category chips, reactions. Never show a "/10" community score.
2. **Reactions are Kitsu's reviews**: surface one on the title page above the fold (ticker), a block of 3 on the page, and your own reaction on your library card.
3. **Where to watch sits high** (app: right after progress; web: under the poster).
4. **Episodes are visual** (16:9 thumbnails with a watched tick) and lead to an **episode discussion**.
5. **Respect the user's Kitsu settings**: rating system (Simple / Regular / Advanced) for every rating read-out and control, title language for every title (`titles.preferred`).
6. **Hide empty sections** (characters, staff, quotes, chapters are often empty).
7. **Library = progress first**: +1 everywhere, completion asks for a rating and a reaction, status counts come from `meta.statusCounts`.
8. **Social is first-class**: profile counters are tappable, the feed mixes posts, reactions and library updates, notifications include airing.


---

# Simkl UI reference for MyWatchList (MWL)

Research date: 2026-10-29. Read-only on the repo. Rule this serves: each tracker is like a separate app, so Simkl screens come from Simkl's own data and from the best Simkl clients, not from MAL's DailyAL-style UI.

How the sources were gathered:
- **simkl.com pages**: fetched anonymously with curl, using a desktop UA, about one request a second. The title, episode, hub, airing, calendar, premieres, best and apps pages answered 200. Profile and user pages could not be fetched: the earlier MWL audit got Cloudflare 403s on them ([docs/kitsu-simkl-report-2026-10-28.md](/home/thinkpad/Bureau/android-project/mywatchlist/docs/kitsu-simkl-report-2026-10-28.md), section 2.1). Logged-in screens (My List, profile, calendar of my shows) were therefore not seen directly. They are described from the API docs and from client store listings.
- **API fields**: taken from the new docs at [api.simkl.org](https://api.simkl.org/llms.txt).
- **Third-party clients**: taken from Google Play and App Store listings, and from the AnymeX source on GitHub.

Short source keys used below:

| Key | URL |
|---|---|
| WEB-TITLE | https://simkl.com/anime/1990194/sousou-no-frieren |
| WEB-EP | https://simkl.com/anime/1990194/sousou-no-frieren/episode-1/ |
| WEB-HUB | https://simkl.com/anime/ |
| WEB-AIRING | https://simkl.com/anime/airing/ |
| WEB-CAL | https://simkl.com/anime/calendar/ |
| WEB-PREM | https://simkl.com/anime/premieres/ |
| WEB-BEST | https://simkl.com/anime/best-anime/ |
| WEB-APPS | https://simkl.com/apps/ |
| API-ANIME | https://api.simkl.org/api-reference/simkl/get-anime.md |
| API-EPS | https://api.simkl.org/api-reference/simkl/get-anime-episodes.md |
| API-IMG | https://api.simkl.org/conventions/images.md |
| API-ANIMEGUIDE | https://api.simkl.org/guides/anime.md |
| API-ALLITEMS | https://api.simkl.org/api-reference/simkl/get-all-items.md |
| API-STATS | https://api.simkl.org/api-reference/simkl/get-user-stats.md |
| API-SETTINGS | https://api.simkl.org/api-reference/simkl/get-user-settings.md |
| API-BG | https://api.simkl.org/api-reference/simkl/get-recently-watched-image.md |
| API-CAL | https://api.simkl.org/api-reference/calendar.md |
| API-TREND | https://api.simkl.org/api-reference/trending.md |
| API-AIRING | https://api.simkl.org/api-reference/simkl/get-anime-airing.md |
| API-PREM | https://api.simkl.org/api-reference/simkl/get-anime-premieres.md |
| API-BEST | https://api.simkl.org/api-reference/simkl/get-best-anime.md |
| API-GENRES | https://api.simkl.org/api-reference/simkl/get-anime-genres.md |
| API-SEARCH | https://api.simkl.org/api-reference/simkl/search-by-text.md |
| API-RATINGS | https://api.simkl.org/api-reference/simkl/get-watchlist-ratings.md |
| API-PLAYBACK | https://api.simkl.org/api-reference/playback.md |
| API-CHECKIN | https://api.simkl.org/api-reference/simkl/scrobble-checkin.md |
| DOC-LISTS | https://docs.simkl.org/how-to-use-simkl/core-features/watchlists-and-custom-lists.md |
| DOC-RECO | https://docs.simkl.org/how-to-use-simkl/core-features/search-and-discovery/recommendations.md |
| PLAY-LISTS | https://play.google.com/store/apps/details?id=com.simkl.lists (official "Simkl Lists") |
| PLAY-CINOPSYS | https://play.google.com/store/apps/details?id=com.cinopsys.movieshows |
| PLAY-JA | https://play.google.com/store/apps/details?id=com.jonathanantoine.simkl ("Anime & TV Series for Simkl") |
| PLAY-WAKO | https://play.google.com/store/apps/details?id=app.wako |
| PLAY-CINEMATIQUE | https://play.google.com/store/apps/details?id=com.arctco.cinematique |
| IOS-SCAENA | https://apps.apple.com/us/app/scaena-tv-movie-tracker/id6787125515 |
| GH-ANYMEX | https://github.com/RyanYuuki/AnymeX/blob/main/lib/controllers/services/simkl/simkl_service.dart |
| MWL-REPORT | /home/thinkpad/Bureau/android-project/mywatchlist/docs/kitsu-simkl-report-2026-10-28.md |

---

## 0. The Simkl app landscape (what to learn from whom)

| Client | Platform | What is worth taking | Source |
|---|---|---|---|
| **simkl.com** (server-rendered site, installable as a PWA; a "Simkl, Beta V2" PWA is listed) | web | The reference for the title page, episode page, airing/calendar/premieres and best-of. It is the only "full" official UI. | [WEB-APPS](https://simkl.com/apps/), [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren) |
| **Simkl Lists** (official) | Android, iOS, web | A deliberately minimal companion: watch lists, **"next episode number you need to watch"**, **"what's airing next on your watchlist"**, a poster-hiding option for slow connections, dark and light themes. Its listing points to the site for "Advanced Profile statistics & charts", "Compare your watchlists with friends", the "full TV Show calendar" and reviews. | [PLAY-LISTS](https://play.google.com/store/apps/details?id=com.simkl.lists) |
| **Anime & TV Series for Simkl** (J. Antoine) | Android | An episode calendar with notifications, "which episodes you haven't watched yet", the network/channel of each series, full episode lists, "a visual overview" of progress, and offline access to the list. | [PLAY-JA](https://play.google.com/store/apps/details?id=com.jonathanantoine.simkl) |
| **Cinopsys** | Android | "Up Next" for every followed show, "Check in to what you are watching right now", a personal calendar with **premiere and finale tags**, anime calendar and anime progress widgets, stats (hours, top genres, rating breakdown, streaks, "On this day", month in review), reorderable score chips. Its Simkl sync adds an **anime tab**. | [PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows) |
| **Scaena** | iOS | Home modules (Continue Watching, Recently Aired, Upcoming, Trending, Recently Watched, Plan to Watch); "Today" badges with exact broadcast times; premiere and finale badges; list filters on **Simkl and IMDb ratings**; watchlist sorting by recently aired, alphabetical, release year and watch progress; "live audience counts" in Explore. | [IOS-SCAENA](https://apps.apple.com/us/app/scaena-tv-movie-tracker/id6787125515) |
| **wako** | Android, iOS | A customizable home of trending, popular and personal rows, a calendar of upcoming episodes, and where to watch by country (from TMDb, not Simkl). | [PLAY-WAKO](https://play.google.com/store/apps/details?id=app.wako) |
| **cinematique** | Android | Stats and streaks; a separate anime section. Its anime sync goes through AniList/MAL, not Simkl. | [PLAY-CINEMATIQUE](https://play.google.com/store/apps/details?id=com.arctco.cinematique) |
| **AnymeX** (open source, Flutter, about 1.3k stars) | Android, desktop | **Counter-example.** It uses Simkl only for movies and series, with generic carousels ("Trending Movies", "K-Dramas"…). Its profile maps Simkl stats onto AniList-shaped "anime/manga count" fields (`stats['movies']['completed']['count']` shown as the anime count). This is exactly the "copy another tracker's UI" trap the owner wants to avoid. | [GH-ANYMEX](https://github.com/RyanYuuki/AnymeX/blob/main/lib/controllers/services/simkl/simkl_service.dart) |

Common pattern in the good Simkl clients: they are **progress- and schedule-first** ("next episode", "airing next", "up next", calendar, premiere/finale badges, check-in), not catalogue-first. Simkl's own tagline says the same: it "tells you how many episodes you've missed, recommends what to watch next" ([WEB-APPS](https://simkl.com/apps/)).

---

## 1. What Simkl gives that MAL does not (design levers)

| Lever | Simkl data | MAL equivalent | Source |
|---|---|---|---|
| **Fanart** (16:9 backdrop) | `fanart` path; sizes `_medium` 1920×1080, `_mobile` 960×540, `_w` 600×338, `_s48` 48×27 blur placeholder; no placeholder exists, so hide the element when null | none (poster only) | [API-IMG](https://api.simkl.org/conventions/images.md) |
| **Episode stills + synopsis + exact air time** | `img`, `description`, `date` (ISO with offset), `runtime`, `aired`, `type` episode/special | MAL has episode titles only, no stills | [API-EPS](https://api.simkl.org/api-reference/simkl/get-anime-episodes.md) |
| **Several rating sources in one record** | `ratings.simkl{rating,votes}`, `ratings.mal{rating,votes}`, `ratings.imdb` when on file; watchlist ratings add `mal.rank` | MAL score only | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md), [API-RATINGS](https://api.simkl.org/api-reference/simkl/get-watchlist-ratings.md) |
| **Rank + drop rate** | `rank`, `droprate` ("1.7%") | rank/popularity, no drop rate | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md), [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren) |
| **Live audience counts** | CDN `watching`, `plan_to_watch`, `completed`, `watched`; the site adds On Hold / Dropped with % | MAL member counts by status (Jikan) | [API-CAL](https://api.simkl.org/api-reference/calendar.md), [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren) |
| **Air schedule with time zone** | `airs{day,time,timezone}`, calendar `date` in UTC, `finale_type` 1 mid-season / 2 season / 3 series | MAL broadcast string, no finale flag | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md), [API-CAL](https://api.simkl.org/api-reference/calendar.md) |
| **Trailers** | `trailers[]{name,youtube,size,type}` (trailer, teaser, clip, opening_credits…); CDN `trailer` YouTube id | one promo video | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md) |
| **Watch time** | `/users/{id}/stats`: `total_mins`, per-status `left_to_watch_mins`, `left_to_watch_episodes`, `watched_last_week.anime_mins` | MAL gives days watched only | [API-STATS](https://api.simkl.org/api-reference/simkl/get-user-stats.md) |
| **Next episode per entry** | `next_to_watch` ("S08E03"), `next_to_watch_info{title,episode,date}`, `last_watched`, `not_aired_episodes_count` | none | [API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md) |
| **Playback / check-in / scrobble** | `/sync/playback` (`progress` %, `paused_at`, episode); `/scrobble/checkin` marks the item watched when the runtime has elapsed | none | [API-PLAYBACK](https://api.simkl.org/api-reference/playback.md), [API-CHECKIN](https://api.simkl.org/api-reference/simkl/scrobble-checkin.md) |
| **Anime ↔ TV mapping** | `mapped_tvdb_seasons`, per-episode `tvdb{season,episode}`, `ids.tvdb/tmdb/imdb` next to `mal/anilist/kitsu/anidb` | none | [API-ANIMEGUIDE](https://api.simkl.org/guides/anime.md) |
| **Recommendations with a "% of users" figure** | `users_recommendations[]{users_percent,users_count,…}` | MAL user recs (count only) | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md) |
| **Title-language preference from the account** | `account.anime_title_language` (`en`/`romaji`/`native`), `account.timezone` | none | [API-SETTINGS](https://api.simkl.org/api-reference/simkl/get-user-settings.md) |
| **Memos** (public one-line notes) and reviews with 5 sub-scores | site only (scraped) | MAL reviews | [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren), [MWL-REPORT](/home/thinkpad/Bureau/android-project/mywatchlist/docs/kitsu-simkl-report-2026-10-28.md) §S-C |

What Simkl does **not** have, so do not leave empty MAL-shaped holes:
- No manga.
- No characters or staff in the API. The site has a "Cast & Crew" heading ([WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren)), but no API field carries it ([API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md)).
- No forum.
- No streaming-provider field in the API. The site's "Watch now on / Streaming in: TG, US" block is regional and site-only ([WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren)).
- Personalized recommendations are PRO/VIP only and are not in the API ([DOC-RECO](https://docs.simkl.org/how-to-use-simkl/core-features/search-and-discovery/recommendations.md)).

Image URL rule: image fields hold paths. Build `https://wsrv.nl/?url=https://simkl.in/{posters|fanart|episodes}/{path}{suffix}.webp&q=90`. The calendar doc gives the poster form verbatim as `https://wsrv.nl/?url=https://simkl.in/posters/{poster}_m.webp&q=90`, with the fallback `https://simkl.in/poster_no_pic.png`. Poster heights vary, so set an aspect ratio and crop ([API-IMG](https://api.simkl.org/conventions/images.md), [API-CAL](https://api.simkl.org/api-reference/calendar.md)).

---

## 2. Anime title page

### 2.1 What simkl.com shows (Frieren, observed 2026-10-29, top to bottom) — [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren)

1. **Header.** English title "Frieren: Beyond Journey's End", romaji "Sousou no Frieren", "2023 - 2024 • Nippon TV • 11 hours • 28 episodes". "11 hours" is the total runtime, computed as runtime × episodes.
2. **Ratings strip.** Simkl "9.2/10, 6535 votes" | MAL "9.2/10, 948572 votes" | "Ranked #1" | **YOUR RATING – Rate This** | "RANKED # 1" | "DROP RATE 1.7%" | REACTIONS.
3. **Genre chips** (Adventure, Drama, Fantasy, Magic, Shounen), then the overview with a "Note:" paragraph and More/Less.
4. **Episode status card.** "Previously Aired Episode – Aired on 03/22/2024 – *It Would Be Embarrassing When We Met Again* – Episode 28", then "New Episode Air Date – Series ended – 28 episodes total", then **"Next to watch - Sequel: Frieren: Beyond Journey's End, TV • 2026"**. For an airing show, this slot holds the next air date.
5. **Trailer** (the YouTube "LAUNCH TRAILER").
6. **"Watch now on" – Local services – "Streaming in: TG, US"** (regional, site-only).
7. **Tabs**: Summary / Episodes / Lists / Shop / Screenshots.
8. **About table**: Other Titles, **Tags** (15 shown, "... 61 more"), Studios, Producers, Licensors, Air Date range, Country, Language, Age Rating, Type, **Links** (Anime Countdown, Crunchyroll, ANN, MAL, Official Website, Wikipedia EN/JP, allcinema, IMDb, TMDB, Twitter, TVDB, AniList, Anime-Planet, aniSearch, Kitsu, LiveChart, JustWatch).
9. **Watcher distribution**: Watching 5,730 (16.6%), Plan to Watch 6,503 (18.9%), Completed 21,259 (61.7%), On Hold 487 (1.4%), Dropped 465 (1.4%), Total 34,444.
10. **Episodes grid** (numbered tiles 28…1 with "more") + a **Specials** grid. "Last Ep. aired on Friday 03/22/2024". **"Mark as watched: All episodes / Unmark All"**.
11. Cast & Crew; Parents Guide (PG-13).
12. **Related Anime**: "Directly related / Indirectly related (more stories)", typed (Sequel), each card "TV, 2026 – **0/10**" (the user's progress / total episodes).
13. **Recommendations**: "Discover more anime like this one", each with a **% badge** (Violet Evergarden 20%, To Your Eternity 13%…) and a 0/N progress badge.
14. **Similar**: "Top anime with similar genre to …".
15. **Lists**, then the community block: "245 Reactions, 6 Reviews, 3 Comments, 236 Memos", sort menu (Newest / Oldest / Top Replies / Top comments / Top Memos / Most Helpful / Most Likes), the review summary "100% positive reviews – 6 Positive 0 Neutral 0 Negative", and review cards (date, author, title, Overall plus Story / Animation / Sound / Character / Enjoyment, excerpt, "x out of y found this helpful").

### 2.2 Episode page — [WEB-EP](https://simkl.com/anime/1990194/sousou-no-frieren/episode-1/)

- Show title, "Episode 1".
- Episode title in several languages ("The Journey's End / Bouken no Owari / 冒険の終わり / La fin de l'aventure").
- "PG-13 • 30 min. • Nippon TV • Aired on September 29, 2023", then the synopsis.
- **"Set progress: … min" + "Started Watching Now"** (this is the check-in), "Find episode on:", "Watched on", "Watch now on".
- "Watching Now / Mark as watched".
- Episode navigator (1 - 28, Specials).

### 2.3 Recommended MWL layout (ordered blocks → data)

| # | Block | Data field | Notes |
|---|---|---|---|
| 1 | **Fanart hero** (16:9, `_mobile`, `_s48` blur-up) with poster (`_m`) overlapping the bottom-left; hide the hero when `fanart` is null (no placeholder) | `/anime/{id}` `fanart`, `poster` | [API-IMG](https://api.simkl.org/conventions/images.md). The Simkl-specific signature: MAL has no backdrop. |
| 2 | Title in the account's preferred language; second line = the other form | `en_title` / `title` / `alt_titles[type=original]`, chosen by `/users/settings` `account.anime_title_language` | [API-SETTINGS](https://api.simkl.org/api-reference/simkl/get-user-settings.md) |
| 3 | Meta line: `year_start_end` • `network` • total time (`runtime`×`total_episodes`) • `total_episodes` eps • `anime_type` • `certification` | same record | mirrors the site header |
| 4 | **Ratings strip** (chips): Simkl x.x (votes) · MAL x.x (votes) · IMDb when present · Rank #n · Drop rate | `ratings.simkl/mal/imdb`, `rank`, `droprate` | [API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md); Cinopsys lets users reorder or hide score chips ([PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows)) |
| 5 | **My status bar**: status button (Watching / Plan to Watch / On Hold / Completed / Dropped), my rating 1–10, progress `watched/total`, memo | `/sync/all-items/anime` entry: `status`, `user_rating`, `watched_episodes_count`, `total_episodes_count`, `memo{text,is_private}` (`memos=yes`) | [API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md), statuses [DOC-LISTS](https://docs.simkl.org/how-to-use-simkl/core-features/watchlists-and-custom-lists.md) |
| 6 | **Next-episode card** (the heart of the page): "Next to watch: Ep N – title – airs Sun 23:15 (local)" or "Last aired Ep 28 – Series ended"; when finished, "Next to watch – Sequel" pointing to the first direct `sequel` relation; primary action "Mark Ep N watched"; secondary "Check in" | `next_to_watch_info{title,episode,date}`, `last_watched`, `airs{day,time,timezone}`, `status`, `last_aired`, `relations[relation_type=sequel,is_direct]`; actions `POST /sync/history`, `POST /scrobble/checkin` | [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren), [API-CHECKIN](https://api.simkl.org/api-reference/simkl/scrobble-checkin.md) |
| 7 | Genre chips, then the synopsis (collapsed to 4 lines) | `genres`, `overview` | |
| 8 | **Trailers** carousel (YouTube thumbnails, typed label) | `trailers[]{name,youtube,type}` | |
| 9 | **Episodes**: a horizontal strip of episode stills (`_c` 210×118) with number, title, air date and watched tick; "See all" opens a full list with a Specials tab and "Mark all / Unmark all"; unaired episodes greyed out with their date | `/anime/episodes/{id}`: `episode`, `title`, `img`, `date`, `aired`, `type`, `runtime`, `description`; watched set from the all-items `seasons[].episodes[].watched_at` (`extended=full`, `episode_watched_at=yes`) | [API-EPS](https://api.simkl.org/api-reference/simkl/get-anime-episodes.md), [API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md); the site's grid + "Mark as watched: All episodes" |
| 10 | **Audience**: a horizontal stacked bar Watching / Plan / Completed / On hold / Dropped with counts and % | scraped C1 (MWL-REPORT §S-C); fallback CDN `watching`, `plan_to_watch`, `completed` | [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren) |
| 11 | **Related** (direct first, then "more stories"), each card with type, year and **my progress badge 0/N** | `relations[]{relation_type,is_direct,anime_type,year,poster,ids}` + my list | site shows "TV, 2026 – 0/10" |
| 12 | **Recommendations** with a **% badge** | `users_recommendations[]{users_percent,users_count,…}` | |
| 13 | Similar (genre-based) | `similar[]` (omitted when empty) | |
| 14 | **Community**: counters row (Reactions · Reviews · Comments · Memos), review summary (% positive, P/N/N counts), 2 review cards with sub-scores, links to the full lists | scraped C3–C7 | [WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren) |
| 15 | **About**: Season (`season_name_year`), Airs, Aired range, Studios, Producers/Licensors (scraped), Country/Language, Tags (scraped, collapsed "+61"), Alt titles | `season_name_year`, `airs`, `first_aired`/`last_aired`, `studios[].name`, `country`, `original_language`, `alt_titles[]` | |
| 16 | **Links** row (icons): MAL, AniList, Kitsu, AniDB, IMDb, TMDB, TVDB built from `ids`, plus the scraped "Links" (Crunchyroll, LiveChart, JustWatch) as the stand-in for "where to watch" | `ids{mal,anilist,kitsu,anidb,imdb,tmdb,tvdb}`, scraped C9 | no API streaming field ([API-ANIME](https://api.simkl.org/api-reference/simkl/get-anime.md)) |

Current MWL order (`lib/pages/Simkl/simkl_media_page.dart`): counters, Synopsis, Watchers, Trailers, Episodes, Related, Recommendations, Similar, Reviews, Comments, Memos, Info. Simkl-first gaps:
- No **next-episode card** and no **my-status bar** near the top.
- The ratings sit in the Info table instead of a header strip.
- The counters row comes before the synopsis. The site puts the community block last.

---

## 3. User list (My List)

### 3.1 What Simkl and its clients show

- **Statuses.** Watching, Plan to Watch, On Hold, Completed, Dropped. "Watching" and "On Hold" are TV/anime only, and Completed is set automatically when the last episode is marked ([DOC-LISTS](https://docs.simkl.org/how-to-use-simkl/core-features/watchlists-and-custom-lists.md)). The API adds `notinteresting` ([API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md)).
- **Simkl Lists** puts the **next episode number** on each row and a "what's airing next on your watchlist" view first ([PLAY-LISTS](https://play.google.com/store/apps/details?id=com.simkl.lists)).
- **Anime & TV Series for Simkl** shows unwatched episodes, the network per series, a visual progress overview, and works offline ([PLAY-JA](https://play.google.com/store/apps/details?id=com.jonathanantoine.simkl)).
- **Scaena** sorts by recently aired, alphabetical, release year and watch progress, and filters by genre, Simkl/IMDb rating, status, personal rating and notes ([IOS-SCAENA](https://apps.apple.com/us/app/scaena-tv-movie-tracker/id6787125515)).
- **Cinopsys** has "Up Next" and "Put a show on hold" ([PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows)).
- On the site, every related or recommended card carries a **"watched/total"** badge (e.g. "0/13") ([WEB-TITLE](https://simkl.com/anime/1990194/sousou-no-frieren)).

### 3.2 Recommended MWL layout

| # | Block | Data field |
|---|---|---|
| 1 | Status tabs with counts (Watching · Plan · On hold · Completed · Dropped) | `/sync/all-items/anime/{status}`; counts from the list or from `/users/{id}/stats` `anime.{status}.count` ([API-STATS](https://api.simkl.org/api-reference/simkl/get-user-stats.md)) |
| 2 | Watching tab, top section **"Airing next"**: entries with `next_to_watch_info.date` in the future, sorted by date, showing "Ep N in 2 d 4 h" | `next_watch_info=yes` → `next_to_watch_info{episode,title,date}` ([API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md)) |
| 3 | Row/card: poster `_c`, title, `anime_type`, **progress bar `watched_episodes_count / total_episodes_count`** (with `not_aired_episodes_count` as a hatched tail), **"Next: Ep N"** chip with a one-tap +1 (POST `/sync/history`), my score, Simkl community score badge | `show{title,poster,year,ids}`, counts, `next_to_watch`, `user_rating`; community score `/ratings/anime?user_watchlist=…&fields=ext,rank` ([API-RATINGS](https://api.simkl.org/api-reference/simkl/get-watchlist-ratings.md)) |
| 4 | "Continue watching" strip (only when non-empty): paused sessions with a % ring | `/sync/playback` `progress`, `paused_at`, `episode` ([API-PLAYBACK](https://api.simkl.org/api-reference/playback.md)) |
| 5 | Sort: last watched, recently aired, next air date, title, year, my score, Simkl score, progress | `last_watched_at`, `next_to_watch_info.date`, `added_to_watchlist_at`, `user_rating`, community `simkl.rating` |
| 6 | Filters: `anime_type` (TV/Movie/OVA/ONA/Special), has memo | `anime_type`, `memo` |
| 7 | Refresh: `/sync/activities` first, then `date_from` pulls (never a full reload) | [API-ALLITEMS](https://api.simkl.org/api-reference/simkl/get-all-items.md) (`date_from`), MWL-REPORT B8 |

The grid card can keep MWL's DailyAL grid styling (see memory "My List grid like DailyAL"). What changes is the **content**: next-episode and airing data replace the MAL-style "score / members" line.

---

## 4. Profile

### 4.1 What is available

- The site profile could not be fetched (Cloudflare challenge, MWL-REPORT §2.1). The official app's listing places "Advanced Profile statistics & charts" and "Compare your watchlists with friends" on the site ([PLAY-LISTS](https://play.google.com/store/apps/details?id=com.simkl.lists)).
- The **stats** object carries `total_mins`. Per type, it gives `total_mins` and, per status, `count`, `watched_episodes_count`, `total_episodes_count`, `left_to_watch_episodes` and `left_to_watch_mins`. It also gives `watched_last_week{total_mins,anime_mins,tv_mins,movies_mins}`. It is "the most expensive call": fetch it only on an explicit open or refresh ([API-STATS](https://api.simkl.org/api-reference/simkl/get-user-stats.md)).
- The **user settings** give `user{name,avatar,bio,loc,age,joined_at,gender}` and `account{id,timezone,type free|pro|vip,anime_title_language}` ([API-SETTINGS](https://api.simkl.org/api-reference/simkl/get-user-settings.md)).
- **Now watching** cover: `/users/recently-watched-background/{id}` returns `{id,url,title,poster,fanart}`, or a 302 to the image with `?image=fanart` ([API-BG](https://api.simkl.org/api-reference/simkl/get-recently-watched-image.md)).
- Third-party stats screens show hours, top genres, rating breakdown, streaks, "On this day" and a month in review ([PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows)).

### 4.2 Recommended MWL layout

| # | Block | Data field |
|---|---|---|
| 1 | **Header on the last-watched fanart** (darkened `_d` or `_mobile`), avatar `_100`/`_256`, name, PRO/VIP badge, "joined 2018", location | `/users/recently-watched-background/{id}` `fanart`; `user.avatar`, `user.name`, `account.type`, `user.joined_at`, `user.loc` |
| 2 | **"Now watching" card** on the header: last title (tap → title page) | same endpoint `title`, `id`; enrich with all-items `last_watched` |
| 3 | **Time block** (Simkl's signature): total anime time as "20 d 14 h" (`anime.total_mins`); "Left to watch: 410 eps · 7 d 3 h" (`anime.watching.left_to_watch_episodes/mins`); "Last week: 2 h 10" (`watched_last_week.anime_mins`) | `/users/{id}/stats` |
| 4 | Status breakdown: a horizontal bar plus counts and episodes per status | `anime.{watching,plantowatch,hold,completed,dropped}.count`, `.watched_episodes_count` |
| 5 | Optional "All media" toggle: TV and movies minutes (Simkl tracks them too) | `tv.total_mins`, `movies.total_mins`, `total_mins` |
| 6 | Computed locally from the list: score distribution, types, genres | all-items `user_rating`, `anime_type`; genres from the CDN metadata |
| 7 | "Top rated by me" (10/10, 9/10) | `GET /sync/ratings/anime/{9,10}` (MWL-REPORT B9) |
| 8 | Lists (PRO/VIP only; hidden for free accounts) | `/lists/user/{id}` (MWL-REPORT B13) |

Do **not** mirror MAL's "Days / Mean score / Favorites characters" layout. Simkl has no favourite characters, and its unit of measure is minutes and episodes left.

---

## 5. Home / Discover

### 5.1 What simkl.com shows

- **Anime hub** ([WEB-HUB](https://simkl.com/anime/)):
  - Genre menu.
  - Sub-nav: My List · **Today (15)** · Calendar · Trending · Premieres · Countdown.
  - **"New episodes"** grouped by day ("Yesterday, Wednesday October 28, 2026"), sortable by Rank / People Watched / Air Date. Each line reads "Bleach: Thousand-Year Blood War – The Calamity episode 10 – **1292 watched**".
  - "Most watched Anime this month tracked using Simkl" (with "That you haven't watched / From your Watchlist" filters), showing a rank (#38) per title.
  - "Most Watched Today".
  - Genres / Years.
- **Premieres** ([WEB-PREM](https://simkl.com/anime/premieres/)): "Upcoming New Animes", "Latest New Animes", "Premiere Calendar". Cards show the title, a "Movie" tag and the date (11/06/2026).
- **Best** ([WEB-BEST](https://simkl.com/anime/best-anime/)): "Best Anime sorted by Rank" with a type filter (All/Series/Movies/OVAs/ONAs/Music). Rows show the rank, title, years, airing time when ongoing ("Now • 04:00 AM"), episodes, genres, the note/overview, **Simkl x/10 and MAL x/10 side by side**, and "add to watchlist".
- **Airing** ([WEB-AIRING](https://simkl.com/anime/airing/)): a browse grid filtered by genre, type, "Shows: Not Seen / Not in My List / status…", network, aired period ("Today, This Week…"), with a drop-rate slider.

### 5.2 Data sources

| Row | Source | Fields |
|---|---|---|
| Trending today/week/month | CDN `https://data.simkl.in/discover/trending/anime/{today,week,month}_{100,500}.json` (no auth, no quota; titles must include "Simkl" and "Trending"/"Most Watched"/"Popular") | `title, poster, rank, ratings, watched/watching/plan_to_watch/completed, drop_rate, status, anime_type, total_episodes, trailer, genres` ([API-TREND](https://api.simkl.org/api-reference/trending.md)) |
| Trending by genre | CDN `anime/genre/index.json` + `anime/genre/<slug>_month_500.json` (skip `hentai`) | same ([API-TREND](https://api.simkl.org/api-reference/trending.md)) |
| Airing today / new episodes | CDN `calendar/v2/anime.json` (rolling: yesterday + 33 days) | `calendar[]{simkl_id,date,finale_type,episode{episode,title,runtime}}` + `metadata{…}` ([API-CAL](https://api.simkl.org/api-reference/calendar.md)) |
| Coming soon / Latest premieres | `/anime/premieres/{soon,new}?type=` (token under AUTH V2) | `title,date,poster,anime_type`; `new` adds `rank,ratings` ([API-PREM](https://api.simkl.org/api-reference/simkl/get-anime-premieres.md)) |
| Best (all/year/month/voted/watched) | `/anime/best/{filter}?type=` (max 60, no paging, token under V2) | `title,year,poster,ratings.simkl/mal` ([API-BEST](https://api.simkl.org/api-reference/simkl/get-best-anime.md)) |
| Genre browse | `/anime/genres/{genre}/{type}/{network}/{year}/{sort}` (sort `popular-this-week…rank…watched`, page ≤20, limit ≤60) | `title,year,date,poster,fanart,anime_type,rank,ratings` ([API-GENRES](https://api.simkl.org/api-reference/simkl/get-anime-genres.md)) |

### 5.3 Recommended MWL home (Simkl tab)

| # | Block | Data |
|---|---|---|
| 1 | **Fanart carousel "Trending on Simkl today"** (5–8 items, `_mobile` fanart, title, Simkl + MAL chips, "1,899 watching") | CDN trending `today_100`; fanart from the calendar metadata or `/anime/{id}` (cached) |
| 2 | **"Up next for you"** (user): watching entries with an aired next episode, poster + "Ep N" + one-tap mark | all-items `next_to_watch`, `next_to_watch_info` |
| 3 | **"Airing today"** (user's shows first, then all), time-ordered, local time, finale badge | CDN calendar v2 filtered to today, joined with the user's list by `simkl_id` |
| 4 | Continue watching (if any playback) | `/sync/playback` |
| 5 | "Most watched this week on Simkl" | CDN `week_100` (`watched` count as the badge, as on [WEB-HUB](https://simkl.com/anime/)) |
| 6 | Coming soon (dated cards) | `/anime/premieres/soon` or CDN calendar entries with episode 1 |
| 7 | Best this season / all time | `/anime/best/year`, `/anime/best/all` |
| 8 | Genre chips → genre browse | CDN genre index + `/anime/genres/…` |

Scaena's customizable home modules (Continue Watching, Recently Aired, Upcoming, Trending, Recently Watched, Plan to Watch) are a good model for letting the user reorder rows ([IOS-SCAENA](https://apps.apple.com/us/app/scaena-tv-movie-tracker/id6787125515)).

---

## 6. Search and filters

- **API.** `GET /search/anime?q=&page(≤20)&limit(≤50)&extended=full`. It matches `title` and `all_titles[]`, and returns `title, title_romaji, title_en, year, type, poster, ids`; `extended=full` adds `all_titles, ep_count, rank, status (tba/ended/airing), ratings (simkl/imdb/mal + mal.rank)` ([API-SEARCH](https://api.simkl.org/api-reference/simkl/search-by-text.md)). Also `/search/id?mal=` to resolve ids, and `POST /search/random` (MWL-REPORT B12, B14).
- **Site filters.** Genre, type, "Not Seen / Not in My List / by status", network (TV Tokyo, Tokyo MX, Fuji TV…), aired period, drop rate ([WEB-AIRING](https://simkl.com/anime/airing/)). The API equivalent is the genres path (genre/type/network/year/sort) ([API-GENRES](https://api.simkl.org/api-reference/simkl/get-anime-genres.md)).

Recommended MWL layout:
1. Search field.
2. Before typing: genre chips + type segmented control + network dropdown + year + sort (Popular this week / month / all time, Rank, Release date, Most voted, Most watched), feeding `/anime/genres/…`.
3. Results list: poster `_c`, title (account language), romaji line, `type` • `year` • `ep_count` eps • `status`, Simkl and MAL chips, a "in my list: Watching 3/12" badge from the local list.
4. Filter "Hide titles in my list" (local, as the site's "Not in My List").
5. A "Surprise me" button (`/search/random`).

---

## 7. Calendar

### 7.1 Site and clients

- **Site** ([WEB-CAL](https://simkl.com/anime/calendar/)): "October 2026 Anime Episode Calendar" with previous/next month, "Show Filters and Options", a header "107 shows". Day cells list "title – Ep. 15 – 11:00 PM" and ranges such as "Ep. 22 - 23"; 🔥 marks popular titles.
- **Premiere Calendar** lives on the premieres page ([WEB-PREM](https://simkl.com/anime/premieres/)).
- **Clients**: Cinopsys has premiere and finale tags plus an anime calendar widget ([PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows)); Scaena has "Today" badges with exact broadcast times and premiere/finale badges ([IOS-SCAENA](https://apps.apple.com/us/app/scaena-tv-movie-tracker/id6787125515)); J. Antoine's app has an episode calendar with notifications ([PLAY-JA](https://play.google.com/store/apps/details?id=com.jonathanantoine.simkl)).

### 7.2 Data

- **Rolling feed**: `https://data.simkl.in/calendar/v2/anime.json`, covering yesterday plus the next 33 days.
- **Monthly archive**: `…/calendar/v2/{YEAR}/{MONTH}/anime.json`. Months are not zero-padded; the archive starts in July 2024 and goes up to the current month + 3.
- **Freshness**: regenerated every 6 h, cached 5 h. The v1 files stop updating on 2027-02-01.
- **Per airing**: `date` (UTC), `finale_type`, `episode{episode,title,runtime,url}`; metadata gives `title, title_romaji, poster, fanart, ids (mal/anilist/kitsu…), rank, ratings, watching, plan_to_watch, network, anime_type, total_episodes, genres, trailer, status` ([API-CAL](https://api.simkl.org/api-reference/calendar.md)).
- `/anime/airing?date=&sort=time|rank|popularity` is uncached; the docs recommend the CDN for frequent use ([API-AIRING](https://api.simkl.org/api-reference/simkl/get-anime-airing.md)).

### 7.3 Recommended MWL layout

1. Toggle **My shows / All anime**: join `simkl_id` with the user list; My shows is the default when logged in.
2. Week strip (Mon–Sun, today selected) + a month view button (monthly archive).
3. Day list ordered by local time: time • poster `_cm` • title • "Ep 15" (or "Ep 22–23" when several episodes of one title share a slot) • network • badges **Premiere** (episode 1), **Finale** (`finale_type` 1/2/3 → "Mid-season / Season / Series finale"), "in my list" status dot, watcher count (`watching`).
4. Tap → title page; long-press → mark watched when aired.
5. Empty state: no text beyond the day name (see memory "No useless text").

---

## 8. Check-in / playback

- **Site**: the episode page has "Set progress: … min", "Started Watching Now", "Watching Now", "Mark as watched" ([WEB-EP](https://simkl.com/anime/1990194/sousou-no-frieren/episode-1/)).
- **Check-in API**: `POST /scrobble/checkin` with `anime{ids}` + `episode{number}`. The server computes progress from the runtime and marks the item watched at 100% (0–2 min lag). Seeking has no effect, and deleting the playback cancels the check-in ([API-CHECKIN](https://api.simkl.org/api-reference/simkl/scrobble-checkin.md)).
- **Playback rules**: `/scrobble/pause` and `/scrobble/stop` under 80% save a playback (`progress`, `paused_at`); one playback is kept per title, retained 7 days (Free), 30 (PRO) or 90 (VIP). Poll `/sync/activities` and do not poll `/sync/playback` on a timer ([API-PLAYBACK](https://api.simkl.org/api-reference/playback.md)).
- **Clients**: Cinopsys offers "Check in to what you are watching right now" ([PLAY-CINOPSYS](https://play.google.com/store/apps/details?id=com.cinopsys.movieshows)).

Recommended MWL design:
- **"Watching now" button** on the next-episode card (title page) and on episode rows. It sends a check-in and shows a mini bar ("Frieren · Ep 5 · 12 / 25 min") that fills locally from `runtime`, with a Cancel action (`DELETE /sync/playback/{id}`).
- **Continue watching**: rows from `/sync/playback` with a % ring and "paused 2 d ago", fed by media-server scrobblers (Plex/Jellyfin/Kodi are listed integrations on [WEB-APPS](https://simkl.com/apps/)). Actions: Resume info, Mark watched, Remove.

---

## 9. Summary: per-screen Simkl signature vs MAL-style default

| Screen | Lead with (Simkl) | Not like MAL/DailyAL |
|---|---|---|
| Title | fanart hero, multi-source rating strip with drop rate, **next-episode card**, episode stills | no character/staff tabs, no "members/favorites" stat grid |
| My List | progress + **next episode** + airing countdown, community score badge | no "score / members" line |
| Profile | **time watched / left to watch / last week**, now-watching fanart | no "days / mean score / favourite characters" |
| Home | trending with audience counts, **up next**, airing today with finale badges | no season-chart-first layout |
| Calendar | My shows vs all, local times, premiere/finale badges | no MAL broadcast strings |
| Check-in | "Watching now" + continue watching | (MAL has none) |
