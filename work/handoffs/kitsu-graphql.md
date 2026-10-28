# Handoff — `kitsu-graphql`: kitsu-graphql

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** sonnet

## Needs done first
- `tracker-followups` (Tracker follow-ups: removed rows disappear, Simkl list categories, notifications for every tracker)

## Owns (may create or edit ONLY these)
- `lib/services/api/Kitsu/kitsu_graphql.dart`
- `test/units/kitsu-graphql/**`
- `lib/l10n/units/kitsu-graphql/**`
- `test/units/kitsu-graphql/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Kitsu/Simkl audit docs/kitsu-simkl-report-2026-10-28.md, unit `kitsu-graphql`: Read-only GraphQL client (`POST /api/graphql`, anonymous or with the token through `sendAuthenticated`), error mapping to `KitsuHttpError` / `KitsuSessionExpired`, `page`/`first` helpers, fixtures Read the matching report items (endpoints, sample responses, selectors, risks) and implement them.
- Owner decision: a Kitsu/Simkl account shows only its own tracker's data (never MAL news/forum); scraping the tracker's own site for extra data is welcome. Replicate DailyAL/MALClient UI conventions where MWL would be weaker; no explanatory captions; theme tokens; English + French. Never write to the owner's tracker accounts in tests (fakes/fixtures only).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

## Definition of Done
- Offline tests on saved responses/pages; checker on the owner's accounts (read-only).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
