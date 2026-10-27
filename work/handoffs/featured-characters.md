# Handoff — `featured-characters`: Featured tags search, character screen sort/dedupe/bookmark/share

**Kind** screen · **Priority** P2 · **Group** community · **Model** sonnet

## Needs done first
- `search-upgrade` (Search: user results, search by id, autocomplete, searchable filters)
- `bookmarks` (Bookmarks: store, screen, add/remove)
- `detail-synopsis-media` (Synopsis translation, streaming links, videos fallback)

## Owns (may create or edit ONLY these)
- `lib/screens/MAL/featured_screen.dart`
- `lib/widgets/MAL/content/show_featured.dart`
- `lib/widgets/MAL/content/show_forum.dart`
- `lib/widgets/MAL/content/show_news.dart`
- `lib/screens/MAL/character_screen.dart`
- `lib/screens/MAL/characters_staff_screen.dart`
- `lib/l10n/units/featured-characters/**`
- `test/units/featured-characters/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Featured tags tap → tag search (featured_screen.dart:281 `onTap: null`); character/person: sort voice roles by favorites (with rate-limit toast), dedupe, bookmark FAB, share, bio translation (translator widget).
- Character screen: CustomScrollView + slivers instead of an eager Column in SingleChildScrollView (:251-256); parse off the UI isolate (:129) — performance.md #9, #12.

## Known bugs to fix in scope
- featured tags not tappable

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/screens/featurescreen.dart`
- `lib/widgets/featured/tagswidget.dart`
- `lib/screens/characterscreen.dart`
- `commits 01d7daf, bf06d05`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body. **Strings:** every screen you own must be fully translatable — move its existing hardcoded literals (e.g. settings_page.dart:55,119, mal_home_page.dart:45-47, mal_home_page_preferences.dart:65) to `S` through your l10n fragment; the checker switches the app to French and flags any English left on your screens.

**Fluidity rules (owner's rule: MWL must feel as smooth as DailyAL).** See `docs/PERFORMANCE.md` once perf-foundation has merged, and `work/inventory/performance.md`.
- Network images only through `AppImage` (decode at displayed size); no `Image.network`.
- Long or unbounded lists: `ListView.builder`/slivers, never a `Column` of many children in a `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on repeated items or on whole pages during animations; use alpha colors / FadeTransition.
- No `setState` in scroll listeners; listeners added once and removed in dispose; dispose every controller you create.
- BlocBuilder/Consumer as low in the tree as possible, with `buildWhen`/`BlocSelector`/`context.select`; `const` constructors wherever possible.
- Heavy JSON/HTML parsing off the UI isolate (`Isolate.run`/`compute`); no sync storage reads in `build`; no `print` in hot paths.
- Look at how DAL makes the same screen fluid and do at least as well; the checker compares janky-frame % on a profile build.

## Definition of Done
- Tapping a featured tag opens tag search on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
