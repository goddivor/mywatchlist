# Handoff — `kitsu-finish`: Kitsu: follow, groups and library count on profiles, % on every tile, sync editor in the account's rating system

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** sonnet

## Needs done first
- `kitsu-redesign` (Kitsu home, explore and library redesigned from the Kitsu UI reference)

## Owns (may create or edit ONLY these)
- `lib/services/api/Kitsu/kitsu_profile.dart`
- `lib/widgets/Kitsu/feed/**`
- `lib/widgets/Kitsu/profile/**`
- `lib/widgets/Kitsu/kitsu_profile_view.dart`
- `lib/widgets/Kitsu/kitsu_media_tile.dart`
- `lib/services/api/Kitsu/kitsu_http.dart`
- `lib/services/api/Kitsu/kitsu_graphql.dart`
- `lib/widgets/user/sync/tracker_entry_editor.dart`
- `lib/l10n/units/kitsu-pages/**`
- `test/units/kitsu-pages/**`
- `lib/l10n/units/kitsu-finish/**`
- `test/units/kitsu-finish/**`
- `test/units/kitsu-finish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Checker batch 4, issue goddivor/mywatchlist#314 (put 'Closes #314' in the PR; reproductions in docs/checks/check-batch4-2026-10-29.md): Kitsu JSON:API text is decoded as Latin-1 (kitsu_http.dart reads response.body; decode UTF-8 from bodyBytes); the time percentile 0.99 shows 'More than 1%' (kitsu_profile.dart:240, fraction read as 0-100); profile Activity titles must open the native page (check after kitsu-redesign #309); double space in feed relative times; empty band under the Groups search field.
- From kitsu-redesign (#309): (1) profile follow button (KitsuHttp gains POST/DELETE for follows), groups tab and library count in kitsu_profile_view.dart, per the Kitsu 'Profile' reference; (2) KitsuMediaTile draws Kitsu's percentage, not a /10 star; (3) the sync dialog's editor (tracker_entry_editor.dart) shows and edits Kitsu ratings in the account's rating system; (4) drop the unused Kitsu_No_Mal_Match strings and update kitsu_browse_test.dart; (5) update KitsuGraphql's doc now that mutations go through execute(auth: true); (6) re-bucket the title page's rating histogram into the user's rating system if simple.
- Owner rule: each tracker is its own app (docs/tracker-ui-references.md); shared pieces stay shared but every tracker-specific behaviour is a hook on its adapter. Fakes only in tests; writes only on the viewer's tap.

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
- Tests: follow request (fake), tile shows %, editor in Simple/Regular/Advanced, histogram buckets.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
