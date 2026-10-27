# Handoff — `detail-resilience`: Detail sections: no endless skeletons, MAL fallbacks when Jikan fails, round avatars without box shadows

**Kind** unit · **Priority** P0 · **Group** detail · **Model** opus

## Needs done first
- `detail-header` (Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown)
- `detail-social` (Reviews AI summary + share, interest stacks and user updates linking to profiles)
- `cards-upgrade` (Anime cards: quick edit, status badges, score reveal, real airing progress)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/detail/sections/**`
- `lib/screens/MAL/detail/pages/**`
- `lib/widgets/MAL/content/scorestatisticswidget.dart`
- `lib/widgets/MAL/content/animestatisticswidget.dart`
- `lib/widgets/MAL/content/userupdate_widget.dart`
- `lib/widgets/MAL/content/show_forum.dart`
- `lib/widgets/MAL/content/show_reviews.dart`
- `lib/widgets/MAL/content/show_featured.dart`
- `lib/widgets/MAL/content/intereststackwidget.dart`
- `lib/widgets/MAL/home/animecharacterwidget.dart`
- `lib/screens/MAL/characters_staff_screen.dart`
- `lib/services/api/Jikan/**`
- `lib/l10n/units/detail-resilience/**`
- `test/units/detail-resilience/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner's screenshots of an anime detail page (Shuiro no Kamen): Score Stats shows grey placeholder bars forever, User Updates shows skeleton cards forever, Forums and Reviews show 'Failed to load'. Jikan (api.jikan.moe) is unreachable from the owner's network (the checker saw a 134 s timeout). The page must still be useful.
- Every Jikan call gets a timeout (e.g. 12 s) in lib/services/api/Jikan/jikan_client.dart (issue #118 item). Every detail section has exactly one of: content, a translated empty state, or a translated error with Retry — never an endless skeleton.
- Fallback sources when Jikan fails: statistics and score distribution from the official MAL API fields where available and/or the mwl-api MAL page parsers (backend-parsers: stats/reviews/forum parsers through MwlApi); forum topics from the MAL forum API (lib/services/api/MAL/mal_forum_api.dart, read only) or the mwl-api forum parser; reviews from the mwl-api `reviews` route; user updates from the mwl-api if a parser exists, else a clean empty/error state. Document which source each section uses in the PR body.
- Owner: 'I only want the circular image — why is there always a weird rectangular shadow behind it?' Staff and character avatars (and the placeholder avatar) must be a clean circle with NO rectangular BoxShadow / Material elevation / grey box behind; same clean treatment for interest-stack posters (intereststackwidget.dart:165 has a blurRadius 10 shadow) and characters_staff_screen.dart:557 elevation. Use AppImage + ClipOval/CircleAvatar, theme colours only.
- Score Stats empty bars: when there is no data, show the empty state instead of grey bars; when there is data, bars use the theme accent with readable labels (colour rule).

## Known bugs to fix in scope
- endless skeletons on Jikan failure
- no Jikan timeout
- rectangular shadow behind round avatars
- heavy shadow on stack posters

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- none

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
- Widget tests with a failing fake Jikan: each section ends in content (fallback) or an error/empty state within the timeout.
- Checker: the Shuiro no Kamen page with Jikan unreachable shows fallbacks or clean states; avatars are clean circles in light/dark.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
