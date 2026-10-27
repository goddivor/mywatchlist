# Handoff — `detail-header`: Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown

**Kind** screen · **Priority** P1 · **Group** detail · **Model** sonnet

## Needs done first
- `detail-split` (Split the 1852-line detail screen into sections with seams)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `bookmarks` (Bookmarks: store, screen, add/remove)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/detail/detail_data.dart`
- `lib/screens/MAL/detail/detail_screen.dart`
- `lib/screens/MAL/detail/sections/media_section.dart`
- `lib/screens/MAL/detail/header/**`
- `lib/screens/MAL/detail/actions/**`
- `lib/screens/MAL/detail/detail_sections.dart`
- `lib/screens/MAL/detail/tabs_customizer.dart`
- `lib/l10n/units/detail-header/**`
- `test/units/detail-header/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- App bar menu: share (share builder), open in browser, bookmark toggle (`BookmarkButton` / `Bookmarks` from the bookmarks unit), search by genre.
- Wire the schedule links from detail-synopsis-media (PR #103): add `scheduleLinks` to `DetailData.copyWith`; in detail_screen.dart, after an anime loads, call `ScheduleLinks.forMalId(id)` and copy the result in when mounted; in sections/media_section.dart pass `fallbackImageUrl: data.coverUrl` to `VideosWidget`.
- More Info modal reachable from the cover info button.
- Hide-score with tap to reveal; preferred title language from the pref (not a per-screen toggle only); detail background pref; next-episode countdown pref.
- Customize / reorder / hide sections, persisted in the contract pref. Manga default order: keep Stats and Score stats on manga pages (an MWL extra over DailyAL, orchestrator recommendation pending the owner) — change the manga default in the contract only through a finding if it lives outside your files.
- Redesign the header (UI directive): compare DAL and MWL side by side.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/contentdetailedscreen.dart`
- `lib/screens/moreinfo.dart`
- `AnimeMangaPageTabEdit`
- `CountDownWidget`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded `Colors.*` or `Color(0x…)` in your screens: use `Theme.of(context).colorScheme` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- All header buttons do something on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
