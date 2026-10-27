# Handoff — `list-cards-dal`: My List: the same UI as DailyAL for every display type (header, tabs, toolbar, cards)

**Kind** unit · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))
- `theme-colors` (Theme colours: status bar, coherent accents per theme, colour tokens, contrast)

## Owns (may create or edit ONLY these)
- `lib/pages/MAL/mal_user_page.dart`
- `lib/widgets/user/list/**`
- `lib/widgets/common/list_sort_filter.dart`
- `lib/user/list_cache/**`
- `lib/l10n/units/list-cards-dal/**`
- `test/units/list-cards-dal/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- OWNER'S EXPLICIT RULE for this screen (overrides the generic 'compare and improve' directive): the My List screen must have THE SAME UI AS DAILYAL, for EVERY display type (grid, list, compact, comfortable, cover only, spacious, custom). Reproduce DailyAL's layout faithfully, in MWL's architecture (BLoC/ChangeNotifier as today, MWL theme colours via colorScheme + status tokens, S strings): read lib/pages/userpage.dart and lib/widgets/user/contentlistwidget.dart in DailyAL and match them screen element by screen element.
- PRIORITY (owner, after seeing MWL vs DailyAL): what matters most is the RENDERING of each display type — MWL's current rendering is completely different from DailyAL's and the owner finds it frustrating, especially the GRID displays. Start with the grid modes (card proportions, cover ratio, spacing between cards, the score/status bar under the cover, title + genres below, badge placement, corner radius, elevation/border exactly like DailyAL), then list, compact, comfortable, cover-only, spacious. Compare screenshots of both apps mode by mode in your PR body (describe them; the checker takes the real ones).
- Header like DailyAL: Anime | Manga segmented toggle on the left, action icons on the right (search, bookmarks, calendar, settings as DailyAL places them on this page); status tabs labelled like DailyAL `All (2315)`, `Watching (202)`… (count in parentheses, underline indicator in the accent); a toolbar row with DailyAL's search pill on the left and the refresh + filter pill on the right.
- Grid card like DailyAL (owner's screenshot): clean rounded cover with no text on the image; directly under it a compact bar — left ★ mean score (or '-'; hide-score tap-to-reveal respected); right a coloured status chip (CW / CMPL / OH / DR / PTW, colour from the theme-colors status tokens) containing the edit pencil; then the title on one line with ellipsis, then the genres in small text on one line; small badges top-right on the cover (e.g. unseen/behind counts) as DailyAL does. List, compact, comfortable, cover-only and spacious modes: copy DailyAL's version of each mode.
- Keep MWL's working behaviour underneath: tracker-agnostic ListEntryView + UserListAdapter (AniList/Kitsu/Simkl reuse it), status cache, pagination/whole-list rules, edit sheet on pencil / long press, +1/-1 where DailyAL shows it, sort/filter options, custom card layouts (DailyAL's layout is the default).
- Fluidity: AppImage at card size, no per-card Opacity/ClipRRect/blur, fixed extents where possible; readable chips and text in light, dark and black.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/userpage.dart`
- `lib/widgets/user/contentlistwidget.dart`
- `lib/user/contentbuilder.dart`
- `lib/widgets/home/animecard.dart`
- `lib/widgets/home/nodebadge.dart`
- `lib/widgets/listsortfilter.dart`
- `lib/widgets/user/customizedlist.dart`

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
- Checker: side-by-side screenshots of MWL My List vs DailyAL on the owner's account in EVERY display type — same structure element by element.
- Widget tests per display type (renders score/status/title/genres), hide-score, French labels.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
