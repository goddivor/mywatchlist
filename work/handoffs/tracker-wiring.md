# Handoff — `tracker-wiring`: AniList / Kitsu / Simkl wiring: notifications, profile routes, remove action, MAL-only notes

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** sonnet

## Needs done first
- `anilist-pages` (AniList: home, explore, user list, profile (replace placeholders))
- `kitsu-pages` (Kitsu: home, explore, user list, profile (replace placeholders))
- `simkl-pages` (Simkl: home, explore, user list, profile (replace placeholders))

## Owns (may create or edit ONLY these)
- `lib/services/notifications/notification_service.dart`
- `lib/services/notifications/**`
- `lib/utils/app_routes.dart`
- `lib/widgets/user/sync/**`
- `lib/screens/settings/user_prefs_settings.dart`
- `lib/screens/settings/anime_manga_settings.dart`
- `lib/screens/settings/list_prefs_settings.dart`
- `lib/screens/settings/prefs/**`
- `test/units/app-shell/app_routes_test.dart`
- `lib/l10n/units/tracker-wiring/**`
- `test/units/tracker-wiring/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Notifications: when the active tracker is AniList, Kitsu or Simkl, feed the planner with that tracker's Watching / Plan to watch candidates (`AnilistListService.airingCandidates()`, `KitsuLibrary.instance.airingCandidates()`, the Simkl equivalent from simkl-pages) — entries are mapped to MAL ids, so the calendar's AiringSchedule works for them.
- Profile routes: `AppRoutes.openUserProfile` / `openUserStats` (`_hasProfileScreen`) open the real AniList / Kitsu / Simkl profile screens (other users included where the tracker allows it) instead of the stub.
- Tracker entry editor (lib/widgets/user/sync/**, `showTrackerEntryEditor`): add a confirmed 'Remove from list' action for AniList, Kitsu and Simkl (owner decision).
- Preference pages: when the active tracker is not MAL, mark MAL-only options (NSFW, priority, airing info, auto dates, MAL statuses…) with a visible translated note (owner decision).
- Never write to the owner's trackers in tests (fakes only).

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
- Checker: switch to AniList on the emulator, open a profile link and a list entry editor (cancel); notifications settings show AniList candidates.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
