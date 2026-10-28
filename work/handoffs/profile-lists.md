# Handoff — `profile-lists`: Other users' anime/manga lists, weekly tab and sidebar shortcuts like DailyAL

**Kind** unit · **Priority** P1 · **Group** user · **Model** opus

## Needs done first
- `color-sweep` (Colour sweep: hardcoded colours of already-merged screens onto the theme tokens)
- `explore-weekly` (Weekly anime per season (MAL broadcast weekday) and Random without Jikan)

## Owns (may create or edit ONLY these)
- `lib/screens/user_profile/sections/**`
- `lib/screens/user_profile/user_profile_view.dart`
- `lib/screens/user_profile/sections/list_section.dart`
- `lib/screens/user_profile/sections/weekly_section.dart`
- `lib/widgets/user/list/mal_user_list_adapter.dart`
- `lib/widgets/user/profile/user_pop_sheet.dart`
- `lib/pages/side_bar.dart`
- `lib/utils/app_routes.dart`
- `lib/l10n/units/profile-lists/**`
- `test/units/profile-lists/**`
- `test/units/profile-lists/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Also UI report docs/ui-check-report-2026-10-28.md group D items 9-11 (List tab first for other users, remove U10/U11, label facts, duplicate club rows, DailyAL icon tab strip) and group N item 22 (replicate DailyAL's sidebar items, drop Profile/Stats duplicates).
- DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items P1, P2, P3, P5, L1 and the profile part of D3. Read those items (DailyAL and MWL file:line, gap, effort) and implement them.
- Owner rules: replicate DailyAL's UI where MWL's would be weaker; no explanatory captions or helper text DailyAL lacks; theme tokens only; full translatability (English + French).

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
- Checker compares with DailyAL on the owner's network (Jikan down).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
