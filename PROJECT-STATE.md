# Project state — MyWatchList

Cap: 80 lines. Rewrite in place; history lives in git and `docs/DECISIONS.md`.

## Where we are (2026-10-27)
- Porting every DailyAL feature (ref `upstream/2026.2.6+108`) into MWL, adapted to BLoC + multi-tracker, redesigning weak UI and fixing bugs on the way.
- Work is split into 38 units (`work/INDEX.md`), built in parallel with the multi-agent-build tooling (`tools/mab/`, `tools/mab.config`), coordinated on GitHub (goddivor/mywatchlist, base `dev`, `master` owner-only).
- Inventory of what MWL has vs DAL, with the bugs found: `work/inventory/*.md`.

## Gate
- `tools/heavy.sh tools/verify.sh`: pub get, flutter analyze, flutter test, dart analyze mwl-api (machine-wide lock).
- `gate-fix` made it green: the counter test is gone; `flutter test` runs offline smoke tests in about 10 s.
- Test layout: `test/smoke/` + `test/helpers/` (`pumpInApp`, `htmlFixture`, `forbidNetwork`), then `test/units/<unit-id>/` per unit.
- `verify.sh` first runs `tools/l10n/build.sh`: `S` is a build output of `lib/l10n/**` (see CLAUDE.md, Localization).

## Localization (`l10n-pipeline`)
- Base ARBs (DailyAL, 11 locales) frozen in `lib/l10n/`; each unit adds keys in `lib/l10n/units/<unit-id>/`; `tools/l10n/build.sh` merges, validates, generates `lib/generated/l10n.dart` + `intl/` (git-ignored).
- Language picker fixed: 11 locales + "follow the device", applied immediately and at startup, Arabic RTL.

## Preferences contract and dependencies (`deps-prefs-contract`)
- `lib/user/preferences/` (barrel `preferences.dart`): `PreferencesBloc` (state `AppPreferences` = `general`, `content`, `list`, `notifications`), one event per group with a `copyWith` updater, `PreferencesReset`, `PreferencesReloaded`; non-widget read `Preferences.current` / `Preferences.general`…; stored as one JSON per group (`prefs_*_v1`), legacy `timezone_pref` migrated.
- Language stays in `LanguageBloc`, theme/font/background in `ThemeBloc`, home layout in `HomePreferencesBloc`; `UserPreference` keeps MWL-only device settings.
- Every dependency of the queued units is in `pubspec.yaml` (pins listed in the PR closing issue #29); manifest has notification, exact alarm, boot, calendar and install-packages permissions, the notification receivers and a FileProvider. `NotificationService.init()` is a no-op stub called from `main`.

## App shell (`app-shell`)
- Cross-unit navigation: `lib/utils/app_routes.dart` (`AppRoutes.openSettings/openSettingsPage(SettingsSection)/openAbout/openBookmarks/openCalendar/openSearch/openUserProfile/openUserStats/openContent/openLogin/openManageAccounts/openSidebar/signInAgain/openFromNotification`); `SettingsSection` (title, description, icon) in `lib/pages/settings/settings_section.dart`.
- Stubs (`ComingSoonPage`): 9 settings pages, bookmarks, calendar, user profile/stats; their units replace the body.
- Home shell: sidebar = end drawer (`AppRoutes.openSidebar` from any tab), startup page pref, only the current tab built unless `keepPagesInMemory` (then lazily kept), "session expired" snackbar for any tracker, notification payload `anime:<id>|manga:<id>|calendar|bookmarks`.

## Detail screen (`detail-split`)
- `lib/screens/MAL/detail/`: `detail_screen.dart` (scaffold, loading, scroll/tab sync), `detail_data.dart` (immutable snapshot), `detail_sections.dart` (registry in the `ContentPreferences` tab order), `sections/` (one builder per `TabType`), `header/`, `actions/` (search + empty share/browser/bookmark/menu extension points), `pages/` (full recommendations, all interest stacks). `contentdetailedscreen.dart` re-exports it.
- Error + retry state when MAL details fail; More Info modal on the cover; preferred title from `Preferences.general`.
## API layer (`api-prefs`)
- Jikan: `JikanClient` (throttle, in-flight sharing, 5 min cache, 429 backoff); MAL: `nsfw=` from the pref, timezone pref in airing helpers, `MalApi.isUnderMaintenance()` (60 s cache) for home wiring, full `MyListStatus` + `save*ListStatus` with text dates.

## Accounts (`accounts-ux`)
- No picker, no "Continue": `AccountBloc` follows `UserManager` (sign in, sign out, dead session) and owns the active account; the first tracker that connects becomes active, signing out of the active one activates the next, `resolveSelection` (`account_selection.dart`) is the pure rule.
- One list everywhere: `AccountsPanel` of `TrackerTile`s (connected = radio, tap switches; expired = "Sign in again"; connecting = Cancel; disconnected = Connect). Used by Settings > Accounts (`ManageAccountsPage` is the same page), the avatar switcher (tap switches and closes), `LoginPage` (first run opens the home by itself; add mode switches to the new account and closes) and the intro page.
- `TrackerActions` (connect, cancel, sign out, switch) is the only caller of the auth classes; Kitsu has its own translated dialog with inline errors.
- One `AuthStatus` (base_user.dart, re-exported by user.dart); `needsReLogin` persists across restarts and `clear()` resets it.
- Strings: `Acc_*` in `lib/l10n/units/accounts-ux/` (en + fr_FR).

## Waves (from `node tools/mab/plan-waves.mjs`)
1. gate-fix
2. auth-refresh, backend-parsers, l10n-pipeline
3. deps-prefs-contract
4. app-shell, detail-split, shared-kit, perf-foundation, edit-sheet, api-prefs, versioning-ci
5+. features (user list/profile, detail, discovery, settings, community), then other trackers.

## Backend (mwl-api)
- `backend-parsers` ported DailyAL's page parsers (`PageParsers`, typed `*Html` models) and routes: `content/characters`, `character|people/*id/pics`, `characters`, `people`, `magazines`, `studios`, `clubs?id=`, `clubs/type`, `search/all`; `reviews`, `users/about` parsed; `schedules` = LiveChart (`source=jikan` for the old proxy).
- Invalid parameters (unknown season, non-numeric id or year, missing `q`/`id`…) answer 400 via `BadRequest` (#72).
- Typed client methods on `MwlApi` (listed in the backend-parsers PR body, issue #27); HTML parsed off the UI isolate.

## Fluidity (`perf-foundation`)
- Baseline home scroll, profile builds: MWL 22-23 % janky frames vs DailyAL 1.6 % (`tools/perf/measure-scroll.sh`, emulator with `-gpu host`).
- Rules and measurement procedure (incl. Impeller vs Skia A/B): `docs/PERFORMANCE.md`. Foundation: high refresh rate, `AppImage` (decode at displayed size), one shared shimmer ticker, MaterialApp rebuilt only on theme/locale, avatars without fade or blurred shadow, viewer without blur.
- Screen-level fixes (home tabs, cards, detail listeners, parsing) belong to their units; cards must switch to `AppImage`.

## Edit sheet (`edit-sheet`)
- `ContentEditWidget` (same constructor) loads the whole MAL `my_list_status` itself (`MalListEntryService`, `lib/widgets/user/edit/`), so dates, priority, rewatch, tags, comments, chapters and volumes are pre-filled exactly (partial dates kept as text); load error / dead session / non-MAL account show a message with retry or sign-in, never a spinner.
- Auto dates follow `autoAddStartEndDate` and only fill empty dates; the last episode completes with a finish date, the first one fills the start date; add uses `defaultAnime/MangaAddStatus`; airing shows without total get an estimated episode count (picker bar or stepper).
- Private notes: `PrivateNotesStore` (`lib/user/private_notes/`, SharedPreferences `private_note_v1:<tracker>:<category>:<id>`), `export()`/`import()` for the backup unit; shown when `showPrivateNotes` is on.

## Known big gaps (see inventory)
- No user list / profile for any tracker; AniList/Kitsu/Simkl tabs are placeholders.
- No notifications, calendar, bookmarks, relation graph, share, translation.
- `auth-refresh` built (PR pending): token refresh/retry in `BaseUser`; call sites in `mal_api.dart`, `mal_user.dart`, Anilist/Kitsu/Simkl clients still use raw `http` and must move to `MalConnect.auth*` / `sendAuthenticated` (see PR findings).
- MAL dead session (#71): public MAL reads (seasonal, ranking, details, search, other users' lists, forum) fall back to the client id; `/users/@me`, suggestions and list writes throw `MalSessionExpired`. The UI listens to `MalApi.sessionExpired` (`ValueListenable<bool>`); the visible prompt is still to build (accounts-ux / app-shell); the detail screen shows its own error/retry state.

## Next
- Board: GitHub Project goddivor #8 "MyWatchList — Roadmap", 38 unit issues synced.
- Wave 2 in progress (`l10n-pipeline` in review). After it merges, every worktree runs `tools/heavy.sh tools/l10n/build.sh` once (generated files leave git).
