# Handoff — `simkl-data-plus`: Simkl: full CDN fields, next_to_watch_info, external ids, title language, calendar route, check-in

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** sonnet

## Needs done first
- `simkl-redesign` (Simkl screens redesigned from the Simkl UI reference: title page, home, explore/calendar, profile, list rows)

## Owns (may create or edit ONLY these)
- `lib/services/api/SimKl/**`
- `lib/pages/Simkl/**`
- `lib/widgets/Simkl/**`
- `lib/utils/app_routes.dart`
- `lib/l10n/units/simkl-data-plus/**`
- `test/units/simkl-data-plus/**`
- `test/units/simkl-data-plus/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Findings from simkl-redesign (#298): (1) simkl_cdn.dart _media() drops watcher counts, drop rate, rank, fanart, finale flag, network and episode total from the CDN feeds: parse them so the trending watcher counts, carousel fanart and real Premiere/Finale badges show (the UI already renders them when present). (2) SimklListService requests and parses next_to_watch_info and uses it instead of the on-device computation. (3) SimklTitle keeps every external id (AniList, Kitsu, IMDb, TMDB, AniDB…) for a link row on the title page; UserProfSimkl reads anime_title_language and titles follow it. (4) The home app bar's calendar icon routes Simkl accounts to SimklCalendarPage (AppRoutes.openCalendar). (5) Check-in ('Watching now'): /scrobble/checkin service + the title page action, and long-press to mark watched in the calendar.
- Owner rule: each tracker is its own app; design per the Simkl part of docs/tracker-ui-references.md. Respect Simkl's API limits. Never write to the owner's Simkl account from tests: fakes only.

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
- Tests on saved Simkl responses: CDN fields parsed, next_to_watch_info used, ids row, calendar route, check-in request (fake).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
