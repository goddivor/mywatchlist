# Handoff — `cards-upgrade`: Anime cards: quick edit, status badges, score reveal, real airing progress

**Kind** unit · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `edit-sheet` (Edit-entry sheet: fix pre-fill, dates, episodes, private notes)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)

## Owns (may create or edit ONLY these)
- `lib/widgets/MAL/home/animegridcard.dart`
- `lib/widgets/MAL/home/animecardbar.dart`
- `lib/widgets/MAL/home/contentlistwidget.dart`
- `lib/widgets/MAL/home/animecharacterwidget.dart`
- `lib/l10n/units/cards-upgrade/**`
- `test/units/cards-upgrade/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- `showContentEditSheet` is an empty stub (animegridcard.dart:620-623) → open the edit sheet.
- `releaseProgress` faked as (eps-1)/eps (~l.389) → real schedule data or hide.
- Status badge from the list status cache, score reveal, favourites count, recommendation badge, NSFW blur per pref, preferred title.

## Known bugs to fix in scope
- dead edit button on every card
- fake airing progress

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/home/animecard.dart`
- `lib/widgets/home/nodebadge.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Card edit button opens the sheet on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
