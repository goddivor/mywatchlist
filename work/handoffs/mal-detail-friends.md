# Handoff — `mal-detail-friends`: MAL detail page: friends' scores and statuses (Friends / Top friends / Everyone)

**Kind** unit · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `mal-polish-2` (MAL polish 2: Settings > Accounts uses the new page, Supporter badge for others, time zone in About, dead TrackerTile, cancelled MAL re-login keeps the session)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/detail/sections/user_updates_section.dart`
- `lib/services/api/MAL/web/friends_updates_api.dart`
- `lib/l10n/units/mal-detail-friends/**`
- `test/units/mal-detail-friends/**`
- `test/units/mal-detail-friends/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner request 2026-10-30 (like the official MAL app's friend feed on a title page): on the MAL detail page, the 'Recently Updated By' section (user_updates_section.dart) gets tabs Friends / Top friends / Everyone. Friends and Top friends come from MAL's own stats page with the website session (MalWebClient GET /{anime|manga}/{id}/_/stats, default = My Friends, ?m=top = My Top Friends; table 'Recently Updated By': member + avatar, score, status, eps seen (or chapters for manga), activity date), checked live by the orchestrator on the owner's account (One Piece: Ma1cus 10 On-Hold 1156 / ?, …). Everyone keeps the current source. Default tab: Friends when the MAL session is active and the friends table is not empty, else Everyone; without a session the tabs are hidden. Rows open the friend's profile; status uses the status colour tokens; DailyAL-style rows (check DailyAL for the members table look).
- Fakes only in tests (a saved stats page with the friends table, trimmed from the live page). Never write to MAL.

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
- Tests: friends rows parsed from a saved page (anime and manga), tabs and default, hidden without a session, row opens the profile.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
