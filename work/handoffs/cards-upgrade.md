# Handoff — `cards-upgrade`: Anime cards: quick edit, status badges, score reveal, real airing progress

**Kind** unit · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
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
- Card images through `AppImage` (perf-foundation) with decode size = card size; no ClipRRect+Opacity per card when a borderRadius/alpha does it (performance.md #3, #7).
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

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Card edit button opens the sheet on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
