# Handoff — `user-profile-mal`: MAL user profile, stats charts and user pop-up

**Kind** screen · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `mal-auth-calls` (Route every MAL request through the token-refresh path)
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)

## Owns (may create or edit ONLY these)
- `test/units/app-shell/app_routes_test.dart`
- `lib/utils/app_routes.dart`
- `lib/pages/MAL/mal_user_profile_page.dart`
- `lib/screens/user_profile/**`
- `lib/widgets/user/profile/**`
- `lib/widgets/charts/**`
- `lib/services/api/MAL/scrapper/user_anime_statistics.dart`
- `lib/services/api/MAL/scrapper/user_friends.dart`
- `lib/services/api/MAL/scrapper/user_history.dart`
- `lib/services/api/MAL/user_anime_statistics.dart`
- `lib/services/api/MAL/mal_user_prof.dart`
- `lib/cache/cached_user_profile.dart`
- `lib/l10n/units/user-profile-mal/**`
- `test/units/user-profile-mal/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Own profile and any other user's profile: header, about (users/about parser from backend-parsers), favorites, friends, clubs, history, stats with charts (fl_chart; colors from the stats chart pref), insights.
- User pop-up sheet (profile header, set/remove profile background, report user).
- Point `openUserProfile` and `openUserStats` in lib/utils/app_routes.dart at your real screens (one-line changes; app-shell merged, you own the file now).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/user_profile.dart`
- `lib/widgets/user/user_header.dart`
- `lib/widgets/user/stats_screen.dart`
- `lib/user/charts/`
- `lib/widgets/barchart.dart`
- `lib/pages/userpop.dart`
- `lib/cache/cacheduserprof.dart`
- `lib/util/insight_service.dart`

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
- Owner's profile and a friend's profile render on the emulator with stats.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
