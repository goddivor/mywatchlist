# Handoff — `color-sweep`: Colour sweep: hardcoded colours of already-merged screens onto the theme tokens

**Kind** unit · **Priority** P1 · **Group** release · **Model** sonnet

## Needs done first
- `profile-polish` (Profile screen: readable themed header, chart colours from status tokens, lighter surfaces, no Jikan wait)
- `list-cards-dal` (My List grid display: the same visual as DailyAL's grid (the rest of MWL's My List stays))
- `detail-resilience` (Detail sections: no endless skeletons, MAL fallbacks when Jikan fails, round avatars without box shadows)
- `home-wiring` (Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections)
- `featured-characters` (Featured tags search, character screen sort/dedupe/bookmark/share)
- `dub-info` (Dub info (MyDubList): icons, languages, settings)
- `detail-more-info` (More-info links: studios, magazines, authors, genres, season, media type)
- `settings-theme-about-backup` (About, backup & restore, clear storage)
- `in-app-update` (In-app update: check GitHub releases, download and install APK)
- `forum-clubs` (Forum posting, profile links, club members in-app)
- `search-upgrade` (Search: user results, search by id, autocomplete, searchable filters)
- `theme-colors` (Theme colours: status bar, coherent accents per theme, colour tokens, contrast)
- `cards-upgrade` (Anime cards: quick edit, status badges, score reveal, real airing progress)
- `detail-header` (Detail header and actions: share, browser, bookmark, More Info, hide score, custom tabs, countdown)
- `detail-social` (Reviews AI summary + share, interest stacks and user updates linking to profiles)
- `detail-related-graph` (Related: view-all grid with statuses and the relation graph (share as PNG))
- `detail-synopsis-media` (Synopsis translation, streaming links, videos fallback)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `user-profile-mal` (MAL user profile, stats charts and user pop-up)
- `edit-sheet` (Edit-entry sheet: fix pre-fill, dates, episodes, private notes)
- `sync-dialog` (Cross-tracker sync: two-way dialog, cancel, lazy load, decimal scores)
- `bookmarks` (Bookmarks: store, screen, add/remove)
- `calendar` (Anime calendar, weekly schedule, .ics export, add to device calendar)
- `explore-seasonal` (Explore page and seasonal screen)
- `settings-prefs-pages` (Settings pages: user prefs, anime/manga, list prefs)
- `accounts-ux` (Redesign the account picker, account switcher and account management)
- `app-shell` (App shell seams: settings hub, sidebar, home shell, startup)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `notifications` (Airing notifications)

## Owns (may create or edit ONLY these)
- `lib/widgets/MAL/home/**`
- `lib/widgets/MAL/content/**`
- `lib/widgets/MAL/review/**`
- `lib/widgets/user/**`
- `lib/widgets/charts/**`
- `lib/widgets/bookmarks/**`
- `lib/widgets/calendar/**`
- `lib/widgets/common/**`
- `lib/screens/MAL/**`
- `lib/screens/explore/**`
- `lib/screens/seasonal/**`
- `lib/screens/calendar/**`
- `lib/screens/user_profile/**`
- `lib/screens/settings/**`
- `lib/screens/bookmarks_screen.dart`
- `lib/pages/side_bar.dart`
- `lib/constants/constants.dart`
- `lib/l10n/units/color-sweep/**`
- `test/units/color-sweep/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Replace every hardcoded `Colors.*` / `Color(0x…)` in the owned screens with `colorScheme` roles or the app_colors tokens (theme-colors), except intrinsic content colours (e.g. a tracker's brand logo) — list those exceptions in the PR body.
- Check each screen in light, dark and black themes for contrast: no button, chip, badge or coloured area where the text is unreadable (owner's complaint); text on images uses the scrim token; no light surface left in dark mode.

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
- `grep -rnE "Colors\.|Color\(0x" lib/<owned>` only shows the documented exceptions.
- Checker: screenshots in light/dark/black of each touched screen.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
