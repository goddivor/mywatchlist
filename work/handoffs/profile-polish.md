# Handoff — `profile-polish`: Profile screen: readable themed header, chart colours from status tokens, lighter surfaces, no Jikan wait

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `theme-colors` (Theme colours: status bar, coherent accents per theme, colour tokens, contrast)

## Owns (may create or edit ONLY these)
- `lib/screens/user_profile/**`
- `lib/widgets/user/profile/**`
- `lib/widgets/charts/**`
- `lib/pages/MAL/mal_user_profile_page.dart`
- `lib/l10n/units/profile-polish/**`
- `test/units/profile-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner's screenshots of his own profile, light Spring theme: 'the rendering / colours are too weird'. Seen: a dark teal gradient header block under a light theme; the app-bar title (username) dark on dark, invisible; tab labels dark grey on the dark header; the status bar barely readable; the 'Anime list' bars use arbitrary hardcoded colours (green, blue, orange, red, brown) unrelated to the theme; grey stat tiles inside grey cards look heavy; 'male' shown raw.
- Header: follow the theme (light header in light mode, dark in dark/black) or, when a profile background image is set, a proper scrim token so the title, tabs, icons and status bar are always readable; compare with DailyAL's profile header and keep the better. Collapsing app bar with an opaque themed background.
- Charts: status bars and score distribution use the theme-colors status tokens (watching/completed/on hold/dropped/plan) and the stats chart colour preference; labels readable; consistent with the list status chips.
- Surfaces: one level of card, no grey-in-grey stacks; spacing and typography consistent with the rest of the app (theme fonts).
- Issue #118 items for this screen: show the MAL `/users/@me` data immediately and merge Jikan when (if) it arrives (never wait minutes); French: gender localised (not raw 'male'), averages with the locale NumberFormat (8,90 in French), media types translated.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/user_profile.dart`
- `lib/widgets/user/user_header.dart`
- `lib/widgets/user/stats_screen.dart`
- `lib/user/charts/`

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
- Checker: screenshots of the own profile and a friend's profile in light, dark and black — readable header/title/tabs/status bar, chart colours = status colours.
- Widget tests: header readable (contrast) in light/dark, tokens used, French formatting.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
