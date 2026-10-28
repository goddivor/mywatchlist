# Handoff — `profile-tabs`: Profile tabs (Friends, Clubs, History) never hang: timeout + MAL page fallback

**Kind** unit · **Priority** P0 · **Group** user · **Model** sonnet

## Needs done first
- `profile-polish` (Profile screen: readable themed header, chart colours from status tokens, lighter surfaces, no Jikan wait)
- `backend-parsers` (mwl-api: port DAL's missing routes and HTML parsers)

## Owns (may create or edit ONLY these)
- `lib/screens/user_profile/sections/**`
- `lib/services/api/mwl_api.dart`
- `mwl-api/**`
- `lib/services/api/MAL/scrapper/user_friends.dart`
- `lib/services/api/MAL/scrapper/user_history.dart`
- `lib/l10n/units/profile-tabs/**`
- `test/units/profile-tabs/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner's screenshot: the profile Friends tab spins forever on 'Loading profile…'. friends_section.dart calls `MwlApi.getUserFriends`, which goes through an mwl-api route (Jikan-backed) with no timeout; Jikan is unreachable on the owner's network, so no error ever shows. Same risk for Clubs and History.
- Every profile tab ends in content, an empty state or an error with Retry within ~12 s: client timeouts on these MwlApi calls; read friends / clubs / history from MAL's own profile pages (myanimelist.net/profile/<name>/friends, /clubs, /history — parsers exist in lib/services/api/MAL/scrapper/ and mwl_commons) when Jikan fails or first; parse off the UI isolate.
- A tab never waits for the rest of the profile to load; translated states; theme tokens only.

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
- Tests with a failing fake Jikan: Friends / Clubs / History end in content or a state within the timeout.
- Checker: owner's profile Friends tab loads on his network.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
