# Handoff — `shared-kit`: Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher

**Kind** kit · **Priority** P0 · **Group** foundation · **Model** opus

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/enums.dart`
- `lib/widgets/common/share_builder.dart`
- `lib/widgets/common/app_bar_menu.dart`
- `lib/widgets/common/score_reveal.dart`
- `lib/widgets/common/select/**`
- `lib/widgets/common/adaptive_layout.dart`
- `lib/utils/web_launcher.dart`
- `lib/constants/constants.dart`
- `lib/l10n/units/shared-kit/**`
- `test/units/shared-kit/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Share builder (choose fields: title, URL, synopsis…; copy or share) usable by any screen.
- App bar overflow menu widget with Share / Open in browser / Bookmark slots (callbacks, no feature logic).
- Select widgets missing from MWL: SelectButton, SelectSheet, SelectDate, ThreeStateSelectBar, SearchableSelect (long lists), showTopSheet.
- Score reveal widget honoring the hide-score preference (tap/eye to reveal one score).
- Web launcher: custom tabs / in-app webview instead of the deprecated `launch()`; restore internal MAL URI handling commented out around constants.dart:1148-1152 (route to in-app screens via app_routes when the app-shell unit has merged, else leave a TODO and report).
- Adaptive layout helper (phone / tablet breakpoints) for later tablet work.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/common/share_builder.dart`
- `lib/widgets/customappbar.dart`
- `lib/widgets/selectbottom.dart`
- `lib/widgets/selecttopper.dart`
- `lib/widgets/home/nodebadge.dart (_CardScoreRevealWidget)`
- `lib/widgets/web/c_webview.dart`
- `lib/widgets/common/adaptive_layout.dart`

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
- Each widget has a widget test under test/units/shared-kit/ and a usage example in the PR body.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
