# MyAnimeList official API v2 (and MAL website leftovers) vs MyWatchList

- MWL read at `origin/dev` = `9b7aba7`. Local `dev` (`968c351`) is ahead by `chore(work)` commits only; `git diff origin/dev dev -- lib mwl-api` is empty, so the line numbers below hold for both. `.wt/*` ignored.
- Reference: https://myanimelist.net/apiconfig/references/api/v2 (endpoints and field lists as documented), plus fields that are undocumented but widely used (`opening_themes`, `ending_themes`, ranking `ona` / `lightnovels`, list sort `anime_id`). Undocumented ones are marked **(undoc)**.
- **No live call was made.** The only client id in a file I may read is Drutol's (in `docs/malclient-fork-report-2026-10-28.md`), which is a third party's credential, and MWL's own id is in `assets/.env`, which I was told not to read. Everything below is from the code and the docs.
- Already covered elsewhere and **not repeated** here: every item of `docs/dal-gap-report-2026-10-28.md` (P1-P5, H1-H4, L1-L2, D1-D4, E1-E3, W1, F1, S1, B1, M1-M2) and every item of the two MALClient reports (web session writes: profile comments, PMs, friends, forum reply/topic/edit/delete/quote/watch, club actions, favourites toggle, notification hub, review reactions; friends RSS feed; list comparison; `/watch/promotion`; personalised suggestions; manga adapted; forum search; last-post jump; wallpapers; ANN; offline queue; widgets).

_Status: complete._

---

## 1. Endpoints of API v2

| # | Endpoint | Params MWL sends | Status | MWL file:line |
|---|---|---|---|---|
| 1 | `GET /anime` (search) | `q, limit, offset, fields`, `nsfw` | **used** (text search without filters) | `lib/services/api/MAL/mal_api.dart:124-143`; callers `lib/screens/search/search_service.dart:317,661` |
| 2 | `GET /anime/{id}` | `fields=Constants.malAnimeFields` | **used** | `mal_api.dart:82-105`; fields `lib/constants/constants.dart:137-138` |
| 3 | `GET /anime/ranking` | `ranking_type, limit, offset, fields` | **used**, all 9 documented types + `ona` (undoc) | `mal_api.dart:183-217`; types `lib/enums.dart:242-251` |
| 4 | `GET /anime/season/{year}/{season}` | `sort, limit, offset, fields` | **used** (seasonal screen, home row, calendar, weekly) | `mal_api.dart:259-287`, `getSchedule` `mal_api.dart:1078-1115`; callers `lib/screens/seasonal/seasonal_data.dart:70`, `lib/screens/weekly/weekly_data.dart:82`, `lib/widgets/calendar/calendar_cubit.dart:16` |
| 5 | `GET /anime/suggestions` | `limit, offset, fields` | **used** (home row, `suggested@anime`) | `mal_api.dart:303-328`; `lib/user/requests/requests_bloc.dart:176` |
| 6 | `PUT /anime/{id}/my_list_status` | every documented form field + `start_date`, `finish_date` | **used** | `mal_api.dart:408-466`, `534-561` |
| 7 | `DELETE /anime/{id}/my_list_status` | – | **used** | `mal_api.dart:617-629` |
| 8 | `GET /users/{user}/animelist` | `status, sort, limit, offset, fields, nsfw`; `@me` and other users | **used** | `lib/widgets/user/list/mal_user_list_adapter.dart:76-139`; insights `lib/screens/user_profile/user_insights.dart:204`; random-from-list `lib/screens/explore/explore_data.dart:500` |
| 9 | `GET /manga` (search) | same as anime | **used** | `mal_api.dart:153-173` |
| 10 | `GET /manga/{id}` | `fields=Constants.malMangaFields` | **used** | `mal_api.dart:107-122`; fields `constants.dart:140-141` |
| 11 | `GET /manga/ranking` | all 8 documented types + `lightnovels` (undoc) | **used** | `lib/enums.dart:117-128` |
| 12 | `PUT / DELETE /manga/{id}/my_list_status` | every documented form field + dates | **used** | `mal_api.dart:468-532`, `563-598`, `631-641` |
| 13 | `GET /users/{user}/mangalist` | as animelist | **used** | `mal_user_list_adapter.dart:139` |
| 14 | `GET /users/{user}` (`@me` only) | `fields=anime_statistics` (profile, list tab counts); no fields at sign-in | **partly used** (see 3.1: `time_zone` misread, `is_supporter` never asked) | `lib/services/api/MAL/mal_user.dart:18-37`; `lib/screens/user_profile/user_profile_data.dart:294`; `mal_user_list_adapter.dart:180`; `lib/services/auth/mal_auth_v2.dart:276` |
| 15 | `GET /forum/boards` | – | **used** | `lib/services/api/MAL/mal_forum_api.dart:19`; `lib/pages/MAL/mal_forum_page.dart:93` |
| 16 | `GET /forum/topics` | `board_id, subboard_id, anime_id, manga_id, q, topic_user_name, user_name, limit, offset, sort` (all documented params) | **used** | `mal_forum_api.dart:55-82`; `lib/screens/search/search_service.dart:546-551`, `lib/screens/forum/forum_topics_screen.dart:51`, `lib/widgets/home/home_sections.dart:353` |
| 17 | `GET /forum/topic/{id}` | `limit, offset`; posts + poll parsed | **used** (poll is read only, see 4.6) | `mal_forum_api.dart:88-110`; `lib/screens/forum/forum_posts_screen.dart:93,216` |
| 18 | `GET /manga/suggestions` **(undoc, not in v2)** | – | **used but probably dead**: reachable only by typing `suggested@manga` | `lib/screens/search/search_queries.dart:29-30` → `mal_api.dart:310`. Already noted by the MALClient report; see 3.4 for the fix |
| 19 | OAuth `/v1/oauth2/authorize`, `/v1/oauth2/token` (code + refresh) | PKCE plain | **used** | `lib/services/auth/mal_auth_v2.dart`, `lib/user/user_mal_v2.dart:30-39` |

**Verdict:** every documented endpoint and every documented query parameter is called. The gaps are in fields, in what the UI does with them, and on the website.

---

## 2. Fields (`fields=`)

### 2.1 Anime details (`GET /anime/{id}`)

| Field | Status | Where it shows (file:line) | If unused: what it would add |
|---|---|---|---|
| id, title, main_picture | used | everywhere | – |
| alternative_titles (synonyms, en, ja) | used | `lib/widgets/MAL/content/more_info_widget.dart:189-193` | – |
| start_date, end_date | used | `more_info_widget.dart` (Aired rows) | – |
| synopsis | used | synopsis section | – |
| background | used | `lib/screens/MAL/detail/sections/synopsis_section.dart:15` | – |
| mean, rank, popularity, num_list_users, num_scoring_users | used | `lib/screens/MAL/detail/header/header_meta.dart:49,66,103` | – |
| nsfw (`white` / `gray` / `black`) | **parsed, never shown** | `lib/services/api/MAL/mal_anime.dart:101`; node `Anime` does not even parse it | An "18+" chip in the header and on cards, and per-entry blur when the global NSFW switch is on (today only the global switch exists, `lib/widgets/MAL/home/animegridcard.dart:666-671`) |
| created_at, updated_at (entry) | **parsed, never shown** | `mal_anime.dart:15-16` | "Added to MAL / last edited on MAL" rows in More Info. Low value |
| media_type, status, num_episodes | used | header, More Info | – |
| genres | used (one flat list) | `more_info_widget.dart:205-232` | v2 merges genres, themes and demographics in one list; the website splits them (see 4.2) |
| my_list_status {status, score, num_episodes_watched, is_rewatching, updated_at, priority, num_times_rewatched, rewatch_value, start_date, finish_date, tags, comments} | used (edit sheet) | `constants.dart:138`; `lib/widgets/user/edit/list_entry.dart` | `updated_at` is never shown ("last updated" line in the edit sheet: tiny) |
| start_season | used | `more_info_widget.dart:65`, `header_meta.dart` | – |
| broadcast | used | `more_info_widget.dart:303`, list cards, calendar, weekly | – |
| source | used | `more_info_widget.dart:86` | – |
| average_episode_duration | used on detail only | `more_info_widget.dart:88` | Not asked on My List: see 4.5 ("time left") |
| rating | used | `more_info_widget.dart:90,339-340`; search filters | – |
| pictures | used | `lib/screens/MAL/detail/sections/pictures_section.dart:12`, `detail_data.dart:105` | – |
| related_anime, related_manga {my_list_status, mean, num_list_users, media_type} | used | `lib/screens/MAL/detail/sections/related_section.dart` | – |
| recommendations {…} | used | `lib/screens/MAL/detail/sections/recommendations_section.dart:11` | – |
| studios | used | `more_info_widget.dart:67`, `header_meta.dart` | – |
| statistics {status{watching…}, num_list_users} | used | `lib/screens/MAL/detail/sections/stats_section.dart:8` | – |
| opening_themes, ending_themes **(undoc)** | used | `lib/screens/MAL/detail/sections/media_section.dart:26-27` | – |

### 2.2 Manga details (`GET /manga/{id}`)

| Field | Status | file:line | Note |
|---|---|---|---|
| num_volumes, num_chapters | used | `header_meta.dart`, `more_info_widget.dart`, edit sheet bounds `lib/widgets/user/edit/edit_rules.dart` | – |
| authors {first_name, last_name} + role | used | `more_info_widget.dart:109`, `header_meta.dart` | – |
| serialization {name} | used | `more_info_widget.dart:108` | – |
| my_list_status {…num_volumes_read, num_chapters_read, is_rereading, num_times_reread, reread_value…} | used | `constants.dart:141` | – |
| nsfw, created_at, updated_at | parsed, never shown | as anime | as anime |
| everything else shared with anime | used | as anime | v2 has no `statistics` for manga (MAL limitation) |

### 2.3 List endpoints (`users/{u}/animelist|mangalist`)

| Item | Status | file:line | Note |
|---|---|---|---|
| `status` filter (5 statuses) | used | `mal_user_list_adapter.dart:133` | – |
| `sort` = list_score, list_updated_at, anime_title / manga_title, anime_start_date / manga_start_date, anime_id **(undoc)** | used | `mal_user_list_adapter.dart:98-110`, `mal_api.dart:737-773` | Other sorts are local |
| `limit` 1000, `offset`, `paging.next` | used | `mal_user_list_adapter.dart:93` | – |
| `nsfw=1` for other users | used | `mal_user_list_adapter.dart:136` | – |
| node fields | used: id, title, main_picture, alternative_titles, mean, num_list_users, num_scoring_users, popularity, status, media_type, genres, start/end date, num_episodes, broadcast; manga num_chapters, num_volumes | `mal_user_list_adapter.dart:76-85` | **Not asked:** `average_episode_duration` (time left, 4.5), `start_season` (season grouping/filter in My List), `rating`, `source`, `studios`, `authors` (filters by studio/author/rating in My List). Each costs a few bytes per entry |
| list_status fields | used: status, score, progress, is_rewatching, updated_at, priority, start/finish date, tags | same | `comments`, `num_times_rewatched`, `rewatch_value` are left out on purpose (the edit sheet loads the detail). A "rewatched N times" badge on list cards would need `num_times_rewatched` |

### 2.4 Ranking types

| Category | Values | Status | file:line |
|---|---|---|---|
| Anime | all, airing, upcoming, tv, ova, movie, special, bypopularity, favorite (+ `ona` undoc) | all used (explore, home rows, media-type links) | `lib/enums.dart:242-262`; home `lib/user/MAL/mal_home_page_preferences.dart:13-39` |
| Manga | all, manga, novels, oneshots, doujin, manhwa, manhua, bypopularity, favorite (+ `lightnovels` undoc) | all used | `lib/enums.dart:117-128`; `more_info_widget.dart:161-172` |

The undoc values (`ona`, `lightnovels`) should be checked once with a client id: if MAL answers 400, those rows fail silently.

### 2.5 Seasonal sort

| Value | Status | file:line |
|---|---|---|
| `anime_score` | used (home "season now", weekly) | `lib/enums.dart:343-347`, `requests_bloc.dart:173`, `mal_api.dart:1089` |
| `anime_num_list_users` | used (seasonal screen, home) | `seasonal_data.dart:73`, `lib/pages/MAL/mal_home_page.dart:378` |

### 2.6 User fields (`GET /users/@me`)

| Field | Status | file:line | If fixed / added |
|---|---|---|---|
| id, name, picture, gender, birthday, location, joined_at | used | `lib/services/api/MAL/mal_user_prof.dart:28-43` | – |
| anime_statistics (num_items_*, num_days_*, num_episodes, num_times_rewatched, mean_score) | used | `lib/services/api/MAL/user_anime_statistics.dart:39-53`; profile stats, list tab counts | – |
| **time_zone** | **bug: read as `timezone`** (`mal_user_prof.dart:34`) and never asked in `fields` | – | Always empty. Fix the key and ask for it; then the calendar's "local" time zone could default to the MAL account's zone, and the profile "About" could show it |
| **is_supporter** | **unused** | – | A "MAL Supporter" badge in the profile header, as the website shows |

### 2.7 Forum fields

| Item | Status | file:line |
|---|---|---|
| boards → categories, boards, subboards | used | `lib/services/api/MAL/models/forum/*` |
| topics → id, title, created_at, created_by, number_of_posts, last_post_created_at, last_post_created_by, is_locked | used | `models/forum/forum_topics_data.dart` |
| topic → posts (number, created_at, created_by{name, forum_avator}, body, signature), poll {question, close, options{text, votes}} | used, read only | `models/forum/forum_topic_post.dart`, `forum_topic_poll.dart`; poll card `forum_posts_screen.dart:425-429` |

---
## 3. API v2 findings (fields MWL ignores or reads wrong)

| # | Finding | Evidence | What it adds or fixes | Effort |
|---|---|---|---|---|
| A1 | **`time_zone` is read under the wrong key** and never requested | `mal_user_prof.dart:34` reads `json['timezone']`; no caller puts `time_zone` in `fields` (`user_profile_data.dart:294`, `mal_auth_v2.dart:276`). `git grep time_zone` finds nothing | Today the value is always `''`. Fixed: the profile About block can show it, and the calendar/weekly "local" zone could offer the MAL account zone when the device zone differs | S |
| A2 | **`is_supporter` never requested** | `git grep is_supporter` finds nothing | A "MAL Supporter" badge in `lib/widgets/user/profile/profile_header.dart`, as on the website (own profile only: v2 serves `@me` only) | S |
| A3 | **Entry `nsfw` rating parsed but unused**, node cards don't parse it | `mal_anime.dart:14,101`; the `Anime` node (`mal_anime.dart:734+`) has no `nsfw` | An "18+" chip on the detail header for `black` (and `gray`) entries, and an "18+" corner on cards when the NSFW switch is on, so adult titles are visible as such in rankings and search | S |
| A4 | **Seasonal fields lack `start_season`** | `seasonal_data.dart:55-57` | `anime/season/{y}/{s}` returns the season's new shows **and** the leftovers still airing from earlier seasons. Without `start_season` MWL mixes them; the website splits "TV (New)" from "TV (Continuing)". See W3 | S |
| A5 | **My List does not ask for `average_episode_duration`** | `mal_user_list_adapter.dart:76-85` | "Time left" per entry (remaining episodes × duration) and a total per tab ("Plan to watch: 41 days"). See W5 | S |
| A6 | `suggested@manga` calls `GET /v2/manga/suggestions`, which v2 does not document | `search_queries.dart:29-30`, `mal_api.dart:310` | Either drop the manga branch or show the empty state at once instead of an error. (The MALClient report already flags that the endpoint does not work; this is the code path to fix.) | S |
| A7 | Undocumented values in use: ranking `ona` (`enums.dart:251`), manga `lightnovels` (`enums.dart:122`), list sort `anime_id` (`mal_api.dart:745`) | – | One anonymous check each with a client id. If MAL answers 400, the "Top ONA" and "Top light novels" home rows and that sort fail | – |
| A8 | Entry `created_at` / `updated_at`, `my_list_status.updated_at` never shown | `mal_anime.dart:15-16` | "Last updated" line in the edit sheet; "Added to MAL" in More Info. Low value | S |
| A9 | List node fields not asked: `start_season`, `rating`, `source`, `studios`, `authors`, `num_times_rewatched` | `mal_user_list_adapter.dart:76-85` | Filters by season / studio / author / rating in My List, a "rewatched ×N" badge on cards | S-M |

Everything else in the v2 reference (every endpoint, every query parameter, every documented detail field, every edit field incl. priority, num_times_rewatched, rewatch_value, tags, comments, dates) is already used.

---

## 4. MAL website features MWL still lacks (not in the three earlier reports)

| # | Feature | Source on MAL | Auth | MWL today (file:line) | Screen it adds | Effort |
|---|---|---|---|---|---|---|
| W1 | **Episode list**: number, title (EN / romaji / JP), aired date, filler / recap flags, episode score; tap = episode page with synopsis; link to the episode's discussion topic | `/anime/{id}/_/episode` (`table.episode_list` rows; selectors to check on a live page), `/anime/{id}/_/episode/{n}`; Jikan `anime/{id}/episodes` as the other racer; discussion topics through API v2 `forum/topics?anime_id={id}` (titles "… Episode N Discussion") | none | **None.** `JikanApi.getAnimeEpisodes` (`lib/services/api/Jikan/jikan_api.dart:316`) and `TenraiApi.getAnimeEpisodes` (`lib/services/api/Tenrai/tenrai_api.dart:239`) have **no caller** | An "Episodes" detail section and a full episode screen; "Next: ep 7 'Title', Sat 23:30" in the header and on Watching cards | M |
| W2 | **Detail sidebar data v2 lacks**: Favorites count, Producers, Licensors, Demographic, Themes (split from Genres), "Premiered" link | anime/manga page `div.leftside .spaceit_pad` (`span.dark_text` labels); MWL already downloads this page (`lib/screens/MAL/detail/detail_screen.dart:176`) but `parseAnimeDetailedHtml` (`mwl-api/mwl_commons/lib/src/services/html_parser.dart:631-650`) reads none of it | none | Not shown. Producers/licensors exist in the Jikan model (`lib/services/api/Jikan/jikan_anime.dart`) but no screen reads them; no favorites count anywhere on the detail | More Info rows (Producers and Licensors as links to the existing studio pager, Demographic and Themes as genre links), a ♥ count next to Members in the header | S-M |
| W3 | **Seasonal "New" vs "Continuing"** and the website's type sections (TV new, TV continuing, ONA, OVA, Movie, Special) | API v2 `start_season` (A4); MAL `/anime/season` page layout | none | One mixed grid (`lib/screens/seasonal/seasonal_screen.dart`) | Section headers or a "Hide leftovers" chip on the seasonal screen | S |
| W4 | **A user's reviews, recommendations and interest stacks** on their profile | `/profile/{u}/reviews`, `/profile/{u}/recommendations` (anonymous pages); stacks list URL to confirm | none | Profile tabs are list, stats, friends, clubs, about, favorites, history, comments, weekly (`lib/screens/user_profile/user_profile_view.dart:31`). The reviews feed has no author filter (`lib/widgets/MAL/review/reviews_list_screen.dart:262`) | Three profile tabs, reusing `review_item.dart`, the recommendation card and the stack tiles | M |
| W5 | **Time left / time spent per list** | computed from API v2 (A5) | O | none | Header line per My List tab, and a "time left" field in the card layout editor | S |
| W6 | **List export / import in MAL's XML format** | MAL: `panel.php?go=export` (session) and `import.php` (session). MWL can **build** the same XML (`<myanimelist><myinfo/><anime><series_animedb_id>…<my_status>…`) from API v2 list data with no session, and can **import** by replaying `PUT my_list_status` | O | Backup covers settings, bookmarks, notes (`lib/cache/cachemanager.dart:327-352`) but not the tracker lists | "Export MAL list (XML)" and "Import MAL XML" in `lib/screens/settings/backup_settings.dart`; the XML is the format AniList, Kitsu and Simkl importers accept | M |
| W7 | **Trailer without Jikan** (part of DAL D1, the cheap half) | MAL page `.video-promotion a`, **already parsed** into `AnimeDetailHtml.trailer` (`html_parser.dart:232-239,635`) | none | Unused: videos come from Jikan only (`detail_screen.dart:192-199`) | The PV tile in the Media section while Jikan is down, with no new request | S |
| W8 | **Vote in a forum poll** | website form on the topic page (session; capture the request first) | S | Poll is display only (`forum_posts_screen.dart:425-429`) | Tap an option to vote, then show the results | S (after capture) |
| W9 | **Write / edit a review, submit a recommendation pair, create an interest stack** | website forms (session; endpoints unknown, capture first) | S | Read only (reviews, recommendations, stacks) | "Write review" on the detail Reviews section, "Recommend a similar title" on Recommendations | M each |
| W10 | **Blogs** (user blogs, blog index) | `/blog/{user}`, `/blog.php` | none | `git grep -i blog` finds nothing in `lib/` | A "Blog" profile tab or link. Low traffic on MAL: low priority | S |
| W11 | **Clubs related to a title** | `/anime/{id}/_/clubs`, `/manga/{id}/_/clubs` | none | Clubs only from the club directory and profiles | A "Clubs" row in the detail Forums section | S |
| W12 | **Latest episode videos (site-wide)** | `/watch/episode` (sibling of `/watch/promotion`, which the MALClient report covers) | none | none | A second tab in the promo-videos explore section if that unit is built | S |

---

## 5. Corrections to the earlier reports (state of `origin/dev`)

- `docs/malclient-report-2026-10-28.md:165` says MWL "Has" episodes (Jikan `episodes`). **It does not:** the API wrappers exist, nothing calls them (W1).
- Items of `docs/dal-gap-report-2026-10-28.md` that look **done** on `origin/dev` (worth syncing the board): P1 other users' lists (`UserProfileTab.list`, `mal_user_list_adapter.dart:47-50`), P2 weekly tab (`UserProfileTab.weekly`), W1 season weekday view (`lib/screens/weekly/weekly_data.dart:82`), H3 OVA/ONA and manga ranking rows (`mal_home_page_preferences.dart:30-39`), L1 manga counts without Jikan (`mal_user_list_adapter.dart:39-45`), D2 user updates from MAL (`lib/widgets/MAL/content/userupdate_widget.dart:18-20`). Not re-audited in depth.
- A MAL website session now exists (`lib/services/api/MAL/web/mal_web_client.dart`, `lib/screens/settings/mal_session_settings.dart`) and profile comments are read (`lib/services/api/MAL/web/profile_comments_api.dart`), so W8 and W9 only need the request captures.

---

## 6. Top 10 (new items only, by user impact)

1. **W1 Episode list** with titles, air dates, filler flags and per-episode discussion links. The biggest content block MWL has none of; Jikan and MAL both serve it.
2. **W2 Detail sidebar**: favorites count, producers, licensors, demographic and themes. The page is already downloaded; only the parser and More Info rows are missing.
3. **W3 + A4 Seasonal New vs Continuing**: one field and a grouping; makes the seasonal screen read like MAL's.
4. **W5 + A5 Time left** per entry and per tab in My List.
5. **W4 A user's reviews, recommendations and stacks** on profiles.
6. **W6 MAL XML export / import** of the user's list (portability to other trackers, safety backup).
7. **W7 Trailer from the MAL page** while Jikan is down (zero new requests).
8. **A3 18+ marking** from the entry `nsfw` field.
9. **A1 + A2** `time_zone` key bug and the Supporter badge.
10. **W8 Poll voting** (first of the session writes the MALClient reports missed), then W9.

Next: A6 `suggested@manga`, A7 undocumented value check, A9 extra list fields and filters, W11 title clubs, W12 episode videos feed, W10 blogs, A8 dates.

---

## 7. Unit split (disjoint file sets)

| Unit | Items | Owns | Needs / clashes |
|---|---|---|---|
| `mal-episodes` | W1 | new `lib/services/api/MAL/scrapper/episodes_page.dart`, new `lib/screens/MAL/episodes/episodes_screen.dart`, new `lib/screens/MAL/detail/sections/episodes_section.dart`, `lib/screens/MAL/detail/detail_sections.dart` (register the section), `lib/constants/constants.dart` (append `TabType.Episodes` only), `lib/l10n/units/mal-episodes/` | none; calls `JikanApi.getAnimeEpisodes` and `MalForumApi.getForumTopics` without editing them |
| `mal-detail-sidebar` | W2, W7, A3, A8 | `mwl-api/mwl_commons/lib/src/model/html/anime_detailed_html.dart`, `mwl-api/mwl_commons/lib/src/services/html_parser.dart` (`parseAnimeDetailedHtml` and a new sidebar helper), `mwl-api/test/fixtures/anime_php.html` + `manga_php.html` tests, `lib/widgets/MAL/content/more_info_widget.dart`, `lib/screens/MAL/detail/header/header_meta.dart`, `lib/screens/MAL/detail/sections/media_section.dart` (trailer fallback), `lib/services/api/MAL/mal_anime.dart` (node `nsfw`), `lib/widgets/MAL/home/animegridcard.dart` (18+ corner), `lib/l10n/units/mal-detail-sidebar/` | **Clashes with DAL `jikan-leftovers`** (it owns `mwl-api/mwl_commons/**` and `detail_screen.dart`): run after it, or give it only its new parser files |
| `mal-seasonal-groups` | W3, A4 | `lib/screens/seasonal/seasonal_data.dart`, `lib/screens/seasonal/seasonal_screen.dart`, `lib/screens/seasonal/season_utils.dart`, `lib/l10n/units/mal-seasonal-groups/` | none |
| `mal-list-time` | W5, A5, A9 | `lib/widgets/user/list/mal_user_list_adapter.dart`, `lib/widgets/user/list/list_entry_view.dart`, `lib/widgets/user/list/user_list_view.dart`, `lib/widgets/user/list/card_layout_editor.dart`, `lib/l10n/units/mal-list-time/` | Do not touch `lib/widgets/user/list/cards/*` (DAL `small-fixes`) |
| `mal-profile-extras` | W4, A1, A2, W10 | `lib/services/api/MAL/mal_user_prof.dart`, `lib/services/api/MAL/mal_user.dart`, `lib/screens/user_profile/user_profile_data.dart`, `lib/screens/user_profile/user_profile_view.dart`, `lib/screens/user_profile/sections/profile_tabs_source.dart`, new `lib/screens/user_profile/sections/reviews_section.dart`, `recommendations_section.dart`, `stacks_section.dart`, `lib/widgets/user/profile/profile_header.dart`, `lib/l10n/units/mal-profile-extras/` | DAL `profile-lists` owned `user_profile_view.dart` (looks merged); check it is done |
| `mal-list-xml` | W6 | new `lib/services/list_export/mal_xml.dart`, new `lib/services/list_export/mal_xml_import.dart`, `lib/screens/settings/backup_settings.dart`, `lib/l10n/units/mal-list-xml/` | none (reads lists through `MalApi`, writes through `MalApi.saveAnimeListStatus` / `saveMangaListStatus`, no edits there) |
| `mal-web-writes-2` | W8, W9 | new `lib/services/api/MAL/web/forum_poll_api.dart`, new `lib/services/api/MAL/web/review_write_api.dart`, new `lib/services/api/MAL/web/recommendation_write_api.dart`, `lib/screens/forum/forum_posts_screen.dart` (`_PollCard` only), `lib/widgets/MAL/review/reviews_list_screen.dart`, `lib/screens/MAL/detail/sections/recommendations_section.dart`, `lib/l10n/units/mal-web-writes-2/` | Logged-in request captures first. Clashes with the MALClient "forum reply" unit on `forum_posts_screen.dart`: sequence them |
| `mal-api-small` | A6, A7, W11, W12 | `lib/screens/search/search_queries.dart`, `lib/services/api/MAL/mal_api.dart` (suggestions only), `lib/enums.dart` (only if A7 finds a dead value), new `lib/services/api/MAL/scrapper/title_clubs.dart`, `lib/screens/explore/explore_sections.dart` (W12, only if the promo-videos unit exists) | A7 needs one anonymous call with MWL's client id (owner runs it) |
