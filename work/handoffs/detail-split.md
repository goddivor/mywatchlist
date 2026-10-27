# Handoff — `detail-split`: Split the 1852-line detail screen into sections with seams

**Kind** foundation · **Priority** P0 · **Group** detail · **Model** opus

## Needs done first
- `deps-prefs-contract` (Dependencies, Android permissions and the preferences contract)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/contentdetailedscreen.dart`
- `lib/screens/MAL/detail/**`
- `lib/l10n/units/detail-split/**`
- `test/units/detail-split/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Split `lib/screens/MAL/contentdetailedscreen.dart` into `lib/screens/MAL/detail/`: `detail_screen.dart` (scaffold + scroll/tab sync), `header/` (cover, scores, meta), `actions/` (app bar actions), `sections/` (one file per section wrapper), `detail_sections.dart` (ordered section registry that reads the detail tab order/visibility pref from the contract). Keep `contentdetailedscreen.dart` as a thin re-export so callers don't change.
- Fix: `super.dispose()` called before disposing own controllers (:159); scroll listener re-added on every `updateVisibleSections()` (:338); info button on the cover is a no-op (:1104) → opens a More Info modal; search icon in app bar is a no-op (:939) → opens search.
- Leave empty, documented extension points in `actions/` for share / open in browser / bookmark (the detail-header unit fills them).
- FLUIDITY (performance.md #4): register the scroll listener ONCE in initState, dispose every TabController you replace (only the last is disposed at :161), update the selected tab only when the visible section changes — not localToGlobal on every scroll tick.
- Remove the second `TitleLang` enum declared in contentdetailedscreen.dart:54 and use the one in constants.dart (deps-prefs-contract finding); read the preferred title from `Preferences.general` instead of a per-screen default.
- Behaviour must stay identical otherwise (no visual redesign here beyond what the split needs); the later detail units redesign their own parts.

## Known bugs to fix in scope
- dispose order :159
- listener leak :338
- dead info button :1104
- dead search button :939

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/contentdetailedscreen.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens. **Colours:** no hardcoded `Colors.*` or `Color(0x…)` in your screens: use `Theme.of(context).colorScheme` and the semantic tokens of lib/widgets/common/app_colors.dart (theme-colors unit, see docs/THEME.md once merged); move the existing hardcoded colours of your files to them. Every text must stay readable on its background (buttons, chips, badges, text on images) in light, dark and black modes. **Icons (owner's rule):** for a feature ported from DailyAL, use THE SAME ICON as DailyAL for each action and element (grep the DAL widget for its `Icons.*` / custom icon and reuse it), never a different MWL pick.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- No file under lib/screens/MAL/detail/ over ~400 lines.
- Detail screen behaves as before on the emulator (checker compares).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
