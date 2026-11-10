# Inventory — DAL commits since 2025-01-01 and backend gaps (vs MWL `dev`, 2026-10-27)

## User-visible DAL commits not (fully) in MWL
| Commit | Date | Subject | MWL | Notes |
|---|---|---|---|---|
| 64e7791 | 2026-05-02 | Hide/show scores (eye icon per card) | MISSING | |
| ce3b001 | 2026-05-02 | Cancel button on sync dialog | MISSING | MWL has no sync dialog (widgets/user/cross_tracker_widget.dart) |
| 7d02a3f | 2026-05-02 | Edit widget infinite loading fix | PARTIAL | widgets/user/contenteditwidget.dart: null `contentDetailed` → spinner forever |
| b490f94, 5f1a965 | 2026-02-21/22 | User list status cache + persistence | MISSING | |
| 704b5b5 | 2026-02-22 | Auto start/end dates on episode count change | PARTIAL | only on status change |
| 6f90a5a | 2026-02-22 | Tappable authors → person page | MISSING | screens/MAL/contentdetailedscreen.dart ~l.1275, widgets/MAL/content/more_info_widget.dart `_getAuthors` |
| c64ccc0, c4f7276, 7c9c165, ce3b001 | 2026-02-21 | Sync dialog with lazy loading, two-way MAL⇄AniList | PARTIAL | MWL: MAL → others only |
| 7ab3460 | 2026-02-21 | Decimal scores, AniList POINT_10_DECIMAL | PARTIAL | tracker_sync_service.dart truncates `.toInt()` |
| 146c681, c42850d | 2026-02-21 | AniList-native status editor / list editing | MISSING/PARTIAL | |
| 820a295, 92cc38d | 2026-02 | Notifications reschedule / hotfix | MISSING | |
| 87c318a | 2026-02-20 | Global seasonal filter | MISSING | |
| bd376af, 1871053 | 2026-02-15/16 | In-app update download/install | MISSING | |
| 024654e, 399851c | 2026-02-16 | Tap serialization → magazine filter; dynamic studios | PARTIAL | |
| e773650 | 2026-02-14 | Private notes (+backup), graph node select, share graph image, .ics export | MISSING | |
| 970111b | 2026-02-02 | Desktop, clear storage, CharacterVATile, startup page, "All" schedule filter | PARTIAL | **BUG** calendar button no-op: pages/MAL/mal_home_page.dart:224 `onCalendarTap: () {}` |
| db3355e | 2026-01-23 | Search by id, dubs, tablet NavigationRail, calendar, 3-state "in list" filter, related graph toggle | PARTIAL | clubs, score stats, video fallback ported; graph stub `_setAnimeGraph() async {}` in relatedanimewidget.dart |
| 6f75ed3 | 2025-10-21 | Dub languages, top characters, bookmark/info button | MISSING | |
| 17dd437 | 2025-08-16 | Add-to-calendar, dub icon, default add-to-list status | PARTIAL | contenteditwidget hardcodes `plan_to_watch` |
| bf06d05 | 2025-07-23 | Top characters list | MISSING | |
| 1d1f930 | 2025-07-23 | Rate-limit (429) handling + caching | MISSING | services/api/Jikan/jikan_api.dart |
| 01d7daf | 2025-07-22 | Character screen sort selector + dedupe | PARTIAL | screens/MAL/characters_staff_screen.dart |
| 2f6b9da, 3f89382, fe88690 | 2025-07-21 | HTML entity decode in comments/tags | MISSING | |
| e7eef19, b5f1e8d | 2025-05 | Total episodes for airing shows in edit widget | MISSING | `maxEp = numEpisodes` |
| 3b0346f | 2025-05-25 | Tablet layout | MISSING | |
| da37082, 6b2aafd, fa2fb68, 3f1f0fd, 158e206 | 2025-03/05 | Search autocomplete (backend cache, synonyms, throttle) | MISSING | |
| ee084b6 | 2025-03-23 | Comments popup editor | MISSING | |

Already PORTED / N-A: AniList sign-in (MWL native, broader), producers dropdown, recommendation count, characters sort by favourites, fonts, ContentListWidget subtype, black theme.

## Backend gaps (DAL dal-api / dal_commons → MWL mwl-api / mwl_commons)
| Area | Gap |
|---|---|
| Rust API | same 7 routes; MWL client has `getAnimeGraph`, `getReviewsSummary` (lib/services/api/mwl_api.dart) with no UI caller |
| Dart routes missing | `content/characters`, `character/*id/pics`, `people/*id/pics`, `characters`, `people` (home), `magazines`, `studios`, `clubs/type` |
| Different source | `character/*id`, `people/*id` (Jikan proxy); `schedules` (Jikan vs LiveChart parser) |
| Partial | `reviews` returns raw text (no parser); `users/about` raw text |
| mwl_commons parsers missing | parseCharacterAllPage, parseCharacterPage, parseCharacterPeopleHome, parseMagazines, parseClubPage/_getClubDetails, parseClubPageViewAll, parseLiveChartSchedule, parseUserAboutPage, allSearchResultFromHtml, forumHtmlFromHtml, animeReviewHtmlfromHtml |
| MWL-only | `users/search`, `stacks/detail`, `stacks/content`, `content/featured` |
