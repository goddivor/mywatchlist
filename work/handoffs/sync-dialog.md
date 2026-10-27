# Handoff — `sync-dialog`: Cross-tracker sync: two-way dialog, cancel, lazy load, decimal scores

**Kind** unit · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `edit-sheet` (Edit-entry sheet: fix pre-fill, dates, episodes, private notes)
- `auth-refresh` (Token refresh and retry for all trackers)

## Owns (may create or edit ONLY these)
- `lib/services/tracker_sync_service.dart`
- `lib/widgets/user/cross_tracker_widget.dart`
- `lib/widgets/user/tracker_search_sheet.dart`
- `lib/widgets/user/sync/**`
- `lib/l10n/units/sync-dialog/**`
- `test/units/sync-dialog/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Sync dialog with loading indicators, lazy loading and a Cancel button; both directions (MAL ⇄ AniList at least; Kitsu/Simkl where their API allows), not only MAL → others.
- Decimal scores / AniList POINT_10_DECIMAL (today `.toInt()` truncates).
- Per-tracker edit (status, score, progress, dates) of the linked entry inside the sheet, not only 'sync MAL values'.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/util/sync_helper.dart`
- `commits 7c9c165, c64ccc0, c4f7276, ce3b001, 7ab3460, 146c681`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Editing on MAL then syncing to AniList updates AniList on the emulator (owner's accounts).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
