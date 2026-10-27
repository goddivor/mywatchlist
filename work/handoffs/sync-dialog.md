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

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Editing on MAL then syncing to AniList updates AniList on the emulator (owner's accounts).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
