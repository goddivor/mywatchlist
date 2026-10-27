# Handoff — `forum-clubs`: Forum posting, profile links, club members in-app

**Kind** screen · **Priority** P2 · **Group** community · **Model** sonnet

## Needs done first
- `mal-auth-calls` (Route every MAL request through the token-refresh path)
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)

## Owns (may create or edit ONLY these)
- `lib/screens/forum/**`
- `lib/widgets/forum/**`
- `lib/pages/MAL/mal_forum_page.dart`
- `lib/services/api/MAL/mal_clubs_api.dart`
- `lib/services/api/MAL/mal_forum_api.dart`
- `lib/l10n/units/forum-clubs/**`
- `test/units/forum-clubs/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- MalForumPage:206 pushes SettingsPage directly → `AppRoutes.openSettings` (app-shell finding); Reply FAB only copies the URL (forum_posts_screen.dart:117-126) → open a webview to post (DAL); post avatar → profile (post_widget.dart:346); club members/staff → in-app profile instead of browser; replace the club scraping in mal_clubs_api.dart by the backend methods `MwlApi.getClubPage/getClubMembers/getClubForumTopics/getClubComments` (backend-parsers finding); HTML parsing off the UI isolate in mal_clubs_api.dart (:20, :34, :61) and the forum API (performance.md #9); share/browser menus; redesign per UI directive.

## Known bugs to fix in scope
- reply FAB
- avatar tap

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/forumposts.dart`
- `lib/screens/forumtopicsscreen.dart`
- `lib/pages/forumpage.dart`
- `lib/screens/clubscreen.dart`

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
- Reply opens the MAL post form in-app on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
