# Inventory — screens & pages (DAL `upstream/2026.2.6+108` vs MWL `dev`, 2026-10-27)

**Every feature below exists in MWL for MAL only.** AniList, Kitsu and Simkl Home/Forum/List/Profile/Explore tabs are empty placeholder pages (`lib/pages/{Anilist,Kitsu,Simkl}/*.dart`); they only get the cross-tracker sync panel and onboarding.

## Detail screen (lib/screens/MAL/contentdetailedscreen.dart)
| Feature | Status | Notes |
|---|---|---|
| Header, title language switch, cover zoom | PARTIAL | **BUG** info button no-op (:1104). No hide-score/tap-to-reveal. No tablet two-pane. |
| App bar: search, share, browser, bookmark, More Info, genre search, customize tabs | MISSING | **BUG** search icon no-op (:939). No bookmarks anywhere. |
| Customizable/reorderable sections | MISSING | fixed `TabType.values` (:384) |
| Edit sheet | PARTIAL | no private note |
| Synopsis | PARTIAL | no translation, no next-episode countdown |
| Media platforms | PARTIAL | **BUG** `_scheduleData` never assigned (widgets/MAL/content/media_platforms.dart:125, used :482) |
| Videos / songs | PORTED | no fallback image |
| Related | PARTIAL | no view-all grid with statuses, no relation graph (stub), no menu |
| Reviews | PARTIAL | no AI summary, no share; **BUG** reviewer tap TODO (widgets/MAL/review/review_detail_page.dart:92) |
| Recommendations, adaptations, pictures, news/featured, stats, score stats, characters/staff, forums | PORTED | minor: missing share/bookmark/browser menus on full screens |
| Interest stacks | PORTED | **BUG** username tap no-op (intereststackwidget.dart:195) |
| User updates | PARTIAL | **BUG** user/avatar tap no-op (userupdate_widget.dart:91,107) |
| More info modal + links | PARTIAL | modal unreachable; studio/genre taps are TODO prints (more_info_widget.dart:111,238); no magazine/author/season/media-type links |
| **BUG** lifecycle | — | `super.dispose()` before own controllers (:159); scroll listener re-added on every `updateVisibleSections()` (:338) |

## Character / person (lib/screens/MAL/character_screen.dart) — PARTIAL
No bookmark FAB, no share, no sort voice roles by favorites.

## Featured article (lib/screens/MAL/featured_screen.dart) — PARTIAL
**BUG** tags not tappable (`onTap: null`, :281); DAL opens tag search.

## Forum — PORTED (MAL)
Posts: **BUG** reply FAB only copies URL (forum_posts_screen.dart:117-126), DAL opens webview to post; avatar tap doesn't open profile (post_widget.dart:346). No tablet layout.

## Clubs — PORTED (MAL)
Members/staff open browser because there is no in-app user profile.

## Search (lib/screens/search/general_search_screen.dart) — PARTIAL
**BUG** user result tap TODO (:2227); `_SeasonalSection._maxYear` hard-coded 2027 (:3643).

## Explore
| Feature | Status |
|---|---|
| Rankings | PORTED |
| Genres grid | PARTIAL (filter modal only) |
| Random pickers (random / watching / PTW) | MISSING |
| Weekly schedule / calendar | MISSING |
| Global recommendations, reviews, interest stacks, top characters, top seiyuu | MISSING |
| Seasonal screen (switcher, header, sort/filter) | PARTIAL (season query only) |

## Home (lib/pages/MAL/mal_home_page.dart)
| Feature | Status | Notes |
|---|---|---|
| Sections | PARTIAL | no user-list section, no forum section |
| Top chips (Categories, Genres, Top…, Popular) | MISSING | **BUG** all `() {}` (:44-52) |
| Bookmarks / Calendar buttons | MISSING | **BUG** `() {}` (:222-223) |
| MAL maintenance dialog | MISSING | API exists (mal_api.dart:1067), unused |
| Shell (lib/screens/home_screen.dart) | PARTIAL | no NavigationRail, no startup page, no deep-link/notification routing |

## User list / profile — MISSING for all 4 trackers
User list (status tabs, sort/filter), user profile (about, favorites, friends, clubs, history, stats), user pop-up sheet: placeholders only (`lib/pages/*/*_user_page.dart`, `*_user_profile_page.dart`).

## Sidebar (lib/pages/side_bar.dart) — PARTIAL, **BUG** never shown
`AppSidebar` only built by `SidebarBuilder`, which nothing calls. About just pops (:278-286).

## Startup
Open screen: **BUG** shows `loadingError()` instead of a loader while loading (open_screen.dart:45). Intro: PORTED (multi-tracker).
