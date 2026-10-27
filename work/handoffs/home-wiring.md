# Handoff — `home-wiring`: Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections

**Kind** screen · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `perf-foundation` (Fluidity foundation: 120 Hz, image decoding, shimmers, root rebuilds)
- `bookmarks` (Bookmarks: store, screen, add/remove)
- `calendar` (Anime calendar, weekly schedule, .ics export, add to device calendar)
- `explore-seasonal` (Explore page and seasonal screen)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))

## Owns (may create or edit ONLY these)
- `lib/widgets/common/bottomnavbar.dart`
- `lib/pages/MAL/mal_home_page.dart`
- `lib/widgets/MAL/home/homeappbar.dart`
- `lib/widgets/MAL/home/accordion.dart`
- `lib/widgets/MAL/home/section_header.dart`
- `lib/widgets/MAL/home/news_widget.dart`
- `lib/widgets/MAL/home/show_news.dart`
- `lib/widgets/home/**`
- `lib/user/MAL/**`
- `lib/screens/settings/mal_home_settings.dart`
- `lib/l10n/units/home-wiring/**`
- `test/units/home-wiring/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Top chips (Categories, Genres, Top anime/manga, Top airing, Popular) are all `() {}` (mal_home_page.dart:44-52) → open the explore/ranking screens; bookmarks and calendar buttons `() {}` (:222-224) → app_routes.
- MAL under-maintenance dialog (API exists mal_api.dart:1067).
- The avatar switcher (homeappbar.dart) still pushes AccountSwitcherPage as a full slide page: open it as a bottom sheet instead (accounts-ux finding). Sidebar entry point (app-shell finding): a visible button in the home app bar (the account avatar, as in DailyAL) calls `AppRoutes.openSidebar` — the edge swipe alone fights Android gesture navigation. Replace the direct `SettingsPage` push (mal_home_page.dart:228) by `AppRoutes.openSettings`.
- homeappbar.dart tooltips (Search, Bookmarks, Calendar, Settings) are hardcoded English → S (user-list-mal finding).
- BottomNavBar (lib/widgets/common/bottomnavbar.dart): honour `startIndex` changes (`didUpdateWidget`) so the shell can switch tab from code, and move its hardcoded tab titles to `S`.
- Home sections: user-list section, forum section, custom items (forum boards, user list status, season/year).
- News items: drop ClipRRect + Opacity per item (news_widget.dart:54-56), use AppImage (performance.md #7).
- First-run feature showcase (tile size, preferred title, startup page).

## Known bugs to fix in scope
- dead chips
- dead bookmarks/calendar buttons

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/homepage.dart`
- `lib/widgets/homeappbar.dart`
- `lib/widgets/home/feature_first.dart`
- `lib/util/homepageutils.dart`
- `lib/pages/settings/homepagesettings.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- No dead button on the MAL home on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
