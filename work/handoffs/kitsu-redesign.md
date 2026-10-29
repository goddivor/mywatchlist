# Handoff — `kitsu-redesign`: Kitsu home, explore and library redesigned from the Kitsu UI reference

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** opus

## Needs done first
- `kitsu-home-extras` (kitsu-home-extras)
- `kitsu-media-page` (kitsu-media-page)
- `kitsu-profile-plus` (kitsu-profile-plus)

## Owns (may create or edit ONLY these)
- `lib/pages/Kitsu/kitsu_media_page.dart`
- `lib/widgets/Kitsu/media/**`
- `lib/widgets/Kitsu/kitsu_open.dart`
- `lib/l10n/units/kitsu-pages/**`
- `lib/pages/Kitsu/kitsu_home_page.dart`
- `lib/pages/Kitsu/kitsu_explore_page.dart`
- `lib/pages/Kitsu/kitsu_browse_screen.dart`
- `lib/pages/Kitsu/kitsu_user_page.dart`
- `lib/widgets/Kitsu/kitsu_rows.dart`
- `lib/widgets/Kitsu/kitsu_media_row.dart`
- `lib/widgets/Kitsu/kitsu_user_list_adapter.dart`
- `lib/services/api/Kitsu/kitsu_catalog.dart`
- `lib/l10n/units/kitsu-redesign/**`
- `test/units/kitsu-redesign/**`
- `test/units/kitsu-redesign/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- From kitsu-media-page (#290): the signed-in parts of the Kitsu title page: library box (status, progress, +1, edit), the user's rating system, watched ticks on episodes, per-episode discussion, favourite heart, next episode line; drop the unused Kitsu_No_Mal_Match strings; rename one of the two KitsuMediaPage classes (kitsu_catalog.dart vs the page).
- Redesign the Kitsu home, explore/search and library from the Kitsu part of docs/tracker-ui-references.md. Home starts with the Quick Update carousel (next-episode thumbnail, '✓ Episode N' button, link to the episode discussion). Library: the five status counts from meta.statusCounts in one call, Kitsu wording ('Want to watch'), the user's rating system (Simple / Regular / Advanced) in every rating display, the user's own reaction on cards. Scores as percentages, never /10. Also from kitsu-home-extras: apply the account rating system to score display; the 'pick from my plan to watch' variant of Surprise me; keep one KitsuCategory type (kitsu_catalog.dart vs kitsu_graphql.dart).
- Owner rule 2026-10-29: each tracker is its own app; DailyAL's UI is the reference for MAL only. Follow the matching section of docs/tracker-ui-references.md (recommended block order and the data field behind each block); own files and own layout; every item opens this tracker's native page. No explanatory captions; theme tokens; English + French; fakes only in tests.

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
- Tests per screen on saved Kitsu responses; before/after screenshots at 360 dp in the PR.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
