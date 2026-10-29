# Handoff — `anilist-list-design`: AniList list and list rows redesigned from the AniList UI reference

**Kind** unit · **Priority** P1 · **Group** trackers · **Model** opus

## Needs done first
- `anilist-list-fidelity` (anilist-list-fidelity)
- `anilist-media-page` (anilist-media-page)

## Owns (may create or edit ONLY these)
- `test/units/mal-list-time/list_time_test.dart`
- `lib/widgets/user/list/list_entry_view.dart`
- `lib/pages/Anilist/anilist_user_page.dart`
- `lib/widgets/Anilist/list/**`
- `lib/widgets/Anilist/anilist_user_list_adapter.dart`
- `lib/l10n/units/anilist-list-design/**`
- `test/units/anilist-list-design/**`
- `test/units/anilist-list-design/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- From tracker-list-hooks (#315): override AnilistUserListAdapter.userScore / communityScore with the account's score format (POINT_100, POINT_10_DECIMAL, POINT_10, POINT_5 stars, POINT_3 faces) and percentages for the community score (checker batch 4: AniList cards always show 0-10); move anilist_list_view.dart:719 and test/units/mal-list-time/list_time_test.dart to listTimeSummary, then delete ListTimeSummary.of.
- Redesign the AniList list (My List and other users' lists) from the AniList part of docs/tracker-ui-references.md, sections 'My List' and 'Score display rules': custom lists, the user's score format everywhere, the label rail (format · 'Ep N in Xd' · 'N behind' · status), title scores as percentages.
- Owner rule 2026-10-29: each tracker is its own app; DailyAL's UI is the reference for MAL only. Follow the matching section of docs/tracker-ui-references.md (recommended block order and the data field behind each block); own files and own layout; every item opens this tracker's native page. No explanatory captions; theme tokens; English + French; fakes only in tests.

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
- Tests on saved AniList responses; before/after screenshots at 360 dp in the PR.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
