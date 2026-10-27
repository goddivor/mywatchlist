# Project state — MyWatchList

Cap: 80 lines. Rewrite in place; history lives in git and `docs/DECISIONS.md`.

## Where we are (2026-10-27)
- Porting every DailyAL feature (ref `upstream/2026.2.6+108`) into MWL, adapted to BLoC + multi-tracker, redesigning weak UI and fixing bugs on the way.
- Work is split into 38 units (`work/INDEX.md`), built in parallel with the multi-agent-build tooling (`tools/mab/`, `tools/mab.config`), coordinated on GitHub (goddivor/mywatchlist, base `dev`, `master` owner-only).

## Gate
- `tools/heavy.sh tools/verify.sh`: pub get, flutter analyze, flutter test, dart analyze mwl-api (machine-wide lock).
- `gate-fix` made it green: the counter test is gone; `flutter test` runs offline smoke tests in about 10 s.
- Test layout: `test/smoke/` + `test/helpers/` (`pumpInApp`, `htmlFixture`, `forbidNetwork`), then `test/units/<unit-id>/` per unit.
- `verify.sh` first runs `tools/l10n/build.sh`: `S` is a build output of `lib/l10n/**` (see CLAUDE.md, Localization).

## Localization (`l10n-pipeline`)
- Base ARBs (DailyAL, 11 locales) frozen in `lib/l10n/`; each unit adds keys in `lib/l10n/units/<unit-id>/`; `tools/l10n/build.sh` merges, validates, generates `lib/generated/l10n.dart` + `intl/` (git-ignored).

## Preferences contract and dependencies (`deps-prefs-contract`)
- `lib/user/preferences/` (barrel `preferences.dart`): `PreferencesBloc` (state `AppPreferences` = `general`, `content`, `list`, `notifications`), one event per group with a `copyWith` updater, `PreferencesReset`, `PreferencesReloaded`; non-widget read `Preferences.current` / `Preferences.general`…; stored as one JSON per group (`prefs_*_v1`), legacy `timezone_pref` migrated.
- Language stays in `LanguageBloc`, theme/font/background in `ThemeBloc`, home layout in `HomePreferencesBloc`; `UserPreference` keeps MWL-only device settings.
- Every dependency of the queued units is in `pubspec.yaml` (pins listed in the PR closing issue #29); manifest has notification, exact alarm, boot, calendar and install-packages permissions, the notification receivers and a FileProvider. `NotificationService.init()` is a no-op stub called from `main`.

## App shell (`app-shell`)
- Cross-unit navigation: `lib/utils/app_routes.dart` (`AppRoutes.openSettings/openSettingsPage(SettingsSection)/openAbout/openBookmarks/openCalendar/openSearch/openUserProfile/openUserStats/openContent/openLogin/openManageAccounts/openSidebar/signInAgain/openFromNotification`); `SettingsSection` (title, description, icon) in `lib/pages/settings/settings_section.dart`.
- Stubs (`ComingSoonPage`): 9 settings pages, bookmarks, calendar, user profile/stats; their units replace the body.
- Home shell: sidebar = end drawer (`AppRoutes.openSidebar` from any tab), startup page pref, only the current tab built unless `keepPagesInMemory` (then lazily kept), "session expired" snackbar for any tracker, notification payload `anime:<id>|manga:<id>|calendar|bookmarks`.
- Back in the shell (`ShellBackScope`, #92): closes the sidebar, then returns to the home tab, then on the home tab asks for a second Back within 2 s before leaving; the sidebar swipe zone is the system back-gesture inset + 24 dp. Signed-in users get "Add an account" in the sidebar (login page in add mode, #88).

## Detail screen (`detail-split`, `detail-header`)
- `lib/screens/MAL/detail/`: `detail_screen.dart`, `detail_data.dart` (immutable snapshot, incl. schedule links and next episode), `detail_sections.dart` (registry in the `ContentPreferences` order, `Dh_Tab_*` labels), `sections/`, `header/`, `actions/`, `tabs_customizer.dart`, `pages/`. `contentdetailedscreen.dart` re-exports it.
- Header (`header/`): fixed extent, 2-line title (long press copies), cover + title language switch + More Info, `ScoreReveal` score, LiveChart countdown chip (pref `showCountdownOnDetail`), faded background (pref `showDetailBackground`). App bar: search, bookmark, overflow (share, browser, More Info, search by genre, customize sections). `Dh_*` strings en + fr_FR. Related (`detail-related-graph`): `RelatedAnimeWidget` (tabs per relation, view-all grid `RelatedGridScreen` with list statuses, graph button for anime) and `AnimeGraphScreen` in `lib/widgets/graph/` (backend `getAnimeGraph`, graphview Sugiyama built once, fixed-size nodes, long-press selects, share as branded PNG through `RepaintBoundary`); strings `Rg_*`. Needs `category: data.category` passed from `related_section.dart` (finding).
## API layer (`api-prefs`)
- Jikan: `JikanClient` (throttle, in-flight sharing, 5 min cache, 429 backoff); MAL: `nsfw=` from the pref (the user's own `/users/@me/animelist|mangalist` always `nsfw=1`, #97), timezone pref in airing helpers, `MalApi.isUnderMaintenance()` (60 s cache) for home wiring, full `MyListStatus` + `save*ListStatus` with text dates.

## Accounts (`accounts-ux`)
- No picker, no "Continue": `AccountBloc` follows `UserManager` (sign in, sign out, dead session) and owns the active account; the first tracker that connects becomes active, signing out of the active one activates the next, `resolveSelection` (`account_selection.dart`) is the pure rule.
- One list everywhere: `AccountsPanel` of `TrackerTile`s (connected = radio, tap switches; expired = "Sign in again"; connecting = Cancel; disconnected = Connect). Used by Settings > Accounts (`ManageAccountsPage` is the same page), the avatar switcher (tap switches and closes), `LoginPage` (first run opens the home by itself; add mode switches to the new account and closes) and the intro page.
- `TrackerActions` (connect, cancel, sign out, switch) is the only caller of the auth classes; Kitsu has its own translated dialog with inline errors; `KitsuAuth.signInWithKitsu` ends any failure unauthenticated (#88). Sign out (`RemoveAccountEvent`) clears that tracker's `ListStatusCache`, `LogoutEvent` all of it (#97).
- One `AuthStatus` (base_user.dart, re-exported by user.dart); `needsReLogin` persists across restarts and `clear()` resets it.
- Strings: `Acc_*` in `lib/l10n/units/accounts-ux/` (en + fr_FR).
## Calendar (`calendar`)
- `CalendarScreen` (`lib/screens/calendar/`, `AppRoutes.openCalendar`): 7-day strip from today, list-status chips (All, Watching, Plan to Watch, 3-state In list / Not in list; hidden with a hint when the active account is not MAL), episode tiles with countdown, "now" rule, add-to-calendar sheet (device calendar with weekly recurrence, `.ics` save or share). Times follow the timezone pref; the app bar menu changes it. Logic in `lib/widgets/calendar/`: `CalendarCubit` (LiveChart schedule joined with the MAL season for covers, episode totals and list status), `calendar_logic.dart` (zones, week grouping, filters), `calendar_ics.dart` (RFC 5545 builder), `calendar_export.dart`. Read API for other units: `AiringSchedule.instance` (`ensureLoaded()`, `nextEpisode(malId)` gives `AiringEpisode` with episode + UTC time, null when unknown so callers keep their estimate).
## Backend (mwl-api)
- `backend-parsers` ported DailyAL's page parsers (`PageParsers`, typed `*Html` models) and routes: `content/characters`, `character|people/*id/pics`, `characters`, `people`, `magazines`, `studios`, `clubs?id=`, `clubs/type`, `search/all`; `reviews`, `users/about` parsed; `schedules` = LiveChart (`source=jikan` for the old proxy).
- Invalid parameters (unknown season, non-numeric id or year, missing `q`/`id`…) answer 400 via `BadRequest` (#72).
- Typed client methods on `MwlApi` (listed in the backend-parsers PR body, issue #27); HTML parsed off the UI isolate.

## Fluidity (`perf-foundation`)
- Baseline home scroll, profile builds: MWL 22-23 % janky frames vs DailyAL 1.6 % (`tools/perf/measure-scroll.sh`, emulator with `-gpu host`).
- Rules and measurement procedure (incl. Impeller vs Skia A/B): `docs/PERFORMANCE.md`. Foundation: high refresh rate, `AppImage` (decode at displayed size), one shared shimmer ticker, MaterialApp rebuilt only on theme/locale, avatars without fade or blurred shadow, viewer without blur.
- Screen-level fixes (home tabs, cards, detail listeners, parsing) belong to their units; cards must switch to `AppImage`.
## Edit sheet (`edit-sheet`)
- `ContentEditWidget` (same constructor) loads the whole MAL `my_list_status` itself (`MalListEntryService`, `lib/widgets/user/edit/`), so dates, priority, rewatch, tags, comments, chapters and volumes are pre-filled exactly; writes go through `MalApi.save*ListStatus` and both list-status models keep dates as MAL text, so a partial date (`2019-03`, `2019`) survives open, save, reopen (#86); load error / dead session / non-MAL account show a message with retry or sign-in, never a spinner.
- Auto dates follow `autoAddStartEndDate` and only fill empty dates; the last episode completes with a finish date, the first one fills the start date; add uses `defaultAnime/MangaAddStatus`; airing shows without total get an estimated episode count (picker bar or stepper).
- Private notes: `PrivateNotesStore` (`lib/user/private_notes/`, SharedPreferences `private_note_v1:<tracker>:<category>:<id>`), `export()`/`import()` for the backup unit; shown when `showPrivateNotes` is on.

## MAL user profile (`user-profile-mal`)
- `AppRoutes.openUserProfile/openUserStats` open `UserProfileScreen` (`lib/screens/user_profile/`) for MyAnimeList (and `none`); other trackers keep the placeholder. `AppRoutes.openUserPop` opens the quick sheet (`showUserPopSheet`, `lib/widgets/user/profile/`). Home profile tab: `MalUserProfilePage` (sign-in prompt when MAL is not connected).
- Data: `UserProfileRepository` (official `/users/@me` for yourself + Jikan `users/{name}/full` for manga numbers and favorites; Jikan alone for others), disk cache `CachedUserProfile` (fresh 1 h, stale 14 days when the network fails).
- Tabs (lazy, kept alive): Stats, Friends, Clubs, About, Favorites, History under a `NestedScrollView`; charts in `lib/widgets/charts/` (fl_chart bars, colors from the stats chart preference). Insights = whole MAL list fetched and reduced off the UI isolate (`UserInsightsLoader`).
- Profile background: picked image kept on this device (`ProfileBackgroundStore`), shown on your own profile only (no server to share it).
## Settings preference pages (`settings-prefs-pages`)
- Tiles in `lib/screens/settings/prefs/` read one contract field (`context.select`), write via the group's `copyWith` event; `Prefs_*` strings (en + fr_FR); "Restore defaults" keeps dub options and card layouts; the card field editor belongs to `user-list-mal`.
## Cross-tracker sync (`sync-dialog`)
- `CrossTrackerWidget` (same constructor) lists the other signed-in trackers; each card loads on its own (link, then entry, in parallel) and offers Link, Edit, Sync, Unlink, Remove. Links are found automatically by MAL id (AniList `idMal`, Kitsu mappings, Simkl `mal:<id>`); unlinking sticks.
- Sync dialog (`lib/widgets/user/sync/sync_dialog.dart`): reads both sides when opened, shows what each would copy, runs MAL to tracker or tracker to MAL, Cancel always available (no write starts after a cancel). Empty fields never erase the target.
- Clients (`tracker_clients.dart`) go through `BaseUser.sendAuthenticated`; AniList scores use `score(format: POINT_10_DECIMAL)` to read and `scoreRaw` to write, Kitsu half points, MAL rounds to whole points. Simkl: anime only, status and score only.
- Editor sheet (`tracker_entry_editor.dart`) edits the tracker's own entry (status, score, progress, volumes, dates) and creates it when absent. Strings: `Sync_*` in `lib/l10n/units/sync-dialog/` (en + fr_FR).

## Explore and seasonal (`explore-seasonal`)
- Explore tab (`lib/pages/MAL/mal_explore_page.dart`, parts in `lib/screens/explore/`): search bar, Anime/Manga switch, random picks, rankings and genre tiles, season card, then Jikan recommendations, reviews, interest stacks, top characters and voice actors; each section loads when it scrolls near, cached 10 min (`ExploreCache`); "View all" pages (`ExploreListScreen`). Seasonal screen (`lib/screens/seasonal/`): whole season fetched once, sorted/filtered on the device with the shared sheet and list cards; shared view when the global seasonal filter pref is on. `lib/cache/top_characters.dart` serves the character screen's favorites. Strings `Explore_*`, `Seasonal_*`.

## Search (`search-upgrade`)
- `lib/screens/search/`: `GeneralSearchScreen` (state + parts `search_logic`, `search_bar_part`, `search_results_part`, `search_active_filters`), `SearchService` (all fetching, no widget), `SearchFilters` (immutable, API values: genre/producer/magazine ids), `SearchCatalog` (current MAL genre, producer and magazine tables in `data/`, name to id), `search_tiles`, `search_home_view`, `search_filter_panel` (kit select widgets, searchable producers/magazines, include/exclude genres).
- Entry points: `GeneralSearchScreen.byQuery/byGenre/byStudio/byMagazine/byTag/bySeason/byRanking/byMangaRanking/bySuggested/byUser`, `AppRoutes.openSearch(query, category, filters)`; the old `filterOutputs:` map still works. User results open the profile (long press: quick sheet); an exact MAL user name shows "User found as"; a numeric query finds the title by id; autocomplete (400 ms) under the field.

## App icon (`app-icon`)
- Android adaptive icon (navy gradient circle, white mwL): layers in `mipmap-*/ic_launcher_{background,foreground,monochrome}.png` and `mipmap-anydpi-v26/ic_launcher(_round).xml`, built from `assets/images/mwl-black-bg.png` by `tools/icon/extract.sh` (sources in `assets/images/app_icon/`). `flutter_launcher_icons` only does legacy and iOS.

## Known big gaps (see inventory)
- No user list / profile for AniList/Kitsu/Simkl (placeholders); no notifications, share, translation.
- MAL dead session (#71): public MAL reads (seasonal, ranking, details, search, other users' lists, forum) fall back to the client id; `/users/@me`, suggestions and list writes throw `MalSessionExpired`. The UI listens to `MalApi.sessionExpired` (`ValueListenable<bool>`); the visible prompt is still to build (accounts-ux / app-shell); the detail screen shows its own error/retry state.
