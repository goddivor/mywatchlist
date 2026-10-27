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

## Waves (from `node tools/mab/plan-waves.mjs`)
1. gate-fix
2. auth-refresh, backend-parsers, l10n-pipeline
3. deps-prefs-contract
4. app-shell, detail-split, shared-kit, perf-foundation, edit-sheet, api-prefs, versioning-ci
5+. features (user list/profile, detail, discovery, settings, community), then other trackers.

## Backend (mwl-api)
- `backend-parsers` ported DailyAL's page parsers (`PageParsers`, typed `*Html` models) and routes: `content/characters`, `character|people/*id/pics`, `characters`, `people`, `magazines`, `studios`, `clubs?id=`, `clubs/type`, `search/all`; `reviews`, `users/about` parsed; `schedules` = LiveChart (`source=jikan` for the old proxy).
- Typed client methods on `MwlApi` (listed in the backend-parsers PR body, issue #27); HTML parsed off the UI isolate.

## Fluidity baseline
- Home scroll, profile builds: MWL 22-23 % janky frames vs DailyAL 1.6 % (`tools/perf/measure-scroll.sh`). Unit `perf-foundation` + fluidity rules in every UI handoff. Emulator must run with `-gpu host`.

## Known big gaps (see inventory)
- No user list / profile for any tracker; AniList/Kitsu/Simkl tabs are placeholders.
- No notifications, calendar, bookmarks, relation graph, share, translation.
- `auth-refresh` built (PR pending): token refresh/retry in `BaseUser`; call sites in `mal_api.dart`, `mal_user.dart`, Anilist/Kitsu/Simkl clients still use raw `http` and must move to `MalConnect.auth*` / `sendAuthenticated` (see PR findings).

## Next
- Board: GitHub Project goddivor #8 "MyWatchList — Roadmap", 38 unit issues synced.
- Wave 2 in progress (`l10n-pipeline` in review). After it merges, every worktree runs `tools/heavy.sh tools/l10n/build.sh` once (generated files leave git).
