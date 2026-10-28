# Handoff — `explore-polish`: Explore: DailyAL images on category and genre cards, explicit genres, recommendations/stacks fallbacks, favourites badges

**Kind** unit · **Priority** P1 · **Group** discovery · **Model** opus

## Needs done first
- `explore-seasonal` (Explore page and seasonal screen)
- `home-wiring` (Home: working chips, bookmarks/calendar buttons, maintenance dialog, user-list and forum sections)
- `profile-tabs` (Profile tabs (Friends, Clubs, History) never hang: timeout + MAL page fallback)

## Owns (may create or edit ONLY these)
- `lib/pages/MAL/mal_explore_page.dart`
- `lib/screens/explore/**`
- `assets/images/explore/**`
- `pubspec.yaml`
- `lib/cache/top_characters.dart`
- `lib/l10n/units/explore-polish/**`
- `test/units/explore-polish/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner's screenshots of the Explore page: (1) Recommendations 'Couldn't load this section' and Interest Stacks 'Nothing to show right now' — wire the new MwlApi global recommendations / interest stacks methods (profile-tabs PR) as the source when Jikan fails (or first), with clean states; (2) Characters and Seiyuu cards: add a ♥ favourites badge (number of people who favourited the character / person, from the top characters/people data); (3) the Seasonal card's 'Search By Season' button text is truncated ('Search By Se…'): redo the layout so both buttons show their full label in every language and width; (4) Genres: the Explicit genres type is missing — add it (anime and manga, respecting the NSFW pref for visibility/blur as appropriate).
- Images like DailyAL (owner request): every category / ranking card and every genre card shows its background picture, as DailyAL does. DailyAL's pictures live in its MIT-licensed repo (`web_assets/`, ~6 MB: `<type>_<category>.jpg` for rankings, `web_assets/genres/<id>_<category>.jpg`); our repo is private, so BUNDLE them as app assets under assets/images/explore/ (copy from /home/thinkpad/.cache/mwl-mab/dailyal-108/web_assets, declare the folders in pubspec.yaml, credit DailyAL via LicenseRegistry with its MIT text). Text on the pictures stays readable through the scrim token; decode at card size (AppImage / ResizeImage) so scrolling stays smooth.
- Theme tokens only; full translatability (English + French).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/search/all_genre_widget.dart`
- `lib/pages/search/allrankingwidget.dart`
- `web_assets/ (category and genre images, MIT)`
- `lib/pages/explorepage.dart`

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
- Checker: Explore on the owner's network — recommendations and stacks show content, character/seiyuu cards show ♥ counts, seasonal buttons fully readable, genre and category cards with pictures like DailyAL, Explicit genres present.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
