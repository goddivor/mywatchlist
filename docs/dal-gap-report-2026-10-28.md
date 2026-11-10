# DailyAL vs MyWatchList: feature-gap audit

Reference: DailyAL `/home/thinkpad/.cache/mwl-mab/dailyal-108` (HEAD 64e7791 "Add option to hide/show scores").
MyWatchList: `origin/dev` at 2a91650 (= local `dev`).
Classes: DONE (counted only), PARTIAL, MISSING, BROKEN-WITHOUT-JIKAN (BWJ).
Paths: DAL paths are relative to the DailyAL repo, MWL paths relative to the MWL repo.

_Status: complete._

## Context found before the audit

- All 59 queued units but two are done (`l10n-quality`, `color-sweep` are todo; `color-sweep` is in `.wt/115`).
- Branch `origin/fix/fix-char` (not merged, `.wt/fix-char`) adds `lib/services/api/MAL/scrapper/character_page.dart` and makes `character_screen.dart` read MAL's character/person pages when Jikan is down. Items below that it covers are marked "in flight".
- DailyAL itself also depends on Jikan in places (its backend proxies `characters/{id}/full`, its random picker calls `jikan/random`); the BWJ class below is about MWL today, whatever DailyAL does.

## Profile / social

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| P1 | Another user's anime/manga **list** (the "List" tab / button of a profile and of the user pop-up) | MISSING | `lib/screens/user_profile.dart:370-380`, `lib/pages/userpop.dart:67-77` (`UserPage(username: ...)`) | none: `UserProfileTab` = stats, friends, clubs, about, favorites, history (`lib/screens/user_profile/user_profile_view.dart:24`); `MalUserListAdapter` is `@me` only (`lib/widgets/user/list/mal_user_list_adapter.dart:34`) | No way to browse a friend's or a forum user's list; MAL's `users/{name}/animelist` works with the client id. | M |
| P2 | "Weekly anime" tab on your own profile (your list grouped by broadcast weekday) | MISSING | `lib/pages/userpage.dart:232-234`, `lib/widgets/user/weeklyanime.dart:141` | none (the Calendar screen is the closest) | No weekday view of the user's own titles inside the profile/list. | S (if P2 reuses W1) |
| P3 | "Details expanded" preference (profile header expanded or collapsed on open) | PARTIAL (dead pref) | `lib/pages/userpage.dart:228` | tile in `lib/screens/settings/user_prefs_settings.dart:143`, never read | The switch does nothing. Either wire it to the profile header or remove the tile. | S |
| P4 | Profile background shared with other users (DAL uploads it to its server: `user-bgs`) | PARTIAL (by decision) | `lib/pages/side_bar.dart:57-65`, `lib/api/dalapi.dart:480-520` | `ProfileBackgroundStore` device-only (PROJECT-STATE "Profile background") | Others never see your background; needs a server, so keep as a known limitation unless mwl-api gets storage. | L |

## Home

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| H1 | Update check at launch (dialog once per release, skipped on F-Droid builds) | MISSING | `lib/screens/homescreen.dart:104,242-269` | update check only in About (`lib/screens/settings/about_settings.dart:43`); no caller in the shell | Users never hear about a new release unless they open About. `ReleaseService` and `update_dialog.dart` already exist. | S |
| H2 | Items per home row above 15 | PARTIAL (bug) | `lib/pages/settings/homepagesettings.dart:30,155-180` (14/18/24/28) | slider 5-30 (`lib/screens/settings/mal_home_settings.dart:711-716`) but every ranking/suggested row is fetched with `limit: 15` (`lib/user/requests/requests_bloc.dart:388-633`); the page only truncates (`lib/pages/MAL/mal_home_page.dart:367`) | Picking 20, 25 or 30 still shows 15 titles on ranking, upcoming, airing and suggested rows. | S |
| H3 | Ranking rows for every MAL ranking type (OVA, ONA; manga: novels, light novels, one-shots, manhwa, manhua, doujin, favourites) | PARTIAL | `lib/enums.dart:116-124,252-263` (types offered by `homepagesettings.dart:332-340`) | `SectionType` has no OVA/ONA nor manga sub-rankings (`lib/user/MAL/mal_home_page_preferences.dart:13-30`) | Home rows cannot show Top OVA/ONA or manhwa/manhua/novel rankings. Append kinds only (the index is stored). | S |
| H4 | News, featured articles and the MAL forum on the home/forum tab while the active account is Kitsu or Simkl | PARTIAL (by decision) | DAL shows them signed out too (public MAL data) | skipped by decision (DECISIONS 2026-10-28 kitsu-pages, simkl-pages); `lib/pages/Kitsu/kitsu_forum_page.dart:9-35`, `lib/pages/Simkl/simkl_forum_page.dart:7-23` show "no forum" | A Kitsu/Simkl user loses news, articles and the forum although they need no MAL login. Owner call: reuse the MAL rows/forum with the client id. | M |

DONE in this area (counted): chips bar and rankings grid, app bar (search, bookmarks, calendar, settings, account), reorderable sections with add/edit/reset, tile size, user-list/forum/fixed-season rows, maintenance dialog, first-run showcase, startup page, keep pages in memory, custom background, pull to refresh, sidebar (12).

## My list

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| L1 | Manga status tab counts | BWJ | MAL API has no manga statistics; DAL reads them from Jikan too | `lib/widgets/user/list/mal_user_list_adapter.dart:160-175` (Jikan `users/{name}/statistics` only) | Without Jikan the manga tabs show no counts; the MAL profile page parser (`lib/services/api/MAL/scrapper/user_profile_page.dart`) already has the manga numbers. | S |
| L2 | Dub icon on My List tiles and search tiles | PARTIAL | `lib/widgets/user/contentlistwidget.dart:779,995,1203` | only `lib/widgets/MAL/home/animegridcard.dart` draws `DubIcon`; none in `lib/widgets/user/list/cards/*` nor `lib/screens/search/search_tiles.dart` | "Show dub icon" has no effect in My List (grid, list, custom cards) and search lists. | S |

DONE (counted): status tabs, last-opened tab, sort/filter popup, display types (list, grid comfortable/compact/cover, horizontal), grid size sliders, custom card profiles, priority and airing info, +1/-1, quick edit, status cache, random from list, AniList list source (via active account) (13).

## Detail screen

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| D1 | Videos (PVs, episode videos, music videos) in the Media section | BWJ | `lib/screens/contentdetailedscreen.dart:240-243` (Jikan) | `lib/screens/MAL/detail/detail_screen.dart:190-199`: Jikan only, error swallowed | Without Jikan the Media section shows themes only; add a mwl-api parser of `/anime/<id>/_/video` and race it (`JikanFallbacks.race`). | M |
| D2 | User updates ("recent list updates by other users") | BWJ | `lib/pages/animedetailed/userupdates.dart` (Jikan) | `lib/widgets/MAL/content/userupdate_widget.dart:41-42` Jikan only, no race | Section ends in an error while Jikan is down; MAL's `/<category>/<id>/_/stats` page (already fetched by `content/stats`) lists the recent updates, so the parser can be extended. | S-M |
| D3 | Bookmark from forum topic, user profile, club, featured/news article and interest stack screens | PARTIAL | `BookMarkFloatingButton` in `lib/screens/forumposts.dart`, `lib/screens/user_profile.dart:321`, `lib/screens/clubscreen.dart:149`, `lib/screens/featurescreen.dart:69`, `lib/pages/animedetailed/intereststackwidget.dart:383` | `BookmarkButton` only in `lib/screens/MAL/detail/actions/detail_actions.dart` and `lib/screens/MAL/character_screen.dart`; `BookmarkKind` has `forumTopic` and `user` but nothing creates them (`lib/cache/bookmarks.dart:7`); club, article, stack kinds left out (DECISIONS 2026-10-27 bookmarks) | Five screens cannot be bookmarked; forum/user kinds are dead code. | M |
| D4 | Character and person pages | BWJ (in flight) | `lib/screens/characterscreen.dart:78,111` (DAL backend proxies Jikan) | `lib/screens/MAL/character_screen.dart:252-371` Jikan only; mwl-api `character/*id`, `people/*id` proxy Jikan too (`mwl-api/lib/handlers/handler_core.dart:413-432`) | Fixed on `origin/fix/fix-char` (MAL page scraper), not merged yet: merge it, then point the mwl-api routes at the same parser. | S (merge) |

DONE (counted): header, countdown, hide score, title language switch, share/browser/More Info/search by genre/customize sections, synopsis + translation, themes, related + graph + view-all, recommendations (with counts), characters/staff + full list (raced), pictures, stats, score stats (raced), reviews + AI summary + share (raced), forums (raced), news (raced), featured, interest stacks, adaptations, more-info links, streaming links, private notes, cross-tracker card (23).

## Edit sheet

No gap. DONE (counted): status, score with labels, episodes/chapters/volumes with airing estimate, start/finish dates with auto-fill, priority, rewatch/reread count and value, tags, comments, delete with confirmation, private note, MAL partial dates, AniList/Kitsu/Simkl editor, two-way sync dialog with cancel (13).

## Explore / search

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| E1 | Random anime/manga ("Random" button) | BWJ | `lib/pages/explorepage.dart:429`, `lib/api/dalapi.dart:170-183` (Jikan, as in DAL) | `lib/screens/explore/explore_data.dart:409-420` (Jikan `random/`, no fallback); "random from my list" works (`:422`) | Without Jikan the random pick fails; fallback: a random page of a MAL ranking (`ranking?offset=rand`) or of `topanime.php`. | S |
| E2 | Report a community recommendation | MISSING | `lib/pages/explorepage.dart:762-772` (`dbchanges.php?go=reportanimerecommendation&id=`) | none in `lib/screens/explore/explore_sections.dart` | No "Report" action on recommendation cards. | S |
| E3 | "User found as" shortcut in search | BWJ (minor) | DAL: `lib/api/maluser.dart:238` (MAL search) | `lib/screens/search/search_service.dart:586-598` (Jikan `users/{name}` probe, null on failure) | The exact-name shortcut silently disappears without Jikan; the user list itself works (MAL `users.php`). Probe `myanimelist.net/profile/<name>` (HEAD) instead. | S |

DONE (counted): search bar with history and recents, Anime/Manga switch, categories and rankings cards with DailyAL pictures, genres with counts and explicit genres, seasonal picker, recommendations/reviews/stacks feeds with fallbacks, top characters and people with favourites, search by id, autocomplete, typed filters (genres, studios, magazines, dates, score, status, rating, type), user/club/article/stack search, studios directory, featured tags (14).

## Seasonal / calendar

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| W1 | Weekly anime of a chosen season (MAL `broadcast` weekday tabs Mon..Sun + Unknown, sort by score/members/scorers, filter by list status incl. "Not in list", display types) | MISSING | `lib/widgets/user/weeklyanime.dart:1-140` (`WeeklySchedulePage(seasonType, year)`), opened from `lib/pages/search/seasonalwidget.dart:94-103`; data `lib/api/malapi.dart:287` `getSchedule` | the "Weekly anime" buttons open the LiveChart calendar of the next 7 days (`lib/screens/explore/explore_sections.dart:455-458`, `lib/screens/seasonal/seasonal_screen.dart:159-163`); `MalApi.getSchedule` exists but has no caller (`lib/services/api/MAL/mal_api.dart:1071`) | The picked season and year are ignored, and past/next seasons have no weekday view. | M |

DONE (counted): seasonal screen with season/year switch, sort/filter/display, global seasonal filter, calendar (7-day strip, status chips, countdown, now line, timezone, add to device calendar with recurrence, .ics save/share) (5).

## Forum / clubs

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| F1 | "Show only the last quote" | PARTIAL (dead pref) | `lib/widgets/forum/postwidget.dart:461-463` | tile in `lib/screens/settings/user_prefs_settings.dart:209`; `lib/widgets/forum/post_widget.dart` never reads `showOnlyLastQuote` (quotes parsed at `:187-235`, always all shown) | The switch does nothing; nested quote chains stay long. | S |

DONE (counted): boards, sub-boards, topic lists with paging, search topics, posts with BBCode, spoilers, polls, sort newest/oldest, copy, signature, report post/user, in-app reply, club list, club page, members, comments, club forum, profile links from posts (17).

## Profile / social (continued)

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| P5 | Sidebar shortcuts to Friends, Clubs, Favorites, History | PARTIAL | `lib/pages/side_bar.dart:114-123` | `lib/pages/side_bar.dart` has Profile and Stats only; `AppRoutes.openUserProfile` takes no tab (`lib/utils/app_routes.dart:147-151`) though `UserProfileView` has `initialTab` | Four one-tap entries of DailyAL's sidebar are gone. | S |

DONE (counted): own and other profiles (MAL page fallback), header, stats charts and insights (genres, studios, authors, sources, media, score compare, above mean), friends, clubs, about with edit link, favourites, history, user pop-up sheet, report user, open in browser, local profile background (13).

## Notifications

No gap. DONE (counted): watching and plan-to-watch airing reminders from LiveChart, large image, permission request, test notification, clear and reschedule, open from notification, every tracker via the active account (7).

## Settings

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| S1 | Dead preference tiles (see P3 `detailsExpanded`, F1 `showOnlyLastQuote`); `NotificationPreferences.dailyReleases` has no tile and no reader (`lib/user/preferences/notification_preferences.dart:10`, also unused in DAL) | PARTIAL | — | see P3, F1 | Two visible switches do nothing. Group with P3 and F1. | S |

DONE (counted): settings hub, theme (mode, accent with seasons, Material You, custom colours, background, font), language (11 locales, follow system), user prefs (title language, startup page, NSFW, card background, YouTube player, keep pages, priority, auto translate, auto dates, airing info, chart colours, link type, display type), anime/manga (countdown, background, private notes, hide score, global seasonal filter, timezone, default add status, custom tabs), list prefs, home settings, dub settings, notifications, accounts, storage, downloads, about with in-app update (12 pages).
Not applicable: DAL's debug-only cache frequency page (`lib/pages/settings_page.dart:395`), "Buy me a copy", Play Store "Rate & review".

## Backup / storage

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| B1 | Search history and recently opened titles in the backup | PARTIAL | DAL backs up the whole cache store (`lib/pages/settings/backup_restore.dart:27`, `CacheManager.getBackUpData`) incl. `HistoryData` (`lib/cache/history_data.dart:19`) | `BackupService.settingsKeys`/`settingsPrefixes` (`lib/cache/cachemanager.dart:327-352`) omit `search_query_history`, `search_recent_anime`, `search_recent_manga`, `search_display_*` (`lib/screens/search/search_history.dart:11-17`) | A restore loses search history, recents and the search display choice. | S |

DONE (counted): save to Downloads, share, restore with review sheet, merge/replace, all-or-nothing validation, bookmarks, private notes, settings, storage clearing (9).

## Sharing / deep links

No gap. DONE (counted): share content/review/list items/graph PNG/images, open in browser, myanimelist.net links for anime, manga, character, people, profile, forum topic/board, clubs, news, featured, search, genre/producer/magazine/season, OAuth redirect (5).

## Misc / platform

| # | Item | Class | DAL | MWL | Missing | Effort |
|---|---|---|---|---|---|---|
| M1 | Remote crash/error reporting (opt-in by server config) | MISSING | `lib/util/error/error_reporting.dart:1-60`, `lib/main.dart:53` | none (remote config and feature flags exist: `lib/services/api/mwl_api.dart:20-70,960`) | No field errors reach the developer; needs an endpoint in mwl-api or mwl-rust-api and a privacy note. | M |
| M2 | Tablet/large-screen layout (navigation rail, tablet startup page), Linux tray, Windows MSIX | out of scope | `lib/util/responsive_helper.dart`, `lib/util/linux_desktop_helper.dart`, `lib/screens/homescreen.dart:301` | none | Out of scope by decision (DECISIONS 2026-10-27 orchestrator). Not counted. | — |

DONE (counted): onboarding (language, theme, trackers), launch splash, adaptive icon, release CI and in-app APK update, image preview save/share, MyDubList data, top characters cache, relation graph, translator, remote config/feature flags, maintenance probe (11).

## Proposed units (disjoint file sets)

| Unit | Items | Owns (files) | Needs |
|---|---|---|---|
| `profile-lists` | P1, P2, P3, P5, L1, profile part of D3 | `lib/screens/user_profile/user_profile_view.dart`, new `lib/screens/user_profile/sections/list_section.dart` and `weekly_section.dart`, `lib/widgets/user/list/mal_user_list_adapter.dart` (username + manga counts from `user_profile_page.dart` data), `lib/widgets/user/profile/user_pop_sheet.dart`, `lib/pages/side_bar.dart`, `lib/utils/app_routes.dart` (tab argument), `lib/l10n/units/profile-lists/` | `explore-weekly` (for P2's weekday widget) |
| `explore-weekly` | W1, E1, E2 | new `lib/screens/weekly/weekly_schedule_screen.dart`, `lib/screens/explore/explore_sections.dart`, `lib/screens/explore/explore_data.dart`, `lib/screens/explore/random_picker.dart`, `lib/screens/seasonal/seasonal_screen.dart`, `lib/services/api/MAL/mal_api.dart` (`getSchedule` only), `lib/l10n/units/explore-weekly/` | none |
| `jikan-leftovers` | D1, D2, D4 (mwl-api side), E3 | `lib/screens/MAL/detail/detail_screen.dart` (`_loadVideos`), `lib/widgets/MAL/content/userupdate_widget.dart`, `lib/services/api/Jikan/jikan_fallbacks.dart`, `lib/services/api/mwl_api.dart`, `mwl-api/lib/handlers/handler_core.dart`, `mwl-api/mwl_commons/**` (video and user-updates parsers), `lib/screens/search/search_service.dart` (`_probeUser`) | merge `origin/fix/fix-char` first |
| `bookmarks-everywhere` | D3 (except profile) | `lib/cache/bookmarks.dart` (append club, article, stack kinds), `lib/widgets/bookmarks/**`, `lib/screens/bookmarks_screen.dart`, `lib/screens/forum/forum_posts_screen.dart`, `lib/screens/forum/club_screen.dart`, `lib/screens/MAL/featured_screen.dart`, `lib/screens/MAL/interest_stack_detail_screen.dart`, `lib/l10n/units/bookmarks-everywhere/` | none (`profile-lists` adds the profile button with the existing `user` kind) |
| `home-rows` | H2, H3 | `lib/user/requests/requests_bloc.dart`, `lib/user/MAL/mal_home_page_preferences.dart`, `lib/pages/MAL/mal_home_page.dart`, `lib/screens/settings/mal_home_settings.dart`, `lib/l10n/units/home-rows/` | none |
| `launch-update-check` | H1 | `lib/screens/home_screen.dart`, `lib/services/updater/update_controller.dart`, `lib/l10n/units/launch-update-check/` | none |
| `small-fixes` | F1, L2, B1, S1 (`dailyReleases`) | `lib/widgets/forum/post_widget.dart`, `lib/widgets/user/list/cards/entry_parts.dart`, `lib/widgets/user/list/cards/entry_cards.dart`, `lib/screens/search/search_tiles.dart`, `lib/cache/cachemanager.dart` (backup keys), `lib/user/preferences/notification_preferences.dart` | none |
| `tracker-public-mal` (owner decision first) | H4 | `lib/pages/Kitsu/kitsu_home_page.dart`, `lib/pages/Kitsu/kitsu_forum_page.dart`, `lib/widgets/Simkl/simkl_home_plan.dart`, `lib/pages/Simkl/simkl_forum_page.dart`, `lib/pages/Simkl/simkl_home_page.dart` | owner decision (it reverses two 2026-10-28 decisions) |
| `error-reporting` (optional) | M1 | `lib/main.dart`, new `lib/services/error_reporting.dart`, `mwl-rust-api/src/**` (endpoint) | owner decision (privacy) |
| deferred | P4 | server storage for profile backgrounds | a backend with storage |

`l10n-quality` should be re-sequenced after these units (it waits for every unit).

## Counts

| Class | Count | Items |
|---|---|---|
| DONE | 154 | counted per area above |
| PARTIAL | 10 | P3, P4, P5, H2, H3, H4, L2, D3, F1, B1 (S1 only points at P3/F1 plus the unused `dailyReleases`, not counted again) |
| MISSING | 6 | P1, P2, H1, E2, W1, M1 |
| BROKEN-WITHOUT-JIKAN | 6 | L1, D1, D2, D4 (fix in flight), E1, E3 |
| Out of scope | 1 group | M2 (tablet, Linux tray, MSIX) |

## Top 10 by user impact

1. **D4** Character and person pages fail while Jikan is down: merge `origin/fix/fix-char` (already built), then repoint mwl-api's `character/*id` and `people/*id`.
2. **P1** You cannot open another user's anime/manga list (friends, forum posters, search results).
3. **D1** No videos/PVs on any anime without Jikan.
4. **E1** Explore "Random" fails without Jikan.
5. **D2** "User updates" section errors without Jikan.
6. **W1** "Weekly anime" ignores the chosen season: no weekday view of a past or next season, no "Not in list" filter.
7. **L1** Manga status tabs lose their counts without Jikan.
8. **H1** No update prompt at launch: users stay on old builds.
9. **D3** Forum topics, profiles, clubs, articles and stacks cannot be bookmarked.
10. **H2** Home rows set above 15 items still show 15 (ranking and suggested rows).

Next after the top 10: L2 dub icon missing in My List and search, F1/P3 switches that do nothing, B1 search history missing from backups, H3 extra ranking rows, P5 sidebar shortcuts, E2 report recommendation, E3 user shortcut, H4 (owner decision), M1, P4.
