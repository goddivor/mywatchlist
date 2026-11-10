# Handoff — `stack-polish`: Interest stack page: squeezed covers, localized date, readable tabs (DailyAL layout)

**Kind** unit · **Priority** P0 · **Group** detail · **Model** sonnet

## Needs done first
- `detail-polish` (Detail page polish: News never loads, faster fallbacks, status colours, tabs, numbers)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/interest_stack_detail_screen.dart`
- `lib/l10n/units/stack-polish/**`
- `test/units/stack-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner screenshot of an interest stack page (Cgdct by Nih_000): the entry covers are thin 35 px strips — `AvatarWidget(height: 150.0, …)` at interest_stack_detail_screen.dart:~709 sets no width, so it takes AvatarWidget's default 35. Give the covers DailyAL's proportions (100 x 150, AppImage decoded at that size), same for the loading skeleton.
- Compare the whole page with DailyAL's stack screen and fix what is worse: the date 'Oct 27 2026, 1:37 AM' must follow the app locale (DateFormat with S locale); the third tab 'MyAnimeList stack…' is cut — labels fully readable (translated, shorter label or proper scrollable tabs); header title/author/description readable in light, dark and black; theme tokens only.
- Grep the repo for other `AvatarWidget(` calls used as covers (height > 60) without a width and list them in the PR body as findings (do not edit files you do not own).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/animedetailed/intereststackwidget.dart`
- `lib/screens/contentdetailedscreen.dart (interest stack screen)`

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
- Widget test: an entry cover is 100 x 150; the date is formatted in French under fr_FR.
- Checker: the owner's stack page side by side with DailyAL.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
