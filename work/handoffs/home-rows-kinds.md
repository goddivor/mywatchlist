# Handoff — `home-rows-kinds`: Home OVA/ONA and manhwa/manhua/novel ranking rows (H3) with tracker cases

**Kind** unit · **Priority** P1 · **Group** discovery · **Model** sonnet

## Needs done first
- `home-rows` (Home rows honour the 30-item slider; OVA/ONA and manhwa/manhua/novel rows)

## Owns (may create or edit ONLY these)
- `lib/user/MAL/mal_home_page_preferences.dart`
- `lib/user/requests/requests_bloc.dart`
- `lib/screens/settings/mal_home_settings.dart`
- `lib/widgets/Anilist/anilist_home_sections.dart`
- `lib/widgets/Kitsu/kitsu_rows.dart`
- `lib/widgets/Simkl/simkl_home_plan.dart`
- `lib/l10n/units/home-rows/**`
- `test/units/home-rows/**`
- `test/units/home-rows-kinds/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- home-rows PR #218 held back H3: restore it with `git revert ed2c93e` (commit 4de52f9 added the 10 DailyAL ranking kinds with titles, icons, strings and tests), then add the cases the new SectionType values need in the three tracker files: AniList formats OVA, ONA, ONE_SHOT, NOVEL and country of origin KR/CN for manhwa/manhua; Kitsu matching subtypes; Simkl has no feed — skip/hide them there. Read PR #218's body.
- Owner rules: replicate DailyAL; no explanatory captions; theme tokens; English + French.

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
- Tests: each new kind renders on MAL and maps (or is hidden) on AniList, Kitsu, Simkl.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
