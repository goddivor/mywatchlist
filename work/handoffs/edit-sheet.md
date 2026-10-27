# Handoff — `edit-sheet`: Edit-entry sheet: fix pre-fill, dates, episodes, private notes

**Kind** unit · **Priority** P0 · **Group** user · **Model** sonnet

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/widgets/user/contenteditwidget.dart`
- `lib/widgets/user/edit/**`
- `lib/user/private_notes/**`
- `lib/l10n/units/edit-sheet/**`
- `test/units/edit-sheet/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Pre-fill everything from the existing entry: start/finish dates, priority, comments, tags, rewatch count (`_loadFromContent` l.104-128 skips them); chapters/volumes are forced to '0' on load (~l.115-122).
- Auto start/end dates only when the `autoAddStartEndDate` pref is on and only when the date is empty; set finish date when completing through the episode count (l.273-285); fill start date when episode count goes 0→1.
- Total episodes for airing shows (DAL e7eef19/b5f1e8d); default add-to-list status from the pref instead of hard-coded `plan_to_watch`.
- No infinite spinner when `contentDetailed` is null: show a retry/fallback (DAL 7d02a3f).
- Comments in a popup editor (DAL ee084b6); decode HTML entities in comments and tags.
- Private notes: local-only note per entry (`lib/user/private_notes/`), shown in the sheet when the `showPrivateNotes` pref is on; expose `PrivateNotesStore.export()/import()` for the backup unit.
- Split the 1567-line widget into `lib/widgets/user/edit/` parts while you are there.

## Known bugs to fix in scope
- pre-fill gaps
- chapters/volumes = 0
- auto dates overwrite existing ones
- no finish date via episode count
- infinite spinner

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/user/contenteditwidget.dart`
- `commits 704b5b5, 7d02a3f, e7eef19, b5f1e8d, ee084b6, 2f6b9da, 3f89382, fe88690, e773650 (private notes)`

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
- Editing an existing completed entry on the emulator shows its real dates/score/progress.
- Private note survives app restart.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
