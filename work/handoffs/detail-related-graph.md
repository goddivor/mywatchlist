# Handoff — `detail-related-graph`: Related: view-all grid with statuses and the relation graph (share as PNG)

**Kind** unit · **Priority** P1 · **Group** detail · **Model** sonnet

## Needs done first
- `detail-split` (Split the 1852-line detail screen into sections with seams)
- `shared-kit` (Shared UI kit: share builder, app bar menu, select widgets, score reveal, web launcher)
- `user-list-mal` (MAL user anime/manga list (status tabs, sort/filter, view modes, status cache))

## Owns (may create or edit ONLY these)
- `lib/widgets/MAL/content/relatedanimewidget.dart`
- `lib/widgets/graph/**`
- `lib/l10n/units/detail-related-graph/**`
- `test/units/detail-related-graph/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Implement the stubbed graph (`_setAnimeGraph` empty l.61, `_animeGraph` returns SizedBox l.77-79) with graphview via the backend `getAnimeGraph`; node layout, order types, long-press to select/reposition; share graph as PNG with branding; view-all grid showing list statuses (status cache).

## Known bugs to fix in scope
- none

## DailyAL reference (read, never copy blindly)
Checkout: `/home/thinkpad/.cache/mwl-mab/dailyal-108` (DAL `upstream/2026.2.6+108`, read-only).
- `lib/widgets/anime_graph.dart`
- `lib/pages/animedetailed/relatedanimewidget.dart`
- `commits e773650 (graph node select, share PNG), db3355e (graph toggle)`

Port the behaviour into MWL's architecture: BLoC for app-wide state, Provider/ChangeNotifier user singletons, MWL's service layer (`lib/services/api/**`), `S` strings via your l10n fragment, multi-tracker awareness (never assume the active account is MAL without checking).

## Inventory
`work/inventory/*.md` lists, per feature, what MWL has and the bugs found on 2026-10-27.

**UI directive (owner's rule).** MWL's current UI is NOT the reference: the owner wrote it early and calls parts of it badly done. For every screen you touch, read the DAL equivalent's UI code, keep whichever is better (often DAL's), and improve it (hierarchy, spacing, empty/loading/error states, no dead buttons). Stay consistent with the theme system in `lib/user/theme/` (accent color, fonts, dark/black modes). Describe the before/after in the PR body.

## Definition of Done
- Graph renders for a franchise with many entries (e.g. Monogatari) on the emulator.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
