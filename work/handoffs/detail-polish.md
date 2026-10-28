# Handoff — `detail-polish`: Detail page polish: News never loads, faster fallbacks, status colours, tabs, numbers

**Kind** unit · **Priority** P0 · **Group** detail · **Model** opus

## Needs done first
- `detail-resilience` (Detail sections: no endless skeletons, MAL fallbacks when Jikan fails, round avatars without box shadows)
- `detail-header` (Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown)
- `home-wiring` (Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/detail/**`
- `lib/widgets/MAL/content/animestatisticswidget.dart`
- `lib/widgets/MAL/home/show_news.dart`
- `lib/services/api/Jikan/**`
- `lib/l10n/units/detail-polish/**`
- `test/units/detail-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- BLOCKING (batch-4 check): News on detail pages loads forever — lib/widgets/MAL/home/show_news.dart:52-62 `_fetchNews` has no try/catch, `JikanUnavailable` is unhandled and the skeleton never goes. Content, empty state or error + Retry, like every other section (repro: Cowboy Bebop, Shuiro no Kamen).
- Faster fallbacks (owner target ~12 s): the MAL fallback only starts after Jikan's 12 s timeout and then waits up to 15–20 s (content_stats_source.dart:77-91, jikan_fallbacks.dart:24): start the fallback early (race Jikan against the fallback after a short head start, or skip Jikan immediately while its circuit breaker is open), cap the total at ~12 s.
- Status colours: the detail edit FAB (detail_fab.dart:36 → getAnimeStatusColor / constants getStatusColor) and the Stats chart (animestatisticswidget.dart:30-34) must use the theme-colors status tokens (DailyAL's green/blue/orange/red/brown).
- Tapping a detail tab while the header is fully expanded highlights the tab but does not scroll — make it scroll. Manga header authors show a leading comma (', Nabana'). Header numbers use the app locale (header_meta.dart:17-19 static NumberFormat without locale: '2,169' → '2 169' in French).

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
- Tests with a failing fake Jikan: News ends in a state; fallbacks finish under ~12 s; status colours = tokens; French number formatting.
- Checker: Cowboy Bebop and Shuiro no Kamen on the owner's network.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
