# Handoff — `kitsu-pages`: Kitsu: home, explore, user list, profile (replace placeholders)

**Kind** screen · **Priority** P2 · **Group** trackers · **Model** sonnet

## Needs done first
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `home-wiring` (Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections)

## Owns (may create or edit ONLY these)
- `lib/pages/Kitsu/**`
- `lib/services/api/Kitsu/**`
- `lib/widgets/Kitsu/kitsu_*.dart`
- `lib/l10n/units/kitsu-pages/**`
- `test/units/kitsu-pages/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Same as anilist-pages for Kitsu (JSON:API).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Owner's Kitsu list renders on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
