# Handoff — `explore-seasonal`: Explore page and seasonal screen

**Kind** screen · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))

## Owns (may create or edit ONLY these)
- `lib/pages/MAL/mal_explore_page.dart`
- `lib/screens/explore/**`
- `lib/screens/seasonal/**`
- `lib/cache/top_characters.dart`
- `lib/l10n/units/explore-seasonal/**`
- `test/units/explore-seasonal/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Explore page (today it is just the search screen): rankings, genres grid, random pickers (random / from watching / from plan-to-watch), seasonal widget + weekly schedule entry, global recommendations / reviews / interest stacks, top characters and seiyuu (backend routes).
- Dedicated seasonal screen: season/year switcher, header image, sort/filter by score/members, global seasonal filter pref.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/explorepage.dart`
- `lib/pages/search/allrankingwidget.dart`
- `lib/pages/search/all_genre_widget.dart`
- `lib/pages/search/seasonalwidget.dart`
- `lib/screens/seasonal_screen.dart`
- `lib/cache/topcharactermanager.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Every Explore card opens a working screen on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
