# Project state — MyWatchList

Cap: 80 lines. Rewrite in place; history lives in git and `docs/DECISIONS.md`.

## Where we are (2026-10-27)
- Porting every DailyAL feature (ref `upstream/2026.2.6+108`) into MWL, adapted to BLoC + multi-tracker, redesigning weak UI and fixing bugs on the way.
- Work is split into 37 units (`work/INDEX.md`), built in parallel with the multi-agent-build tooling (`tools/mab/`, `tools/mab.config`), coordinated on GitHub (goddivor/mywatchlist, base `dev`, `master` owner-only).
- Inventory of what MWL has vs DAL, with the bugs found: `work/inventory/*.md`.

## Gate
- `tools/heavy.sh tools/verify.sh`: pub get, flutter analyze, flutter test, dart analyze mwl-api (machine-wide lock).
- On `dev` today: analyze green, **flutter test red** (default counter test) → fixed by unit `gate-fix` first.

## Waves (from `node tools/mab/plan-waves.mjs`)
1. gate-fix
2. auth-refresh, backend-parsers, l10n-pipeline
3. deps-prefs-contract
4. app-shell, detail-split, shared-kit, edit-sheet, api-prefs, versioning-ci
5+. features (user list/profile, detail, discovery, settings, community), then other trackers.

## Known big gaps (see inventory)
- No user list / profile for any tracker; AniList/Kitsu/Simkl tabs are placeholders.
- No notifications, calendar, bookmarks, relation graph, share, translation.
- Language picker broken; MAL token never refreshed; release manifest lacks INTERNET.

## Next
- Owner validates the plan → commit tooling + queue on `dev`, push, create the board, sync issues, launch wave 1.
