# Handoff — `search-upgrade`: Search: user results, search by id, autocomplete, searchable filters

**Kind** screen · **Priority** P2 · **Group** discovery · **Model** sonnet

## Needs done first
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)

## Owns (may create or edit ONLY these)
- `lib/screens/search/**`
- `lib/widgets/MAL/search/**`
- `lib/l10n/units/search-upgrade/**`
- `test/units/search-upgrade/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- User result tap → profile (TODO :2227) and 'User found as …' shortcut; search by MAL id; autocomplete with throttle; SearchableSelect for producers/magazines; three-state include/exclude.
- `_SeasonalSection._maxYear` hard-coded 2027 (:3643) → current year + 1.
- Expose static entry points (e.g. `GeneralSearchScreen.byGenre/byStudio/byMagazine/byTag/bySeason`) used by more-info and featured units; list them in the PR body.
- Split the 3719-line file into parts under lib/screens/search/; while splitting, remove the ~12 ClipRRect per result item where a decoration radius suffices and use AppImage (performance.md #7).

## Known bugs to fix in scope
- user tap TODO
- maxYear 2027

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/generalsearchscreen.dart`
- `lib/widgets/search/filtermodal.dart`
- `commits da37082, 6b2aafd, fa2fb68, 3f1f0fd, 158e206 (autocomplete), db3355e (search by id, 3-state)`

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
- Searching a username opens the profile; searching '1' finds Cowboy Bebop by id.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
