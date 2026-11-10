# Handoff — `kitsu-polish`: Kitsu polish: Quick update carousel, exact ratings and reactions in the library, histogram buckets, grid short words, status filter wording

**Kind** unit · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `kitsu-finish` (Kitsu: follow, groups and library count on profiles, % on every tile, sync editor in the account's rating system)
- `tracker-list-hooks` (Shared My List: adapter hooks for status labels, score display, card badges and a rating prompt)

## Owns (may create or edit ONLY these)
- `lib/widgets/Kitsu/kitsu_rows.dart`
- `lib/pages/Kitsu/kitsu_home_page.dart`
- `lib/widgets/Kitsu/media/**`
- `lib/services/api/Kitsu/kitsu_library.dart`
- `lib/widgets/Kitsu/kitsu_user_list_adapter.dart`
- `lib/widgets/common/list_sort_filter.dart`
- `lib/l10n/units/kitsu-polish/**`
- `test/units/kitsu-polish/**`
- `test/units/kitsu-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Seen on the emulator 2026-10-29 with the owner's Kitsu account: the Kitsu home shows no Quick update carousel although the account has 38 'Currently watching' titles: find why (query, condition or empty mapping) and fix it, with a test on a saved library answer. From tracker-list-hooks (#315): kitsu_library.dart keeps ratingTwenty and the reaction when it parses a page, then drop KitsuExtrasHttp; the list filter sheet's status facet (list_sort_filter.dart) uses the adapter's statusLabel; Kitsu gets its own short words on the grid chip. From kitsu-finish (#317): the title page histogram (kitsu_media_cards.dart) uses KitsuRatingFrequencies.rebucket for the account's rating system.
- Owner rules: each tracker is its own app (docs/tracker-ui-references.md); MAL screens follow DailyAL; no explanatory captions DailyAL lacks. Fakes only in tests; writes only on the viewer's tap.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

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
- Tests: Quick update shows for a library with current entries; exact rating and reaction parsed; histogram rebucketed; status facet wording.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
