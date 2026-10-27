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
- Language picker broken.
- `auth-refresh` built (PR pending): token refresh/retry in `BaseUser`; call sites in `mal_api.dart`, `mal_user.dart`, Anilist/Kitsu/Simkl clients still use raw `http` and must move to `MalConnect.auth*` / `sendAuthenticated` (see PR findings).

## Next
- Board: GitHub Project goddivor #8 "MyWatchList — Roadmap", 38 unit issues synced.
- Wave 1 (`gate-fix`) in review; launch wave 2 once it merges.
