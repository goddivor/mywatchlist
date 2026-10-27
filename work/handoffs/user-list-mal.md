# Handoff — `user-list-mal`: MAL user anime/manga list (status tabs, sort/filter, view modes, status cache)

**Kind** screen · **Priority** P0 · **Group** user · **Model** opus

## Needs done first
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `edit-sheet` (Edit-entry sheet: fix pre-fill, dates, episodes, private notes)

## Owns (may create or edit ONLY these)
- `lib/pages/MAL/mal_user_page.dart`
- `lib/widgets/user/list/**`
- `lib/widgets/common/list_sort_filter.dart`
- `lib/user/list_cache/**`
- `lib/l10n/units/user-list-mal/**`
- `test/units/user-list-mal/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Replace the placeholder MAL user page with the full list: anime/manga, status tabs (respecting the custom list tabs pref), sort & filter popup, grid/list + compact/comfortable/cover-only/spacious view modes, custom card layout editor (card view props pref), show priority, airing info, hide-score reveal, pull to refresh, pagination, quick edit opening the edit sheet.
- User list status cache with persistence (DAL b490f94/5f1a965): `lib/user/list_cache/` exposes the status of any id so cards elsewhere can show badges. This cache is a shared shape for cards-upgrade: document its API in the PR body.
- Design the list widgets tracker-agnostic (a list-entry view model) so the AniList/Kitsu/Simkl units reuse them.

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/pages/userpage.dart`
- `lib/widgets/user/contentlistwidget.dart`
- `lib/user/contentbuilder.dart`
- `lib/widgets/listsortfilter.dart`
- `lib/user/userlistcache.dart`
- `lib/widgets/user/customizedlist.dart`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- The owner's real MAL list loads on the emulator, all statuses, sort and filters work.
- Status cache survives restart.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
