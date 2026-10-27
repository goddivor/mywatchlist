# Handoff — `list-cards-dal`: My List grid display: a better grid card (inspired by DailyAL's, not a copy)

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `theme-colors` (Theme colours: status bar, coherent accents per theme, colour tokens, contrast)

## Owns (may create or edit ONLY these)
- `lib/widgets/user/list/cards/**`
- `lib/widgets/user/list/list_entry_view.dart`
- `lib/l10n/units/list-cards-dal/**`
- `test/units/list-cards-dal/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- OWNER'S DECISION: MWL's My List interface is better than DailyAL's — keep MWL's header, tabs, toolbar, icons and non-grid display modes. Only the GRID display types must be IMPROVED (the owner finds the current grid rendering frustrating). Do NOT copy DailyAL exactly: use DailyAL's grid card as inspiration and make the best grid card for MWL (UI directive: compare, keep the better, improve).
- Direction the owner liked in DailyAL's grid: a clean cover without text or heavy gradient over the image, the essential info (score, list status with an edit action) in a compact bar under the cover, then the title and the genres; readable status chips coloured from the theme-colors status tokens. Choose proportions, spacing and badges that look best in MWL's design.
- Keep MWL's behaviour: tap opens the detail, pencil / long press opens the edit sheet, the status cache updates the chip, airing info and priority prefs, the grid column/height settings, custom card layouts (the new grid card becomes the default grid layout).
- Fluidity: AppImage at card size, no per-card Opacity/ClipRRect/blur, fixed extents; readable text and chips in light, dark and black.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/home/animecard.dart`
- `lib/widgets/home/nodebadge.dart`
- `lib/widgets/user/contentlistwidget.dart (grid mode)`

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
- Checker: screenshots of the new grid in light/dark/black on the owner's account; other display modes unchanged.
- Widget tests: grid card renders score/status/title/genres, hide-score, French labels.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
