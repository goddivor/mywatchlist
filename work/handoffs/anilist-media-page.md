# Handoff — `anilist-media-page`: anilist-media-page

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** opus

## Needs done first
- `anilist-list-fidelity` (anilist-list-fidelity)
- `anilist-people-pages` (anilist-people-pages)
- `anilist-social` (anilist-social)

## Owns (may create or edit ONLY these)
- `lib/widgets/Anilist/anilist_user_list_adapter.dart`
- `lib/pages/Anilist/anilist_media_page.dart`
- `lib/services/api/Anilist/anilist_media_detail.dart`
- `lib/widgets/Anilist/media/**`
- `lib/widgets/Anilist/anilist_media_card.dart`
- `lib/l10n/units/anilist-media-page/**`
- `test/units/anilist-media-page/**`
- `lib/l10n/units/anilist-media-page/**`
- `test/units/anilist-media-page/**`
- `test/units/anilist-media-page/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner bug 2026-10-29: AniList list rows open the MAL detail page (or anilist.co when unmapped). Every AniList entry point (list adapter open(), home cards, search results, related, recommendations, people pages) opens the native AniList title page, mapped to MAL or not; one helper (openAnilistTitle) used everywhere.
- Audit docs/anilist-report-2026-10-28.md, unit `anilist-media-page`: A1-A21: native title page reusing the MAL detail layout and widgets by import only (section frame, header, stats widgets), "Open on MyAnimeList", favourite heart, my entry through `showAnilistEntryEditor`, reviews section → `AnilistReviewPage`, characters / staff / studios → people pages, recommendation votes and submit; `openAnilistMedia` now always opens this page Read the matching report items (queries/endpoints, samples, file:line) and implement them.
- Owner rules: every tracker gets everything its API allows (never capped at MAL); Each tracker is its own app (owner, 2026-10-29): design this tracker's screens from its own data and from the popular third-party apps built on it (docs/tracker-ui-references.md), in their own files; DailyAL's UI is the reference for MAL screens only. Every item of this tracker (list rows, home cards, search results, related, recommendations) opens this tracker's native page, never the MAL page, mapped or not; no explanatory captions; theme tokens; English + French. Never write to the owner's accounts in tests (fakes).

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
- Offline tests on saved responses; checker on the owner's account (read-only).
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
