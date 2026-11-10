# Handoff — `search-sources`: Search: every filter returns data without Jikan (MAL search page fallback, live-verified) + studios directory with logos

**Kind** unit · **Priority** P0 · **Group** discovery · **Model** opus

## Needs done first
- `search-upgrade` (Search: user results, search by id, autocomplete, searchable filters)
- `profile-tabs` (Profile tabs (Friends, Clubs, History) never hang: timeout + MAL page fallback)

## Owns (may create or edit ONLY these)
- `lib/screens/search/**`
- `lib/widgets/MAL/search/**`
- `lib/screens/studios/**`
- `mwl-api/**`
- `lib/services/api/mwl_api.dart`
- `lib/services/api/MAL/scrapper/mal_scrapper.dart`
- `tools/search-live/**`
- `lib/l10n/units/search-sources/**`
- `test/units/search-sources/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner: filtering the anime search by a producer/studio (e.g. Arch) shows 'Couldn't load the results. Check your connection' — filtered searches go through Jikan, unreachable on his network, and the official MAL API only searches by name, rankings and seasons. A specific filter like a studio must return data; only absurd filter combinations may return nothing; never a connection error when the network works.
- AUDIT AND FIX EVERY SEARCH PATH (anime and manga): text, genres/themes/demographics (include/exclude), producers/studios/licensors, magazines, season/year, type, status, rating, score min/max, start/end dates, sort/order, pagination. For each, a source that works without Jikan: the official MAL API where it can, else MAL's own search page (https://myanimelist.net/anime.php with q, type, score, status, p, r, sm/sd/sy, em/ed/ey, c[], gx, genre[], o, w, and the /anime/producer/<id>, /anime/genre/<id>, /manga/magazine/<id> pages) scraped through mwl-api routes with HTML fixtures; Jikan only as a fast path when it answers. Translate MWL's filter model to these URLs exactly.
- LIVE VERIFICATION (owner: test every scraping method, it must return data): a script in tools/search-live/ that runs each filter once against the real MAL site (rate-limited, at most 1 request per second) and prints filter → result count; every single filter (studio Arch, a genre, a magazine, a season, each type/status/rating…) must return more than 0. Paste its full output in the PR body. Unit tests stay offline (fixtures).
- STUDIOS DIRECTORY (owner request): lib/screens/studios/studios_screen.dart (`StudiosScreen`) listing ALL studios with their NAME and LOGO (the mwl-api `studios` route + MAL producer pages / company logos — the owner's existing scraping in mwl-api and lib/services/api/MAL/scrapper/mal_scrapper.dart fetched the images: read it, fix it, test it live), infinite scroll (loads more when scrolling down), search box, tap → `GeneralSearchScreen.byStudio` (the anime of that studio). explore-polish adds the Explore entry button — document the constructor in the PR body.
- Error states say what failed (no network vs source failed vs no result), translated; theme tokens only; AppImage at tile size; parse off the UI isolate.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/generalsearchscreen.dart`
- `dal-api/ search routes`

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
- tools/search-live output in the PR: every filter returns more than 0 results.
- Checker: studio Arch and a genre filter return anime on the owner's network; the studios directory scrolls with logos and opens the filtered search.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
