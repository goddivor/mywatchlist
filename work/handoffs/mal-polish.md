# Handoff — `mal-polish`: MAL polish: Accounts caption, MAL session from its tile, active account after the website login, bell label, Clubs row, Supporter badge for others, time zone in About

**Kind** unit · **Priority** P1 · **Group** user · **Model** sonnet

## Needs done first
- `mal-hub-followups` (MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller)

## Owns (may create or edit ONLY these)
- `lib/screens/manage_accounts_page.dart`
- `lib/user/accounts/**`
- `lib/widgets/MAL/home/homeappbar.dart`
- `lib/screens/MAL/detail/sections/forums_section.dart`
- `lib/services/api/MAL/scrapper/user_profile_page.dart`
- `lib/screens/user_profile/sections/about_section.dart`
- `lib/widgets/user/profile/profile_header.dart`
- `lib/l10n/units/mal-polish/**`
- `test/units/mal-polish/**`
- `test/units/mal-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner-visible leftovers (2026-10-29): (1) Settings > Accounts shows the caption 'The active account decides which tracker the home, your list and your profile show…' that DailyAL lacks: remove it; (2) the MyAnimeList website session page opens from the MyAnimeList account tile (its menu), not from a separate row above the list; (3) seen on the emulator: after the MAL website login and back presses, the home showed the AniList account (no bell) while Accounts said MAL active, tapping MAL restored it: find why the active account and the home disagree after MalSession login and fix it, with a test; (4) the MAL bell's accessibility label is only the count ('25'): 'Notifications, 25 unread'; (5) W11: a 'Clubs' row in the detail Forums section using scrapper/title_clubs.dart (TitleClubs.fetch), DailyAL-style; (6) the Supporter badge for other users from the .icon-supporter marker of their profile page (user_profile_page.dart); (7) the time zone moves from the header line into the About block, labelled.
- Owner rules: each tracker is its own app (docs/tracker-ui-references.md); MAL screens follow DailyAL; no explanatory captions DailyAL lacks. Fakes only in tests; writes only on the viewer's tap.

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
- Tests per item; the account-state test reproduces the mismatch first.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
