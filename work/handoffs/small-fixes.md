# Handoff — `small-fixes`: Dead settings switches, dub icon on cards and tiles, report recommendation, backup keys

**Kind** unit · **Priority** P1 · **Group** settings · **Model** opus

## Needs done first
- `ux-edit-sheet` (Edit sheet as DailyAL's single compact card; sync panel behind More options)
- `mal-session` (Optional MAL website session (WebView login, native cookies, CSRF client) + profile comments)
- `color-sweep` (Colour sweep: hardcoded colours of already-merged screens onto the theme tokens)

## Owns (may create or edit ONLY these)
- `lib/widgets/user/edit/edit_fields.dart`
- `test/units/edit-sheet/**`
- `lib/screens/settings/accounts_settings.dart`
- `lib/widgets/forum/post_widget.dart`
- `lib/widgets/user/list/cards/entry_parts.dart`
- `lib/widgets/user/list/cards/entry_cards.dart`
- `lib/screens/search/search_tiles.dart`
- `lib/cache/cachemanager.dart`
- `lib/user/preferences/notification_preferences.dart`
- `lib/l10n/units/small-fixes/**`
- `test/units/small-fixes/**`
- `test/units/small-fixes/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner rule (no captions DailyAL lacks): remove the edit sheet's 'of 64' episode hint and '10 · Masterpiece' score hint (lib/widgets/user/edit/edit_fields.dart), and update the edit-sheet unit tests that pin them.
- Wire mal-session (PR #220): in Settings > Accounts, the MyAnimeList tile opens `MalSessionSettingsPage` (state, check, disconnect, connect).
- DailyAL feature-gap audit docs/dal-gap-report-2026-10-28.md: items F1, L2, B1, S1 (detailsExpanded / showOnlyLastQuote switches that do nothing, search history + recently opened in backups, community recommendation Report action). Read those items (DailyAL and MWL file:line, gap, effort) and implement them.
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
