# Handoff — `mal-graph-local`: MAL relation graph built in the app (no backend needed)

**Kind** unit · **Priority** P0 · **Group** trackers · **Model** opus

## Needs done first
- `mal-hub-followups` (MAL hub follow-ups: in-app thread on message tap, JSON posts through postJson, message poller next to the hub poller)

## Owns (may create or edit ONLY these)
- `lib/widgets/graph/**`
- `lib/services/api/MAL/anime_graph_builder.dart`
- `lib/l10n/units/mal-graph-local/**`
- `test/units/mal-graph-local/**`
- `test/units/mal-graph-local/**`

Plus `PROJECT-STATE.md` (rewrite in place, within its cap) and `docs/DECISIONS.md` (append one line per decision). Anything else you need is a FINDING to report, never an edit.

## Goal
- Owner report 2026-10-30: the MAL anime relation graph never works. Cause (checked by the orchestrator): AnimeGraphScreen loads it from the self-hosted mwl-rust-api (GET {API_URL}/anime/{id}/related with API_SECRET) and API_URL is empty in assets/.env, so the request is never sent and the screen fails. Build the graph inside the app instead, with the same algorithm as mwl-rust-api/src/anime_service.rs (get_related_anime_with_graph): start from the title, MAL API v2 /anime/{id}?fields=related_anime,... (MalApi, the app's client id / user token), follow valid relation types (the root also includes 'other' relations, the others do not, as valid_relation does), BFS with 5 requests at a time, skip visited nodes, produce the same nodes/edges JSON shape AnimeGraphData.fromJson reads. Bound it (e.g. 120 nodes, stop politely on 429 with what is loaded), cache per title (session + disk, a few days), show progress while it grows. Keep the Rust API as an optional first source when API_URL is set and answers; otherwise the local builder.
- Fakes only in tests (saved MAL related_anime answers).

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
- Tests on saved MAL answers: graph nodes/edges match the Rust algorithm (root other relations, no others after), bounds and 429 stop, cache; the screen loads without API_URL.
- `tools/heavy.sh flutter analyze` clean (the gate runs the full `tools/heavy.sh tools/verify.sh`).
- PR against `dev` with `Closes #<issue>`, gate tail, decisions, findings.
