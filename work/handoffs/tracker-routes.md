# Handoff — `tracker-routes`: Routes and app bar per tracker: calendar, search, bookmarks, bell, sidebar, notification taps, startup page

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `tracker-contracts` (Contracts for tracker isolation: tracker-tagged notification payloads, per-tracker preference reads, global notification gate)
- `mal-polish-2` (MAL polish 2: Settings > Accounts uses the new page, Supporter badge for others, time zone in About, dead TrackerTile, cancelled MAL re-login keeps the session)
- `anilist-calendar` (AniList calendar: the weekly airing schedule from AniList)
- `kitsu-calendar` (Kitsu calendar: upcoming episodes of the user's Kitsu library)
- `simkl-search` (Simkl search screen so the search icon opens Simkl's search on Simkl)

## Owns (may create or edit ONLY these)
- `lib/utils/app_routes.dart`
- `lib/widgets/MAL/home/homeappbar.dart`
- `lib/pages/side_bar.dart`
- `lib/screens/home_screen.dart`
- `lib/pages/Anilist/anilist_home_page.dart`
- `lib/pages/Simkl/simkl_user_page.dart`
- `lib/l10n/units/tracker-routes/**`
- `test/units/tracker-routes/**`
- `test/units/tracker-routes/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Implement unit U1 of docs/tracker-isolation-audit-2026-10-29.md (sections A and F): openCalendar / openSearch / openBookmarks dispatch on the active tracker (AniList calendar from anilist-calendar, Kitsu calendar from kitsu-calendar, Simkl search from simkl-search, Simkl calendar existing); notification taps use NotificationPayload (tracker-contracts) and switch the active account first when the payload is another tracker's; the app bar bell / search / bookmarks / calendar per tracker (AniList bell on every AniList tab, removed from the AniList home title; Kitsu/Simkl get the bell only when they have a notification screen); sidebar entries per tracker (AniList notifications entry); startup page read per tracker.
- Owner rule 2026-10-29 (memory tracker-account-isolation, docs/DECISIONS.md): switching the active account is switching app; every screen shows the active tracker's own data; tracker settings are per tracker; notifications come from every connected tracker, each with its own switch. Fakes only in tests; never write to the owner's accounts.

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
- Tests: each route opens the active tracker's screen; a payload of another tracker switches account then opens; app bar icons per tracker.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
