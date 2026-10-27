# Handoff — `calendar`: Anime calendar, weekly schedule, .ics export, add to device calendar

**Kind** screen · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))

## Owns (may create or edit ONLY these)
- `lib/screens/calendar/**`
- `lib/widgets/calendar/**`
- `lib/l10n/units/calendar/**`
- `test/units/calendar/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Per-day schedule with status filter chips (incl. 'All' and 3-state 'in list'), timezone pref (JST/UTC/local), .ics download/share, add to device calendar with recurring option; fills app-shell's calendar stub.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/home/anime_calendar.dart`
- `lib/widgets/user/weeklyanime.dart`
- `commits 1e3e833 (ics), 17dd437 (add to calendar), 970111b ('All' filter)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Calendar shows this week's airing anime with the owner's watching list highlighted.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
