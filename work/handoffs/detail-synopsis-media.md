# Handoff — `detail-synopsis-media`: Synopsis translation, streaming links, videos fallback

**Kind** unit · **Priority** P2 · **Group** detail · **Model** sonnet

## Needs done first
- `detail-split` (Split the 1852-line detail screen into sections with seams)
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/widgets/MAL/content/synopsis_widget.dart`
- `lib/widgets/MAL/content/media_platforms.dart`
- `lib/widgets/MAL/content/videowidget.dart`
- `lib/widgets/common/translator.dart`
- `lib/l10n/units/detail-synopsis-media/**`
- `test/units/detail-synopsis-media/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Synopsis translation (translator_plus) with the auto-translate pref; reusable translator widget (character bios use it later).
- media_platforms.dart: `_scheduleData` is never assigned (:125, used :482) → schedule related links never show; preferred link type from the pref instead of hard-coded `streaming` (:55, :233).
- Video fallback image; respect the allow-YouTube-player pref.

## Known bugs to fix in scope
- _scheduleData never assigned

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/animedetailed/synopsiswidget.dart`
- `lib/widgets/translator.dart`
- `lib/pages/animedetailed/media_platforms.dart`
- `lib/pages/animedetailed/videoswidget.dart`

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
- Synopsis translates to French on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
